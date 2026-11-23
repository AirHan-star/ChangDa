extends Node3D

const PICKUP_RANGE := 2.15
const MINE_RANGE := 1.72
const CHEST_RANGE := 2.55
const DOOR_RANGE := 2.85
const SWING_COOLDOWN := 0.51
const RECIPES := {
	&"craft_wood_pick": SupplyRules.Tool.WOOD_PICK,
	&"craft_stone_pick": SupplyRules.Tool.STONE_PICK,
	&"craft_stone_sword": SupplyRules.Tool.STONE_SWORD,
}
@onready var player: RelayPlayer = $Player
@onready var supplies: Node3D = $Clearing/Supplies
@onready var ores: Node3D = $Clearing/Ores
@onready var chest: Marker3D = $Clearing/ChestInteraction
@onready var gate: StationGate = $Clearing/Station/Gate
@onready var lighting: RelayLighting = $Clearing/Lighting
@onready var hud: RelayHUD = $HUD

var rules := SupplyRules.new()
var survival := SurvivalRules.new()
var field: ResourceField
var raid: NightRaid
var _requested: Array[StringName] = []
var _swing_in := 0.0
var _restarting := false
var _last_player_health := SurvivalRules.PLAYER_MAX_HEALTH
var _mining_target: MineableOre
var _mouse_before_panel := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	field = ResourceField.new(supplies, ores, rules)
	raid = NightRaid.new($Clearing/Infected, gate, player)
	rules.changed.connect(_refresh_inventory)
	survival.phase_changed.connect(_phase_changed)
	survival.player_health_changed.connect(_refresh_player_health)
	hud.restart_requested.connect(_restart)
	hud.gear.panel_requested.connect(_toggle_panel)
	hud.gear.craft_requested.connect(_craft)
	hud.gear.equip_requested.connect(_equip)
	hud.gear.ration_requested.connect(_eat_ration)
	player.tool_impact.connect(_on_tool_impact)
	_refresh_inventory()
	_refresh_survival()


func _physics_process(delta: float) -> void:
	if survival.is_over():
		return
	var previous_phase := survival.phase
	survival.tick(delta)
	if survival.is_over():
		return
	if survival.phase == SurvivalRules.Phase.DAY:
		field.tick(delta)
	elif previous_phase == SurvivalRules.Phase.NIGHT:
		raid.tick(delta, survival)
	_refresh_survival()
	if survival.is_over():
		return

	_swing_in = maxf(0.0, _swing_in - delta)
	if player.panel_open:
		_requested.clear()
		hud.set_prompt("")
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_requested.clear()
		hud.set_prompt("鼠标已释放 · 单击画面继续")
		return
	var target := _interaction_target()
	for action in _requested:
		if action == &"interact" and is_instance_valid(target) and not target.is_queued_for_deletion():
			_interact(target)
		elif action == &"reinforce":
			_reinforce()
		elif action == &"attack":
			_attack(target)
		elif RECIPES.has(action):
			_craft(RECIPES[action])
	_requested.clear()
	if is_instance_valid(target) and target.is_queued_for_deletion():
		target = null
	hud.set_prompt(_prompt(target))


func _input(event: InputEvent) -> void:
	if survival.is_over():
		return
	if event.is_action_pressed(&"eat_ration"):
		_eat_ration()
	elif event.is_action_pressed(&"open_crafting"):
		_toggle_panel(GearPanels.PanelKind.CRAFT)
	elif event.is_action_pressed(&"open_backpack"):
		_toggle_panel(GearPanels.PanelKind.BAG)
	elif player.panel_open and event.is_action_pressed(&"release_mouse"):
		_toggle_panel(GearPanels.PanelKind.NONE)
	else:
		return
	get_viewport().set_input_as_handled()


func _toggle_panel(panel: int) -> void:
	if survival.is_over():
		return
	if panel == hud.gear.active_panel:
		panel = GearPanels.PanelKind.NONE
	if panel == GearPanels.PanelKind.NONE:
		if player.panel_open:
			Input.mouse_mode = _mouse_before_panel
		player.panel_open = false
	else:
		if not player.panel_open:
			_mouse_before_panel = Input.mouse_mode
		player.panel_open = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_requested.clear()
	hud.set_prompt("")
	hud.gear.show_panel(panel)


