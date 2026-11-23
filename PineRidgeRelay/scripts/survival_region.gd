class_name SurvivalRegion
extends Node3D

const CLEARING := preload("res://scenes/clearing.tscn")
const CRATE := preload("res://assets/world/supply_crate.glb")
const FENCE := Color("#5e625d")
const CONCRETE := Color("#77796f")
const RUST := Color("#774d3d")
const STEEL := Color("#353e3e")
const LIGHT := Color("#62e3ce")

# x, z, resource type. Placement is deliberately off the main trail.
const DEPOSITS := [
	[[9,-3,0],[-13,2,0],[15,9,0],[-10,15,0],[19,19,0],[-17,25,0],[10,32,0],[-7,43,0],
		[-9,-1,2],[12,27,2],[-13,37,2],[6,12,1],[-8,30,1]],
	[[-14,-21,0],[13,-15,0],[17,10,0],[-13,22,0],[11,30,0],
		[-13,-7,2],[15,-3,2],[6,24,2],[-18,13,3],[18,16,3],[-17,29,3],[19,-8,3],[14,32,3]],
	[[-9,-23,0],[18,-13,0],[-17,4,0],[15,17,0],[-20,28,0],
		[-21,-18,2],[19,20,2],[0,29,2]],
	[[-10,-16,0],[12,-12,0],[-14,15,0],[10,31,0],
		[-15,-24,2],[21,3,2],[-19,30,2],[-18,-6,4],[15,-4,4],[-17,13,4],[18,16,4],[20,28,4]],
]
const NESTS := [
	[Vector2(-10,6),Vector2(13,14),Vector2(-12,26),Vector2(12,36),Vector2(-7,43)],
	[Vector2(-14,-13),Vector2(13,-7),Vector2(-16,8),Vector2(15,17),Vector2(-8,28),Vector2(10,34)],
	[Vector2(-8,-16),Vector2(11,-6),Vector2(-9,0),Vector2(8,13),Vector2(-11,24),Vector2(5,29)],
	[Vector2(-13,-18),Vector2(13,-11),Vector2(-12,1),Vector2(10,6),Vector2(-11,16),Vector2(12,27)],
]

var id: int
var ground: Node3D
var supplies := Node3D.new()
var ores := Node3D.new()
var infected := Node3D.new()
var lighting: RelayLighting
var sites: Array[RelaySite] = []
var portal: RelaySite
var bench: RelaySite
var furnace: RelaySite
var arrival: Vector3
var shelter: Vector3
var _materials: Dictionary = {}


func build(map_id: int, opened: Dictionary, rules: SupplyRules) -> void:
	id = map_id
	add_child(supplies)
	add_child(ores)
	add_child(infected)
	if id == 0:
		ground = CLEARING.instantiate()
		add_child(ground)
		lighting = ground.get_node("Lighting")
		shelter = Vector3(0, 0.10, -9.7)
		_station()
		_portal(Vector2(5.8, -4.8))
	else:
		ground = Node3D.new()
		add_child(ground)
		_sky()
		_terrain()
		_border()
		match id:
			1: _quarry()
			2: _city()
			3: _basin()
		_portal(Vector2(0, -29))
		shelter = arrival
	for entry in sites:
		if entry.role == RelaySite.Role.CRATE and opened.has(entry.key):
			entry.mark_looted()
	refresh_stations(rules)


