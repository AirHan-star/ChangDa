class_name SurvivorPose
extends RelayBiped
## Visual pose driver. The CharacterBody3D owns movement and collision.

signal foot_planted(point: Vector3, heavy: bool)

const PICKUP_TIME := 0.52
# Wind-up, impact and recovery use the same normalized clock as the hit.
const SWING_PHASES: Array[float] = [0.0, 0.30, 0.56, 0.79, 1.0]
# The pelvis leads the draw and turns back before the hands reach impact.
const WAIST_PHASES: Array[float] = [0.0, 0.22, 0.49, 0.76, 1.0]
const PICK_WAIST: Array[Vector3] = [
	Vector3.ZERO, Vector3(-0.072, 0.23, -0.073), Vector3(0.10, -0.14, 0.041),
	Vector3(0.058, -0.18, 0.051), Vector3.ZERO,
]
const SWORD_WAIST: Array[Vector3] = [
	Vector3.ZERO, Vector3(-0.072, 0.32, -0.074), Vector3(0.08, -0.22, 0.053),
	Vector3(0.047, -0.27, 0.052), Vector3.ZERO,
]
const PICK_CHEST: Array[Vector3] = [
	Vector3.ZERO, Vector3(-0.19, 0.46, -0.15), Vector3(0.32, -0.15, 0.10),
	Vector3(0.15, -0.35, 0.048), Vector3.ZERO,
]
const SWORD_CHEST: Array[Vector3] = [
	Vector3.ZERO, Vector3(-0.14, 0.67, -0.11), Vector3(0.16, -0.25, 0.08),
	Vector3(0.065, -0.56, 0.13), Vector3.ZERO,
]
const PICK_WRISTS: Array[Vector3] = [
	Vector3(0.37, 0.93, 0.03), Vector3(0.36, 1.52, -0.13),
	Vector3(0.30, 0.86, 0.47), Vector3(0.34, 0.76, 0.25), Vector3(0.37, 0.93, 0.03),
]
const PICK_ANGLES: Array[Vector3] = [
	Vector3(-1.13, 0.14, -0.08), Vector3(-2.83, 0.08, 0.12),
	Vector3(-1.23, -0.03, 0.05), Vector3(-0.53, -0.10, -0.13), Vector3(-1.13, 0.14, -0.08),
]
const SWORD_WRISTS: Array[Vector3] = [
	Vector3(0.37, 0.93, 0.03), Vector3(0.59, 1.35, -0.17),
	Vector3(0.16, 1.10, 0.49), Vector3(-0.25, 0.99, 0.35), Vector3(0.37, 0.93, 0.03),
]
const SWORD_ANGLES: Array[Vector3] = [
	Vector3(-0.77, -0.16, -0.09), Vector3(-1.98, 0.94, 1.18),
	Vector3(-1.41, -0.30, 0.42), Vector3(-1.08, -1.14, -0.56), Vector3(-0.77, -0.16, -0.09),
]
const PICK_FREE_HAND: Array[Vector3] = [
	Vector3(-0.37, 0.93, 0.04), Vector3(-0.32, 1.21, 0.36),
	Vector3(-0.38, 1.05, 0.23), Vector3(-0.40, 0.88, -0.10), Vector3(-0.37, 0.93, 0.04),
]
const SWORD_FREE_HAND: Array[Vector3] = [
	Vector3(-0.37, 0.93, 0.04), Vector3(-0.30, 1.21, 0.32),
	Vector3(-0.50, 1.12, -0.02), Vector3(-0.46, 1.03, -0.21), Vector3(-0.37, 0.93, 0.04),
]
const WALK_SPEED := 4.1
const RUN_SPEED := 6.6

var _spine: int
var _cycle := 0.0
var _gait := 0.0
var _elapsed := 0.0
var _reach_left := 0.0
var _lift := 0.0
var _air_time := 0.0
var _landing := 0.0
var _hurt := 0.0
var _hurt_side := 1.0
var _grip := Transform3D.IDENTITY
var _pick_mount := Transform3D.IDENTITY
var _sword_mount := Transform3D.IDENTITY
var _tool_basis := Basis.IDENTITY


