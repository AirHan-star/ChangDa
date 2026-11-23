class_name RegionLandscape
extends RefCounted

const WOODLAND := preload("res://assets/world/woodland.glb")
const WOOD := Color("#9c8060")
const IRON := Color("#6e7772")
const RUST := Color("#996a55")
const CONCRETE := Color("#aaac9e")
const FIELD := Color("#b9ad7f")
var _root: Node3D
var _surface: Callable
var _finishes: RegionFinishes
var _trees: Array[Mesh] = []
var _tufts: Array[Mesh] = []
var _stones: Array[Mesh] = []
var _rng := RandomNumberGenerator.new()


func _init(root: Node3D, surface: Callable, finishes: RegionFinishes) -> void:
	_root = root
	_surface = surface
	_finishes = finishes
	var original := WOODLAND.instantiate()
	for child in original.get_children():
		var art := child as MeshInstance3D
		if art == null:
			continue
		var group: Array[Mesh]
		var id := String(art.name)
		if id.begins_with("Pine"):
			group = _trees
		elif id.begins_with("Tuft"):
			group = _tufts
		elif id.begins_with("Stone"):
			group = _stones
		else:
			continue
		if not group.has(art.mesh):
			group.append(art.mesh)
	original.free()


func decorate(district: int) -> void:
	_rng.seed = 24033 + district*79
	if district == 2:
		_streets()
	else:
		_rough_verge(district == 3)
		if district == 1:
			_quarry_track()
		else:
			_basin_pipes()


func _rough_verge(arid: bool) -> void:
	for side in [-1,1]:
		for i in range(27):
			var z := -37.0 + i*3.04 + _rng.randf_range(-1.15,1.15)
			var x: float = side*_rng.randf_range(20.8,34.3)
			var position: Vector3 = _surface.call(Vector2(x,z))
			if not arid and i%3 != 1:
				var tree := _plant(_trees, position, Vector3.ONE*_rng.randf_range(0.78,1.18))
				if tree != null:
					_collide_trunk(position)
			else:
				_plant(_stones,position,Vector3.ONE*_rng.randf_range(1.33,2.48))
		for i in range(42):
			var p := Vector2(side*_rng.randf_range(4.2,22.5), -37.0 + i*1.88)
			_plant(_tufts,_surface.call(p),Vector3.ONE*_rng.randf_range(0.55,1.5))
		for i in range(13):
			var p := Vector2(side*_rng.randf_range(4.4,8.4), -33.0+i*5.8 + _rng.randf_range(-0.5,0.5))
			_plant(_stones,_surface.call(p),Vector3.ONE*_rng.randf_range(0.57,1.2))


func _quarry_track() -> void:
	for i in range(18):
		var at: Vector3 = _surface.call(Vector2(3.24,-24+i*1.07))
		_box(at+Vector3.UP*0.026,Vector3(1.46,0.055,0.16),"wood",WOOD)
	for x in [2.78,3.70]:
		var at: Vector3 = _surface.call(Vector2(x,-14.96))
		_box(at+Vector3.UP*0.073,Vector3(0.080,0.060,18.2),"iron",IRON)
	_lamp(Vector2(3.0,-18), -1.0)
	_lamp(Vector2(-4.7,10), 1.0)
	_pallet(Vector2(3.2,8.2), 0.18)
	_pallet(Vector2(-4.8,19.8), -0.41)
	_scrub_patch(Vector2(-6.75,5.2),true)
	_scrub_patch(Vector2(7.15,6.7),true)
	_scrub_patch(Vector2(-6.9,-10.3),true)
	_scrub_patch(Vector2(9.6,19.4),true)
	_rail(Vector2(5.75,-8.1),3.3)