func refresh_stations(rules: SupplyRules) -> void:
	if id != 0:
		return
	if rules.has_station(SupplyRules.Station.BENCH) and not is_instance_valid(bench):
		bench = _site(RelaySite.Role.BENCH, "bench", "工作台", Vector3(-2.4, 1.03, -11.2))
		_table(bench.position - Vector3.UP * 0.98, Color("#79533a"))
		bench.mark("工作台", Vector3(0, 0.38, 0))
	if rules.has_station(SupplyRules.Station.FURNACE) and not is_instance_valid(furnace):
		furnace = _site(RelaySite.Role.FURNACE, "furnace", "熔炉", Vector3(2.7, 1.0, -10.4))
		var base := furnace.position - Vector3.UP * 0.94
		_block(base + Vector3.UP * 0.47, Vector3(1.18, 0.94, 0.89), STEEL, true)
		_block(base + Vector3(0, 0.80, -0.03), Vector3(1.30, 0.17, 0.99), CONCRETE)
		_block(base + Vector3(0.31, 1.22, -0.25), Vector3(0.29, 0.78, 0.29), RUST)
		_block(base + Vector3(0, 0.42, 0.46), Vector3(0.64, 0.38, 0.04), Color("#c66232"), false, 0.62)
		furnace.position.y += 0.20
		furnace.mark("熔炉", Vector3(0, 0.39, 0))


func deposits() -> Array:
	return DEPOSITS[id]


func nests() -> Array:
	return NESTS[id]


func surface(flat: Vector2) -> Vector3:
	if id == 0 or id == 2:
		return Vector3(flat.x, 0, flat.y)
	var origin := (flat / 2.4).floor() * 2.4
	var fraction := (flat - origin) / 2.4
	var b := _height(origin.x + 2.4, origin.y)
	var c := _height(origin.x, origin.y + 2.4)
	var y: float
	if fraction.x + fraction.y <= 1.0:
		y = _height(origin.x, origin.y) * (1.0 - fraction.x - fraction.y) + b*fraction.x + c*fraction.y
	else:
		var d := _height(origin.x + 2.4, origin.y + 2.4)
		y = d * (fraction.x + fraction.y - 1.0) + b*(1.0 - fraction.y) + c*(1.0 - fraction.x)
	return Vector3(flat.x, y, flat.y)


func _height(x: float, z: float) -> float:
	var shoulder := smoothstep(5, 26, absf(x))
	if id == 1:
		return shoulder * (2.1 + 1.4 * sin(z * 0.14 + x * 0.12) + 1.1 * cos(x * 0.18))
	if id == 3:
		return shoulder * (-0.36 + 1.45 * sin(z * 0.17 - x * 0.13)) + smoothstep(23, 41, absf(z)) * 0.45
	return 0.0


func _soil(x: float, z: float, index: int) -> Color:
	var trail := absf(x) < 4.2
	if id == 2:
		return Color("#383d40") if trail else Color("#62645f").lightened(0.04 * (index % 4))
	if id == 1:
		return (Color("#938063") if trail else Color("#676a52")).lightened(0.018 * (index % 6))
	return (Color("#9e8664") if trail else Color("#81765f")).lightened(0.021 * (index % 5))


func _terrain() -> void:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ix in range(-16, 16):
		for iz in range(-19, 19):
			var x := ix * 2.4
			var z := iz * 2.4
			var a := Vector3(x, _height(x, z), z)
			var b := Vector3(x + 2.4, _height(x + 2.4, z), z)
			var c := Vector3(x, _height(x, z + 2.4), z + 2.4)
			var d := Vector3(x + 2.4, _height(x + 2.4, z + 2.4), z + 2.4)
			var tint := _soil(x + 1.2, z, absi(ix*7 + iz*13))
			for vertex in [a, b, c, b, d, c]:
				surface_tool.set_color(tint)
				surface_tool.set_smooth_group(-1)
				surface_tool.add_vertex(vertex)
	surface_tool.generate_normals()
	var land := surface_tool.commit()
	var paint := RelayGeometry.finish(Color.WHITE)
	paint.vertex_color_use_as_albedo = true
	var terrain := RelayGeometry.mesh(ground, land, Vector3.ZERO, paint)
	RelayGeometry.body(terrain, land.create_trimesh_shape())