func _unhandled_input(event: InputEvent) -> void:
	if survival.is_over():
		if event.is_action_pressed(&"restart"):
			_restart()
		return
	if player.panel_open or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	for action in [&"interact", &"reinforce", &"attack",
			&"craft_wood_pick", &"craft_stone_pick", &"craft_stone_sword"]:
		if event.is_action_pressed(action):
			_requested.append(action)
			get_viewport().set_input_as_handled()
			return


func _interact(target: Node3D) -> void:
	if target == chest:
		rules.deposit()
	elif target is SupplyPickup:
		if rules.collect(target.supply_id):
			player.play_pickup(target.global_position)
			field.remove(target)
	elif target is MineableOre:
		var tool := _mining_tool()
		if tool < 0:
			hud.notify("按 Tab 合成木镐，再开采")
		else:
			if _begin_mine(target, tool) and player.equipped != tool:
				_equip(tool)


func _reinforce() -> void:
	if not _near_gate():
		hud.notify("靠近气象站大门才能加固")
	elif survival.phase != SurvivalRules.Phase.DAY:
		hud.notify("只能在白天加固大门")
	elif survival.reinforce(rules):
		gate.set_upgrades(survival.upgrades)
		_refresh_survival()
		hud.notify("加固完成 · 门耐久 +%d" % SurvivalRules.HEALTH_PER_UPGRADE)
	elif survival.upgrades < SurvivalRules.MAX_UPGRADES:
		hud.notify("加固需要 %d 份木料" % SurvivalRules.WOOD_PER_UPGRADE)


func _craft(tool: SupplyRules.Tool) -> void:
	if rules.has_tool(tool):
		_equip(tool)
	elif rules.craft(tool):
		_equip(tool)
		hud.notify("已制作%s" % GearPanels.TOOL_NAMES[tool])
	else:
		hud.notify("制作%s的材料不足" % GearPanels.TOOL_NAMES[tool])


func _equip(tool: SupplyRules.Tool) -> void:
	if rules.has_tool(tool):
		player.equip(tool)
		_refresh_inventory()


func _eat_ration() -> void:
	if survival.is_over():
		return
	var restored := survival.eat_ration(rules)
	if restored > 0:
		hud.notify("食用罐头 · 生命 +%d" % restored)
	elif survival.player_health == SurvivalRules.PLAYER_MAX_HEALTH:
		hud.notify("生命已满")
	else:
		hud.notify("背包里没有罐头")


func _mining_tool() -> int:
	if player.equipped >= 0 and rules.mining_power(player.equipped) > 0:
		return player.equipped
	if rules.has_tool(SupplyRules.Tool.STONE_PICK):
		return SupplyRules.Tool.STONE_PICK
	return SupplyRules.Tool.WOOD_PICK if rules.has_tool(SupplyRules.Tool.WOOD_PICK) else -1


func _begin_mine(ore: MineableOre, tool: int) -> bool:
	var direction := ore.global_position - player.global_position
	direction.y = 0.0
	if not player.start_swing(tool, direction.normalized()):
		return false
	_mining_target = ore
	return true


func _attack(target: Node3D) -> void:
	var tool := player.equipped
	if tool < 0 or _swing_in > 0.0:
		return
	if tool != SupplyRules.Tool.STONE_SWORD and target is MineableOre:
		_begin_mine(target, tool)
	elif player.start_swing(tool, -player.orbit.global_basis.z):
		_mining_target = null
		if tool == SupplyRules.Tool.STONE_SWORD:
			_swing_in = SWING_COOLDOWN


func _on_tool_impact(tool: int, facing: Vector3) -> void:
	if survival.is_over():
		return
	if tool == SupplyRules.Tool.STONE_SWORD:
		if survival.phase == SurvivalRules.Phase.NIGHT:
			var origin := player.global_position + Vector3.UP * 0.95
			if raid.strike(origin, facing, player.get_rid()):
				hud.notify("击中感染者", 0.65)
		return
	var ore := _mining_target
	_mining_target = null
	if not is_instance_valid(ore) or ore.is_queued_for_deletion():
		return
	if not _within_reach(ore.global_position + Vector3.UP * 0.45, MINE_RANGE, ore):
		return
	if ore.strike(rules.mining_power(tool)):
		rules.add_stone(MineableOre.YIELD)
		field.remove(ore)
		hud.notify("石头 +%d" % MineableOre.YIELD)


