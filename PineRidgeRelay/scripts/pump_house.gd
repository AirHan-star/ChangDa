class_name PumpHouse
extends RefCounted

const CONCRETE := Color("#8a9389")
const STEEL := Color("#566a65")
const RUST := Color("#98604b")
const SIGNAL := Color("#e3b571")
const ROOF := Color("#5f6e69")

var _room: Node3D
var _finish: RegionFinishes


func _init(room: Node3D, finishes: RegionFinishes) -> void:
	_room = room
	_finish = finishes
	_box(Vector3(0, -0.19, 0), Vector3(30, 0.38, 38), "floor", CONCRETE, true)
	_box(Vector3(0, 7.02, 0), Vector3(30.5, 0.34, 38.5), "roof", ROOF)
	for side in [-1, 1]:
		_side_wall(side)
		_pump(side, -9.0)
		_pump(side, 11.0)
		_console(side)
		_service_door(side)
	for end in [-1, 1]:
		_box(Vector3(0, 3.48, end * 18.8), Vector3(30.5, 7.0, 0.55), "concrete", CONCRETE, true)
		_box(Vector3(0, 0.51, end * 18.46), Vector3(29.5, 1.0, 0.18), "brick", Color("#727970"))
		_box(Vector3(0, 5.4, end * 18.45), Vector3(27.6, 0.20, 0.25), "iron", RUST)
	for z in [-14.0, -7.0, 0.0, 7.0, 14.0]:
		_box(Vector3(0, 6.52, z), Vector3(29.7, 0.44, 0.4), "iron", STEEL)
		_box(Vector3(0, 6.75, z), Vector3(29.7, 0.08, 0.66), "iron", RUST)
		_lamp(Vector3(-5.0, 5.96, z), Color("#b6dcdf"), 15.0, 2.7)
		_lamp(Vector3(5.0, 5.96, z), Color("#ead3ae"), 15.0, 2.4)
	for side in [-1, 1]:
		for z in range(-17, 18, 2):
			_box(Vector3(side * 3.25, 0.012, float(z)), Vector3(0.10, 0.022, 1.47), "floor", SIGNAL)
	for z in [-16.5, 16.5]:
		_walk_grate(z)
	for side in [-1, 1]:
		for z in [-6.0, 8.0]:
			_column(side, z)
		_lockers(side)


func control_point(side: int) -> Vector3:
	return Vector3(side * 10.77, 1.13, 2.15)


func _side_wall(side: int) -> void:
	_box(Vector3(side * 14.8, 3.45, 0), Vector3(0.50, 6.9, 38), "concrete", CONCRETE, true)
	_box(Vector3(side * 14.47, 0.58, 0), Vector3(0.27, 1.15, 37), "brick", Color("#7a877e"))
	_box(Vector3(side * 14.45, 1.19, 0), Vector3(0.30, 0.12, 37), "iron", STEEL)
	var shaft := _pipe(Vector3(side * 13.15, 5.25, 0), 0.37, 36.8, RUST)
	shaft.rotation.x = PI / 2.0
	for z in [-16.0, -10.0, -4.0, 3.0, 9.0, 15.0]:
		_box(Vector3(side * 14.36, 3.44, z), Vector3(0.63, 6.9, 0.58), "concrete", Color("#a4a79a"))
		_box(Vector3(side * 14.0, 5.25, z), Vector3(1.10, 0.13, 0.44), "iron", STEEL)
		var clamp := _pipe(Vector3(side * 13.15, 5.25, z), 0.42, 0.19, STEEL)
		clamp.rotation.x = PI / 2.0
		var patch := _box(Vector3(side * 14.48, 3.28, z + 1.28), Vector3(0.045, 0.41, 1.67),
			"plaster", Color("#9b9f8d"))
		patch.rotation.x = side * 0.09


func _pump(side: int, z: float) -> void:
	var x := side * 10.65
	_box(Vector3(x, 0.18, z), Vector3(3.35, 0.36, 3.5), "concrete", CONCRETE, true)
	_box(Vector3(x, 0.65, z), Vector3(2.90, 0.65, 2.95), "iron", STEEL, true)
	var drum := _pipe(Vector3(x, 1.42, z), 0.95, 2.35, Color("#738479"), true)
	drum.rotation.z = PI / 2.0
	for offset in [-0.93, -0.65, -0.37, 0.37, 0.65, 0.93]:
		var rib := _pipe(Vector3(x + offset, 1.42, z), 0.98, 0.11, STEEL)
		rib.rotation.z = PI / 2.0
	for offset in [-1.05, 1.05]:
		var pressure_end := _pipe(Vector3(x + offset, 1.42, z), 1.04, 0.17, RUST)
		pressure_end.rotation.z = PI / 2.0
	var face_x: float = x - side * 1.22
	for segment in range(8):
		var angle := segment * TAU / 8
		var bolt := _pipe(Vector3(face_x, 1.42 + cos(angle) * 0.84, z + sin(angle) * 0.84), 0.066, 0.09, SIGNAL, false, 6)
		bolt.rotation.z = PI / 2.0
	_pipe(Vector3(x + side * 0.54, 3.60, z), 0.25, 3.2, RUST)
	_pipe(Vector3(x + side * 0.54, 2.43, z), 0.38, 0.36, STEEL)
	var connector := _pipe(Vector3(side * 12.15, 5.25, z), 0.25, 2.42, RUST)
	connector.rotation.z = PI / 2.0
	_box(Vector3(x - side * 1.40, 0.73, z + 1.07), Vector3(0.065, 0.24, 0.63), "iron", SIGNAL)
	for i in range(3):
		var stripe := _box(Vector3(x - side * 1.438, 0.73, z + 0.88 + i * 0.17),
			Vector3(0.031, 0.22, 0.078), "iron", STEEL)
		stripe.rotation.x = -0.42


