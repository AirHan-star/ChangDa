class_name RelayPlayer
extends CharacterBody3D

signal tool_impact(tool: int, facing: Vector3)

const PICK_SWING_TIME := 0.40
const SWORD_SWING_TIME := 0.45
const IMPACT_FRACTION := 0.56

const WALK_SPEED := 4.1
const RUN_SPEED := 6.6
const JUMP_SPEED := 6.3
const LOOK_SENSITIVITY := 0.0026
const RECOIL_TIME := 0.24
const AIM_OFFSET := 0.90
const AIM_LENGTH := 2.65
const AIM_FOV := 51.0
const AIM_BLEND_SPEED := 6.0
const PLAYER_VIEW_LAYER := 5

@onready var orbit: Node3D = $Orbit
@onready var arm: SpringArm3D = $Orbit/Arm
@onready var camera: Camera3D = $Orbit/Arm/Camera
@onready var _normal_arm_length := arm.spring_length
@onready var _normal_fov := camera.fov
@onready var model: Node3D = $Model
@onready var survivor: SurvivorPose = $Model/Survivor
@onready var held_tool: Node3D = $Model/HeldTool
@onready var sword: Node3D = $Model/HeldTool/Sword
@onready var _tool_models: Array[Node3D] = [$Model/HeldTool/WoodPick, $Model/HeldTool/StonePick, sword]

