extends Node3D

const PICKUP_RANGE := 2.05
const MINE_RANGE := 1.75
const SITE_RANGE := 2.3
const PORTAL_RANGE := 2.95
const DIRECTIONS := ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"]

@onready var player: RelayPlayer = $Player
@onready var hud: RelayHUD = $HUD

var audio := RelayAudio.new()
var rules := SupplyRules.new()
var survival := SurvivalRules.new()
var story := RelayStory.new()
var region: SurvivalRegion
var field: ResourceField
var raid: NightRaid
var opened: Dictionary = {}
var depleted: Dictionary = {}
var tree_deadlines: Dictionary = {}
var cleared_nests: Dictionary = {}
var magazine := RelayMagazine.new()
var road: RoadRun
var finale: PumpFight
var _finale_return: Dictionary
var _finale_exit_prompt := false
var _finale_last_health := 100
var _dialogue_site: RelaySite
var _dialogue_lines: Array
var _dialogue_page := 0
var _dialogue_stage := -1
var _crate_seed := 0
var _road_return: Dictionary
var _road_exit_prompt := false
var _road_last_health := 100

var _map_id := 0
var _station := SupplyRules.Station.HAND
var _input_queue: Array[StringName] = []
var _save_in := 20.0
var _trigger_held := false
var _last_health := SurvivalRules.PLAYER_MAX_HEALTH
var _mining_target: MineableOre
var _chop_target: HarvestTree
var _mouse_before_panel := Input.MOUSE_MODE_CAPTURED
var _restoring := true


func _ready() -> void:
	add_child(audio)
	get_tree().auto_accept_quit = false
	hud.recover_requested.connect(_recover)
	hud.gear.panel_requested.connect(_request_panel)
	hud.gear.station_requested.connect(_select_station)
	hud.gear.craft_requested.connect(_craft)
	hud.gear.equip_requested.connect(_equip)
	hud.gear.ration_requested.connect(_eat)
	hud.gear.travel_requested.connect(_travel)
	hud.gear.upgrade_requested.connect(_road_upgrade)
	hud.gear.road_leave_requested.connect(_leave_encounter)
	hud.gear.road_resume_requested.connect(_resume_encounter)
	hud.gear.dialogue_next_requested.connect(_next_dialogue)
	player.tool_impact.connect(_tool_contact)
	player.survivor.foot_planted.connect(func(point: Vector3, heavy: bool):
		audio.play_at(RelayAudio.Cue.FOOTSTEP, point, 1.0 if heavy else -3.0))
	rules.changed.connect(_refresh_bag)
	survival.player_health_changed.connect(_health_changed)
	survival.phase_changed.connect(_phase_changed)
	var saved := RelaySave.load_game()
	_restore(saved)
	_load_region(_map_id, saved.get("position", Vector3.INF))
	player.orbit.rotation.y = float(saved.get("facing", PI))
	player.model.rotation.y = player.orbit.rotation.y - PI
	var tool := int(saved.get("equipped", -1))
	if rules.has_tool(tool):
		player.equip(tool)
	_restoring = false
	_health_changed()
	_refresh_bag()
	_refresh_display()
	if saved.has("position"):
		_validate_saved_position.call_deferred()


func _validate_saved_position() -> void:
	await get_tree().physics_frame
	if survival.player_health <= 0:
		return
	var probe := CapsuleShape3D.new()
	probe.radius = 0.27
	probe.height = 1.49
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform.origin = player.global_position + Vector3.UP * 0.89
	query.collision_mask = 9
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		player.relocate(region.shelter)


func _restore(saved: Dictionary) -> void:
	rules.restore(saved)
	_crate_seed = int(saved.get("crate_seed",randi()))
	magazine.rounds = clampi(int(saved.get("magazine",0)),0,RelayMagazine.STANDARD_CAPACITY)
	if not saved.is_empty() and not saved.has("magazine") and rules.has_tool(SupplyRules.Tool.CARBINE):
		magazine.fill(rules)
	story.stage = clampi(int(saved.get("stage", 0)), 0, RelayStory.STEPS.size())
	var saved_map := int(saved.get("map", 0))
	_map_id = saved_map if story.unlocked(saved_map) else 0
	survival.day = maxi(1, int(saved.get("day", 1)))
	survival.phase = SurvivalRules.Phase.NIGHT if saved.get("night", false) else SurvivalRules.Phase.DAY
	var duration := SurvivalRules.NIGHT_SECONDS if survival.phase == SurvivalRules.Phase.NIGHT else SurvivalRules.DAY_SECONDS
	survival.remaining = clampf(float(saved.get("remaining", duration)), 0.05, duration)
	survival.elapsed = maxf(0.0, float(saved.get("elapsed", 0.0)))
	survival.player_health = clampi(int(saved.get("health", 100)), 0, 100)
	_last_health = survival.player_health
	opened = saved.get("opened", {})
	var now := int(Time.get_unix_time_from_system())
	for key in opened.keys():
		var opened_at: Variant = opened[key]
		if opened_at is bool and opened_at:
			opened[key] = now + SurvivalRegion.CRATE_REFILL_SECONDS
		elif int(opened_at) <= now:
			opened.erase(key)
	depleted = saved.get("depleted", {})
	tree_deadlines = saved.get("trees",{})
	cleared_nests = saved.get("cleared", {})