func _column(side: int, z: float) -> void:
	var x := side * 6.35
	_box(Vector3(x, 0.15, z), Vector3(0.86, 0.30, 0.91), "concrete", CONCRETE, true)
	_box(Vector3(x, 3.31, z), Vector3(0.58, 6.62, 0.61), "concrete", Color("#a5aaa0"), true)
	_box(Vector3(x, 6.44, z), Vector3(0.87, 0.57, 0.94), "iron", STEEL)
	_box(Vector3(x, 0.93, z), Vector3(0.68, 0.37, 0.68), "iron", SIGNAL)
	_box(Vector3(x, 0.70, z), Vector3(0.69, 0.11, 0.69), "iron", STEEL)
	for i in range(3):
		var stripe := _box(Vector3(x - side * 0.347, 0.93, z - 0.20 + i * 0.20),
			Vector3(0.025, 0.36, 0.078), "iron", STEEL)
		stripe.rotation.x = -0.42
	var cable := _pipe(Vector3(x + side * 0.42, 3.67, z + 0.22), 0.046, 5.35, STEEL, false, 8)
	cable.rotation.z = side * 0.03
	for y in [1.7, 2.6, 3.8, 5.0]:
		_box(Vector3(x + side * 0.35, y, z + 0.22), Vector3(0.23, 0.054, 0.14), "iron", RUST)


func _lockers(side: int) -> void:
	var x := side * 13.98
	for z in [-1.25, -0.2, 0.85]:
		_box(Vector3(x, 0.93, z), Vector3(0.93, 1.86, 0.94), "iron", STEEL, true)
		_box(Vector3(x - side * 0.48, 0.98, z), Vector3(0.066, 1.67, 0.83), "iron", Color("#748882"))
		_box(Vector3(x - side * 0.53, 0.82, z - 0.25), Vector3(0.068, 0.22, 0.045), "iron", RUST)
		for i in range(4):
			_box(Vector3(x - side * 0.52, 1.38 + i * 0.067, z), Vector3(0.015, 0.021, 0.52), "iron", STEEL)


func _console(side: int) -> void:
	var x := side * 10.77
	var at := Vector3(x, 1.06, 3.05)
	_box(Vector3(x, 0.17, 3.08), Vector3(1.73, 0.34, 1.60), "concrete", CONCRETE, true)
	_box(at + Vector3.DOWN * 0.31, Vector3(1.13, 1.09, 0.78), "iron", STEEL, true)
	_box(at + Vector3.UP * 0.29, Vector3(1.32, 0.25, 0.93), "iron", RUST)
	_box(at + Vector3(0, 0.35, -0.48), Vector3(1.00, 0.22, 0.06), "iron", STEEL)
	var pointer := _pipe(at + Vector3(0, 0.29, -0.60), 0.22, 0.15, RUST, false, 10)
	pointer.rotation.x = PI / 2.0
	for i in range(3):
		var spoke := _box(at + Vector3(0, 0.29, -0.688), Vector3(0.35, 0.035, 0.030), "iron", SIGNAL)
		spoke.rotation.z = i * PI / 3.0
	_lamp(at + Vector3(0.41, 0.48, -0.14), Color("#8de8bc"), 5.0, 0.95)


func _service_door(side: int) -> void:
	var x := side * 4.8
	var z := side * 18.46
	_box(Vector3(x, 1.82, z), Vector3(3.0, 3.64, 0.31), "iron", RUST)
	_box(Vector3(x, 1.68, z - side * 0.17), Vector3(2.70, 3.20, 0.16), "iron", STEEL)
	for y in [0.56, 1.41, 2.49, 3.12]:
		_box(Vector3(x, y, z - side * 0.26), Vector3(2.62, 0.075, 0.12), "iron", RUST)
	_lamp(Vector3(x, 3.96, z - side * 0.25), Color("#f0ad74"), 7.0, 1.05)
	RelayGeometry.label(_room, "检修通道" if side < 0 else "北压泵房",
		Vector3(x, 3.52, z - side * 0.27), Color("#ddd2ab"))


func _walk_grate(z: float) -> void:
	for x in [-2.65, 2.65]:
		_box(Vector3(x, 0.022, z), Vector3(0.11, 0.04, 1.24), "iron", RUST)
	for i in range(12):
		_box(Vector3(0, 0.026, z - 0.56 + i * 0.101), Vector3(5.25, 0.033, 0.038), "iron", STEEL)


func _pipe(at: Vector3, radius: float, height: float, tint: Color, solid := false, sides := 12) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.radial_segments = sides
	cylinder.rings = 0
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	var mesh := RelayGeometry.mesh(_room, cylinder, at, _finish.paint("iron", tint))
	if solid:
		var hull := CylinderShape3D.new()
		hull.radius = radius
		hull.height = height
		RelayGeometry.body(mesh, hull)
	return mesh


func _box(at: Vector3, size: Vector3, texture: String, tint: Color, solid := false) -> MeshInstance3D:
	return _finish.box(_room, at, size, texture, tint, solid)


func _lamp(at: Vector3, tint: Color, radius: float, energy: float) -> void:
	_box(at, Vector3(0.92, 0.20, 0.32), "iron", STEEL)
	RelayGeometry.box(_room, at + Vector3.DOWN * 0.11, Vector3(0.78, 0.055, 0.24), RelayGeometry.finish(tint, 1.15))
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.50
	light.position = at + Vector3.DOWN * 0.25
	_room.add_child(light)