func _prompt(target: Node3D) -> String:
	if target != null and target == chest:
		return "按 E 存入补给箱" if rules.can_deposit() else "补给箱 · 木料和罐头为空"
	if target is SupplyPickup:
		return "按 E 拾取"
	if target is MineableOre:
		var tool := _mining_tool()
		if tool < 0:
			return "石矿 · 按 Tab 合成木镐"
		var power := rules.mining_power(tool)
		var hits := ceili(float(target.hardness) / power)
		return "按 E 开采 · 还需 %d 次" % hits
	if not _near_gate():
		return ""
	if survival.phase == SurvivalRules.Phase.NIGHT:
		return "气象站大门 · 夜间关闭"
	if survival.upgrades == SurvivalRules.MAX_UPGRADES:
		return "大门已加固至上限"
	return "按 R 加固大门 · 木料 %d" % SurvivalRules.WOOD_PER_UPGRADE


func _interaction_target() -> Node3D:
	var nearest: Node3D = null
	var best_distance := INF
	if _within_reach(chest.global_position, CHEST_RANGE):
		nearest = chest
		best_distance = player.global_position.distance_squared_to(chest.global_position)
	for group in [supplies, ores]:
		for child in group.get_children():
			var resource := child as Node3D
			if resource.is_queued_for_deletion():
				continue
			var distance := player.global_position.distance_squared_to(resource.global_position)
			var ore := resource as MineableOre
			var reach := MINE_RANGE if ore != null else PICKUP_RANGE
			if distance < best_distance and _within_reach(resource.global_position + Vector3.UP * 0.45, reach, ore):
				nearest = resource
				best_distance = distance
	return nearest


func _within_reach(point: Vector3, reach: float, resource: StaticBody3D = null) -> bool:
	var from := player.global_position + Vector3.UP * 0.85
	if from.distance_squared_to(point) > reach * reach:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, point, 9, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (resource != null and hit.get("collider") == resource)


func _near_gate() -> bool:
	var offset := player.global_position - gate.global_position
	return Vector2(offset.x, offset.z).length_squared() <= DOOR_RANGE * DOOR_RANGE


func _phase_changed() -> void:
	if survival.phase == SurvivalRules.Phase.NIGHT:
		var offset := player.global_position - gate.global_position
		if absf(offset.x) < 1.66 and absf(offset.z) < 0.56:
			player.global_position.z = gate.global_position.z + (0.58 if offset.z >= 0.0 else -0.58)
		gate.close_gate()
		hud.notify("入夜 · 感染者正沿小路来袭", 4.0)
	elif survival.is_over():
		if survival.loss_cause == SurvivalRules.LossCause.GATE:
			gate.break_gate()
		hud.gear.show_panel(GearPanels.PanelKind.NONE)
		player.panel_open = false
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.show_result(survival, rules.is_complete())
	_refresh_survival()


func _restart() -> void:
	if survival.is_over() and not _restarting:
		_restarting = true
		get_tree().reload_current_scene.call_deferred()


func _refresh_inventory() -> void:
	hud.show_supplies(rules, player.equipped)
	_refresh_player_health()


func _refresh_player_health() -> void:
	var points := survival.player_health
	if points > 0 and points < _last_player_health:
		hud.notify("受到攻击 · 生命 -%d" % (_last_player_health - points), 1.1)
	_last_player_health = points
	hud.show_player_health(points)
	hud.gear.set_ration_available(
		points < SurvivalRules.PLAYER_MAX_HEALTH and rules.carried(SupplyRules.Kind.CAN) > 0)


func _refresh_survival() -> void:
	lighting.update_light(survival.phase, survival.remaining)
	hud.show_survival(survival, raid.spawned, raid.active.size(), raid.chasing_count)
