class_name RegionalBuilding
extends Node3D

enum Style { SERVICE, CLINIC, DISPATCH, STORE, RELAY }
const CLEAR_HEIGHT := 2.76
const STOREY := 2.95
const DOOR_WIDTH := 1.82
const DOOR_HEIGHT := 2.22
const THICKNESS := 0.25
const FRAME := Color("#77726a")
const STEEL := Color("#6d716f")
const WOOD := Color("#846c51")
const BARE := Color("#d3c9ac")
const WINDOW := Color("#343c3b")

var code: String
var title: String
var footprint: Vector2
var floors: int
var style: int
var entrance: Marker3D
var stair_start: Marker3D
var stair_end: Marker3D
var crates: Array[RelaySite] = []
var _paint: RegionFinishes
var _wall: Color
var _trim: Color
var _pitched: bool


func construct(key: String, label: String, size: Vector2, floor_count: int, use: int,
		tint: Color, pitched: bool, finishes: RegionFinishes) -> void:
	code = key
	title = label
	footprint = size
	floors = floor_count
	style = use
	_paint = finishes
	_wall = tint
	_trim = tint.darkened(0.29)
	_pitched = pitched
	entrance = _marker(Vector3(0,0.04,size.y/2+0.9))
	_floor(0.0, size)
	if floors == 2:
		_stairs()
	for level in range(floors):
		_build_storey(level)
	_roof()
	_front_fittings()
	_furnish()


func _build_storey(level: int) -> void:
	var w := footprint.x
	var d := footprint.y
	var y := level * STOREY
	var h := STOREY if level < floors - 1 else CLEAR_HEIGHT
	_facade(Vector3(0,y,d/2), 0.0, w, h, level == 0, level * 3)
	_facade(Vector3(0,y,-d/2), PI, w, h, false, level * 3 + 1)
	_facade(Vector3(w/2,y,0), PI/2, d, h, false, level * 3 + 2)
	_facade(Vector3(-w/2,y,0), -PI/2, d, h, false, level * 3 + 3)


func _facade(point: Vector3, angle: float, span: float, height: float, doorway: bool, pattern: int) -> void:
	var face := Node3D.new()
	face.position = point
	face.rotation.y = angle
	add_child(face)
	var sill := 1.07
	var head := 2.04
	var window_width := 1.18 if span > 7.0 else 0.99
	var sidelight := span * 0.29
	var holes: Array[Vector4] = [Vector4(-sidelight, window_width, sill, head)]
	if doorway:
		holes.append(Vector4(0, DOOR_WIDTH, 0, DOOR_HEIGHT))
	holes.append(Vector4(sidelight, window_width, sill, head))
	var start := -span / 2
	for i in range(holes.size()):
		var opening := holes[i]
		var left := opening.x - opening.y / 2
		_wall_panel(face, start, left, 0, height, pattern + i)
		if opening.z > 0.0:
			_wall_panel(face, left, left+opening.y, 0, opening.z, pattern+i+1)
			_window(face, opening, (pattern + i) % 3 != 1)
		_wall_panel(face, left, left+opening.y, opening.w, height, pattern+i+2)
		start = left + opening.y
	_wall_panel(face, start, span/2, 0, height, pattern+3)
	_paint.box(face, Vector3(0,height-0.08,0.057), Vector3(span+0.10,0.14,0.33), "concrete", _trim)
	for side in [-1.0, 1.0]:
		_paint.box(face, Vector3(side*(span/2-0.11), height/2, 0.025), Vector3(0.21,height,0.36), "concrete", _trim)


func _wall_panel(face: Node3D, left: float, right: float, bottom: float, top: float, pattern: int) -> void:
	var w := right - left
	var h := top - bottom
	if w <= 0.015 or h <= 0.015:
		return
	var center := (left + right) / 2
	var y := (bottom + top) / 2
	_paint.box(face, Vector3(center,y,0), Vector3(w,h,THICKNESS), "plaster", _wall, true)
	if bottom < 0.03:
		var panel_height := 0.56 if style == Style.RELAY else 0.39
		var base_surface := "iron" if style == Style.RELAY else "concrete"
		_paint.box(face, Vector3(center,panel_height/2,0.127), Vector3(w-0.008,panel_height,0.075), base_surface, _trim)
		_paint.box(face,Vector3(center,0.108,-0.134),Vector3(w-0.008,0.20,0.040),"wood",FRAME)
		if style == Style.RELAY:
			for slot in range(floori(w / 0.23)):
				_paint.box(face,Vector3(left+0.13+slot*0.23,0.274,0.174),Vector3(0.043,0.49,0.026),"iron",STEEL)
	if w >= 0.48 and h >= 0.50 and pattern % 5 != 3:
		var patch_x := lerpf(left, right, 0.40 if pattern % 2 == 0 else 0.58)
		var patch_y := bottom + h * (0.44 if pattern % 3 == 0 else 0.22)
		var size := Vector2(minf(w*0.34, 0.58), minf(h*0.19, 0.34))
		_spall(face, Vector3(patch_x,patch_y,THICKNESS/2+0.002), size, pattern)
		if h > 1.9 and w > 0.9:
			_spall(face, Vector3(center-w*0.20,top-0.53,THICKNESS/2+0.002), size*0.67, pattern+2)