func _ready() -> void:
	super._ready()
	_spine = _rig.find_bone("Spine")
	var hand_rest := _rest[_arms[1].end].basis.inverse()
	# The pick's shaft follows the palm's transverse axis, not the forearm.
	_pick_mount = Transform3D(
		hand_rest * Basis(Vector3.RIGHT, -PI * 0.5),
		hand_rest * Vector3(-0.014, -0.048, 0.017))
	_sword_mount = Transform3D(_pick_mount.basis, hand_rest * Vector3(-0.016, -0.049, 0.018))
	update_pose(0.0, 0.0, true)


func pick_up() -> void:
	_reach_left = PICKUP_TIME


func flinch() -> void:
	_hurt = 1.0
	_hurt_side = -_hurt_side


func grip_transform() -> Transform3D:
	return global_transform.affine_inverse() * _rig.global_transform * _grip


func update_pose(delta: float, speed: float, grounded: bool, tool := -1,
		progress := 0.0, swinging := false, rising_speed := 0.0, recoil_shot := 0.0, aim_pitch := 0.0) -> void:
	_elapsed += delta
	_reach_left = maxf(0.0, _reach_left - delta)
	var pickup_progress := 1.0 - _reach_left / PICKUP_TIME
	var reach := smoothstep(0.0, 0.43, pickup_progress) * (1.0 - smoothstep(0.50, 1.0, pickup_progress))
	reach *= 1.0 - minf(speed / 10.0, 0.55)
	_hurt = maxf(0.0, _hurt - delta * 3.35)
	var recoil := smoothstep(0.0, 0.68, _hurt)
	var firearm := tool == SupplyRules.Tool.CARBINE
	var sword_equipped := tool in [SupplyRules.Tool.STONE_SWORD, SupplyRules.Tool.IRON_AXE]
	var pick_equipped := tool >= 0 and not sword_equipped and not firearm
	var waist_turn := Vector3.ZERO
	var chest_turn := Vector3.ZERO
	if swinging:
		reach = 0.0
		_reach_left = 0.0
		waist_turn = _sample(progress, SWORD_WAIST if sword_equipped else PICK_WAIST, WAIST_PHASES)
		chest_turn = _sample(progress, SWORD_CHEST if sword_equipped else PICK_CHEST)
	_tool_basis = Basis.from_euler(_sample(progress, PICK_ANGLES if pick_equipped else SWORD_ANGLES))
	var landed := grounded and _air_time > 0.12
	if grounded:
		_landing = 1.0 if landed else maxf(0.0, _landing - delta * 5.8)
		_air_time = 0.0
	else:
		_air_time += delta
	_lift = move_toward(_lift, 0.0 if grounded else 1.0, delta * 10.0)
	var running := smoothstep(WALK_SPEED, RUN_SPEED, speed)
	_gait = move_toward(_gait, clampf(speed / WALK_SPEED, 0.0, 1.0), delta * 6.5)
	var stride := lerpf(0.80, 1.02, running)
	var contact := lerpf(0.59, 0.43, running)
	var phase_advance := speed * contact / stride * delta
	var previous_cycle := _cycle
	if grounded:
		_cycle = fposmod(_cycle + phase_advance, 1.0)
	var step_l := _step(_cycle, stride, contact, running)
	var step_r := _step(fposmod(_cycle + 0.5, 1.0), stride, contact, running)
	if _lift > 0.0:
		var tuck := smoothstep(-5.0, 1.0, rising_speed)
		step_l = step_l.lerp(Vector3(0.12, 0.044 + 0.095 * tuck, -0.13), _lift)
		step_r = step_r.lerp(Vector3(-0.16, 0.067 + 0.117 * tuck, -0.25), _lift)

	var ankle_l := _rest[_legs[0].end].origin + Vector3(0.0, step_l.y, step_l.x)
	var ankle_r := _rest[_legs[1].end].origin + Vector3(0.0, step_r.y, step_r.x)
	var stride_angle := _cycle * TAU
	var stride_sway := cos(stride_angle) * _gait
	var stride_twist := sin(stride_angle) * _gait
	var brace := 1.0 - minf(_gait + _lift, 1.0)
	var hips := Vector3(0.025 * stride_sway + waist_turn.y * 0.24 * brace,
		-0.011 - 0.025 * _gait - reach * 0.33 - 0.11 * _landing - 0.031 * recoil,
		0.025 * running - 0.072 * reach + waist_turn.x * 0.36 * brace)
	hips.y += 0.014 * _gait * cos(stride_angle * 2.0) + sin(_elapsed * 2.5) * 0.002
	hips.y -= 0.22 * maxf(0.0, waist_turn.x)
	var hip_angles := Vector3(0.025 * running - 0.12 * reach,
		-stride_twist * lerpf(0.063, 0.115, running), -0.034 * stride_sway) + waist_turn
	var pelvis := _joint_frame(_hip, Basis.from_euler(hip_angles), _rest[_hip].origin + hips)
	pelvis.origin.y += minf(0.0, minf(
		_leg_height_margin(_legs[0], ankle_l, pelvis), _leg_height_margin(_legs[1], ankle_r, pelvis)))
	_rig.set_bone_global_pose(_hip, pelvis * _rest[_hip])

	var lean := lerpf(0.025, 0.20, running) + 0.023 * _gait + 0.68 * reach + 0.18 * _landing - 0.17 * recoil
	var roll := stride_sway * lerpf(0.052, 0.086, running) + 0.10 * recoil * _hurt_side
	var twist := stride_twist * lerpf(0.115, 0.170, running) - 0.14 * recoil * _hurt_side
	var breath := sin(_elapsed * 2.4) * 0.009 * (1.0 - _gait)
	var torso := _pose_torso(pelvis, Vector3(lean + breath, twist, roll), chest_turn, -0.08 * running - 0.29 * reach)

	# Let the rear foot pivot without moving either contact point across the ground.
	_pose_leg(_legs[0], ankle_l, step_l.z, pelvis, waist_turn.y * 0.14 * brace)
	_pose_leg(_legs[1], ankle_r, step_r.z, pelvis, waist_turn.y * 0.64 * brace)
	var swing_tool := tool if swinging else -1
	_pose_arm(_arms[0], torso, -1.0, step_l.x, running, reach, swing_tool, progress)
	_pose_arm(_arms[1], torso, 1.0, step_r.x, running, 0.0, swing_tool, progress)
	if firearm:
		_aim(torso, recoil_shot, aim_pitch)
	_attach_tool(pick_equipped, sword_equipped or firearm)
	if landed:
		foot_planted.emit(to_global(Vector3(0.0, 0.04, 0.0)), true)
	elif grounded and speed > 1.0:
		if _cycle < previous_cycle:
			foot_planted.emit(to_global(ankle_l - Vector3.UP * 0.10), running > 0.5)
		elif previous_cycle < 0.5 and _cycle >= 0.5:
			foot_planted.emit(to_global(ankle_r - Vector3.UP * 0.10), running > 0.5)