func _save(manual := false) -> void:
	if _restoring or road != null or not is_instance_valid(region):
		return
	if finale != null and finale.outcome != PumpFight.Outcome.WON:
		return
	_save_in = 20.0
	var data := {
		"version": 1, "map": _map_id, "stage": story.stage,
		"position": player.global_position, "facing": player.orbit.rotation.y,
		"equipped": player.equipped, "health": survival.player_health,
		"day": survival.day, "night": survival.phase == SurvivalRules.Phase.NIGHT,
		"remaining": survival.remaining, "elapsed": survival.elapsed,
		"items": rules.inventory, "tools": rules.tools, "stations": rules.stations,
		"opened": opened, "depleted": depleted, "cleared": cleared_nests, "trees": tree_deadlines,
		"crate_seed": _crate_seed, "magazine": magazine.rounds,
	}
	if finale != null:
		data.map = _finale_return["map"]
		data.position = _finale_return["point"]
		data.facing = _finale_return["facing"]
		data.equipped = _finale_return["tool"]
	if not RelaySave.store(data):
		hud.notify("无法写入存档")
	elif manual:
		hud.notify("进度已保存")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
		get_tree().quit()


func _load_region(map_id: int, point := Vector3.INF, arriving := false) -> void:
	_trigger_held = false
	if is_instance_valid(region):
		remove_child(region)
		region.queue_free()
	_map_id = map_id
	region = SurvivalRegion.new()
	add_child(region)
	region.build(map_id,opened,rules,_crate_seed,tree_deadlines)
	field = ResourceField.new(region, depleted)
	raid = NightRaid.new(region, player, cleared_nests)
	raid.enemy_struck.connect(func(at: Vector3): audio.play_at(RelayAudio.Cue.BLADE, at))
	var destination := region.arrival if arriving else region.shelter
	if point.is_finite() and absf(point.x) < 38 and absf(point.z) < 60 and point.y > -3 and point.y < 40:
		destination = point
	player.relocate(destination)
	_mining_target = null
	_chop_target = null
	_input_queue.clear()
	_refresh_display()


func _physics_process(delta: float) -> void:
	if _restoring:
		return
	if road != null:
		_tick_road(delta)
		return
	if finale != null:
		_tick_finale(delta)
		return
	if survival.player_health == 0 or hud.gear.active_panel == GearPanels.PanelKind.DIALOGUE:
		return
	survival.tick(delta)
	var daylight := survival.phase == SurvivalRules.Phase.DAY
	field.tick(survival.elapsed, daylight)
	region.tick_crates(int(Time.get_unix_time_from_system()))
	region.tick_trees(survival.elapsed)
	if not daylight:
		raid.tick(delta, survival)
	if survival.player_health == 0:
		return
	if player.global_position.y < -5.0:
		player.relocate(region.shelter)
	_maybe_autosave(delta)
	magazine.tick(delta,rules)
	_refresh_display()
	_refresh_magazine()
	if player.panel_open or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_input_queue.clear()
		hud.set_prompt("")
		return
	var target := _near_target()
	for action in _input_queue:
		match action:
			&"travel":
				if _near_portal():
					_request_panel(GearPanels.PanelKind.TRAVEL)
			&"interact":
				if is_instance_valid(target) and not target.is_queued_for_deletion():
					_interact(target)
			&"attack":
				_attack(target)
			&"craft_wood_pick": _craft(SupplyRules.Recipe.WOOD_PICK)
			&"craft_stone_pick": _craft(SupplyRules.Recipe.STONE_PICK)
			&"craft_stone_sword": _craft(SupplyRules.Recipe.STONE_SWORD)
	_input_queue.clear()
	if player.panel_open:
		return
	_repeat_fire()
	if is_instance_valid(target) and target.is_queued_for_deletion():
		target = null
	hud.set_prompt(_prompt(target))


func _maybe_autosave(delta: float) -> void:
	_save_in -= delta
	if _save_in <= 0.0:
		_save()


func _input(event: InputEvent) -> void:
	if event.is_action_released(&"attack"):
		_trigger_held = false
	if road != null:
		_road_input(event)
		return
	if finale != null:
		_finale_input(event)
		return
	if hud.gear.active_panel == GearPanels.PanelKind.DIALOGUE:
		if event.is_action_pressed(&"interact"):
			_next_dialogue()
		elif event.is_action_pressed(&"release_mouse"):
			_set_panel(GearPanels.PanelKind.NONE)
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if survival.player_health == 0:
		return
	if event.is_action_pressed(&"open_crafting"):
		_request_panel(GearPanels.PanelKind.CRAFT)
	elif event.is_action_pressed(&"open_backpack"):
		_request_panel(GearPanels.PanelKind.BAG)
	elif event.is_action_pressed(&"journal"):
		_request_panel(GearPanels.PanelKind.JOURNAL)
	elif player.panel_open and event.is_action_pressed(&"release_mouse"):
		_set_panel(GearPanels.PanelKind.NONE)
	elif event.is_action_pressed(&"eat_ration"):
		_eat()
	elif event.is_action_pressed(&"reload"):
		if player.equipped == SupplyRules.Tool.CARBINE:
			if not player.panel_open:
				_reload()
		else:
			_save(true)
	elif event.is_action_pressed(&"save_game"):
		_save(true)
	else:
		return
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if survival.player_health == 0 or player.panel_open or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if road != null:
		if event.is_action_pressed(&"attack"):
			_trigger_held = true
			_input_queue.append(&"attack")
			get_viewport().set_input_as_handled()
		return
	for action in [&"travel", &"interact", &"attack", &"craft_wood_pick", &"craft_stone_pick", &"craft_stone_sword"]:
		if event.is_action_pressed(action):
			if action == &"attack":
				_trigger_held = true
			_input_queue.append(action)
			get_viewport().set_input_as_handled()
			return


