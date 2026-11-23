class_name RelayContact
extends RelayBiped

const MODELS: Array[PackedScene] = [
	preload("res://assets/npcs/shen.glb"), preload("res://assets/npcs/liang.glb"),
	preload("res://assets/npcs/xu.glb"), preload("res://assets/npcs/chi.glb"),
]
const NAMES := ["沈苇", "梁砾", "许岑", "池照"]
const ROLES := ["接收员", "机修工", "路口联络员", "中继员"]
const BASE_YAW := [-0.35, PI / 2.0, -0.75, -1.17]

var role: int
var _elapsed := 0.0
var _breath_timer := 0.0


func _ready() -> void:
	add_child(MODELS[role].instantiate())
	super._ready()
	_pose()


func _process(delta: float) -> void:
	_elapsed += delta
	_breath_timer += delta
	if _breath_timer >= 1.0 / 24.0:
		_breath_timer = 0.0
		_pose()


func _pose() -> void:
	var breath := sin(_elapsed * 1.7 + float(role)) * 0.008
	var seated := role == 1
	var pelvis := Transform3D(Basis.IDENTITY, Vector3(0, -0.43 if seated else -0.025, 0))
	var upper_pivot := _rest[_hip].origin + pelvis.origin
	var lean := -0.095 if seated else -0.045 + breath
	var turn := Basis.from_euler(Vector3(lean, cos(_elapsed * 0.87) * 0.045, -0.10 if seated else 0.025))
	var shoulders := Transform3D(turn, upper_pivot - turn * _rest[_hip].origin + Vector3.UP * breath)
	_rig.set_bone_global_pose(_hip, pelvis * _rest[_hip])
	_rig.set_bone_global_pose(_chest, shoulders * _rest[_chest])
	var head_pose := shoulders * _rest[_head]
	head_pose.basis = Basis.from_euler(Vector3(-0.075 if seated else 0.04, sin(_elapsed * 0.71) * 0.13, 0.035)) * head_pose.basis
	_rig.set_bone_global_pose(_head, head_pose)
	for index in range(2):
		var side := -1.0 if index == 0 else 1.0
		var leg := _legs[index]
		var foot := _rest[leg.end].origin
		foot.x += side * 0.055
		foot.z += (0.40 if index == 0 else 0.54) if seated else side * 0.067
		_pose_leg(leg, foot, 0.0, pelvis, side * 0.11)
		var hand := Vector3(side * 0.335, 0.94, 0.09 + side * 0.045)
		if seated:
			hand = Vector3(side * 0.197, 0.52, 0.29 + side * 0.05)
		elif (role == 0 and index == 0) or (role == 3 and index == 1):
			hand = Vector3(side * 0.14, 1.11 + breath, 0.27)
		_solve_limb(_arms[index], shoulders, hand, Vector3(side * 0.72, -0.64, -0.25))
