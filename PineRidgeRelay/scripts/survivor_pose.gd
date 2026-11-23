class_name SurvivorPose
extends RelayBiped
## Visual pose driver. The CharacterBody3D owns movement and collision.

signal foot_planted(point: Vector3, heavy: bool)

const PICKUP_TIME := 0.56
# Wind-up, impact and recovery use the same normalized clock as the hit.
const SWING_PHASES: Array[float] = [0.0, 0.31, 0.56, 0.76, 1.0]
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
	Vector3(0.37, 0.93, 0.03), Vector3(0.35, 1.54, -0.10),
	Vector3(0.25, 0.85, 0.46), Vector3(0.34, 0.76, 0.25), Vector3(0.37, 0.93, 0.03),
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
const AXE_WRISTS: Array[Vector3] = [
	Vector3(0.36, 0.94, 0.03), Vector3(0.50, 1.46, -0.13), Vector3(0.24, 0.93, 0.49),
	Vector3(0.04, 0.80, 0.30), Vector3(0.36, 0.94, 0.03),
]
const AXE_ANGLES: Array[Vector3] = [
	Vector3(-1.02, 0.10, -0.08), Vector3(-2.37, 0.83, 0.54), Vector3(-1.20, -0.14, 0.15),
	Vector3(-0.72, -0.63, -0.30), Vector3(-1.02, 0.10, -0.08),
]
const WALK_SPEED := 4.1
const RUN_SPEED := 6.6

var _spine: int
var _pack: int
var _cargo: int
var _feet: Array[SurvivorContact] = [SurvivorContact.new(), SurvivorContact.new()]
var _motion_axis := Vector3.BACK
var _last_vertical := 0.0
var _load_angle := Vector3.ZERO
var _load_speed := Vector3.ZERO
var _turn := 0.0
var _pickup_distance := 0.62
var _magazine_hand := Transform3D.IDENTITY
var _equip_weight := 0.0
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
	_pack = _rig.find_bone("Pack")
	_cargo = _rig.find_bone("Cargo")
	var hand_rest := _rest[_arms[1].end].basis.inverse()
	# The pick's shaft follows the palm's transverse axis, not the forearm.
	_pick_mount = Transform3D(
		hand_rest * Basis(Vector3.RIGHT, -PI * 0.5),
		hand_rest * Vector3(-0.014, -0.048, 0.017))
	_sword_mount = Transform3D(_pick_mount.basis, hand_rest * Vector3(-0.016, -0.049, 0.018))
	update_pose(0.0, 0.0, true)


func pick_up(distance := 0.62) -> void:
	_pickup_distance = clampf(distance, 0.44, 0.69)
	_reach_left = PICKUP_TIME


func reset_motion() -> void:
	_cycle = 0.0
	_gait = 0.0
	_air_time = 0.0
	_lift = 0.0
	_landing = 0.0
	_last_vertical = 0.0
	_reach_left = 0.0
	_motion_axis = Vector3.BACK
	_turn = 0.0
	_equip_weight = 0.0
	_load_angle = Vector3.ZERO
	_load_speed = Vector3.ZERO
	for foot in _feet:
		foot.reset()


func magazine_transform() -> Transform3D:
	return global_transform.affine_inverse() * _rig.global_transform * _magazine_hand


func flinch() -> void:
	_hurt = 1.0
	_hurt_side = -_hurt_side


func grip_transform() -> Transform3D:
	return global_transform.affine_inverse() * _rig.global_transform * _grip