func _request_panel(panel: int) -> void:
	if road != null or finale != null:
		return
	if panel == hud.gear.active_panel:
		_set_panel(GearPanels.PanelKind.NONE)
		return
	if panel == GearPanels.PanelKind.CRAFT:
		_station = _nearest_station()
	elif panel == GearPanels.PanelKind.TRAVEL:
		if not _near_portal():
			return
		hud.gear.travel_context(story, _map_id)
	elif panel == GearPanels.PanelKind.JOURNAL:
		_read_journal()
	_set_panel(panel)


func _set_panel(panel: int) -> void:
	_trigger_held = false
	if panel != GearPanels.PanelKind.DIALOGUE:
		_dialogue_site = null
	if panel == GearPanels.PanelKind.NONE:
		if player.panel_open:
			Input.mouse_mode = _mouse_before_panel
		player.panel_open = false
	else:
		if not player.panel_open:
			_mouse_before_panel = Input.mouse_mode
		player.panel_open = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.gear.show_panel(panel)
	hud.aim.visible = not player.panel_open and player.equipped == SupplyRules.Tool.CARBINE
	hud.set_prompt("")
	if panel == GearPanels.PanelKind.CRAFT:
		_refresh_crafting()


func _near_portal() -> bool:
	return is_instance_valid(region.portal) and (
		player.global_position.distance_squared_to(region.portal.global_position) < PORTAL_RANGE ** 2)


func _travel(map_id: int) -> void:
	if hud.gear.active_panel != GearPanels.PanelKind.TRAVEL or not _near_portal():
		return
	if map_id == RelayStory.ROAD_MAP:
		_enter_road()
		return
	if map_id == _map_id or not story.unlocked(map_id):
		return
	_set_panel(GearPanels.PanelKind.NONE)
	_load_region(map_id, Vector3.INF, true)
	_save()
	hud.notify(RelayStory.MAP_NAMES[map_id])


func _enter_road() -> void:
	_road_return = _encounter_origin()
	_save()
	_set_panel(GearPanels.PanelKind.NONE)
	_load_region(RelayStory.ROAD_MAP,Vector3.INF,true)
	road = RoadRun.new(region,player,raid)
	road.vitals.player_health_changed.connect(_road_health_changed)
	_road_last_health = 100
	_road_exit_prompt = false
	player.orbit.rotation.y = PI
	player.arm.rotation.x = 0.0
	player.model.rotation.y = 0.0
	player.equip(SupplyRules.Tool.CARBINE)
	hud.road_mode(true)
	hud.show_player_health(road.vitals.player_health)
	hud.aim.show()
	hud.show_road(road)
	_refresh_magazine()
	hud.notify("临时卡宾枪已就绪 · 无限后备弹药")


func _tick_road(delta: float) -> void:
	if player.panel_open:
		return
	road.tick(delta)
	if player.global_position.y < -4.0:
		player.relocate(region.shelter)
	road.tick_weapon(delta,rules)
	hud.show_road(road)
	_refresh_magazine()
	_sync_road_dialog()
	if player.panel_open:
		_input_queue.clear()
		return
	if _input_queue.has(&"attack"):
		_fire()
	_input_queue.clear()
	_repeat_fire()
	_sync_road_dialog()
	if not player.panel_open:
		hud.set_prompt("按 F 打开离场确认" if _near_portal() else "")


func _road_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"release_mouse") and road.outcome == RoadRun.Outcome.ACTIVE:
		if _road_exit_prompt:
			_resume_road()
		else:
			_road_exit_prompt = true
			_sync_road_dialog()
	elif event.is_action_pressed(&"travel") and _near_portal() and road.outcome == RoadRun.Outcome.ACTIVE:
		_road_exit_prompt = true
		_sync_road_dialog()
	elif event.is_action_pressed(&"reload") and not player.panel_open:
		_reload()
	else:
		return
	get_viewport().set_input_as_handled()


