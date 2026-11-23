class_name HarvestTree
extends StaticBody3D

const REGROW_SECONDS := 300.0
const CHOPS := 3
const WOOD_YIELD := 4

var chops_left := CHOPS
var regrow_left := 0
var _key: String
var _deadlines: Dictionary
var _plant: MeshInstance3D
var _stump: Node3D
var _finishes: RegionFinishes
var _sign: Label3D
var _hull := CollisionShape3D.new()
var _live_shape := CylinderShape3D.new()
var _stump_shape := CylinderShape3D.new()
var _cut := false
var _clearance := PhysicsShapeQueryParameters3D.new()


func configure(key: String, deadlines: Dictionary, plant: MeshInstance3D, finishes: RegionFinishes) -> void:
	_key = key
	_deadlines = deadlines
	_plant = plant
	global_position = plant.global_position
	_live_shape.radius = clampf(0.235 * absf(plant.scale.x),0.17,0.32)
	_live_shape.height = 2.32
	_stump_shape.radius = _live_shape.radius * 1.15
	_stump_shape.height = 0.34
	add_child(_hull)
	_clearance.shape = _live_shape
	_clearance.collision_mask = 6
	_finishes = finishes
	_show_cut(_deadlines.has(_key))


func hit_point() -> Vector3:
	return global_position + Vector3.UP * (0.22 if _cut else 0.83)


func is_cut() -> bool:
	return _cut


func chop(world_time: float) -> bool:
	if _cut:
		return false
	chops_left -= 1
	if chops_left > 0:
		return false
	_deadlines[_key] = world_time + REGROW_SECONDS
	_show_cut(true)
	_update_remaining(int(REGROW_SECONDS))
	return true


func tick(world_time: float) -> void:
	if not _cut:
		return
	var left := ceili(float(_deadlines[_key])-world_time)
	if left > 0:
		_update_remaining(left)
		return
	_clearance.transform.origin = global_position + Vector3.UP * _live_shape.height * 0.5
	if not get_world_3d().direct_space_state.intersect_shape(_clearance,1).is_empty():
		_update_remaining(0)
		return
	_deadlines.erase(_key)
	chops_left = CHOPS
	_show_cut(false)


func regrow_text() -> String:
	if regrow_left == 0:
		return "树桩 · 等待周围腾空"
	return "树桩 · 再生 %02d:%02d" % [floori(regrow_left/60.0),regrow_left%60]


func _update_remaining(seconds: int) -> void:
	if regrow_left != seconds or _sign.text == "":
		regrow_left = seconds
		_sign.text = regrow_text()


func _show_cut(cut: bool) -> void:
	_cut = cut
	_plant.visible = not cut
	if cut and not is_instance_valid(_stump):
		_build_stump(_finishes)
	if is_instance_valid(_stump):
		_stump.visible = cut
	_hull.shape = _stump_shape if cut else _live_shape
	_hull.position.y = (_stump_shape.height if cut else _live_shape.height)*0.5


func _build_stump(finishes: RegionFinishes) -> void:
	_stump = Node3D.new()
	add_child(_stump)
	var width := _stump_shape.radius
	var bark := finishes.paint("wood",Color("#67513e"))
	var trunk := CylinderMesh.new()
	trunk.radial_segments = 9
	trunk.rings = 1
	trunk.height = 0.32
	trunk.top_radius = width*0.83
	trunk.bottom_radius = width*1.12
	RelayGeometry.mesh(_stump,trunk,Vector3.UP*0.16,bark)
	var colors := [Color("#a37750"),Color("#bea074"),Color("#a88661"),Color("#c6a477")]
	for i in range(colors.size()):
		var disc := CylinderMesh.new()
		disc.radial_segments = 9
		disc.rings = 1
		disc.height = 0.017
		disc.top_radius = width*(0.84-i*0.165)
		disc.bottom_radius = disc.top_radius
		RelayGeometry.mesh(_stump,disc,Vector3.UP*(0.321+i*0.002),finishes.paint("wood",colors[i]))
	_sign = RelayGeometry.label(_stump,"",Vector3.UP*1.10,Color("#dcd29c"))
	_sign.visibility_range_end = 16.0
