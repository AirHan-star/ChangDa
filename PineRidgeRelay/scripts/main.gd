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
var cleared_nests: Dictionary = {}

var _map_id := 0
var _station := SupplyRules.Station.HAND
var _input_queue: Array[StringName] = []
var _save_in := 20.0
var _fire_in := 0.0
var _last_health := SurvivalRules.PLAYER_MAX_HEALTH
var _mining_target: MineableOre
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


func _restore(saved: Dictionary) -> void:
	rules.restore(saved)
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
	depleted = saved.get("depleted", {})
	cleared_nests = saved.get("cleared", {})


func _save(manual := false) -> void:
	if _restoring or not is_instance_valid(region):
		return
	_save_in = 20.0
	var data := {
		"version": 1, "map": _map_id, "stage": story.stage,
		"position": player.global_position, "facing": player.orbit.rotation.y,
		"equipped": player.equipped, "health": survival.player_health,
		"day": survival.day, "night": survival.phase == SurvivalRules.Phase.NIGHT,
		"remaining": survival.remaining, "elapsed": survival.elapsed,
		"items": rules.inventory, "tools": rules.tools, "stations": rules.stations,
		"opened": opened, "depleted": depleted, "cleared": cleared_nests,
	}
	if not RelaySave.store(data):
		hud.notify("无法写入存档")
	elif manual:
		hud.notify("进度已保存")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
		get_tree().quit()


func _load_region(map_id: int, point := Vector3.INF, arriving := false) -> void:
	if is_instance_valid(region):
		remove_child(region)
		region.queue_free()
	_map_id = map_id
	region = SurvivalRegion.new()
	add_child(region)
	region.build(map_id, opened, rules)
	field = ResourceField.new(region, depleted)
	raid = NightRaid.new(region, player, cleared_nests)
	raid.growled.connect(func(at: Vector3): audio.play_at(RelayAudio.Cue.GROWL, at))
	raid.enemy_struck.connect(func(at: Vector3): audio.play_at(RelayAudio.Cue.BLADE, at))
	var destination := region.arrival if arriving else region.shelter
	if point.is_finite() and absf(point.x) < 38 and absf(point.z) < 60 and point.y > -3 and point.y < 40:
		destination = point
	player.relocate(destination)
	_mining_target = null
	_input_queue.clear()
	_refresh_display()


func _physics_process(delta: float) -> void:
	if _restoring or survival.player_health == 0:
		return
	survival.tick(delta)
	var daylight := survival.phase == SurvivalRules.Phase.DAY
	field.tick(survival.elapsed, daylight)
	if not daylight:
		raid.tick(delta, survival)
	if survival.player_health == 0:
		return
	if player.global_position.y < -5.0:
		player.relocate(region.shelter)
	_maybe_autosave(delta)
	_fire_in = maxf(0.0, _fire_in - delta)
	_refresh_display()
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
	if is_instance_valid(target) and target.is_queued_for_deletion():
		target = null
	hud.set_prompt(_prompt(target))


func _maybe_autosave(delta: float) -> void:
	_save_in -= delta
	if _save_in <= 0.0:
		_save()


func _input(event: InputEvent) -> void:
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
	elif event.is_action_pressed(&"save_game"):
		_save(true)
	else:
		return
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if survival.player_health == 0 or player.panel_open or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	for action in [&"travel", &"interact", &"attack", &"craft_wood_pick", &"craft_stone_pick", &"craft_stone_sword"]:
		if event.is_action_pressed(action):
			_input_queue.append(action)
			get_viewport().set_input_as_handled()
			return


func _request_panel(panel: int) -> void:
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
	return player.global_position.distance_squared_to(region.portal.global_position) < PORTAL_RANGE ** 2


func _travel(map_id: int) -> void:
	if hud.gear.active_panel != GearPanels.PanelKind.TRAVEL or not _near_portal():
		return
	if map_id == _map_id or not story.unlocked(map_id):
		return
	_set_panel(GearPanels.PanelKind.NONE)
	_load_region(map_id, Vector3.INF, true)
	_save()
	hud.notify(RelayStory.MAP_NAMES[map_id])