func _sky() -> void:
	var sky_paint := ProceduralSkyMaterial.new()
	sky_paint.sky_top_color = Color("#4c6871") if id == 2 else Color("#547b83")
	sky_paint.sky_horizon_color = Color("#b2b3a1")
	sky_paint.ground_horizon_color = Color("#aaa68d")
	sky_paint.ground_bottom_color = Color("#484b44")
	var sky := Sky.new()
	sky.sky_material = sky_paint
	var weather := Environment.new()
	weather.background_mode = Environment.BG_SKY
	weather.sky = sky
	weather.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	weather.fog_enabled = true
	var ambient := WorldEnvironment.new()
	ambient.name = "WorldEnvironment"
	ambient.environment = weather
	ground.add_child(ambient)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-41, -36, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 74.0
	ground.add_child(sun)
	lighting = RelayLighting.new()
	ground.add_child(lighting)


func _border() -> void:
	for side in [-1, 1]:
		_block(Vector3(side*37,1.5,0), Vector3(0.45,6.7,88), FENCE, true)
		_block(Vector3(0,1.5,side*43), Vector3(74,6.7,0.45), FENCE, true)
		for z in range(-40, 41, 7):
			_block(Vector3(side*36.7,1.5,z), Vector3(0.38,6.9,0.34), STEEL)
		for x in range(-35, 36, 7):
			_block(Vector3(x,1.5,side*42.7), Vector3(0.31,6.9,0.34), STEEL)


func _station() -> void:
	var radio := _site(RelaySite.Role.STORY, "station_radio", "通讯台", Vector3(-3.15,1.05,-15.55))
	radio.mark("通讯台", Vector3(0, 0.72, 0))
	var crate := _site(RelaySite.Role.CRATE, "station_supplies", "气象站补给箱", Vector3(2.65,1.23,-14.15))
	crate.contents = {SupplyRules.Kind.WOOD: 2, SupplyRules.Kind.CAN: 2, SupplyRules.Kind.STONE: 2}
	crate.mark("气象站补给箱", Vector3(0, 0.23, 0))


func _quarry() -> void:
	var work := _building(Vector2(-1,2), Vector2(8,7), 3.1, Color("#78715c"), "采石场工棚")
	_terminal(work + Vector3(-1.8,0,-1.65), "quarry_log", "交接簿")
	_crate(work + Vector3(2.1,0,-1.65), "quarry_crate", "工棚补给箱",
		{SupplyRules.Kind.WOOD: 5, SupplyRules.Kind.CAN: 2, SupplyRules.Kind.STONE: 4})
	_block(Vector3(5,0.66,6), Vector3(2.6,1.32,2.8), RUST, true)
	for side in [-1,1]:
		for i in range(8):
			var x: float = side * (26 + (i%3)*2.8)
			var z := float(-34 + i*9)
			_rock(surface(Vector2(x,z)), Vector3(2.9,1.4+0.52*(i%3),3.2), Color("#625f53"))
		for i in range(6):
			var x: float = side * (22 + 4*(i%2))
			var z := float(-26 + i*12)
			_pine(surface(Vector2(x,z)), 2.8 + (i%3)*0.55)


