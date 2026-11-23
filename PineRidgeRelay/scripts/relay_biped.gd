class_name RelayBiped
extends Node3D
## Shared two-bone pose fitting for the two humanoid rigs.

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


func _limb(upper: String, lower: String, end: String) -> Limb:
	return Limb.new(_rig, [_rig.find_bone(upper), _rig.find_bone(lower), _rig.find_bone(end)], _rest)


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


func _solve_limb(limb: Limb, parent_delta: Transform3D, target: Vector3, pole: Vector3) -> void:
	var start := parent_delta * _rest[limb.upper].origin
	var offset := target - start
	var toward := offset.normalized() if not offset.is_zero_approx() else Vector3.DOWN
	var distance := clampf(start.distance_to(target),
		absf(limb.upper_length - limb.lower_length) + 0.003,
		limb.upper_length + limb.lower_length - 0.001)
	var bend := pole.slide(toward).normalized()
	if bend.is_zero_approx():
		var alternate := Vector3.RIGHT if absf(toward.x) < 0.9 else Vector3.BACK
		bend = alternate.slide(toward).normalized()
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