func _read_journal(hint := "") -> void:
	var line := hint
	if line.is_empty() and story.stage > 0:
		line = RelayStory.STEPS[story.stage - 1][3]
	if line.is_empty():
		line = "撤离广播断了。气象站里的通讯台也许还留着最后收到的消息。"
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
	elif target is RelaySite:
		_interact_site(target)


func _interact_site(site: RelaySite) -> void:
	match site.role:
		RelaySite.Role.CRATE:
			if opened.has(site.key):
				hud.notify("这个箱子已经搜空")
				return
			opened[site.key] = true
			rules.add(site.contents)
			site.mark_looted()
			var items := PackedStringArray()
			for kind in site.contents:
				items.append("%s +%d" % [SupplyRules.ITEMS[kind], site.contents[kind]])
			hud.notify("  ·  ".join(items))
			_save()
		RelaySite.Role.STORY:
			var previous := story.stage
			_read_journal(story.advance(site.key, rules))
			_set_panel(GearPanels.PanelKind.JOURNAL)
			hud.show_story(story)
			if previous != story.stage:
				_save()
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


func _attack(target: Node3D) -> void:
	var tool := player.equipped
	if tool < 0 or player.is_swinging():
		return
	if tool == SupplyRules.Tool.CARBINE:
		_fire()
	elif target is MineableOre and rules.mining_power(tool) > 0:
		_begin_mine(target)
	elif player.start_swing(tool, -player.orbit.global_basis.z):
		_mining_target = null
		audio.play_at(RelayAudio.Cue.SWING, player.global_position + Vector3.UP)


func _tool_contact(tool: int, facing: Vector3) -> void:
	if survival.player_health == 0:
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


func _fire() -> void:
	if _fire_in > 0:
		return
	_fire_in = 0.38
	if not rules.pay({SupplyRules.Kind.AMMO: 1}):
		hud.notify("没有弹药")
		return
	var camera := get_viewport().get_camera_3d()
	var middle := get_viewport().get_visible_rect().size * 0.5
	var start := camera.project_ray_origin(middle)
	var axis := camera.project_ray_normal(middle)
	var aim := start + axis * 38.0
	var ray := PhysicsRayQueryParameters3D.create(start, aim, 13, [player.get_rid()])
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(ray)
	if not hit.is_empty():
		aim = hit.position + axis * 0.09
	var heading := Vector3(axis.x, 0, axis.z).normalized()
	var muzzle := player.begin_fire(heading)
	var chest := player.global_position + Vector3.UP * 1.24
	var blocked := space.intersect_ray(PhysicsRayQueryParameters3D.create(chest, muzzle, 9))
	var impact := raid.shoot(muzzle, (aim - muzzle).normalized()) if blocked.is_empty() else (blocked.position as Vector3)
	audio.play_at(RelayAudio.Cue.REPORT, muzzle)
	_shot_effect(muzzle, impact)


func _shot_effect(muzzle: Vector3, impact: Vector3) -> void:
	var tracer := MeshInstance3D.new()
	var segment := BoxMesh.new()
	var distance := muzzle.distance_to(impact)
	if distance < 0.05:
		return
	segment.size = Vector3(0.018, 0.020, distance)
	tracer.mesh = segment
	tracer.material_override = RelayGeometry.finish(Color("#ffd19b"), 2.4)
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
	return best


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
	if target is RelaySite:
		if target.role == RelaySite.Role.CRATE and opened.has(target.key):
			return "%s · 已搜空" % target.title
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
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.show_recovery()
		_save()


func _refresh_bag() -> void:
	hud.gear.refresh(rules, player.equipped)
	hud.gear.set_ration_available(survival.player_health > 0 and survival.player_health < 100
		and rules.carried(SupplyRules.Kind.CAN) > 0)
	hud.aim.visible = not player.panel_open and player.equipped == SupplyRules.Tool.CARBINE
	if hud.gear.active_panel == GearPanels.PanelKind.CRAFT and is_instance_valid(region):
		_refresh_crafting()


func _refresh_display() -> void:
	region.lighting.update_light(survival.phase, survival.remaining)
	hud.show_survival(survival, _map_id, raid.active.size(), raid.chasing_count)
	hud.show_story(story)
	_guide()


func _guide() -> void:
	if story.stage >= RelayStory.STEPS.size():
		return
	var destination := region.portal
	var key: String = RelayStory.STEPS[story.stage][2]
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