func _city() -> void:
	for side in [-1,1]:
		_block(Vector3(side*5.1,0.071,1), Vector3(2.2,0.14,79), Color("#777b73"), true)
		for z in range(-26, 34, 12):
			_block(Vector3(side*4.05,0.018,z), Vector3(0.16,0.036,5.0), Color("#b6a67f"))
	for z in range(-26, 34, 7):
		_block(Vector3(0,0.013,z), Vector3(0.16,0.02,2.2), Color("#b3a88c"))
	var clinic := _building(Vector2(-14,-8), Vector2(11,8), 4.0, Color("#848b7c"), "社区诊所", true)
	var dispatch := _building(Vector2(14,1), Vector2(12,10), 4.7, Color("#8b6e5f"), "旧城调度站", true)
	var depot := _building(Vector2(-12,15), Vector2(10,8), 3.6, Color("#77786b"), "物资库")
	_terminal(dispatch + Vector3(-2.4,0,-2), "city_dispatch", "调度录音")
	_crate(dispatch + Vector3(2.8,0,-2.1), "dispatch_crate", "调度站补给箱",
		{SupplyRules.Kind.WOOD: 4, SupplyRules.Kind.CAN: 2, SupplyRules.Kind.STONE: 3})
	_crate(clinic + Vector3(1.9,0,-2.1), "clinic_crate", "诊所补给箱",
		{SupplyRules.Kind.CAN: 5, SupplyRules.Kind.WOOD: 2})
	_crate(depot + Vector3(-1.8,0,-1.7), "depot_crate", "库房补给箱",
		{SupplyRules.Kind.CAN: 2, SupplyRules.Kind.WOOD: 6, SupplyRules.Kind.STONE: 5})
	for side in [-1,1]:
		for index in range(4):
			_tower(Vector2(side*(26 + 2*(index%2)), -25 + index*18), index + 2)
	for p in [Vector2(-2,-11), Vector2(2,7), Vector2(-2.5,21)]:
		_wreck(p)


func _basin() -> void:
	var shelter_at := _building(Vector2(1,22), Vector2(8,8), 3.1, Color("#706c58"), "应急中继棚")
	_terminal(shelter_at + Vector3(-1.8,0,-1.7), "basin_relay", "应急中继")
	_crate(shelter_at + Vector3(2.0,0,-1.65), "relay_crate", "中继棚补给箱",
		{SupplyRules.Kind.CAN: 3, SupplyRules.Kind.WOOD: 4})
	for side in [-1,1]:
		for i in range(9):
			var at := surface(Vector2(side*(24+(i%3)*3), -34+i*8))
			_rock(at, Vector3(3.8,1.1 + (i%4)*0.50,3.7), Color("#77644c"))
	for side in [-1,1]:
		var point := surface(Vector2(side*5,25))
		_block(point + Vector3.UP*3.7, Vector3(0.18,7.4,0.18), RUST, true)
		for i in range(4):
			_block(point + Vector3.UP*(5.0+i*0.52), Vector3(1.9-i*0.36,0.11,0.15), STEEL)
		_block(point + Vector3.UP*7.36, Vector3(0.21,0.16,0.22), Color("#fd915d"), false, 1.0)


func _building(flat: Vector2, size: Vector2, h: float, tint: Color, title: String, upper := false) -> Vector3:
	var at := surface(flat)
	var w := size.x
	var d := size.y
	_block(at + Vector3(0,-0.086,0), Vector3(w+0.3,0.17,d+0.32), CONCRETE, true)
	_block(at + Vector3(0,h/2,-d/2), Vector3(w,h,0.32), tint, true)
	for side in [-1,1]:
		_block(at + Vector3(side*w/2,h/2,0), Vector3(0.34,h,d), tint, true)
		_block(at + Vector3(side*(w/4+0.66),h/2,d/2), Vector3(w/2-1.3,h,0.36), tint, true)
		_block(at + Vector3(side*1.31,1.09,d/2+0.22), Vector3(0.18,2.18,0.21), RUST)
		for i in range(3):
			var x: float = side*(w/2-0.58-i*0.43)
			_block(at + Vector3(x,1.81,d/2+0.22), Vector3(0.33,0.91,0.10), STEEL)
			_block(at + Vector3(x,1.35,d/2+0.28), Vector3(0.40,0.10,0.14), CONCRETE)
		if id == 2:
			for z in [-d*0.33, 0.0, d*0.33]:
				_recess(at + Vector3(side*(w/2 + 0.20), 2.12, z), true)
			_block(at + Vector3(side*(w/2+0.20), 0.32, 0), Vector3(0.14, 0.45, d+0.05), tint.darkened(0.27))
		_block(at + Vector3(side*(w/2-1.05),0.38,d/2+0.24), Vector3(1.20,0.45,0.10), CONCRETE.darkened(0.20))
	_block(at + Vector3(0,(h+2.16)/2,d/2), Vector3(2.6,h-2.16,0.37), tint, true)
	_block(at + Vector3(0,h+0.10,0), Vector3(w+0.56,0.24,d+0.63), STEEL, true)
	_block(at + Vector3(0,2.18,d/2+0.25), Vector3(2.82,0.16,0.24), RUST)
	RelayGeometry.label(ground, title, at + Vector3(0, h-0.31, d/2+0.45))
	if id == 2:
		for x in [-w*0.34, 0.0, w*0.34]:
			_recess(at + Vector3(x, 2.1, -d/2-0.20), false, -1)
		_block(at + Vector3(0, h-0.22, -d/2-0.22), Vector3(w+0.25,0.19,0.19), tint.darkened(0.27))
	if upper:
		var top := at + Vector3(0, h+1.5, -0.53)
		_block(top, Vector3(w*0.87,3.0,d*0.84), tint.darkened(0.14))
		for i in range(-3,4):
			_block(top + Vector3(i*w/9,0.10,d*0.43), Vector3(0.53,1.04,0.09), STEEL)
			_block(top + Vector3(i*w/9,0.10,-d*0.43), Vector3(0.53,1.04,0.09), STEEL)
		_block(top + Vector3.UP*1.49, Vector3(w*0.92,0.23,d*0.89), CONCRETE)
	return at


