class_name SurvivorPose
extends Node3D
## Visual pose driver. The CharacterBody3D owns movement and collision.

const PICKUP_TIME := 0.52
# Wind-up, impact and recovery use the same normalized clock as the hit.
const SWING_PHASES := [0.0, 0.30, 0.56, 0.79, 1.0]
const PICK_WRISTS: Array[Vector3] = [
	Vector3(0.37, 0.93, 0.03), Vector3(0.37, 1.54, 0.11),
	Vector3(0.31, 0.80, 0.44), Vector3(0.34, 0.76, 0.25), Vector3(0.37, 0.93, 0.03),
]
const PICK_ANGLES: Array[Vector3] = [
	Vector3(-0.18, 0.0, -0.10), Vector3(-2.77, 0.08, 0.13),
	Vector3(-1.19, -0.03, 0.05), Vector3(-0.53, -0.10, -0.13), Vector3(-0.18, 0.0, -0.10),
]
const SWORD_WRISTS: Array[Vector3] = [
	Vector3(0.37, 0.93, 0.03), Vector3(0.59, 1.35, -0.17),
	Vector3(0.16, 1.10, 0.49), Vector3(-0.25, 0.99, 0.35), Vector3(0.37, 0.93, 0.03),
]
const SWORD_ANGLES: Array[Vector3] = [
	Vector3(-0.18, 0.0, -0.10), Vector3(-1.98, 0.94, 1.18),
	Vector3(-1.41, -0.30, 0.42), Vector3(-1.08, -1.14, -0.56), Vector3(-0.18, 0.0, -0.10),
]
const WALK_SPEED := 4.1
const RUN_SPEED := 6.6

class Limb:
	var upper: int
	var lower: int
	var end: int
	var upper_length: float
	var lower_length: float

	func _init(rig: Skeleton3D, ids: Array[int], rest: Array[Transform3D]) -> void:
		upper = ids[0]
		lower = ids[1]
		end = ids[2]
		upper_length = rest[upper].origin.distance_to(rest[lower].origin)
		lower_length = rest[lower].origin.distance_to(rest[end].origin)
		assert(rig.get_bone_parent(lower) == upper and rig.get_bone_parent(end) == lower)

var _rig: Skeleton3D
var _rest: Array[Transform3D] = []
var _hip: int
var _chest: int
var _head: int
var _legs: Array[Limb] = []
var _arms: Array[Limb] = []
var _cycle := 0.0
var _gait := 0.0
var _elapsed := 0.0
var _reach_left := 0.0
var _grip := Vector3.ZERO
var tool_basis := Basis.IDENTITY


func _ready() -> void:
	_rig = find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for i in range(_rig.get_bone_count()):
		_rest.append(_rig.get_bone_global_rest(i))
	_hip = _rig.find_bone("Hip")
	_chest = _rig.find_bone("Chest")
	_head = _rig.find_bone("Head")
	for side in ["L", "R"]:
		_legs.append(_limb("Thigh" + side, "Shin" + side, "Foot" + side))
		_arms.append(_limb("Arm" + side, "Forearm" + side, "Hand" + side))
	update_pose(0.0, 0.0, true)


func pick_up() -> void:
	_reach_left = PICKUP_TIME


func grip_position() -> Vector3:
	return to_local(_rig.to_global(_grip))


func update_pose(delta: float, speed: float, grounded: bool, tool := -1, progress := 0.0) -> void:
	_elapsed += delta
	_reach_left = maxf(0.0, _reach_left - delta)
	var reach := sin(PI * _reach_left / PICKUP_TIME) * (1.0 - minf(speed / 10.0, 0.55))
	var wielding := tool >= 0
	var sword_swing := tool == SupplyRules.Tool.STONE_SWORD
	var effort := sin(progress * PI) if wielding else 0.0
	if wielding:
		reach = 0.0
		_reach_left = 0.0
	var body_twist := (_sample(progress, SWORD_ANGLES).y * 0.32) if sword_swing else effort * 0.07
	tool_basis = Basis.from_euler(_sample(progress, SWORD_ANGLES if sword_swing else PICK_ANGLES))
	var running := smoothstep(WALK_SPEED, RUN_SPEED, speed)
	_gait = move_toward(_gait, clampf(speed / WALK_SPEED, 0.0, 1.0), delta * 6.5)
	var stride := lerpf(0.80, 1.02, running)
	var contact := lerpf(0.59, 0.43, running)
	_cycle = fposmod(_cycle + speed * contact / stride * delta, 1.0)
	var step_l := _step(_cycle, stride, contact, running)
	var step_r := _step(fposmod(_cycle + 0.5, 1.0), stride, contact, running)
	if not grounded:
		step_l = Vector3(0.11, 0.062, -0.08)
		step_r = Vector3(-0.115, 0.143, -0.20)

	var ankle_l := _rest[_legs[0].end].origin + Vector3(0.0, step_l.y, step_l.x)
	var ankle_r := _rest[_legs[1].end].origin + Vector3(0.0, step_r.y, step_r.x)
	var hips := Vector3(0.0, -0.011 - 0.025 * _gait - reach * 0.33,
		lerpf(0.0, 0.025, running) - 0.072 * reach)
	var bob := 0.014 * _gait * cos(_cycle * TAU * 2.0) + sin(_elapsed * 2.5) * 0.002
	hips.y = minf(hips.y + bob, minf(
		_hip_limit(_legs[0], ankle_l, hips.z), _hip_limit(_legs[1], ankle_r, hips.z)))
	_rig.set_bone_global_pose(_hip, Transform3D(_rest[_hip].basis, _rest[_hip].origin + hips))

	var lean := lerpf(0.025, 0.20, running) + 0.023 * _gait + 0.68 * reach
	var roll := cos(_cycle * TAU) * _gait * lerpf(0.026, 0.046, running)
	var breathing := sin(_elapsed * 2.4) * 0.009 * (1.0 - _gait)
	var upper_body := Basis(Vector3.UP, body_twist) * Basis(Vector3.RIGHT, lean + breathing + effort * 0.14) * Basis(Vector3.BACK, roll)
	var torso := Transform3D(upper_body, _rest[_chest].origin + hips - upper_body * _rest[_chest].origin)
	_rig.set_bone_global_pose(_chest, torso * _rest[_chest])
	var head := torso * _rest[_head]
	head.basis = Basis(Vector3.RIGHT, -0.08 * running - 0.29 * reach) * head.basis
	_rig.set_bone_global_pose(_head, head)

	_pose_leg(_legs[0], ankle_l, step_l.z, hips)
	_pose_leg(_legs[1], ankle_r, step_r.z, hips)
	_pose_arm(_arms[0], torso, -1.0, step_l.x, running, reach, tool, progress)
	_pose_arm(_arms[1], torso, 1.0, step_r.x, running, 0.0, tool, progress)