func _sync_road_dialog() -> void:
	if road.outcome != RoadRun.Outcome.ACTIVE:
		_set_panel(GearPanels.PanelKind.ROAD)
		var win := road.outcome == RoadRun.Outcome.WON
		var title := "公路挑战胜利" if win else "公路挑战失败"
		hud.gear.road_dialog(title,"波次 %d / %d  ·  等级 %d  ·  击杀 %d" % [
			road.wave,RoadRun.WAVE_LIMIT,road.level,road.kills],[],false,"返回生存")
	elif _road_exit_prompt:
		_set_panel(GearPanels.PanelKind.ROAD)
		hud.gear.road_dialog("离开断线公路","离开将结束本次挑战，回到进入前的位置。",[],true,"结束并返回")
	elif not road.choices.is_empty():
		_set_panel(GearPanels.PanelKind.ROAD)
		hud.gear.road_dialog("等级 %d · 选择强化" % road.level,
			"选一项，效果持续到本局结束。",road.choices,false,"结束并返回")


func _road_upgrade(upgrade: int) -> void:
	if road == null or _road_exit_prompt or not road.choose(upgrade):
		return
	_set_panel(GearPanels.PanelKind.NONE)
	hud.show_road(road)
	_refresh_magazine()
	_sync_road_dialog()


func _resume_road() -> void:
	if road != null and road.outcome == RoadRun.Outcome.ACTIVE:
		_road_exit_prompt = false
		_set_panel(GearPanels.PanelKind.NONE)
		_sync_road_dialog()


func _leave_road() -> void:
	if road == null or hud.gear.active_panel != GearPanels.PanelKind.ROAD:
		return
	road.vitals.player_health_changed.disconnect(_road_health_changed)
	road.dispose()
	road = null
	_road_exit_prompt = false
	_restore_encounter_origin(_road_return)
	hud.notify("已返回生存地图")


func _road_health_changed() -> void:
	var points := road.vitals.player_health
	if points < _road_last_health:
		player.survivor.flinch()
		hud.flash_damage()
		audio.play_damage()
	_road_last_health = points
	hud.show_player_health(points)


func _encounter_origin() -> Dictionary:
	return {"map": _map_id, "point": player.global_position, "tool": player.equipped,
		"facing": player.orbit.rotation.y, "pitch": player.arm.rotation.x}


func _restore_encounter_origin(origin: Dictionary) -> void:
	_set_panel(GearPanels.PanelKind.NONE)
	_load_region(origin["map"], origin["point"])
	player.orbit.rotation.y = origin["facing"]
	player.arm.rotation.x = origin["pitch"]
	player.model.rotation.y = player.orbit.rotation.y + PI
	player.equip(origin["tool"])
	hud.road_mode(false)
	_health_changed()
	_refresh_bag()
	_save()


func _leave_encounter() -> void:
	if finale == null:
		_leave_road()
		return
	if hud.gear.active_panel != GearPanels.PanelKind.ROAD:
		return
	var won := finale.outcome == PumpFight.Outcome.WON
	finale.vitals.player_health_changed.disconnect(_finale_health_changed)
	finale.dispose()
	finale = null
	_finale_exit_prompt = false
	_restore_encounter_origin(_finale_return)
	hud.notify("公共频段恢复 · 主线完成" if won else "已返回池照身边，可再次尝试")


func _resume_encounter() -> void:
	if finale == null:
		_resume_road()
	elif finale.outcome == PumpFight.Outcome.ACTIVE:
		_finale_exit_prompt = false
		_set_panel(GearPanels.PanelKind.NONE)


func _enter_finale() -> void:
	_finale_return = _encounter_origin()
	_save()
	_set_panel(GearPanels.PanelKind.NONE)
	_load_region(RelayStory.FINALE_MAP, Vector3.INF, true)
	finale = PumpFight.new(region, player, raid)
	finale.vitals.player_health_changed.connect(_finale_health_changed)
	_finale_exit_prompt = false
	_finale_last_health = SurvivalRules.PLAYER_MAX_HEALTH
	player.orbit.rotation.y = PI
	player.arm.rotation.x = 0.0
	player.model.rotation.y = 0.0
	player.equip(SupplyRules.Tool.CARBINE)
	hud.road_mode(true)
	hud.finale_controls()
	hud.show_player_health(finale.vitals.player_health)
	hud.show_finale(finale)
	hud.aim.show()
	_refresh_magazine()


func _finale_health_changed() -> void:
	var points := finale.vitals.player_health
	if points < _finale_last_health:
		player.survivor.flinch()
		hud.flash_damage()
		audio.play_damage()
	_finale_last_health = points
	hud.show_player_health(points)


func _finale_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"release_mouse") and finale.outcome == PumpFight.Outcome.ACTIVE:
		if _finale_exit_prompt:
			_resume_encounter()
		else:
			_finale_exit_prompt = true
			_sync_finale_dialog()
	elif event.is_action_pressed(&"reload") and not player.panel_open:
		_reload()
	else:
		return
	get_viewport().set_input_as_handled()


func _tick_finale(delta: float) -> void:
	if player.panel_open:
		return
	finale.tick(delta)
	if player.global_position.y < -4.0:
		player.relocate(region.shelter)
	hud.show_finale(finale)
	_refresh_magazine()
	_sync_finale_dialog()
	if player.panel_open:
		_input_queue.clear()
		return
	var control := _near_target() as RelaySite
	if _input_queue.has(&"interact") and is_instance_valid(control):
		if finale.vent(control):
			audio.play_at(RelayAudio.Cue.ROCK, control.global_position)
			hud.notify("稳压器停机 · 趁现在攻击")
	if _input_queue.has(&"attack"):
		_fire()
	_input_queue.clear()
	_repeat_fire()
	_sync_finale_dialog()
	if not player.panel_open:
		hud.set_prompt(_prompt(control))