func _spall(face: Node3D, origin: Vector3, size: Vector2, seed: int) -> void:
	var stencil := SurfaceTool.new()
	stencil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [
		Vector2(-0.94,0.39),Vector2(-0.52,0.91),Vector2(-0.06,0.62),Vector2(0.36,0.98),
		Vector2(0.92,0.43),Vector2(0.68,-0.35),Vector2(0.15,-0.88),Vector2(-0.58,-0.51),
	]
	for i in range(corners.size()):
		var next: Vector2 = corners[(i+1)%corners.size()]
		var edge: Vector2 = corners[i]
		for v in [Vector2.ZERO, edge, next]:
			var warping := 1.0 + 0.20*sin(v.x*19.0+seed)
			var local: Vector2 = v * size * warping
			stencil.add_vertex(Vector3(local.x,local.y,0))
	stencil.generate_normals()
	var shade := Color("#ad957d") if seed % 2 == 0 else Color("#97816a")
	RelayGeometry.mesh(face, stencil.commit(), origin, _paint.paint("brick", shade))


func _window(face: Node3D, opening: Vector4, boarded: bool) -> void:
	var w := opening.y
	var h := opening.w-opening.z
	var center := Vector3(opening.x, (opening.z+opening.w)/2, 0)
	var reveal := Color("#a49a82")
	for side in [-1.0, 1.0]:
		_paint.box(face, center+Vector3(side*(w/2+0.014),0,0), Vector3(0.116,h+0.19,0.34), "concrete", reveal)
		_paint.box(face, center+Vector3(0,side*(h/2+0.008),0.016), Vector3(w+0.16,0.108,0.37), "concrete", reveal)
		_paint.box(face, center+Vector3(side*(w/2-0.061),0,-0.041), Vector3(0.06,h,0.16), "wood", FRAME)
	_paint.box(face, center+Vector3(0,-h/2-0.047,0.06), Vector3(w+0.28,0.10,0.46), "concrete", FRAME)
	_paint.box(face, center+Vector3(0,0,-0.045), Vector3(w-0.10,h-0.10,0.033), "iron", WINDOW, true)
	_paint.box(face, center+Vector3(0,0,0.009), Vector3(0.057,h-0.07,0.074), "wood", WOOD)
	_paint.box(face, center+Vector3(0,0.038,0.009), Vector3(w-0.07,0.044,0.074), "wood", WOOD)
	var shard := _paint.box(face, center + Vector3(-w*0.18,0.19,0.012), Vector3(w*0.37,0.15,0.014),
		"iron", Color("#6a8587"))
	shard.rotation.z = -0.24
	if boarded:
		for row in range(2):
			var board := _paint.box(face, center+Vector3(0.044,0.23-row*0.37,0.141),
				Vector3(w+0.25-row*0.09,0.14+row*0.043,0.050), "wood", WOOD.lightened(row*0.18))
			board.rotation.z = 0.10 if row == 0 else -0.21


func _floor(y: float, size: Vector2, shift := Vector2.ZERO) -> void:
	_paint.box(self, Vector3(shift.x,y-0.073,shift.y), Vector3(size.x,0.15,size.y), "floor", BARE, true)