func update_pose(delta: float, speed: float, grounded: bool, tool := -1,
		progress := 0.0, swinging := false, rising_speed := 0.0, recoil_shot := 0.0, aim_pitch := 0.0,
		motion := Vector3.BACK, yaw_rate := 0.0, aim_weight := 0.0, reload := -1.0) -> void:
	_elapsed += delta
	_reach_left = maxf(0.0, _reach_left - delta)
	var pickup_progress := 1.0 - _reach_left / PICKUP_TIME
	var reach := smoothstep(0.03, 0.45, pickup_progress) * (1.0 - smoothstep(0.55, 1.0, pickup_progress))
	reach *= 1.0 - minf(speed / 7.0, 0.79)
	_hurt = maxf(0.0, _hurt - delta * 3.35)
	var hit_reaction := smoothstep(0.0, 0.68, _hurt)
	var firearm := tool == SupplyRules.Tool.CARBINE
	_equip_weight = move_toward(_equip_weight, 1.0 if firearm else 0.0, delta * 6.4)
	var axe := tool == SupplyRules.Tool.IRON_AXE
	var blade := tool == SupplyRules.Tool.STONE_SWORD
	var pick := tool >= 0 and not blade and not axe and not firearm
	var waist_turn := Vector3.ZERO
	var chest_turn := Vector3.ZERO
	if swinging:
		reach = 0.0
		_reach_left = 0.0
		waist_turn = _sample(progress, SWORD_WAIST if blade or axe else PICK_WAIST, WAIST_PHASES)
		chest_turn = _sample(progress, SWORD_CHEST if blade else PICK_CHEST)
	_tool_basis = Basis.from_euler(_sample(progress, _tool_angles(tool)))

	var landed := grounded and _air_time > 0.12
	if grounded:
		_landing = clampf(absf(_last_vertical) / 6.5, 0.30, 1.18) if landed else move_toward(_landing, 0.0, delta * 5.1)
		_air_time = 0.0
	else:
		_air_time += delta
		_last_vertical = rising_speed
	_lift = move_toward(_lift, 0.0 if grounded else 1.0, delta * (12.0 if grounded else 9.0))
	_turn = lerpf(_turn, clampf(yaw_rate / 7.0, -1.0, 1.0), minf(delta * 12.0, 1.0))
	if motion.length_squared() > 0.01:
		var direction := motion.normalized()
		var heading := atan2(_motion_axis.x, _motion_axis.z)
		var desired := atan2(direction.x, direction.z)
		var angle := lerp_angle(heading, desired, minf(delta * 20.0, 1.0))
		_motion_axis = Vector3(sin(angle), 0, cos(angle))

	var running := smoothstep(WALK_SPEED, RUN_SPEED, speed)
	var strafe := absf(_motion_axis.x)
	var stride := lerpf(1.04, 1.17, running) * (1.0 - strafe * 0.16)
	var contact := lerpf(0.57, 0.43, running)
	var pivot := absf(_turn) * (1.0 - smoothstep(0.05, 1.05, speed))
	_gait = move_toward(_gait, clampf(speed / WALK_SPEED, 0.0, 1.0), delta * (5.2 if speed < 0.1 else 7.4))
	var prior_cycle := _cycle
	if grounded:
		var frequency := speed * contact / stride + pivot * 1.25
		_cycle = fposmod(_cycle + frequency * delta, 1.0)
	var phases := Vector2(_cycle, fposmod(_cycle + 0.5, 1.0))
	var step_l := _step(phases.x, stride, contact, running)
	var step_r := _step(phases.y, stride, contact, running)
	var floor_space: PhysicsDirectSpaceState3D
	if delta > 0.0 and is_inside_tree():
		floor_space = get_world_3d().direct_space_state
	var ankle_l := _ankle(0, step_l, phases.x < contact, pivot, reach, grounded, rising_speed, delta, floor_space)
	var ankle_r := _ankle(1, step_r, phases.y < contact, pivot, reach, grounded, rising_speed, delta, floor_space)

	var stride_angle := _cycle * TAU
	var sway := cos(stride_angle) * _gait
	var counterstep := sin(stride_angle) * _gait
	var brace := 1.0 - minf(_gait + _lift, 1.0)
	var rest_shift := sin(_elapsed * 1.05) * 0.013 * brace * (1.0 - reach)
	var hips := Vector3(rest_shift - 0.012 * brace + sway * 0.031 + waist_turn.y * 0.22 * brace + 0.034 * reach,
		-0.017 - 0.025 * _gait - 0.29 * reach - 0.13 * _landing - 0.039 * hit_reaction,
		0.021 * running + 0.051 * reach + waist_turn.x * 0.28 * brace)
	hips.y += 0.021 * _gait * cos(stride_angle * 2.0) + sin(_elapsed * 2.2) * 0.003
	hips.y -= 0.17 * maxf(0.0, waist_turn.x)
	var leg_turn := counterstep * lerpf(0.073, 0.135, running) * lerpf(1.0, 0.58, strafe)
	var hip_angles := Vector3(0.035 * running * _motion_axis.z - 0.10 * reach,
		-leg_turn + _turn * 0.09, -0.043 * sway + _motion_axis.x * _gait * 0.05) + waist_turn
	var pelvis := _joint_frame(_hip, Basis.from_euler(hip_angles), _rest[_hip].origin + hips)
	pelvis.origin.y += minf(0.0, minf(
		_leg_height_margin(_legs[0], ankle_l, pelvis), _leg_height_margin(_legs[1], ankle_r, pelvis)))
	_rig.set_bone_global_pose(_hip, pelvis * _rest[_hip])

	var lean := 0.020 + (0.055 * _gait + 0.20 * running) * _motion_axis.z
	lean += 0.74 * reach + 0.19 * _landing - 0.16 * hit_reaction
	var roll := 0.016 * brace - rest_shift * 1.1 + sway * lerpf(0.060, 0.095, running) + 0.11 * hit_reaction * _hurt_side
	roll -= _motion_axis.x * _gait * 0.16 + _turn * _gait * 0.12
	var twist := counterstep * lerpf(0.12, 0.19, running) - 0.14 * hit_reaction * _hurt_side - _turn * 0.15
	if firearm:
		twist = lerpf(twist, -0.18, aim_weight * 0.75)
		roll *= 1.0 - aim_weight * 0.71
		lean += recoil_shot * -0.046
	var breath := sin(_elapsed * 2.4) * lerpf(0.015, 0.006, _gait)
	var torso := _pose_torso(pelvis, Vector3(lean + breath, twist, roll), chest_turn,
		-0.073 * running - 0.39 * reach + aim_pitch * 0.46 * aim_weight)
	_pose_pack(torso, progress if swinging else 0.0, _landing, sway, delta)

	_place_leg(0, ankle_l, step_l.z, pelvis, waist_turn.y * 0.15 * brace)
	_place_leg(1, ankle_r, step_r.z, pelvis, waist_turn.y * 0.54 * brace)
	var swing_tool := tool if swinging else -1
	_pose_arm(_arms[0], torso, -1.0, step_l.x, running, reach, swing_tool, progress)
	_pose_arm(_arms[1], torso, 1.0, step_r.x, running, 0.0, swing_tool, progress)
	if firearm:
		_pose_carbine(torso, recoil_shot, aim_pitch, aim_weight, reload, running)
	else:
		_attach_tool(pick, blade or axe)
		if swinging and (pick or axe):
			_support_handle(torso, progress, axe)
	if landed:
		foot_planted.emit(to_global(Vector3(0, 0.035, 0)), true)
	elif grounded and speed > 1.0:
		if _cycle < prior_cycle:
			foot_planted.emit(to_global(ankle_l - Vector3.UP * 0.10), running > 0.5)
		elif prior_cycle < 0.5 and _cycle >= 0.5:
			foot_planted.emit(to_global(ankle_r - Vector3.UP * 0.10), running > 0.5)