func _basin_pipes() -> void:
	var x := 4.30
	for z in [-23.0,-16.8,-10.6,-4.4,1.8,8.0,14.2]:
		var at: Vector3 = _surface.call(Vector2(x,z))
		var tube := CylinderMesh.new()
		tube.height = 6.19
		tube.top_radius = 0.115
		tube.bottom_radius = 0.115
		tube.radial_segments = 9
		var pipe := RelayGeometry.mesh(_root,tube,at+Vector3.UP*0.64,_finishes.paint("iron",RUST))
		pipe.rotation.x = PI/2
		_box(at+Vector3(0,0.29,-2.69),Vector3(0.17,0.58,0.16),"concrete",CONCRETE,true)
		_box(at+Vector3(0,0.64,-3.08),Vector3(0.26,0.29,0.27),"iron",IRON)
	_lamp(Vector2(-3.8,16.3), 1.0)
	_lamp(Vector2(-3.5,-15.2), 1.0)
	_pallet(Vector2(5.1,28.3), 0.09)
	_scrub_patch(Vector2(-5.4,28.5),false)
	_scrub_patch(Vector2(7.9,24.8),false)
	_scrub_patch(Vector2(-8.8,18.6),false)
	_scrub_patch(Vector2(6.0,16.2),false)
	_rail(Vector2(-5.6,23.7),3.8)


func _scrub_patch(flat: Vector2, wooded: bool) -> void:
	var at: Vector3 = _surface.call(flat)
	_plant(_stones,at,Vector3(1.67,1.33,1.81))
	if wooded and not _trees.is_empty():
		var point: Vector3 = _surface.call(flat+Vector2(0.82,-0.9))
		_plant(_trees,point,Vector3.ONE*0.68)
		_collide_trunk(point)
	for i in range(7):
		var patch := flat+Vector2(_rng.randf_range(-1.1,1.1),_rng.randf_range(-1.14,1.14))
		_plant(_tufts,_surface.call(patch),Vector3.ONE*_rng.randf_range(0.79,1.32))


func _streets() -> void:
	for side in [-1,1]:
		for i in range(39):
			var z := -37.0+i*1.95
			_box(Vector3(side*5.01,0.022,z),Vector3(2.05,0.048,1.93),"concrete", CONCRETE.darkened(0.06*(i%4)))
			_box(Vector3(side*4.01,0.037,z),Vector3(0.16,0.078,1.90),"concrete",CONCRETE.darkened(0.20))
			if i%3 == 0:
				_plant(_tufts,Vector3(side*6.10,0.012,z+0.72),Vector3.ONE*_rng.randf_range(0.58,0.99))
		for z in [-22.0,-5.0,10.7,24.9,34.5]:
			_lamp(Vector2(side*5.54,z), -side)
		for z in [-27.0,3.7,26.0,36.0]:
			_pallet(Vector2(side*7.15,z), side*0.20)
		for z in [-31.0,-10.3,13.7,30.7]:
			var p := Vector3(side*6.48,0.22,z)
			_box(p,Vector3(0.78,0.43,1.52),"concrete", CONCRETE.darkened(0.24),true)
			_box(p+Vector3.UP*0.205,Vector3(0.61,0.04,1.31),"wood",FIELD.darkened(0.51))
			_plant(_tufts,p+Vector3.UP*0.25,Vector3(1.43,1.0,1.43))
	for z in [-19.2,7.8,21.9]:
		for lane in range(-4,5):
			_box(Vector3(lane*0.71,0.014,z),Vector3(0.43,0.022,2.1),"floor",FIELD)
	for z in [-32.8,-12.1,0.8,15.5,34.0]:
		_box(Vector3(0,0.015,z),Vector3(0.104,0.018,3.4),"floor",FIELD.darkened(0.13))
	for point in [Vector2(-2,-11),Vector2(2,4.1),Vector2(-2.5,23.3)]:
		_wreck(point)
	for point in [Vector2(-7.25,-31),Vector2(7.8,-25),Vector2(-7.0,-2.8),Vector2(7.8,12.4),
			Vector2(-7.6,28.5),Vector2(7.7,36.6)]:
		_rail(point,4.2)


func _rail(flat: Vector2, length: float) -> void:
	var root: Vector3 = _surface.call(flat)
	for side in [-1.0,1.0]:
		_box(root+Vector3(0,0.49,side*length/2),Vector3(0.11,0.98,0.12),"iron",IRON,true)
	for y in [0.44,0.82]:
		_box(root+Vector3.UP*y,Vector3(0.077,0.078,length+0.11),"iron",RUST)


