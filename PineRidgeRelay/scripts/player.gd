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

@onready var orbit: Node3D = $Orbit
@onready var arm: SpringArm3D = $Orbit/Arm
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


func _ready() -> void:
	arm.add_excluded_object(get_rid())
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
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		steer = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var direction := orbit.basis * Vector3(steer.x, 0.0, steer.y)
	var sprint := Input.is_action_pressed(&"sprint")
	var speed := RUN_SPEED if sprint else WALK_SPEED
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(direction * speed, 28.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_just_pressed(&"jump"):
		velocity.y = JUMP_SPEED
	elif not is_on_floor():
		velocity.y -= 18.0 * delta
	move_and_slide()

	var progress := 0.0
	var impact := false
	if _swing_tool >= 0:
		var previous := _swing_elapsed / _swing_duration
		_swing_elapsed = minf(_swing_elapsed + delta, _swing_duration)
		progress = _swing_elapsed / _swing_duration
		impact = previous < IMPACT_FRACTION and progress >= IMPACT_FRACTION
	elif direction.length_squared() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.z), minf(12.0 * delta, 1.0))
	elif _pickup_turn_left > 0.0:
		model.rotation.y = lerp_angle(model.rotation.y, _pickup_facing, minf(14.0 * delta, 1.0))
	_pickup_turn_left = maxf(0.0, _pickup_turn_left - delta)
	var motion := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	var visual_tool := _swing_tool if is_swinging() else equipped
	survivor.update_pose(delta, motion, is_on_floor(), visual_tool, progress, is_swinging(), get_real_velocity().y)
	held_tool.transform = survivor.grip_transform()
	if impact:
		tool_impact.emit(_swing_tool, _swing_facing)
	if progress >= 1.0:
		_swing_tool = -1
		_show_tool()


func play_pickup(location: Vector3) -> void:
	var offset := location - global_position
	if Vector2(offset.x, offset.z).length_squared() > 0.02:
		_pickup_facing = atan2(offset.x, offset.z)
		_pickup_turn_left = SurvivorPose.PICKUP_TIME
	survivor.pick_up()


func equip(tool: int) -> void:
	equipped = tool
	_show_tool()


func is_swinging() -> bool:
	return _swing_tool >= 0


func start_swing(tool: int, facing: Vector3) -> bool:
	if is_swinging():
		return false
	_swing_tool = tool
	_swing_facing = facing
	_swing_elapsed = 0.0
	_swing_duration = SWORD_SWING_TIME if tool == SupplyRules.Tool.STONE_SWORD else PICK_SWING_TIME
	_pickup_turn_left = 0.0
	if not facing.is_zero_approx():
		model.rotation.y = atan2(facing.x, facing.z)
	_show_tool()
	return true


func _show_tool() -> void:
	var active := _swing_tool if is_swinging() else equipped
	for i in range(_tool_models.size()):
		_tool_models[i].visible = i == active