func _joint_frame(bone: int, rotation_basis: Basis, pivot: Vector3) -> Transform3D:
	return Transform3D(rotation_basis, pivot - rotation_basis * _rest[bone].origin)


func _pose_torso(pelvis: Transform3D, base_angles: Vector3, swing_angles: Vector3,
		head_pitch: float) -> Transform3D:
	var upper_body := Basis.from_euler(base_angles + swing_angles)
	var spine_basis := pelvis.basis.slerp(upper_body, 0.46)
	var spine := _joint_frame(_spine, spine_basis, pelvis * _rest[_spine].origin)
	_rig.set_bone_global_pose(_spine, spine * _rest[_spine])
	var torso := _joint_frame(_chest, upper_body, spine * _rest[_chest].origin)
	_rig.set_bone_global_pose(_chest, torso * _rest[_chest])
	var head := torso * _rest[_head]
	# Keep eyes near the contact point while the shoulders turn through the strike.
	var counter := Vector3(head_pitch - swing_angles.x * 0.44, -swing_angles.y * 0.72, -swing_angles.z * 0.72)
	head.basis = Basis.from_euler(counter) * head.basis
	_rig.set_bone_global_pose(_head, head)
	return torso


func _step(phase: float, stride: float, contact: float, run: float) -> Vector3:
	var travel := stride * _gait
	if phase < contact:
		return Vector3(lerpf(0.5, -0.5, phase / contact) * travel, 0.0, 0.0)
	var through := (phase - contact) / (1.0 - contact)
	var z := lerpf(-0.5, 0.5, smoothstep(0.0, 1.0, through)) * travel
	var pitch := -sin(through * TAU) * _gait * lerpf(0.16, 0.25, run)
	var lift := pow(sin(through * PI), 1.25) * _gait * lerpf(0.11, 0.235, run)
	# Leave room for the toe and heel as the boot rotates around its ankle.
	lift += absf(sin(pitch)) * 0.18
	return Vector3(z, lift, pitch)


