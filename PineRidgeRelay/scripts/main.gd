extends Node3D

const PICKUP_RANGE := 2.15
const CHEST_RANGE := 2.55
const DOOR_RANGE := 2.85
const SWING_COOLDOWN := 0.51
const RECIPES := {
	&"craft_wood_pick": SupplyRules.Tool.WOOD_PICK,
	&"craft_stone_pick": SupplyRules.Tool.STONE_PICK,
	&"craft_stone_sword": SupplyRules.Tool.STONE_SWORD,
}
const TOOL_NAMES := {
	SupplyRules.Tool.WOOD_PICK: "木镐",
	SupplyRules.Tool.STONE_PICK: "石镐",
	SupplyRules.Tool.STONE_SWORD: "石剑",
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


func _ready() -> void:
	field = ResourceField.new(supplies, ores, rules)
	raid = NightRaid.new($Clearing/Infected, gate)
	rules.changed.connect(_refresh_inventory)
	survival.phase_changed.connect(_phase_changed)
	hud.restart_requested.connect(_restart)
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
			_attack()
		elif RECIPES.has(action):
			_craft(RECIPES[action])
	_requested.clear()
	if is_instance_valid(target) and target.is_queued_for_deletion():
		target = null
	hud.set_prompt(_prompt(target))


func _unhandled_input(event: InputEvent) -> void:
	if survival.is_over():
		if event.is_action_pressed(&"restart"):
			_restart()
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
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
		var power := rules.mining_power()
		if power == 0:
			hud.notify("先按 1 制作木镐，再开采")
		elif target.strike(power):
			rules.add_stone(MineableOre.YIELD)
			field.remove(target)
			hud.notify("石头 +%d" % MineableOre.YIELD)


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
		hud.notify("已持有%s" % TOOL_NAMES[tool])
	elif rules.craft(tool):
		hud.notify("已制作%s" % TOOL_NAMES[tool])
	else:
		hud.notify("制作%s的材料不足" % TOOL_NAMES[tool])


func _attack() -> void:
	if not rules.has_tool(SupplyRules.Tool.STONE_SWORD) or _swing_in > 0.0:
		return
	_swing_in = SWING_COOLDOWN
	var facing := -player.orbit.global_basis.z
	player.swing_sword(facing)
	if survival.phase == SurvivalRules.Phase.NIGHT:
		var origin := player.global_position + Vector3.UP * 0.95
		if raid.strike(origin, facing, player.get_rid()):
			hud.notify("击中感染者", 0.65)


func _prompt(target: Node3D) -> String:
	if target != null and target == chest:
		return "按 E 存入补给箱" if rules.can_deposit() else "补给箱 · 木料和罐头为空"
	if target is SupplyPickup:
		return "按 E 拾取"
	if target is MineableOre:
		var power := rules.mining_power()
		if power == 0:
			return "石矿 · 按 1 制作木镐"
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
			if distance < best_distance and _within_reach(resource.global_position + Vector3.UP * 0.45, PICKUP_RANGE):
				nearest = resource
				best_distance = distance
	return nearest


func _within_reach(point: Vector3, reach: float) -> bool:
	var from := player.global_position + Vector3.UP * 0.85
	if from.distance_squared_to(point) > reach * reach:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, point, 1, [player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


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
		if survival.phase == SurvivalRules.Phase.LOST:
			gate.break_gate()
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.show_result(survival.phase == SurvivalRules.Phase.WON, survival.health, rules.is_complete())
	_refresh_survival()


func _restart() -> void:
	if survival.is_over() and not _restarting:
		_restarting = true
		get_tree().reload_current_scene.call_deferred()


func _refresh_inventory() -> void:
	player.sword.visible = rules.has_tool(SupplyRules.Tool.STONE_SWORD)
	hud.show_supplies(rules)


func _refresh_survival() -> void:
	lighting.update_light(survival.phase, survival.remaining)
	hud.show_survival(survival, raid.spawned, raid.active.size())