func _limb(upper: String, lower: String, end: String) -> Limb:
	return Limb.new(_rig, [_rig.find_bone(upper), _rig.find_bone(lower), _rig.find_bone(end)], _rest)


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


func _hip_limit(leg: Limb, ankle: Vector3, pelvis_z: float) -> float:
	var rest_hip := _rest[leg.upper].origin
	var depth := ankle.z - rest_hip.z - pelvis_z
	var lateral := ankle.x - rest_hip.x
	var reach := leg.upper_length + leg.lower_length - 0.007
	return ankle.y - rest_hip.y + sqrt(maxf(0.0, reach * reach - depth * depth - lateral * lateral))


func _pose_leg(leg: Limb, ankle: Vector3, pitch: float, pelvis: Vector3) -> void:
	_solve_limb(leg, Transform3D(Basis.IDENTITY, pelvis), ankle, Vector3.BACK)
	var foot := _rig.get_bone_global_pose(leg.end)
	foot.basis = Basis(Vector3.RIGHT, pitch) * _rest[leg.end].basis
	_rig.set_bone_global_pose(leg.end, foot)


func _pose_arm(arm: Limb, torso: Transform3D, side: float, step: float,
		running: float, reach: float, tool: int, progress: float) -> void:
	var wrist := torso * _rest[arm.end].origin
	wrist.x += side * (0.019 + 0.022 * _gait)
	wrist.y += _gait * (0.018 + 0.07 * running) + absf(step) * 0.22
	wrist.z -= step * lerpf(0.53, 0.68, running)
	wrist = wrist.lerp(Vector3(-0.274, 0.45, 0.54), reach)
	if tool >= 0:
		var weight := smoothstep(0.0, 0.18, progress) * (1.0 - smoothstep(0.83, 1.0, progress))
		if side > 0.0:
			var keys := SWORD_WRISTS if tool == SupplyRules.Tool.STONE_SWORD else PICK_WRISTS
			wrist = wrist.lerp(_sample(progress, keys), weight)
		elif tool != SupplyRules.Tool.STONE_SWORD:
			wrist = wrist.lerp(Vector3(-0.22, 1.10, 0.27), weight * 0.58)
	_solve_limb(arm, torso, wrist, Vector3(side * 0.29, -0.10, -0.95))
	if side > 0.0:
		var hand := _rig.get_bone_global_pose(arm.end)
		var grip_offset := _rest[arm.end].basis.inverse() * Vector3(-0.008, -0.052, 0.018)
		_grip = hand * grip_offset


func _sample(progress: float, keys: Array[Vector3]) -> Vector3:
	for i in range(1, SWING_PHASES.size()):
		if progress <= SWING_PHASES[i]:
			var weight := smoothstep(SWING_PHASES[i - 1], SWING_PHASES[i], progress)
			return keys[i - 1].lerp(keys[i], weight)
	return keys.back()


func _solve_limb(limb: Limb, parent_delta: Transform3D, target: Vector3, pole: Vector3) -> void:
	var start := parent_delta * _rest[limb.upper].origin
	var toward := (target - start).normalized()
	var distance := clampf(start.distance_to(target),
		absf(limb.upper_length - limb.lower_length) + 0.003,
		limb.upper_length + limb.lower_length - 0.001)
	var bend := (pole - toward * pole.dot(toward)).normalized()
	var straight := (limb.upper_length ** 2 - limb.lower_length ** 2 + distance ** 2) / (2.0 * distance)
	var height := sqrt(maxf(0.0, limb.upper_length ** 2 - straight ** 2))
	var mid := start + toward * straight + bend * height
	var end := start + toward * distance
	var upper := _segment(limb.upper, limb.lower, parent_delta.basis, start, mid)
	var lower := _segment(limb.lower, limb.end, parent_delta.basis, mid, end)
	_rig.set_bone_global_pose(limb.upper, upper)
	_rig.set_bone_global_pose(limb.lower, lower)
	var carried := lower.basis * _rest[limb.lower].basis.inverse() * _rest[limb.end].basis
	_rig.set_bone_global_pose(limb.end, Transform3D(carried, end))


func _segment(index: int, next: int, frame: Basis, start: Vector3, finish: Vector3) -> Transform3D:
	var reference := frame * (_rest[next].origin - _rest[index].origin)
	var turn := Basis(Quaternion(reference.normalized(), (finish - start).normalized()))
	return Transform3D(turn * frame * _rest[index].basis, start)