func _sync_finale_dialog() -> void:
	if finale.outcome == PumpFight.Outcome.WON:
		story.complete_finale()
		_save()
		_set_panel(GearPanels.PanelKind.ROAD)
		hud.gear.road_dialog("北压泵房 · 报警解除",
			"沈苇的呼叫传到了公共频段。撤离名单上的八个人回了话。", [], false, "返回黄烟盆地")
	elif finale.outcome == PumpFight.Outcome.LOST:
		_set_panel(GearPanels.PanelKind.ROAD)
		hud.gear.road_dialog("北压泵房 · 失去联络",
			"池照会在检修线入口等你。回去休整后，可以向她申请再次出发。", [], false, "返回池照身边")
	elif _finale_exit_prompt:
		_set_panel(GearPanels.PanelKind.ROAD)
		hud.gear.road_dialog("撤离北压泵房", "确认后回到池照身边，本次战斗结束。", [], true, "撤离并返回")


func _talk(site: RelaySite) -> void:
	_dialogue_site = site
	_dialogue_stage = story.stage
	_dialogue_page = 0
	if site.key != story.current_target():
		_dialogue_lines = [RelayStory.WAITING[site.partner]]
		_dialogue_stage = -1
	elif story.stage == RelayStory.RELAY_REPAIR and rules.carried(SupplyRules.Kind.IRON) == 0:
		_dialogue_lines = ["中继缺一份生铁。灰脊的铁矿可以带回气象站熔炼。我守着线路，等你回来。"]
		_dialogue_stage = -1
	else:
		_dialogue_lines = RelayStory.LINES[story.stage]
	_set_panel(GearPanels.PanelKind.DIALOGUE)
	_show_dialogue()


func _show_dialogue() -> void:
	var action := "继续"
	if _dialogue_page == _dialogue_lines.size() - 1:
		match _dialogue_stage:
			-1: action = "结束对话"
			RelayStory.RELAY_REPAIR: action = "交付 1 份生铁"
			RelayStory.FINALE_READY: action = "进入北压泵房"
			_: action = "记下线索"
	hud.gear.dialogue(_dialogue_site.title, _dialogue_lines[_dialogue_page], action)


func _next_dialogue() -> void:
	if hud.gear.active_panel != GearPanels.PanelKind.DIALOGUE or not is_instance_valid(_dialogue_site):
		return
	if _dialogue_page < _dialogue_lines.size() - 1:
		_dialogue_page += 1
		_show_dialogue()
		return
	var key := _dialogue_site.key
	_set_panel(GearPanels.PanelKind.NONE)
	if _dialogue_stage != story.stage or key != story.current_target():
		return
	if story.stage == RelayStory.FINALE_READY:
		_enter_finale()
	elif story.advance(key, rules):
		_refresh_display()
		hud.notify(RelayStory.STEPS[story.stage - 1][3], 4.0)
		_save()


func _read_journal(hint := "") -> void:
	var line := hint
	if line.is_empty() and story.stage > 0:
		line = RelayStory.STEPS[story.stage - 1][3]
	if line.is_empty():
		line = "撤离广播断了。去气象站里问问负责接收的沈苇。"
	hud.gear.journal("%s\n\n当前目标\n%s" % [line, story.objective()])


func _interact(target: Node3D) -> void:
	if target is SupplyPickup:
		var multiplier := 2 if target.kind == SupplyRules.Kind.WOOD and player.equipped == SupplyRules.Tool.IRON_AXE else 1
		rules.add({target.kind: multiplier})
		player.play_pickup(target.global_position)
		field.remove(target, survival.elapsed)
		hud.notify("%s +%d" % [SupplyRules.ITEMS[target.kind], multiplier], 1.1)
	elif target is MineableOre:
		_begin_mine(target)
	elif target is HarvestTree:
		_begin_chop(target)
	elif target is RelaySite:
		_interact_site(target)


func _interact_site(site: RelaySite) -> void:
	match site.role:
		RelaySite.Role.CRATE:
			var now := int(Time.get_unix_time_from_system())
			var refill := region.refill_left(site,now)
			if refill > 0:
				site.update_refill(refill)
				hud.notify(site.cooldown_text())
				return
			region.start_refill(site,now)
			rules.add(site.contents)
			var items := PackedStringArray()
			for kind in site.contents:
				items.append("%s +%d" % [SupplyRules.ITEMS[kind], site.contents[kind]])
			hud.notify("  ·  ".join(items))
			_save()
		RelaySite.Role.STORY:
			_read_journal(RelayStory.NOTES[site.key])
			_set_panel(GearPanels.PanelKind.JOURNAL)
		RelaySite.Role.NPC:
			_talk(site)
		RelaySite.Role.BENCH, RelaySite.Role.FURNACE:
			_station = SupplyRules.Station.BENCH if site.role == RelaySite.Role.BENCH else SupplyRules.Station.FURNACE
			_set_panel(GearPanels.PanelKind.CRAFT)


