class_name RelayPlayer
extends CharacterBody3D

const WALK_SPEED := 4.1
const RUN_SPEED := 6.6
const JUMP_SPEED := 6.3
const LOOK_SENSITIVITY := 0.0026

@onready var orbit: Node3D = $Orbit
@onready var arm: SpringArm3D = $Orbit/Arm
@onready var model: Node3D = $Model
@onready var left_leg: Node3D = $Model/LeftLeg
@onready var right_leg: Node3D = $Model/RightLeg

@onready var sword: Node3D = $Model/Sword

var _stride := 0.0
var _swing_left := 0.0


func _ready() -> void:
	arm.add_excluded_object(get_rid())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
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

	if _swing_left > 0.0:
		_swing_left = maxf(0.0, _swing_left - delta)
		sword.rotation.x = -1.5 * sin(_swing_left / 0.28 * PI)
	elif direction.length_squared() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.z), minf(12.0 * delta, 1.0))
	var motion := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	_stride += motion * delta * 2.65
	var swing := sin(_stride) * minf(motion / WALK_SPEED, 1.0) * 0.48
	left_leg.rotation.x = lerpf(left_leg.rotation.x, swing, minf(15.0 * delta, 1.0))
	right_leg.rotation.x = -left_leg.rotation.x



func swing_sword(facing: Vector3) -> void:
	model.rotation.y = atan2(facing.x, facing.z)
	_swing_left = 0.28