func _roof() -> void:
	var top := (floors-1)*STOREY + CLEAR_HEIGHT
	var w := footprint.x
	var d := footprint.y
	if not _pitched:
		_paint.box(self, Vector3(0,top+0.09,0), Vector3(w+0.42,0.18,d+0.41), "roof", Color("#626665"), true)
		for side in [-1.0, 1.0]:
			_paint.box(self, Vector3(side*w/2,top+0.28,0), Vector3(0.26,0.48,d+0.22), "concrete", _trim)
			_paint.box(self, Vector3(0,top+0.28,side*d/2), Vector3(w+0.34,0.48,0.26), "concrete", _trim)
		_paint.box(self, Vector3(w/2-0.71,top+0.56,-d/2+0.69), Vector3(0.57,0.91,0.50), "brick", BARE)
		if style == Style.RELAY:
			_paint.box(self,Vector3(-w*0.20,top+0.57,-0.34),Vector3(1.58,0.77,1.04),"iron",STEEL)
			_paint.box(self,Vector3(-w*0.20,top+0.96,-0.34),Vector3(1.77,0.10,1.17),"roof",FRAME)
			for i in range(6):
				_paint.box(self,Vector3(-w*0.20,top+0.32+i*0.082,0.194),Vector3(1.24,0.027,0.040),"iron",WINDOW)
		return
	var rise := 0.93
	var slope := atan2(rise,w/2)
	var gable := PrismMesh.new()
	gable.size = Vector3(w, rise, 0.21)
	for side in [-1.0,1.0]:
		RelayGeometry.mesh(self,gable,Vector3(0,top+rise/2,side*d/2),_paint.paint("plaster",_wall))
		var valley := Vector3(side*(w/4+0.115),top+rise/2+0.055,0)
		var panel := _paint.box(self, valley, Vector3(w/2/cos(slope)+0.48,0.16,d+1.06), "roof", Color("#917158"), true)
		panel.rotation.z = -side*slope
		_paint.box(self, Vector3(side*(w/2+0.33),top-0.025,0), Vector3(0.16,0.19,d+0.98), "wood", FRAME)
		for z in range(-2,3):
			var seam := _paint.box(self, valley+Vector3(0,0.091,z*d/5.0), Vector3(w/2+0.23,0.078,0.11),
				"iron", Color("#a48367"))
			seam.rotation.z = -side*slope
	_paint.box(self, Vector3(0,top+rise+0.108,0), Vector3(0.22,0.13,d+1.12), "iron", Color("#a17b5e"))


func _front_fittings() -> void:
	var front := footprint.y / 2
	var trim := Color("#89684e") if _pitched else Color("#677578")
	for side in [-1.0,1.0]:
		_paint.box(self, Vector3(side*(DOOR_WIDTH/2+0.065),1.11,front+0.023),
			Vector3(0.15,2.22,0.42), "wood", trim)
		_paint.box(self, Vector3(side*(DOOR_WIDTH/2+0.154),0.23,front+0.20),
			Vector3(0.13,0.44,0.095), "iron", STEEL)
	_paint.box(self, Vector3(0,DOOR_HEIGHT+0.069,front+0.036), Vector3(2.15,0.17,0.44), "wood", trim)
	_paint.box(self, Vector3(0,2.31,front+0.52), Vector3(2.65,0.13,0.91), "iron", trim)
	_paint.box(self, Vector3(0.22,2.54,front+0.21), Vector3(1.67,0.30,0.12), "iron", WINDOW)
	var display := RelayGeometry.label(self,title,Vector3(0.22,2.54,front+0.282),Color("#e0d3aa"))
	display.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	display.pixel_size = 0.0057
	display.outline_size = 4
	_paint.box(self, Vector3(-1.22,2.11,front+0.25), Vector3(0.22,0.21,0.17), "iron", STEEL)
	RelayGeometry.box(self, Vector3(-1.22,2.05,front+0.35), Vector3(0.14,0.09,0.07),
		RelayGeometry.finish(Color("#eccb87"),0.87))
	if style in [Style.CLINIC, Style.STORE]:
		var awning := _paint.box(self,Vector3(-footprint.x*0.26,2.26,front+0.51),
			Vector3(footprint.x*0.35,0.087,0.91),"roof",Color("#9b6352") if style == Style.STORE else Color("#6c8a7d"))
		awning.rotation.x = 0.14
		_paint.box(self,Vector3(-footprint.x*0.26,2.178,front+0.958),
			Vector3(footprint.x*0.35,0.128,0.061),"iron",FRAME)
	var opened := _paint.box(self, Vector3(1.11,1.075,front-0.54), Vector3(0.07,2.04,1.03), "wood", WOOD, true)
	_paint.box(opened, Vector3(-0.05,0.05,-0.38), Vector3(0.1,0.07,0.09), "iron", STEEL)
	_paint.box(self, Vector3(0,0.023,front+0.50), Vector3(2.45,0.05,1.02), "floor", FRAME)