func _ankle(index: int, trajectory: Vector3, in_contact: bool, pivot: float, reach: float,
		grounded: bool, vertical: float, delta: float, space: PhysicsDirectSpaceState3D) -> Vector3:
	var sign_side := -1.0 if index == 0 else 1.0
	var foot := _rest[_legs[index].end].origin
	var travel := trajectory.x * _motion_axis
	foot += travel + Vector3.UP * trajectory.y
	foot.x += sign_side * _gait * 0.025 + sign_side * pivot * 0.024
	foot.z += reach * (0.065 if index == 0 else -0.055)
	var tucked := smoothstep(-5.2, 2.0, vertical)
	var jump_ankle := _rest[_legs[index].end].origin
	jump_ankle += Vector3(sign_side * 0.034, 0.077 + tucked * 0.13,
		lerpf(0.015, 0.33 if index == 0 else -0.23, tucked))
	foot = foot.lerp(jump_ankle, _lift)
	if space == null:
		return foot
	var lock_now := in_contact and (_gait > 0.18 or pivot > 0.22) and reach < 0.35
	return _feet[index].place(_rig.global_transform, foot, lock_now, grounded, delta, space)


func _place_leg(index: int, ankle: Vector3, pitch: float, pelvis: Transform3D, pivot_yaw: float) -> void:
	var limb := _legs[index]
	var side := -1.0 if index == 0 else 1.0
	var pole := pelvis.basis * Vector3(side * 0.11, 0.0, 1.0)
	_solve_limb(limb, pelvis, ankle, pole)
	var foot := _rig.get_bone_global_pose(limb.end)
	var surface := _feet[index].floor_angles
	var yaw := side * 0.078 + pivot_yaw + _motion_axis.x * _gait * 0.15
	var hover := lerpf(pitch, 0.18 if index == 0 else -0.21, _lift)
	var tilt := Basis.from_euler(Vector3(surface.x + hover, yaw, surface.y))
	foot.basis = tilt * _rest[limb.end].basis
	_rig.set_bone_global_pose(limb.end, foot)