var equipped := -1
var panel_open := false
var _swing_tool := -1
var _swing_facing := Vector3.ZERO
var _swing_elapsed := 0.0
var _swing_duration := 0.0
var _pickup_turn_left := 0.0
var _pickup_facing := 0.0
var reload_progress := -1.0
var _fire_left := 0.0
var _magazine_mesh: MeshInstance3D
var _magazine_rest := Transform3D.IDENTITY
var _fire_weight := 0.0
var _aim_blend := 0.0
var _shoulder_clearance := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	for tool in [RelayEquipment.iron_pick(), RelayEquipment.axe(), RelayEquipment.carbine()]:
		held_tool.add_child(tool)
		_tool_models.append(tool)
	_magazine_mesh = _tool_models[SupplyRules.Tool.CARBINE].get_node("DetachableMagazine")
	_magazine_rest = _magazine_mesh.transform
	_show_tool()
	arm.add_excluded_object(get_rid())
	_shoulder_clearance.shape = arm.shape
	_shoulder_clearance.collision_mask = arm.collision_mask
	_shoulder_clearance.exclude = [get_rid()]
	_shoulder_clearance.margin = 0.025
	for visual in model.find_children("*", "GeometryInstance3D", true, false):
		visual.set_layer_mask_value(1, false)
		visual.set_layer_mask_value(PLAYER_VIEW_LAYER, true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if panel_open:
		return
	if event.is_action_pressed(&"release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		orbit.rotate_y(-event.relative.x * LOOK_SENSITIVITY)
		arm.rotation.x = clampf(arm.rotation.x - event.relative.y * LOOK_SENSITIVITY, -0.95, 0.42)


func _physics_process(delta: float) -> void:
	var steer := Vector2.ZERO
	if not panel_open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		steer = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var direction := orbit.basis * Vector3(steer.x, 0.0, steer.y)
	var sprint := Input.is_action_pressed(&"sprint")
	var speed := RUN_SPEED if sprint else WALK_SPEED
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(direction * speed, 28.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not panel_open and is_on_floor() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_just_pressed(&"jump"):
		velocity.y = JUMP_SPEED
	elif not is_on_floor():
		velocity.y -= 18.0 * delta
	move_and_slide()

	var aiming := is_aiming()
	_update_aim_camera(aiming, delta)
	_fire_left = maxf(0.0, _fire_left - delta)
	var previous_facing := model.rotation.y
	var progress := 0.0
	var impact := false
	var flat_velocity := get_real_velocity()
	var vertical := flat_velocity.y
	flat_velocity.y = 0.0
	if _swing_tool >= 0:
		var previous := _swing_elapsed / _swing_duration
		_swing_elapsed = minf(_swing_elapsed + delta, _swing_duration)
		progress = _swing_elapsed / _swing_duration
		impact = previous < IMPACT_FRACTION and progress >= IMPACT_FRACTION
	elif aiming:
		model.rotation.y = lerp_angle(model.rotation.y, orbit.rotation.y + PI, minf(18.0 * delta, 1.0))
	elif _pickup_turn_left > 0.0 and direction.length_squared() < 0.02:
		model.rotation.y = lerp_angle(model.rotation.y, _pickup_facing, minf(15.0 * delta, 1.0))
	elif _fire_left <= 0.0 and direction.length_squared() > 0.01:
		var heading := atan2(direction.x, direction.z)
		if flat_velocity.length_squared() > 0.18 and flat_velocity.normalized().dot(direction.normalized()) > 0.40:
			heading = atan2(flat_velocity.x, flat_velocity.z)
		var stiffness := 15.0 if is_on_floor() else 7.0
		model.rotation.y = lerp_angle(model.rotation.y, heading, 1.0 - exp(-stiffness * delta))
	_pickup_turn_left = maxf(0.0, _pickup_turn_left - delta)
	var turn_rate := angle_difference(previous_facing, model.rotation.y) / delta
	var speed_now := flat_velocity.length()
	var local_motion := model.global_basis.inverse() * flat_velocity
	var visual_tool := _swing_tool if is_swinging() else equipped
	var aim_amount := smoothstep(0.0, 1.0, _aim_blend)
	_fire_weight = move_toward(_fire_weight, 0.7 if _fire_left > 0.0 else 0.0, delta * 5.8)
	var raised := maxf(aim_amount, _fire_weight)
	survivor.update_pose(delta, speed_now, is_on_floor(), visual_tool, progress, is_swinging(),
		vertical, _fire_left / RECOIL_TIME, arm.rotation.x * aim_amount,
		local_motion, turn_rate, raised, reload_progress)
	held_tool.transform = survivor.grip_transform()
	_pose_magazine()
	if impact:
		tool_impact.emit(_swing_tool, _swing_facing)
	if progress >= 1.0:
		_swing_tool = -1
		_show_tool()


func _pose_magazine() -> void:
	_magazine_mesh.visible = true
	_magazine_mesh.transform = _magazine_rest
	if equipped != SupplyRules.Tool.CARBINE or reload_progress < 0.24 or reload_progress > 0.78:
		return
	if reload_progress > 0.45 and reload_progress < 0.56:
		_magazine_mesh.hide()
		return
	var attached := smoothstep(0.24, 0.32, reload_progress) * (1.0 - smoothstep(0.71, 0.78, reload_progress))
	var palm := held_tool.transform.affine_inverse() * survivor.magazine_transform()
	_magazine_mesh.transform = _magazine_rest.interpolate_with(palm, attached)


func is_aiming() -> bool:
	return (equipped == SupplyRules.Tool.CARBINE and not is_swinging() and not panel_open
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed(&"aim"))


func _update_aim_camera(aiming: bool, delta: float) -> void:
	if not aiming and _aim_blend == 0.0:
		return
	_aim_blend = move_toward(_aim_blend, 1.0 if aiming else 0.0, AIM_BLEND_SPEED * delta)
	var amount := smoothstep(0.0, 1.0, _aim_blend)
	var side := AIM_OFFSET * amount
	if side > 0.0:
		# Sweep sideways before the spring arm sweeps backward, so its origin cannot move through a wall.
		_shoulder_clearance.transform.origin = orbit.global_position
		_shoulder_clearance.motion = orbit.global_basis.x * side
		side *= get_world_3d().direct_space_state.cast_motion(_shoulder_clearance)[0]
	arm.position.x = side
	arm.spring_length = lerpf(_normal_arm_length, AIM_LENGTH, amount)
	camera.fov = lerpf(_normal_fov, AIM_FOV, amount)
	var crowded := side < 0.52 or arm.get_hit_length() < 0.54
	camera.set_cull_mask_value(PLAYER_VIEW_LAYER, not (aiming and amount > 0.75 and crowded))


func reset_aim_camera() -> void:
	_aim_blend = 0.0
	arm.position.x = 0.0
	arm.spring_length = _normal_arm_length
	camera.fov = _normal_fov
	camera.set_cull_mask_value(PLAYER_VIEW_LAYER, true)


func play_pickup(location: Vector3) -> void:
	var offset := location - global_position
	if Vector2(offset.x, offset.z).length_squared() > 0.02:
		_pickup_facing = atan2(offset.x, offset.z)
		_pickup_turn_left = SurvivorPose.PICKUP_TIME
	survivor.pick_up(Vector2(offset.x, offset.z).length())


func equip(tool: int) -> void:
	equipped = tool
	if equipped != SupplyRules.Tool.CARBINE:
		reload_progress = -1.0
		_fire_weight = 0.0
		_fire_left = 0.0
	_show_tool()


func is_swinging() -> bool:
	return _swing_tool >= 0


func start_swing(tool: int, facing: Vector3) -> bool:
	if is_swinging():
		return false
	_swing_tool = tool
	_swing_facing = facing
	_swing_elapsed = 0.0
	_swing_duration = SWORD_SWING_TIME if tool in [SupplyRules.Tool.STONE_SWORD, SupplyRules.Tool.IRON_AXE] else PICK_SWING_TIME
	_pickup_turn_left = 0.0
	if not facing.is_zero_approx():
		model.rotation.y = atan2(facing.x, facing.z)
	_show_tool()
	return true


func begin_fire(direction: Vector3) -> Vector3:
	model.rotation.y = atan2(direction.x, direction.z)
	var pitch := asin(direction.y) if is_aiming() else 0.0
	var speed := Vector2(velocity.x, velocity.z).length()
	survivor.update_pose(0.0, speed, is_on_floor(), SupplyRules.Tool.CARBINE,
		0.0, false, velocity.y, 0.0, pitch, Vector3.ZERO, 0.0, 1.0)
	held_tool.transform = survivor.grip_transform()
	_fire_left = RECOIL_TIME
	_fire_weight = 1.0
	return (_tool_models[SupplyRules.Tool.CARBINE].get_node("Muzzle") as Node3D).global_position


func relocate(point: Vector3) -> void:
	global_position = point
	velocity = Vector3.ZERO
	_swing_tool = -1
	_fire_left = 0.0
	_fire_weight = 0.0
	reload_progress = -1.0
	_pickup_turn_left = 0.0
	survivor.reset_motion()
	reset_aim_camera()
	_show_tool()


func _show_tool() -> void:
	var active := _swing_tool if is_swinging() else equipped
	for i in range(_tool_models.size()):
		_tool_models[i].visible = i == active
