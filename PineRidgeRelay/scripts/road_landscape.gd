class_name RoadLandscape
extends RefCounted

var _root: Node3D
var _paint: RegionFinishes


func _init(root: Node3D, finishes: RegionFinishes) -> void:
	_root = root
	_paint = finishes
	_build()


func _build() -> void:
	var concrete := Color("#a3aa9b")
	var ochre := Color("#a89a6b")
	var blue := Color("#4e6366")
	var metal := Color("#586357")
	var road := Color("#555b56")
	_box(Vector3(0,-0.31,7),Vector3(44,0.60,124),"concrete",Color("#aaa187"),true)
	_box(Vector3(0,-0.077,7),Vector3(15.3,0.14,124),"floor",road)
	for mark in range(18):
		var z := -48.0 + mark*6.5
		_box(Vector3(0,0.013,z),Vector3(0.12,0.018,2.65),"floor",ochre)
		for side in [-1.0,1.0]:
			_box(Vector3(side*6.85,0.014,z),Vector3(0.098,0.015,6.40),"floor",concrete)
			_box(Vector3(side*9.15,0.60,z),Vector3(0.34,0.34,6.53),"iron",metal,true)
			_box(Vector3(side*9.19,0.33,z-2.48),Vector3(0.22,0.72,0.46),"concrete",concrete,true)
			if mark % 2 == 0:
				_rumble_marker(Vector3(side*8.30,0.0,z),side)
	for side in [-1.0,1.0]:
		_box(Vector3(side*10.7,1.03,7),Vector3(0.21,2.15,123),"iron",blue,true)
		_box(Vector3(side*14.0,0.41,-4),Vector3(5.7,0.86,86),"concrete",Color("#6b6751"))
		for i in range(6):
			var z: float = -43+i*19.0
			_lamp(Vector3(side*8.47,0,z),side)
			_rock(Vector3(side*(15.7+i%3),0.30,z+5.7),2.2+i%3*0.43)
	for z in [-53.0,65.0]:
		_box(Vector3(0,1.34,z),Vector3(23,2.69,0.66),"iron",blue,true)
		_box(Vector3(0,2.73,z),Vector3(23.1,0.14,0.76),"concrete",concrete)
		for x in range(-10,11,2):
			_box(Vector3(x,0.16,z+signf(z)*-0.36),Vector3(1.10,0.22,0.065),"floor",ochre)
	for side in [-1.0,1.0]:
		_box(Vector3(side*8.45,2.9,43.8),Vector3(0.39,5.80,0.40),"iron", metal,true)
	_box(Vector3(0,5.61,43.8),Vector3(17.6,0.46,0.51),"iron",metal)
	_box(Vector3(0,5.17,43.45),Vector3(5.45,0.78,0.18),"iron",blue)
	var banner := RelayGeometry.label(_root,"前方封锁",Vector3(0,5.17,43.31),Color("#ded39c"))
	banner.pixel_size = 0.018
	_wreck(Vector3(-6.4,0,-7.1),Color("#9b6353"),-0.19)
	_wreck(Vector3(6.6,0,19.4),Color("#718788"),0.12)
	_wreck(Vector3(-6.6,0,37.7),Color("#8e8670"),0.08)
	_mark_zone(Vector3(0,0,-30.0),"断线公路")
	_mark_zone(Vector3(0,0,47.0),"感染区")


func _rumble_marker(at: Vector3, side: float) -> void:
	_box(at+Vector3.UP*0.46,Vector3(0.113,0.90,0.21),"concrete",Color("#a4a394"))
	_box(at+Vector3(side*0.049,0.63,-0.012),Vector3(0.024,0.18,0.24),"iron",Color("#a56345"))


func _lamp(at: Vector3, side: float) -> void:
	_box(at+Vector3.UP*2.0,Vector3(0.10,4.0,0.10),"iron",Color("#5c655d"),true)
	_box(at+Vector3(-side*0.45,3.95,0),Vector3(1.0,0.08,0.14),"iron",Color("#757e74"))
	RelayGeometry.box(_root,at+Vector3(-side*0.89,3.89,0),Vector3(0.20,0.10,0.32),
		RelayGeometry.finish(Color("#eac37d"),0.85))


func _rock(at: Vector3, width: float) -> void:
	var scalar := SphereMesh.new()
	scalar.radial_segments = 7
	scalar.rings = 3
	var prop := RelayGeometry.mesh(_root,scalar,at,_paint.paint("concrete",Color("#716f61")))
	prop.scale = Vector3(width,1.32,width*1.2)


func _wreck(at: Vector3, tint: Color, yaw: float) -> void:
	var shell := _box(at+Vector3.UP*0.56,Vector3(1.88,0.62,3.6),"iron",tint,true)
	shell.rotation.y = yaw
	_paint.box(shell,Vector3(0,0.49,-0.25),Vector3(1.61,0.46,1.99),"iron",tint)
	_paint.box(shell,Vector3(0,0.45,0.76),Vector3(1.46,0.27,0.05),"iron",Color("#364743"))
	_paint.box(shell,Vector3(0,-0.10,1.83),Vector3(1.97,0.12,0.13),"iron",Color("#717975"))
	for side in [-1.0,1.0]:
		for z in [-1.08,1.07]:
			var tire := CylinderMesh.new()
			tire.radial_segments = 9
			tire.top_radius = 0.31
			tire.bottom_radius = 0.31
			tire.height = 0.23
			var wheel := RelayGeometry.mesh(shell,tire,Vector3(side*0.88,-0.29,z),_paint.paint("rubber",Color("#303735")))
			wheel.rotation.z = PI/2
			_paint.box(shell,Vector3(side*1.0,-0.27,z),Vector3(0.024,0.156,0.156),"iron",Color("#7c7f70"))


func _mark_zone(at: Vector3, label: String) -> void:
	for side in [-1.0,1.0]:
		_box(at+Vector3(side*7.62,1.24,0),Vector3(0.14,2.5,0.16),"iron",Color("#616c5f"))
	var sign := RelayGeometry.label(_root,label,at+Vector3(0,3.19,0),Color("#e7d4a0"))
	sign.pixel_size = 0.012


func _box(at: Vector3, size: Vector3, surface: String, color: Color, solid := false) -> MeshInstance3D:
	return _paint.box(_root,at,size,surface,color,solid)
