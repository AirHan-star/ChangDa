class_name RelayInfected
extends CharacterBody3D

const SPEED := 1.95
const HIT_INTERVAL := 2.55

var lane: int
var health := 3
var _attack_in := 0.9
var _stride := 0.0
var _hit_feedback := 0.0
var _detour_side := 1.0

@onready var model: Node3D = $Model
@onready var left_leg: Node3D = $Model/Visual/LeftLeg
@onready var right_leg: Node3D = $Model/Visual/RightLeg
@onready var left_arm: Node3D = $Model/Visual/LeftArm
@onready var right_arm: Node3D = $Model/Visual/RightArm
@onready var left_elbow: Node3D = $Model/Visual/LeftArm/ElbowLeft
@onready var right_elbow: Node3D = $Model/Visual/RightArm/ElbowRight


func advance(delta: float, lane_x: float, stop_z: float, front: bool) -> bool:
	var offset := Vector3(lane_x - global_position.x, 0.0, stop_z - global_position.z)
	var arrived := absf(offset.z) < 0.08 and absf(offset.x) < 0.20
	var course := Vector3.ZERO if arrived else _clear_course(offset)
	var speed := minf(SPEED, offset.length() / delta)
	velocity.x = course.x * speed
	velocity.z = course.z * speed
	if not course.is_zero_approx():
		rotation.y = lerp_angle(rotation.y, atan2(course.x, course.z), minf(delta * 8.0, 1.0))
	elif arrived:
		rotation.y = lerp_angle(rotation.y, PI, minf(delta * 9.0, 1.0))
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	move_and_slide()

	_stride += delta * 7.25
	var moving := Vector2(get_real_velocity().x, get_real_velocity().z).length_squared() > 0.02
	var swing := sin(_stride) * 0.29 if moving else 0.0
	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
	left_arm.rotation.x = -1.15 + swing * 0.55
	right_arm.rotation.x = -1.25 - swing * 0.55
	left_elbow.rotation.x = -0.23 + swing * 0.37
	right_elbow.rotation.x = -0.14 - swing * 0.26
	_hit_feedback = maxf(0.0, _hit_feedback - delta)
	model.rotation.z = _hit_feedback * 0.74

	if not front or not arrived:
		return false
	_attack_in -= delta
	if _attack_in <= 0.0:
		_attack_in += HIT_INTERVAL
		return true
	if _attack_in > HIT_INTERVAL - 0.38:
		right_arm.rotation.x = -1.86
		right_elbow.rotation.x = -0.44
	return false


func _clear_course(offset: Vector3) -> Vector3:
	var heading := offset.normalized()
	var look_ahead := minf(offset.length(), 1.0)
	if not test_move(global_transform, heading * look_ahead):
		return heading
	# Stay on the chosen side of an obstruction until the direct route clears.
	for turn in [0.70, 1.20, 1.61]:
		for side in [_detour_side, -_detour_side]:
			var candidate := heading.rotated(Vector3.UP, turn * side)
			if not test_move(global_transform, candidate * look_ahead):
				_detour_side = side
				return candidate
	return Vector3.ZERO


func take_sword_hit() -> bool:
	health -= 2
	_hit_feedback = 0.22
	return health <= 0