func _wreck(flat: Vector2) -> void:
	var at := Vector3(flat.x,0,flat.y)
	var faded := RUST if flat.x < 0 else Color("#789296")
	var shell := _box(at+Vector3.UP*0.54,Vector3(1.71,0.57,3.56),"iron",faded,true)
	shell.rotation.y = 0.11 if flat.x < 0 else -0.12
	_finishes.box(shell,Vector3(0,0.49,-0.22),Vector3(1.45,0.48,1.91),"iron",faded)
	_finishes.box(shell,Vector3(0,0.46,0.755),Vector3(1.29,0.30,0.056),"iron",Color("#3e514d"))
	_finishes.box(shell,Vector3(0,0.45,-1.20),Vector3(1.31,0.30,0.065),"iron",Color("#424948"))
	_finishes.box(shell,Vector3(0,-0.03,1.80),Vector3(1.79,0.13,0.17),"iron",IRON)
	for side in [-1,1]:
		_finishes.box(shell,Vector3(side*0.73,0.48,-0.19),Vector3(0.042,0.29,1.65),"iron",Color("#343c39"))
		_finishes.box(shell,Vector3(side*0.59,0.084,1.79),Vector3(0.24,0.108,0.055),"floor",FIELD)
		for z in [-1.08,1.07]:
			var tire := CylinderMesh.new()
			tire.top_radius = 0.31
			tire.bottom_radius = 0.31
			tire.height = 0.23
			tire.radial_segments = 10
			var wheel := RelayGeometry.mesh(shell,tire,Vector3(side*0.80,-0.25,z),_finishes.paint("rubber",Color("#272d2a")))
			wheel.rotation.z = PI/2
			_finishes.box(shell,Vector3(side*0.921,-0.24,z),Vector3(0.026,0.24,0.24),"iron",IRON)


func _lamp(flat: Vector2, direction: float) -> void:
	var ground: Vector3 = _surface.call(flat)
	_box(ground+Vector3.UP*0.09,Vector3(0.48,0.18,0.46),"concrete",CONCRETE,true)
	_box(ground+Vector3.UP*1.59,Vector3(0.104,3.18,0.108),"iron",IRON,true)
	_box(ground+Vector3(direction*0.31,3.16,0),Vector3(0.76,0.095,0.107),"iron",IRON)
	var lamp := ground+Vector3(direction*0.64,3.08,0)
	_box(lamp,Vector3(0.38,0.12,0.28),"iron",IRON)
	RelayGeometry.box(_root,lamp-Vector3.UP*0.069,Vector3(0.24,0.041,0.19),RelayGeometry.finish(Color("#ecc88b"),0.47))


func _pallet(flat: Vector2, turn: float) -> void:
	var at: Vector3 = _surface.call(flat)
	var pad := Node3D.new()
	pad.position = at
	pad.rotation.y = turn
	_root.add_child(pad)
	for i in range(5):
		_finishes.box(pad,Vector3(0,0.124,-0.31+i*0.155),Vector3(1.08,0.052,0.132),"wood",WOOD)
	for x in [-0.40,0.39]:
		_finishes.box(pad,Vector3(x,0.047,0),Vector3(0.13,0.10,0.78),"wood",WOOD.darkened(0.21))


func _plant(pool: Array[Mesh], at: Vector3, stretch: Vector3) -> MeshInstance3D:
	if pool.is_empty():
		return null
	var mesh := RelayGeometry.mesh(_root,pool[_rng.randi_range(0,pool.size()-1)],at,null)
	mesh.scale = stretch
	mesh.rotation.y = _rng.randf_range(-PI,PI)
	return mesh


func _collide_trunk(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at+Vector3.UP*0.9
	_root.add_child(root)
	var trunk := CylinderShape3D.new()
	trunk.radius = 0.22
	trunk.height = 1.8
	RelayGeometry.body(root,trunk)


func _box(at: Vector3, size: Vector3, surface: String, color: Color, solid := false) -> MeshInstance3D:
	return _finishes.box(_root,at,size,surface,color,solid)