func _nearest_station() -> int:
	for site in [region.bench, region.furnace]:
		if is_instance_valid(site) and player.global_position.distance_squared_to(site.global_position) <= SITE_RANGE ** 2:
			return SupplyRules.Station.BENCH if site.role == RelaySite.Role.BENCH else SupplyRules.Station.FURNACE
	return SupplyRules.Station.HAND


func _select_station(station: int) -> void:
	_station = station
	_refresh_crafting()


func _refresh_crafting() -> void:
	var hint := "随身可制作基础工具。工作台安装在气象站内。"
	if _station != SupplyRules.Station.HAND:
		hint = "靠近气象站内的%s才能制作。" % SupplyRules.STATIONS[_station]
		if _nearest_station() == _station:
			hint = "正在使用%s" % SupplyRules.STATIONS[_station]
		if _station == SupplyRules.Station.BENCH and story.stage < 3:
			hint += "  ·  枪械图纸位于旧城"
	hud.gear.craft_context(_station, rules,
		func(id: int): return _can_craft(id, _station), hint)


func _can_craft(id: int, station: int) -> bool:
	var recipe: Array = SupplyRules.RECIPES[id]
	if recipe[1] != station or rules.recipe_owned(id) or not rules.can_pay(recipe[2]):
		return false
	if station != SupplyRules.Station.HAND and _nearest_station() != station:
		return false
	if id in [SupplyRules.Recipe.CARBINE, SupplyRules.Recipe.AMMO] and story.stage < 3:
		return false
	if id == SupplyRules.Recipe.BENCH:
		var point := player.global_position
		return _map_id == 0 and absf(point.x) < 4.8 and point.z <= -7.9 and point.z >= -17.4 and point.y < 3.0
	return true


func _craft(id: int) -> void:
	var recipe: Array = SupplyRules.RECIPES[id]
	var station: int = recipe[1]
	var tool: int = recipe[4]
	if tool >= 0 and rules.has_tool(tool):
		_equip(tool)
		return
	if not _can_craft(id, station) or not rules.craft(id, station):
		hud.notify("材料或制作条件不足")
		return
	if tool >= 0:
		_equip(tool)
	region.refresh_stations(rules)
	hud.notify("已制作%s" % recipe[0])
	_refresh_crafting()
	_save()


func _equip(tool: int) -> void:
	if rules.has_tool(tool):
		if tool != SupplyRules.Tool.CARBINE:
			magazine.reload_left = 0
		player.equip(tool)
		_refresh_bag()


func _eat() -> void:
	var restored := survival.eat_ration(rules)
	if restored > 0:
		hud.notify("食用罐头 · 生命 +%d" % restored)
		_save()
	elif survival.player_health == SurvivalRules.PLAYER_MAX_HEALTH:
		hud.notify("生命已满")
	else:
		hud.notify("背包里没有罐头")


func _mining_tool(minimum: int) -> int:
	return player.equipped if rules.mining_power(player.equipped) >= minimum else rules.best_pick()


func _begin_mine(ore: MineableOre) -> void:
	var tool := _mining_tool(ore.required_power())
	if rules.mining_power(tool) < ore.required_power():
		hud.notify("需要石镐或铁镐" if ore.required_power() > 1 else "先制作一把木镐")
		return
	var direction := ore.global_position - player.global_position
	direction.y = 0.0
	if player.start_swing(tool, direction.normalized()):
		_equip(tool)
		_mining_target = ore
		audio.play_at(RelayAudio.Cue.SWING, player.global_position + Vector3.UP, -3.0)


func _begin_chop(tree: HarvestTree) -> void:
	if tree.is_cut():
		hud.notify(tree.regrow_text())
		return
	var axe := SupplyRules.Tool.IRON_AXE
	if not rules.has_tool(axe):
		hud.notify("砍树需要铁斧")
		return
	var direction := tree.global_position - player.global_position
	direction.y = 0
	if player.start_swing(axe,direction.normalized()):
		_chop_target = tree
		_equip(axe)
		audio.play_at(RelayAudio.Cue.SWING,player.global_position+Vector3.UP,-3.0)


func _attack(target: Node3D) -> void:
	var tool := player.equipped
	if tool < 0 or player.is_swinging():
		return
	if tool == SupplyRules.Tool.CARBINE:
		_fire()
	elif target is MineableOre and rules.mining_power(tool) > 0:
		_begin_mine(target)
	elif target is HarvestTree and tool == SupplyRules.Tool.IRON_AXE:
		_begin_chop(target)
	elif player.start_swing(tool, -player.orbit.global_basis.z):
		_mining_target = null
		audio.play_at(RelayAudio.Cue.SWING, player.global_position + Vector3.UP)