func _stairs() -> void:
	var w := footprint.x
	var d := footprint.y
	var gap := 1.64
	var x := w/2-gap/2-0.17
	var start := d/2-0.85
	var finish := -d/2+1.44
	var run := start-finish
	var steps := 15
	var riser := STOREY/steps
	var tread := run/steps
	var edge := x-gap/2
	_floor(STOREY, Vector2(edge+w/2,d), Vector2((edge-w/2)/2,0))
	var front_depth := d/2-start
	var back_depth := finish+d/2
	_floor(STOREY, Vector2(w/2-edge,front_depth), Vector2((edge+w/2)/2,start+front_depth/2))
	_floor(STOREY, Vector2(w/2-edge,back_depth), Vector2((edge+w/2)/2,finish-back_depth/2))
	for i in range(steps):
		var height := (i+0.54)*riser
		var z := start-(i+0.5)*tread
		_paint.box(self, Vector3(x,height-riser/2,z), Vector3(1.41,riser,tread+0.012), "wood", WOOD)
		_paint.box(self, Vector3(x,height-0.027,z+tread/2), Vector3(1.49,0.054,0.078), "iron", STEEL)
	var ramp := _paint.box(self,Vector3(x,STOREY/2-0.038,(start+finish)/2),
		Vector3(1.43,0.072,sqrt(STOREY*STOREY+run*run)), "wood", WOOD, true)
	ramp.rotation.x = atan2(STOREY,run)
	ramp.hide()
	for side in [-1.0,1.0]:
		var stringer := _paint.box(self,Vector3(x+side*0.56,STOREY/2-0.235,(start+finish)/2),
			Vector3(0.155,0.29,sqrt(STOREY*STOREY+run*run)),"wood",WOOD.darkened(0.24))
		stringer.rotation.x = ramp.rotation.x
	var slope_rail := _paint.box(self,Vector3(x-0.735,STOREY/2+0.78,(start+finish)/2),
		Vector3(0.073,0.075,sqrt(STOREY*STOREY+run*run)),"iron",STEEL)
	slope_rail.rotation.x = ramp.rotation.x
	for i in range(5):
		var fraction := (i+0.3)/5.0
		_paint.box(self,Vector3(x-0.735,fraction*STOREY+0.38,lerpf(start,finish,fraction)),
			Vector3(0.074,0.77,0.075),"iron",STEEL)
	var guard := _paint.box(self, Vector3(edge-0.028,STOREY+0.45,(start+finish)/2),
		Vector3(0.081,0.9,run), "iron", STEEL, true)
	guard.hide()
	_paint.box(self, Vector3(edge-0.028,STOREY+0.93,(start+finish)/2), Vector3(0.12,0.10,run), "wood", WOOD)
	_paint.box(self, Vector3(edge-0.028,STOREY+0.41,(start+finish)/2), Vector3(0.055,0.056,run), "iron", STEEL)
	for i in range(6):
		_paint.box(self,Vector3(edge-0.028,STOREY+0.46,lerpf(finish,start,i/5.0)),
			Vector3(0.068,0.92,0.061),"iron",STEEL)
	stair_start = _marker(Vector3(x,0.04,start+0.37))
	stair_end = _marker(Vector3(x,STOREY+0.04,finish-0.58))


func _furnish() -> void:
	var w := footprint.x
	var d := footprint.y
	var light := OmniLight3D.new()
	light.position = Vector3(0,2.26,0.12)
	light.omni_range = maxf(w,d)*1.04
	light.light_energy = 1.21
	light.light_color = Color("#f0d7a7")
	add_child(light)
	if floors == 2:
		var top_light := light.duplicate() as OmniLight3D
		top_light.position = Vector3(-0.9,STOREY+2.25,1.0)
		top_light.light_energy = 0.51
		add_child(top_light)
	_paint.box(self, Vector3(0,2.53,0), Vector3(1.29,0.095,0.25), "iron", STEEL)
	RelayGeometry.box(self, Vector3(0,2.475,0), Vector3(0.93,0.039,0.15), RelayGeometry.finish(Color("#d3caaa"),0.4))
	var left := -w/2+0.52
	var bench_length := minf(2.2,d*0.37)
	var bench_height := 0.90
	if style == Style.CLINIC:
		bench_height = 0.69
	elif style == Style.STORE:
		bench_height = 1.03
	_paint.box(self, Vector3(left,bench_height,0.26), Vector3(0.73,0.13,bench_length),
		"wood", WOOD if style != Style.CLINIC else Color("#99a89d"), true)
	for z in [0.26-bench_length*0.39, 0.26+bench_length*0.39]:
		_paint.box(self, Vector3(left,bench_height/2,z), Vector3(0.58,bench_height,0.15), "iron", STEEL, true)
	if style == Style.CLINIC:
		_paint.box(self, Vector3(left,bench_height+0.13,-0.06), Vector3(0.54,0.13,bench_length*0.61),
			"cloth", Color("#a3a89c"))
	else:
		for i in range(3):
			_paint.box(self, Vector3(left,bench_height+0.105+i*0.036,0.14+i*0.21),
				Vector3(0.39-i*0.047,0.065,0.37), "wood", BARE.darkened(i*0.16))
	if floors == 1:
		var shelf := Vector3(w/2-0.52,0,-0.08)
		for level in range(3):
			_paint.box(self, shelf+Vector3(0,0.27+level*0.46,0), Vector3(0.57,0.07,1.58), "wood", WOOD, true)
		for z in [-0.70,0.70]:
			_paint.box(self, shelf+Vector3(0,0.72,z), Vector3(0.47,1.44,0.087), "iron", STEEL, true)
	elif style == Style.DISPATCH:
		var board := Vector3(-w/2+0.20,1.86,0.29)
		_paint.box(self,board,Vector3(0.11,0.71,1.51),"wood",FRAME)
		_paint.box(self,board+Vector3(0.066,0.013,0.03),Vector3(0.025,0.58,1.33),"iron",Color("#55625b"))
	_storage_fittings()