func _pose_arm(arm: Limb, torso: Transform3D, side: float, step: float,
		running: float, reach: float, tool: int, progress: float) -> void:
	var wrist := torso * _rest[arm.end].origin
	wrist.x += side * (0.019 + 0.022 * _gait)
	wrist.y += _gait * (0.018 + 0.07 * running) + absf(step) * 0.22
	wrist.z -= step * lerpf(0.53, 0.68, running)
	wrist = wrist.lerp(Vector3(-0.274, 0.45, 0.54), reach)
	if tool >= 0:
		var weight := smoothstep(0.0, 0.16, progress) * (1.0 - smoothstep(0.80, 1.0, progress))
		var sword := tool == SupplyRules.Tool.STONE_SWORD
		var keys: Array[Vector3]
		if side > 0.0:
			keys = SWORD_WRISTS if sword else PICK_WRISTS
		else:
			keys = SWORD_FREE_HAND if sword else PICK_FREE_HAND
		var shoulder := _rest[arm.upper].origin
		var target := _sample(progress, keys) + (torso * shoulder - shoulder) * 0.30
		wrist = wrist.lerp(target, weight)
	_solve_limb(arm, torso, wrist, torso.basis * Vector3(side * 0.33, -0.14, -0.91))


func _aim(torso: Transform3D, recoil: float, pitch: float) -> void:
	var elevation := pitch + recoil * 0.21
	_tool_basis = Basis(Vector3.RIGHT, -PI * 0.5 - elevation)
	var stock := Vector3(0.23, 1.27 + recoil * 0.04, 0.30 - recoil * 0.09)
	_solve_limb(_arms[1], torso, stock, Vector3(0.78, -0.61, -0.31))
	var support := Vector3(0.12, 1.20 + sin(elevation) * 0.20, 0.30 + cos(elevation) * 0.20 - recoil * 0.08)
	_solve_limb(_arms[0], torso, support, Vector3(-0.76, -0.44, -0.35))


func _attach_tool(pick_equipped: bool, sword_equipped: bool) -> void:
	var wrist := _arms[1].end
	var hand := _rig.get_bone_global_pose(wrist)
	if not pick_equipped and not sword_equipped:
		_grip = hand * _pick_mount
		return
	var mount := _pick_mount if pick_equipped else _sword_mount
	hand.basis = _tool_basis * mount.basis.inverse()
	_rig.set_bone_global_pose(wrist, hand)
	_grip = hand * mount


func _sample(progress: float, keys: Array[Vector3], phases: Array[float] = SWING_PHASES) -> Vector3:
	for i in range(1, phases.size()):
		if progress <= phases[i]:
			var weight := smoothstep(phases[i - 1], phases[i], progress)
			return keys[i - 1].lerp(keys[i], weight)
	return keys.back()