func _tool_contact(tool: int, facing: Vector3) -> void:
	if survival.player_health == 0:
		return
	var tree := _chop_target
	_chop_target = null
	if is_instance_valid(tree) and tool == SupplyRules.Tool.IRON_AXE:
		if not tree.is_cut() and _reachable(tree.hit_point(),MINE_RANGE,tree):
			audio.play_at(RelayAudio.Cue.CHOP,tree.hit_point())
			if tree.chop(survival.elapsed):
				rules.add({SupplyRules.Kind.WOOD:HarvestTree.WOOD_YIELD})
				hud.notify("木料 +%d" % HarvestTree.WOOD_YIELD)
				_save()
		return
	if tool in [SupplyRules.Tool.STONE_SWORD, SupplyRules.Tool.IRON_AXE]:
		if raid.strike(player.global_position + Vector3.UP*0.95, facing, 2.55, 3 if tool == SupplyRules.Tool.IRON_AXE else 2):
			hud.notify("击中感染者", 0.65)
		return
	var ore := _mining_target
	_mining_target = null
	if not is_instance_valid(ore) or ore.is_queued_for_deletion():
		return
	if not _reachable(ore.global_position + Vector3.UP * 0.45, MINE_RANGE, ore):
		return
	audio.play_at(RelayAudio.Cue.ROCK, ore.global_position + Vector3.UP * 0.50)
	if ore.strike(rules.mining_power(tool)):
		rules.add({ore.kind: ore.yield_count()})
		field.remove(ore, survival.elapsed)
		hud.notify("%s +%d" % [SupplyRules.ITEMS[ore.kind], ore.yield_count()])


func _current_magazine() -> RelayMagazine:
	if finale != null:
		return finale.gun
	return road.gun if road != null else magazine


func _ammo_inventory() -> SupplyRules:
	return finale.reserve if finale != null else rules


func _reload() -> void:
	_current_magazine().start_reload(_ammo_inventory())
	_refresh_magazine()


func _repeat_fire() -> void:
	if (_trigger_held and not player.panel_open and player.equipped == SupplyRules.Tool.CARBINE
			and not player.is_swinging() and Input.is_action_pressed(&"attack")):
		_fire()


func _fire() -> void:
	var gun := _current_magazine()
	if player.panel_open or (road != null and (road.outcome != RoadRun.Outcome.ACTIVE or not road.choices.is_empty())):
		return
	if finale != null and finale.outcome != PumpFight.Outcome.ACTIVE:
		return
	if not gun.take_shot(road.cadence_scale() if road != null else 1.0):
		if gun.rounds == 0 and gun.reload_left <= 0 and gun.shot_left <= 0 and not gun.start_reload(_ammo_inventory()):
			hud.notify("没有后备弹药")
			gun.shot_left = 0.40
		return
	var camera := get_viewport().get_camera_3d()
	var middle := get_viewport().get_visible_rect().size * 0.5
	var start := camera.project_ray_origin(middle)
	var axis := camera.project_ray_normal(middle)
	var reach := RoadRun.SHOT_RANGE if road != null else 36.0
	var damage := gun.damage
	if road != null:
		damage = road.shot_damage()
	elif finale != null:
		damage = finale.shot_damage()
	var through := road.pierce_damage(damage) if road != null else 0
	var aim := start + axis * (reach + 3.0)
	var ray := PhysicsRayQueryParameters3D.create(start, aim, 13, [player.get_rid()])
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(ray)
	if not hit.is_empty():
		aim = hit.position + axis * 0.09
	var muzzle := player.begin_fire(axis)
	var chest := player.global_position + Vector3.UP * 1.24
	var blocked := space.intersect_ray(PhysicsRayQueryParameters3D.create(chest, muzzle, 9))
	var impact := muzzle
	if not blocked.is_empty():
		impact = blocked.position
	elif (aim - muzzle).dot(axis) > 0.05:
		impact = raid.shoot(muzzle,(aim-muzzle).normalized(),damage,reach,through)
	audio.play_at(RelayAudio.Cue.REPORT, muzzle)
	_shot_effect(muzzle,impact,Color("#ff9e58") if damage > gun.damage else Color("#ffd19b"))
	_refresh_magazine()


func _refresh_magazine() -> void:
	hud.gear.show_magazine(_current_magazine(),_ammo_inventory().carried(SupplyRules.Kind.AMMO),player.equipped == SupplyRules.Tool.CARBINE)


func _shot_effect(muzzle: Vector3, impact: Vector3, tint: Color) -> void:
	var tracer := MeshInstance3D.new()
	var segment := BoxMesh.new()
	var distance := muzzle.distance_to(impact)
	if distance < 0.05:
		return
	segment.size = Vector3(0.018, 0.020, distance)
	tracer.mesh = segment
	tracer.material_override = RelayGeometry.finish(tint,2.4)
	region.add_child(tracer)
	tracer.position = muzzle.lerp(impact, 0.5)
	if absf((impact - muzzle).normalized().dot(Vector3.UP)) < 0.999:
		tracer.look_at(impact)
	tracer.get_tree().create_timer(0.065).timeout.connect(tracer.queue_free)


func _near_target() -> Node3D:
	var best: Node3D
	var distance := INF
	var candidates := region.supplies.get_children() + region.ores.get_children()
	for site in region.sites:
		if site.role != RelaySite.Role.PORTAL:
			candidates.append(site)
	for entry in candidates:
		var target := entry as Node3D
		if target.is_queued_for_deletion():
			continue
		var offset := 0.45
		var reach := PICKUP_RANGE
		if target is MineableOre:
			reach = MINE_RANGE
		elif target is RelaySite:
			reach = SITE_RANGE
			offset = 0.0
		var point := target.global_position + Vector3.UP * offset
		var next := player.global_position.distance_squared_to(target.global_position)
		if next < distance and _reachable(point, reach, target as StaticBody3D):
			best = target
			distance = next
	if best != null:
		return best
	return _near_tree()