func _pose_pack(torso: Transform3D, swing: float, landing: float, sway: float, delta: float) -> void:
	var draw := sin(swing * TAU) * 0.069
	var target := Vector3(-0.095 * landing + draw, -0.047 * _turn + sway * 0.023, -0.048 * sway)
	_load_speed += ((target - _load_angle) * 158.0 - 17.0 * _load_speed) * minf(delta, 0.05)
	_load_angle += _load_speed * minf(delta, 0.05)
	var frame := _joint_frame(_pack, torso.basis * Basis.from_euler(_load_angle), torso * _rest[_pack].origin)
	_rig.set_bone_global_pose(_pack, frame * _rest[_pack])
	var cargo := frame * _rest[_cargo]
	cargo.basis = Basis.from_euler(_load_angle * 0.28) * cargo.basis
	_rig.set_bone_global_pose(_cargo, cargo)


func _tool_angles(tool: int) -> Array[Vector3]:
	if tool == SupplyRules.Tool.STONE_SWORD:
		return SWORD_ANGLES
	if tool == SupplyRules.Tool.IRON_AXE:
		return AXE_ANGLES
	return PICK_ANGLES

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
		var stance := phase / contact
		var roll := pow(smoothstep(0.65, 1.0, stance), 2.0) * _gait
		return Vector3(lerpf(0.5, -0.5, stance) * travel, roll * 0.032, roll * 0.17)
	var through := (phase - contact) / (1.0 - contact)
	var z := lerpf(-0.5, 0.5, smoothstep(0.0, 1.0, through)) * travel
	var pitch := lerpf(0.17, 0.0, smoothstep(0.0, 0.46, through)) * _gait
	pitch -= sin(through * PI) * _gait * lerpf(0.18, 0.35, run)
	var lift := pow(sin(through * PI), 1.25) * _gait * lerpf(0.11, 0.235, run)
	# Leave room for the toe and heel as the boot rotates around its ankle.
	lift += absf(sin(pitch)) * 0.18
	return Vector3(z, lift, pitch)


func _pose_arm(arm: Limb, torso: Transform3D, side: float, step: float,
		running: float, reach: float, tool: int, progress: float) -> void:
	var wrist := torso * _rest[arm.end].origin
	wrist.x += side * (0.016 + 0.025 * _gait) - _motion_axis.x * step * 0.34
	wrist.y += _gait * (0.018 + 0.07 * running) + absf(step) * 0.22
	wrist.z -= step * lerpf(0.56, 0.73, running) * maxf(0.32, absf(_motion_axis.z))
	wrist.y += _lift * (0.07 if side < 0.0 else 0.11)
	wrist.z += _lift * (0.15 if side < 0.0 else -0.12)
	wrist = wrist.lerp(Vector3(-0.15, 0.34, _pickup_distance), reach)
	if tool >= 0:
		var weight := smoothstep(0.0, 0.16, progress) * (1.0 - smoothstep(0.80, 1.0, progress))
		var sword := tool == SupplyRules.Tool.STONE_SWORD
		var keys: Array[Vector3]
		if side > 0.0:
			keys = SWORD_WRISTS if sword else (AXE_WRISTS if tool == SupplyRules.Tool.IRON_AXE else PICK_WRISTS)
		else:
			keys = SWORD_FREE_HAND if sword else PICK_FREE_HAND
		var shoulder := _rest[arm.upper].origin
		var target := _sample(progress, keys) + (torso * shoulder - shoulder) * 0.30
		wrist = wrist.lerp(target, weight)
	_solve_limb(arm, torso, wrist, torso.basis * Vector3(side * 0.33, -0.14, -0.91))


