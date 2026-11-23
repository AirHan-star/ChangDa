class_name RelayInfected
extends CharacterBody3D

const SPEED := 1.95
const HIT_INTERVAL := 2.55

var lane: int
var health := 3
var _attack_in := 0.9
var _stride := 0.0
var _hit_feedback := 0.0

@onready var model: Node3D = $Model
@onready var left_leg: Node3D = $Model/Visual/LeftLeg
@onready var right_leg: Node3D = $Model/Visual/RightLeg
@onready var left_arm: Node3D = $Model/Visual/LeftArm
@onready var right_arm: Node3D = $Model/Visual/RightArm
@onready var left_elbow: Node3D = $Model/Visual/LeftArm/ElbowLeft
@onready var right_elbow: Node3D = $Model/Visual/RightArm/ElbowRight


func advance(delta: float, stop_z: float, front: bool) -> bool:
	var distance := global_position.z - stop_z
	velocity.z = -minf(SPEED, maxf(distance, 0.0) / delta)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	move_and_slide()

	_stride += delta * 7.25
	var moving := distance > 0.10
	var swing := sin(_stride) * 0.29 if moving else 0.0
	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
	left_arm.rotation.x = -1.15 + swing * 0.55
	right_arm.rotation.x = -1.25 - swing * 0.55
	left_elbow.rotation.x = -0.23 + swing * 0.37
	right_elbow.rotation.x = -0.14 - swing * 0.26
	_hit_feedback = maxf(0.0, _hit_feedback - delta)
	model.rotation.z = _hit_feedback * 0.74

	if not front or moving:
		return false
	_attack_in -= delta
	if _attack_in <= 0.0:
		_attack_in += HIT_INTERVAL
		return true
	if _attack_in > HIT_INTERVAL - 0.38:
		right_arm.rotation.x = -1.86
		right_elbow.rotation.x = -0.44
	return false


func take_sword_hit() -> bool:
	health -= 2
	_hit_feedback = 0.22
	return health <= 0