func _near_tree() -> HarvestTree:
	var nearest: HarvestTree
	var best_distance := MINE_RANGE * MINE_RANGE
	var origin := player.global_position + Vector3.UP * 0.88
	for tree in region.trees:
		var point := tree.hit_point()
		var distance := origin.distance_squared_to(point)
		if distance < best_distance and _reachable(point,MINE_RANGE,tree):
			nearest = tree
			best_distance = distance
	return nearest


func _reachable(point: Vector3, range_limit: float, resource: StaticBody3D) -> bool:
	var origin := player.global_position + Vector3.UP * 0.88
	if origin.distance_squared_to(point) > range_limit ** 2:
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, point, 9)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (resource != null and hit.get("collider") == resource)


func _prompt(target: Node3D) -> String:
	if target is SupplyPickup:
		return "按 E 拾取%s" % SupplyRules.ITEMS[target.kind]
	if target is MineableOre:
		var power := rules.mining_power(_mining_tool(target.required_power()))
		if power < target.required_power():
			return "%s · %s" % [target.mineral_name(), "需要石镐或铁镐" if target.required_power() > 1 else "需要木镐"]
		return "按 E 开采%s · 还需 %d 次" % [target.mineral_name(), ceili(float(target.hardness) / power)]
	if target is HarvestTree:
		if target.is_cut():
			return target.regrow_text()
		if not rules.has_tool(SupplyRules.Tool.IRON_AXE):
			return "松树 · 需要铁斧"
		return "按 E 砍树 · 还需 %d 次" % target.chops_left
	if target is RelaySite:
		if target.role == RelaySite.Role.NPC:
			return "按 E 与%s对话" % target.title
		if target.role == RelaySite.Role.PUMP_CONTROL:
			if target.used:
				return "泄压阀已使用"
			if finale.exposed_for > 0:
				return "等待稳压器恢复"
			return "按 E 打开泄压阀"
		if target.role == RelaySite.Role.CRATE and target.refill_seconds > 0:
			return target.cooldown_text()
		return "按 E 查看%s" % target.title
	return "按 F 选择传送去处" if _near_portal() else ""


func _phase_changed() -> void:
	if survival.phase == SurvivalRules.Phase.DAY and raid != null:
		raid.end_night()
		cleared_nests.clear()
		hud.notify("天亮了")
	elif survival.phase == SurvivalRules.Phase.NIGHT:
		hud.notify("入夜 · 避开徘徊的感染者", 3.5)


func _recover() -> void:
	if survival.player_health > 0:
		return
	_load_region(0)
	survival.recover()
	hud.result.hide()
	player.set_physics_process(true)
	player.set_process_unhandled_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_save()


func _health_changed() -> void:
	var points := survival.player_health
	if points < _last_health:
		player.survivor.flinch()
		hud.flash_damage()
		audio.play_damage()
		if points > 0:
			hud.notify("受到攻击 · 生命 -%d" % (_last_health - points), 1.1)
	_last_health = points
	hud.show_player_health(points)
	hud.gear.set_ration_available(points > 0 and points < 100 and rules.carried(SupplyRules.Kind.CAN) > 0)
	if points == 0:
		_set_panel(GearPanels.PanelKind.NONE)
		player.reset_aim_camera()
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.show_recovery()
		_save()


func _refresh_bag() -> void:
	hud.gear.refresh(rules, player.equipped)
	_refresh_magazine()
	hud.gear.set_ration_available(survival.player_health > 0 and survival.player_health < 100
		and rules.carried(SupplyRules.Kind.CAN) > 0)
	hud.aim.visible = not player.panel_open and player.equipped == SupplyRules.Tool.CARBINE
	if hud.gear.active_panel == GearPanels.PanelKind.CRAFT and is_instance_valid(region):
		_refresh_crafting()


func _refresh_display() -> void:
	if _map_id >= RelayStory.ROAD_MAP:
		return
	region.lighting.update_light(survival.phase, survival.remaining)
	hud.show_survival(survival, _map_id, raid.active.size(), raid.chasing_count)
	hud.show_story(story)
	_guide()


func _guide() -> void:
	if story.stage >= RelayStory.STEPS.size():
		return
	var destination := region.portal
	var key := story.current_target()
	for site in region.sites:
		if site.key == key:
			destination = site
			break
	var offset := destination.global_position - player.global_position
	var horizontal := Vector3(offset.x, 0, offset.z)
	var relative := player.orbit.global_basis.inverse() * horizontal
	var turn := atan2(relative.x, -relative.z)
	var segment := posmod(roundi(turn * 4.0 / PI), 8)
	hud.route.text += "\n%s  %s  %d 米" % [DIRECTIONS[segment], destination.title, roundi(horizontal.length())]

func _exit_tree() -> void:
	if finale != null:
		finale.dispose()
	if road != null:
		road.dispose()
