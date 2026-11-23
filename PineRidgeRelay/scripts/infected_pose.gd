class_name InfectedPose
extends RelayBiped

const STRIKE_RECOVERY := 0.52

var _jaw: int

var _cycle := 0.0
var _gait := 0.0
var _time := 0.0
var _flinch := 0.0
var _voice := 0.0
var _strike_side := 1.0
var _fall := 0.0


func _ready() -> void:
	super._ready()
	_jaw = _rig.find_bone("Jaw")
	_cycle = randf()
	_time = _cycle * TAU
	animate(0.0, 0.0, false, 0.0, 0.0)


func stagger() -> void:
	_flinch = 1.0


func growl(duration: float) -> void:
	_voice = duration


func next_strike() -> void:
	_strike_side = -_strike_side


func collapse(progress: float) -> void:
	_fall = progress


func animate(delta: float, speed: float, chasing: bool, windup: float, recovery: float) -> void:
	_time += delta
	_voice = maxf(0.0, _voice - delta)
	_flinch = maxf(0.0, _flinch - delta * 2.8)
	var stride := lerpf(0.62, 0.75, float(chasing))
	_gait = move_toward(_gait, clampf(speed / 1.5, 0.0, 1.0), delta * 5.2)
	_cycle = fposmod(_cycle + speed * 0.64 / stride * delta, 1.0)
	var left_phase := _cycle
	var right_phase := fposmod(_cycle + 0.45, 1.0)
	var left := _step(left_phase, stride, 0.72, 0.060)
	var right := _step(right_phase, stride, 0.62, 0.135)
	var ankle_l := _rest[_legs[0].end].origin + Vector3(-0.024, left.y, left.x)
	var ankle_r := _rest[_legs[1].end].origin + Vector3(0.032, right.y, right.x)
	var stagger_weight := smoothstep(0.0, 0.76, _flinch)
	# Draw back through the wind-up, drive forward just before impact, then ease out.
	var draw := sin(smoothstep(0.0, 0.70, windup) * PI * 0.5) * (1.0 - smoothstep(0.68, 0.98, windup))
	var hit := maxf(smoothstep(0.64, 1.0, windup), 1.0 - smoothstep(0.0, 1.0, recovery) if recovery > 0.0 else 0.0)
	var hips := Vector3(sin(_cycle * TAU) * 0.036 * _gait,
		-0.041 - draw * 0.065 - hit * 0.095 - _fall * 0.16,
		0.015 - draw * 0.065 + hit * 0.095)
	hips.y = minf(hips.y, minf(
		_hip_limit(_legs[0], ankle_l - Vector3(hips.x, 0, 0), hips.z),
		_hip_limit(_legs[1], ankle_r - Vector3(hips.x, 0, 0), hips.z)))
	_rig.set_bone_global_pose(_hip, Transform3D(_rest[_hip].basis, _rest[_hip].origin + hips))
	_pose_leg(_legs[0], ankle_l, left.z, hips)
	_pose_leg(_legs[1], ankle_r, right.z, hips)

	var pulse := sin(_time * 4.0)
	var twist := 0.10 * cos(_cycle * TAU) * _gait + (hit * 0.30 - draw * 0.36) * _strike_side
	var lean := 0.17 + float(chasing) * _gait * 0.13 + pulse * 0.035 + hit * 0.40 - draw * 0.10
	var roll := 0.068 + sin(_cycle * TAU) * _gait * 0.087 - stagger_weight * 0.29 + hit * _strike_side * 0.08
	var chest := Basis(Vector3.UP, twist) * Basis(Vector3.RIGHT, lean - stagger_weight * 0.29) * Basis(Vector3.BACK, roll)
	var torso := Transform3D(chest, _rest[_chest].origin + hips - chest * _rest[_chest].origin)
	_rig.set_bone_global_pose(_chest, torso * _rest[_chest])
	var head := torso * _rest[_head]
	head.basis = Basis.from_euler(Vector3(-lean * 0.71 - draw * 0.19,
		-twist * 0.85 + pulse * 0.043, -0.13 - roll * 0.41)) * head.basis
	_rig.set_bone_global_pose(_head, head)
	var jaw := _rig.get_bone_global_pose(_jaw)
	var vocal := minf(_voice * 5.0, 1.0) * (0.12 + 0.08 * sin(_time * 14.0))
	jaw.basis = Basis(head.basis * (_rest[_head].basis.inverse() * Vector3.RIGHT),
		0.07 + vocal + hit * 0.21 + draw * 0.10) * jaw.basis
	_rig.set_bone_global_pose(_jaw, jaw)
	_arm(0, torso, left.x, chasing, draw, hit, stagger_weight)
	_arm(1, torso, right.x, chasing, draw, hit, stagger_weight)


func _step(phase: float, stride: float, contact: float, height: float) -> Vector3:
	var reach := stride * _gait
	if phase < contact:
		return Vector3(lerpf(0.5, -0.5, phase / contact) * reach, 0.0, 0.0)
	var travel := (phase - contact) / (1.0 - contact)
	var lift := sin(travel * PI)
	var pitch := -sin(travel * TAU) * height * 1.3 * _gait
	return Vector3(lerpf(-0.5, 0.5, smoothstep(0.0, 1.0, travel)) * reach,
		lift * height * _gait + absf(sin(pitch)) * 0.16, pitch)


func _arm(index: int, torso: Transform3D, step: float, chasing: bool,
		draw: float, hit: float, stagger_weight: float) -> void:
	var side := -1.0 if index == 0 else 1.0
	var active := side == _strike_side
	var wrist := torso * _rest[_arms[index].end].origin
	var lifted := 0.04 + 0.07 * float(chasing)
	wrist += Vector3(side * 0.037, lifted + maxf(step, 0.0) * 0.19, 0.10 - step * 0.55)
	if active:
		wrist = wrist.lerp(Vector3(side * 0.43, 1.29, -0.19), draw)
		wrist = wrist.lerp(Vector3(side * 0.14, 1.23, 0.64), hit)
	else:
		wrist = wrist.lerp(Vector3(side * 0.31, 1.20, 0.41), hit * 0.69)
	wrist += Vector3(side * stagger_weight * 0.16, stagger_weight * 0.12, -stagger_weight * 0.18)
	_solve_limb(_arms[index], torso, wrist, Vector3(side * 0.54, -0.52, -0.46))