func _pose_carbine(torso: Transform3D, kick: float, pitch: float, raised: float,
		reload: float, running: float) -> void:
	var unloading := 0.0
	if reload >= 0.0:
		unloading = smoothstep(0.0, 0.17, reload) * (1.0 - smoothstep(0.77, 1.0, reload))
	var ready := raised * (1.0 - unloading)
	var held := maxf(smoothstep(0.0, 1.0, _equip_weight), raised)
	var spring := pow(clampf(kick, 0.0, 1.0), 2.6)
	var elevation := lerpf(-0.53, lerpf(-0.40 - running * 0.11, pitch, ready), held)
	elevation += spring * 0.12 - unloading * 0.21
	var roll := lerpf(-0.17, 0.0, ready) + unloading * -0.31
	_tool_basis = Basis.from_euler(Vector3(-PI * 0.5 - elevation, unloading * -0.12, roll))
	var grip_target := Vector3(0.263, lerpf(1.13, 1.283, ready) + spring * 0.027,
		lerpf(0.246, 0.30, ready) - spring * 0.054)
	grip_target += Vector3(0, -unloading * 0.03, 0) + torso.basis * Vector3(0, 0.013, 0)
	var right := _rig.get_bone_global_pose(_arms[1].end).origin
	var left := _rig.get_bone_global_pose(_arms[0].end)
	_solve_limb(_arms[1], torso, right.lerp(grip_target, held), Vector3(0.78, -0.61, -0.39))
	_attach_tool(false, true)

	var palm := _grip * Vector3(-0.055, -0.275, 0.037)
	var socket := _grip * Vector3(-0.039, -0.068, 0.084)
	var withdrawal := Vector3(-0.15, 0.95, 0.25)
	var pouch := torso * Vector3(-0.227, 0.96, 0.066)
	if reload >= 0.0:
		if reload < 0.25:
			palm = palm.lerp(socket, smoothstep(0.025, 0.25, reload))
		elif reload < 0.42:
			palm = socket.lerp(withdrawal, smoothstep(0.25, 0.42, reload))
		elif reload < 0.56:
			palm = withdrawal.lerp(pouch, smoothstep(0.42, 0.56, reload))
		elif reload < 0.78:
			palm = pouch.lerp(socket, smoothstep(0.56, 0.78, reload))
		else:
			palm = socket.lerp(palm, smoothstep(0.78, 1.0, reload))
	_solve_limb(_arms[0], torso, left.origin.lerp(palm, held), Vector3(-0.75, -0.65, -0.19))
	var hand := _rig.get_bone_global_pose(_arms[0].end)
	var grip_frame := _grip.basis * Basis.from_euler(Vector3(1.45, 0.0, -0.67))
	hand.basis = hand.basis.slerp(grip_frame * _rest[_arms[0].end].basis, held * 0.84)
	_rig.set_bone_global_pose(_arms[0].end, hand)
	_magazine_hand = Transform3D(_grip.basis * Basis(Vector3.FORWARD, unloading * 0.18),
		hand.origin + _grip.basis * Vector3(0.035, 0.010, -0.016))


func _support_handle(torso: Transform3D, progress: float, axe: bool) -> void:
	var hand := _rig.get_bone_global_pose(_arms[0].end)
	var on_handle := _grip * Vector3(-0.022, -0.18 if axe else -0.22, 0.024)
	var hold := smoothstep(0.09, 0.27, progress) * (1.0 - smoothstep(0.70, 0.98, progress))
	_solve_limb(_arms[0], torso, hand.origin.lerp(on_handle, hold), Vector3(-0.57, -0.66, -0.44))
	var wrist := _rig.get_bone_global_pose(_arms[0].end)
	var along := _grip.basis * Basis.from_euler(Vector3(-0.77, -0.20, 0.96))
	wrist.basis = wrist.basis.slerp(along * _rest[_arms[0].end].basis, hold * 0.76)
	_rig.set_bone_global_pose(_arms[0].end, wrist)


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
		if progress > phases[i]:
			continue
		var start := phases[i - 1]
		var width := phases[i] - start
		var before := maxi(0, i - 2)
		var after := mini(phases.size() - 1, i + 1)
		var weight := clampf((progress - start) / width, 0.0, 1.0)
		return keys[i - 1].cubic_interpolate_in_time(keys[i], keys[before], keys[after],
			weight, width, phases[before] - start, phases[after] - start)
	return keys.back()