func _recess(at: Vector3, side_wall: bool, depth_sign := 1) -> void:
	var depth := Vector3.RIGHT * signf(at.x) if side_wall else Vector3.BACK * depth_sign
	var sill_size := Vector3(0.20, 0.12, 1.16) if side_wall else Vector3(1.16, 0.12, 0.20)
	var well_size := Vector3(0.13, 1.12, 0.96) if side_wall else Vector3(0.96, 1.12, 0.13)
	var sash_size := Vector3(0.06, 1.01, 0.047) if side_wall else Vector3(0.047, 1.01, 0.06)
	_block(at, well_size, STEEL)
	_block(at + depth*0.11 - Vector3.UP*0.52, sill_size, CONCRETE)
	_block(at + depth*0.09, sash_size, RUST)
	var slat := Vector3(0.11,0.12,1.17) if side_wall else Vector3(1.17,0.12,0.11)
	var plank := _block(at + depth*0.14 + Vector3.UP*0.13, slat, Color("#8c735b"))
	if side_wall:
		plank.rotation.x = 0.27
	else:
		plank.rotation.z = -0.27


func _tower(flat: Vector2, floors: int) -> void:
	var at := surface(flat)
	var height := 2.6*floors
	_block(at + Vector3.UP*height/2, Vector3(8,height,8), CONCRETE.darkened(0.15), true)
	for floor in range(floors):
		var y := floor*2.6
		_block(at + Vector3(0,y+0.19,4.03), Vector3(8.1,0.18,0.16), STEEL)
		for column in range(-2, 3):
			var color := STEEL if (floor+column)%3 == 0 else Color("#596063")
			_block(at + Vector3(column*1.36,y+1.25,4.04), Vector3(0.91,1.24,0.08), color)
	_block(at + Vector3.UP*height, Vector3(8.3,0.30,8.3), RUST)


func _wreck(flat: Vector2) -> void:
	var at := surface(flat)
	_block(at + Vector3.UP*0.42, Vector3(1.63,0.66,3.0), RUST, true)
	_block(at + Vector3(0,0.87,-0.19), Vector3(1.32,0.38,1.40), STEEL)
	for side in [-1,1]:
		for front in [-1,1]:
			_block(at + Vector3(side*0.77,0.19,front*0.87), Vector3(0.33,0.42,0.55), STEEL)
		_block(at + Vector3(side*0.56,0.43,1.51), Vector3(0.27,0.19,0.05), Color("#bba47f"))


