class_name RelayInfected
extends CharacterBody3D

const SPEED := 1.95
const PLAYER_REACH := 1.05
const PLAYER_STRIKE_INTERVAL := 1.60
const PLAYER_WINDUP := 0.48

var home: Vector3
var nest: int
var chasing := false
var returning := false
var _wander_target := Vector3.ZERO
var _wander_in := 0.0
var sight_lost_for := 0.0
var last_seen_player := Vector3.ZERO
var health := 3
var _player_attack_in := PLAYER_WINDUP
var _fall_time := 0.0
var _fall_side := 1.0
var _struck := false
var _detour_side := 1.0

@onready var model: InfectedPose = $Model


func _ready() -> void:
	_wander_target = home
	_fall_side = -1.0 if randi() % 2 == 0 else 1.0
	set_physics_process(false)


func return_home() -> void:
	chasing = false
	returning = true
	_player_attack_in = PLAYER_WINDUP
	_wander_in = 1.0


func roam(delta: float) -> void:
	if returning:
		var offset := home - global_position
		offset.y = 0
		if offset.length_squared() < 0.65 ** 2:
			returning = false
			_wander_target = home
		_move(delta, offset if returning else Vector3.ZERO, rotation.y, 1.45)
	else:
		_wander_in -= delta
		if _wander_in <= 0:
			_wander_in = randf_range(2.3, 4.2)
			var heading := randf() * TAU
			_wander_target = home + Vector3(sin(heading), 0, cos(heading)) * randf_range(0.6, 2.3)
		var offset := _wander_target - global_position
		offset.y = 0
		_move(delta, offset if offset.length_squared() > 0.12 else Vector3.ZERO, rotation.y, 0.68)
	_animate(delta, false, 0.0, 0.0)


func pursue(delta: float, may_strike: bool) -> bool:
	var offset := last_seen_player - global_position
	var height := absf(offset.y)
	offset.y = 0.0
	var distance := offset.length()
	var in_reach := may_strike and distance <= PLAYER_REACH and height < 0.95
	var facing := atan2(offset.x, offset.z) if not offset.is_zero_approx() else rotation.y
	var travel := Vector3.ZERO if in_reach else offset.normalized() * maxf(distance - 0.86, 0.0)
	_move(delta, travel, facing)

	_player_attack_in = maxf(0.0, _player_attack_in - delta)
	if not in_reach:
		# Moving away before contact interrupts the strike.
		_player_attack_in = maxf(_player_attack_in, PLAYER_WINDUP)
		_animate(delta, true, 0.0, 0.0)
		return false
	var contact := _player_attack_in <= 0.0
	_strike_pose(delta, true, _player_attack_in, PLAYER_STRIKE_INTERVAL, PLAYER_WINDUP, contact)
	if contact:
		_player_attack_in = PLAYER_STRIKE_INTERVAL
	return contact


func _strike_pose(delta: float, chasing: bool, next_hit: float, interval: float,
		windup_time: float, contact: bool) -> void:
	var windup := clampf(1.0 - next_hit / windup_time, 0.0, 1.0)
	var since_hit := interval - next_hit
	var recovery := 0.0
	if _struck and since_hit < InfectedPose.STRIKE_RECOVERY:
		recovery = clampf(since_hit / InfectedPose.STRIKE_RECOVERY, 0.001, 1.0)
	if _struck and recovery == 0.0 and not contact:
		_struck = false
		model.next_strike()
	_struck = _struck or contact
	_animate(delta, chasing, windup, recovery)


func _animate(delta: float, chasing: bool, windup: float, recovery: float) -> void:
	var motion := get_real_velocity()
	model.animate(delta, Vector2(motion.x, motion.z).length(), chasing, windup, recovery)


func _move(delta: float, offset: Vector3, rest_facing: float, top_speed := SPEED) -> void:
	var course := Vector3.ZERO if offset.is_zero_approx() else _clear_course(offset)
	var speed := minf(top_speed, offset.length() / delta)
	velocity.x = course.x * speed
	velocity.z = course.z * speed
	var desired_yaw := rest_facing if course.is_zero_approx() else atan2(course.x, course.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, minf(delta * 8.0, 1.0))
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	move_and_slide()


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


func take_hit(damage: int) -> bool:
	health -= damage
	model.stagger()
	if health > 0:
		return false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(true)
	return true


func _physics_process(delta: float) -> void:
	_fall_time += delta
	var fall := smoothstep(0.0, 0.51, _fall_time)
	model.collapse(fall)
	model.rotation.x = -1.28 * fall
	model.rotation.z = _fall_side * 0.34 * fall
	model.position = Vector3(_fall_side * 0.23 * fall, 0.18 * fall, -0.38 * fall)
	model.animate(delta, 0.0, false, 0.0, 0.0)
	if _fall_time >= 1.40:
		queue_free()