func _storage_fittings() -> void:
	var w := footprint.x
	var d := footprint.y
	var bank := Vector3(-w*0.39,0,-d*0.36)
	var color := Color("#949d96") if style in [Style.CLINIC,Style.DISPATCH] else Color("#937e68")
	_paint.box(self,bank+Vector3.UP*0.77,Vector3(0.83,1.53,0.49),"iron",color,true)
	_paint.box(self,bank+Vector3.UP*1.54,Vector3(0.91,0.08,0.55),"iron",FRAME)
	for panel in range(2):
		var face := bank+Vector3(-0.191+panel*0.382,0.79,0.256)
		_paint.box(self,face,Vector3(0.35,1.37,0.037),"iron",color.lightened(panel*0.10))
		_paint.box(self,face+Vector3(0.10,0.04,0.029),Vector3(0.047,0.23,0.059),"wood",FRAME)
		for slot in range(3):
			_paint.box(self,face+Vector3(0,0.49+slot*0.048,0.025),Vector3(0.20,0.022,0.019),"iron",WINDOW)
	if style == Style.DISPATCH:
		var chart := Vector3(-w*0.49,1.80,d*0.24)
		_paint.box(self,chart,Vector3(0.053,0.66,1.38),"wood",FRAME)
		_paint.box(self,chart+Vector3.RIGHT*0.034,Vector3(0.025,0.54,1.21),"floor",Color("#beb289"))
		for i in range(5):
			_paint.box(self,chart+Vector3(0.055,0.14-i*0.064,-0.16),Vector3(0.016,0.012,0.57),"wood",FRAME)
	elif style == Style.CLINIC:
		var bed := Vector3(w/2-0.53,0.47,d*0.25)
		_paint.box(self,bed,Vector3(0.73,0.12,1.78),"iron",STEEL,true)
		_paint.box(self,bed+Vector3.UP*0.095,Vector3(0.67,0.12,1.65),"cloth",Color("#9da797"))
		_paint.box(self,bed+Vector3(0,0.194,-0.55),Vector3(0.45,0.10,0.37),"cloth",BARE)
		for end in [-1.0,1.0]:
			_paint.box(self,bed+Vector3(0,-0.18,end*0.76),Vector3(0.64,0.47,0.077),"iron",STEEL)
	elif style == Style.STORE:
		var shelf := Vector3(-w/2+0.47,1.13,d*0.28)
		_paint.box(self,shelf,Vector3(0.70,0.09,1.12),"wood",WOOD,true)
		for i in range(4):
			_paint.box(self,shelf+Vector3(0,0.139,-0.38+i*0.222),Vector3(0.18,0.21,0.18),
				"iron",Color("#8b8d7c").lightened(i*0.035))
	if floors == 2:
		var upstairs := Vector3(-w/2+0.62,STOREY+0.83,0.38)
		_paint.box(self,upstairs,Vector3(0.87,0.16,2.16),"wood",WOOD,true)
		for i in range(3):
			_paint.box(self,upstairs+Vector3(0,0.11,-0.68+i*0.66),Vector3(0.52,0.08,0.49),"floor",BARE)
		_paint.box(self,upstairs+Vector3(0,-0.42,0),Vector3(0.69,0.79,1.92),"wood",WOOD.darkened(0.12),true)


func _marker(point: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.position = point
	add_child(marker)
	return marker