func _rock(at: Vector3, scale_to: Vector3, tint: Color) -> void:
	var stone := SphereMesh.new()
	stone.radial_segments = 6
	stone.rings = 3
	var visual := RelayGeometry.mesh(ground, stone, at + Vector3.UP*0.23, _paint(tint))
	visual.scale = scale_to
	RelayGeometry.body(visual, stone.create_convex_shape())


func _pine(at: Vector3, height: float) -> void:
	_block(at + Vector3.UP*0.95, Vector3(0.24,1.9,0.24), Color("#695641"), true)
	for i in range(3):
		var tier := CylinderMesh.new()
		tier.top_radius = 0.04
		tier.bottom_radius = 1.25 - i*0.25
		tier.height = height*0.52
		tier.radial_segments = 7
		RelayGeometry.mesh(ground, tier, at + Vector3.UP*(1.42+i*height*0.29), _paint(Color("#525d45").lightened(i*0.045)))


func _portal(flat: Vector2) -> void:
	var at := surface(flat)
	portal = _site(RelaySite.Role.PORTAL, "portal", "中继传送门", at + Vector3.UP*0.9)
	portal.mark("中继传送门  [F]", Vector3(0,2.22,0), LIGHT)
	_block(at + Vector3.UP*0.06, Vector3(3.2,0.12,2.2), STEEL)
	for side in [-1,1]:
		_block(at + Vector3(side*1.18,1.25,0), Vector3(0.31,2.5,0.77), STEEL, true)
		_block(at + Vector3(side*1.0,1.19,0.40), Vector3(0.08,2.07,0.08), LIGHT, false, 1.0)
	_block(at + Vector3.UP*2.45, Vector3(2.72,0.23,0.75), RUST, true)
	_block(at + Vector3(0,2.43,0.39), Vector3(1.73,0.08,0.06), LIGHT, false, 1.0)
	arrival = surface(flat + Vector2(0,1.54)) + Vector3.UP*0.26


func _terminal(at: Vector3, key: String, title: String) -> void:
	var terminal := _site(RelaySite.Role.STORY, key, title, at + Vector3.UP*1.04)
	terminal.mark(title, Vector3(0,0.56,0))
	_table(at, RUST)
	_block(at + Vector3.UP*1.09, Vector3(0.92,0.34,0.52), STEEL)
	_block(at + Vector3(0.17,1.12,0.27), Vector3(0.36,0.17,0.022), LIGHT, false, 0.74)


func _table(at: Vector3, tint: Color) -> void:
	_block(at + Vector3.UP*0.83, Vector3(1.46,0.17,0.79), tint, true)
	for side in [-1,1]:
		_block(at + Vector3(side*0.57,0.40,0), Vector3(0.18,0.80,0.62), STEEL, true)


func _crate(at: Vector3, key: String, title: String, contents: Dictionary) -> void:
	var crate := _site(RelaySite.Role.CRATE, key, title, at + Vector3.UP*0.91)
	crate.contents = contents
	crate.mark(title, Vector3(0,0.43,0))
	var model := CRATE.instantiate() as Node3D
	model.position = at
	ground.add_child(model)
	_block(at + Vector3.UP*0.40, Vector3(1.73,0.80,0.97), Color("#3e4034"), true).hide()


func _site(role: int, key: String, title: String, at: Vector3) -> RelaySite:
	var site := RelaySite.new()
	site.role = role
	site.key = key
	site.title = title
	site.position = at
	add_child(site)
	sites.append(site)
	return site


func _paint(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		_materials[color] = RelayGeometry.finish(color)
	return _materials[color]


func _block(at: Vector3, size: Vector3, color: Color, solid := false, glow := 0.0) -> MeshInstance3D:
	var material := _paint(color) if glow <= 0.0 else RelayGeometry.finish(color, glow)
	return RelayGeometry.box(ground, at, size, material, solid)
