class_name SurvivalRegion
extends Node3D

const CLEARING := preload("res://scenes/clearing.tscn")
const STATION_FITTINGS := preload("res://assets/world/station_fittings.glb")
const CRATE := preload("res://assets/world/supply_crate.glb")
const DISTRICT_GROUND := preload("res://assets/regions/ground.gdshader")
const FENCE := Color("#74796d")
const TERRACES := {
	1: [Vector4(-1,2,5.0,4.5), Vector4(7.8,-13,4.4,4.0), Vector4(-8.4,15.2,4.3,4.0)],
	3: [Vector4(1,22,5.2,5.1), Vector4(8.6,-20,4.4,4.1), Vector4(-8.1,7.4,4.3,4.0)],
}
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
	[[-20,-27,0],[18,-13,0],[-17,4,0],[15,17,0],[-20,28,0],
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
var buildings: Array[RegionalBuilding] = []
var _finishes := RegionFinishes.new()
var _materials: Dictionary = {}
var _crate_seed := 0
var _opened: Dictionary


func build(map_id: int, opened: Dictionary, rules: SupplyRules, crate_seed := 0) -> void:
	id = map_id
	_crate_seed = crate_seed
	_opened = opened
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
	elif id == RelayStory.ROAD_MAP:
		ground = Node3D.new()
		add_child(ground)
		_sky()
		lighting.update_light(SurvivalRules.Phase.DAY, 12.0)
		lighting.environment.fog_density = 0.006
		RoadLandscape.new(ground, _finishes)
		_portal(Vector2(0,-44))
		shelter = arrival
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
		RegionLandscape.new(ground, surface, _finishes).decorate(id)
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
	return [] if id == RelayStory.ROAD_MAP else DEPOSITS[id]


func nests() -> Array:
	return [] if id == RelayStory.ROAD_MAP else NESTS[id]


func surface(flat: Vector2) -> Vector3:
	if id == 0 or id == 2 or id == RelayStory.ROAD_MAP:
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
	var elevation := 0.0
	if id == 1:
		elevation = shoulder * (2.1 + 1.4*sin(z*0.14+x*0.12) + 1.1*cos(x*0.18))
	elif id == 3:
		elevation = shoulder * (-0.36+1.45*sin(z*0.17-x*0.13)) + smoothstep(23,41,absf(z))*0.45
	for pad in TERRACES.get(id, []):
		var margin := maxf(absf(x-pad.x)-pad.z,absf(z-pad.y)-pad.w)
		elevation *= smoothstep(0.35,2.75,margin)
	return elevation


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
			for vertex in [a, b, c, b, d, c]:
				surface_tool.set_smooth_group(-1)
				surface_tool.add_vertex(vertex)
	surface_tool.generate_normals()
	var land := surface_tool.commit()
	var paint := ShaderMaterial.new()
	paint.shader = DISTRICT_GROUND
	paint.set_shader_parameter(&"district",id)
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
	for side in [-1.0,1.0]:
		_finishes.box(ground,Vector3(side*37,1.5,0),Vector3(0.45,7.4,88),"iron",FENCE,true)
		_finishes.box(ground,Vector3(0,1.5,side*43),Vector3(74,7.4,0.45),"iron",FENCE,true)
		for z in range(-40,41,4):
			_finishes.box(ground,Vector3(side*36.72,1.5,z),Vector3(0.21,7.50,0.18),"iron",STEEL)
		for x in range(-35,36,4):
			_finishes.box(ground,Vector3(x,1.5,side*42.72),Vector3(0.18,7.50,0.21),"iron",STEEL)


func _station() -> void:
	var radio := _site(RelaySite.Role.STORY, "station_radio", "通讯台", Vector3(-3.15,1.05,-15.55))
	radio.mark("通讯台", Vector3(0, 0.72, 0))
	var crate := _site(RelaySite.Role.CRATE, "station_supplies", "气象站补给箱", Vector3(2.65,1.23,-14.15))
	crate.contents = {SupplyRules.Kind.WOOD: 2, SupplyRules.Kind.CAN: 2, SupplyRules.Kind.STONE: 2}
	crate.mark("气象站补给箱", Vector3(0, 0.23, 0))


func _quarry() -> void:
	var work := _structure("quarry", "采石场工棚", Vector2(-1,2), Vector2(8.0,7.0),
		RegionalBuilding.Style.SERVICE, Color("#c7b998"), true)
	_terminal(work.to_global(Vector3(-1.8,0,-1.65)), "quarry_log", "交接簿")
	_stock(work, "quarry_crate", "工棚木箱", {SupplyRules.Kind.WOOD: 5, SupplyRules.Kind.CAN: 2, SupplyRules.Kind.STONE: 4})
	var weigh := _structure("weigh", "地磅值班室", Vector2(7.8,-13), Vector2(6.7,5.8),
		RegionalBuilding.Style.DISPATCH, Color("#b4b8a2"), true)
	_stock(weigh, "weigh_crate", "值班室木箱", {SupplyRules.Kind.WOOD: 2, SupplyRules.Kind.CAN: 1})
	var repair := _structure("quarry_repair", "机修间", Vector2(-8.4,15.2), Vector2(6.9,5.9),
		RegionalBuilding.Style.SERVICE, Color("#bda48a"), true)
	_stock(repair, "quarry_repair_crate", "机修间木箱", {SupplyRules.Kind.WOOD: 2, SupplyRules.Kind.STONE: 3})


func _city() -> void:
	var clinic := _structure("clinic", "社区诊所", Vector2(-14,-8), Vector2(10.5,8.9),
		RegionalBuilding.Style.CLINIC, Color("#b5c0aa"), false)
	_stock(clinic, "clinic_crate", "诊所木箱", {SupplyRules.Kind.CAN: 5, SupplyRules.Kind.WOOD: 2})
	var dispatch := _structure("dispatch", "旧城调度站", Vector2(14,1), Vector2(11.5,10.0),
		RegionalBuilding.Style.DISPATCH, Color("#cba892"), false, 2)
	_terminal(dispatch.to_global(Vector3(-2.4,0,-2)), "city_dispatch", "调度录音")
	_stock(dispatch, "dispatch_crate", "调度站木箱", {SupplyRules.Kind.WOOD: 4, SupplyRules.Kind.CAN: 2, SupplyRules.Kind.STONE: 3})
	var depot := _structure("depot", "物资库", Vector2(-12,15), Vector2(9.0,8.0),
		RegionalBuilding.Style.STORE, Color("#b4a98e"), false)
	_stock(depot, "depot_crate", "库房木箱", {SupplyRules.Kind.CAN: 2, SupplyRules.Kind.WOOD: 6, SupplyRules.Kind.STONE: 5})
	var store := _structure("store", "街口杂货铺", Vector2(13,-20), Vector2(8.5,7.6),
		RegionalBuilding.Style.STORE, Color("#c5b594"), false)
	_stock(store, "store_crate", "杂货铺木箱", {SupplyRules.Kind.CAN: 2, SupplyRules.Kind.WOOD: 1})
	var home := _structure("old_home", "旧住址", Vector2(-13,-24.7), Vector2(8.6,8.1),
		RegionalBuilding.Style.STORE, Color("#b2b5a5"), false, 2)
	_stock(home, "home_crate", "住户木箱", {SupplyRules.Kind.CAN: 1, SupplyRules.Kind.WOOD: 2})
	var post := _structure("post", "邮务所", Vector2(13,25), Vector2(9.0,8.1),
		RegionalBuilding.Style.DISPATCH, Color("#b3ada4"), false, 2)
	_stock(post, "post_crate", "邮务所木箱", {SupplyRules.Kind.WOOD: 2, SupplyRules.Kind.STONE: 2})
	var workshop := _structure("city_repair", "维修铺", Vector2(-13,31), Vector2(8.6,7.1),
		RegionalBuilding.Style.SERVICE, Color("#c4a08c"), true)
	_stock(workshop, "city_repair_crate", "维修铺木箱", {SupplyRules.Kind.WOOD: 2, SupplyRules.Kind.STONE: 2})


func _basin() -> void:
	var shelter_at := _structure("relay", "应急中继棚", Vector2(1,22), Vector2(8.0,8.0),
		RegionalBuilding.Style.RELAY, Color("#a1b1a0"), false)
	_terminal(shelter_at.to_global(Vector3(-1.8,0,-1.7)), "basin_relay", "应急中继")
	_stock(shelter_at, "relay_crate", "中继棚木箱", {SupplyRules.Kind.CAN: 3, SupplyRules.Kind.WOOD: 4})
	var valve := _structure("valve", "阀门值房", Vector2(8.6,-20), Vector2(6.8,6.1),
		RegionalBuilding.Style.SERVICE, Color("#b8a687"), true)
	_stock(valve, "valve_crate", "值房木箱", {SupplyRules.Kind.CAN: 2, SupplyRules.Kind.STONE: 2})
	var sampling := _structure("sampling", "采样室", Vector2(-8.1,7.4), Vector2(6.5,6.0),
		RegionalBuilding.Style.CLINIC, Color("#bcc0ab"), true)
	_stock(sampling, "sampling_crate", "采样室木箱", {SupplyRules.Kind.WOOD: 2, SupplyRules.Kind.CAN: 1})
	for side in [-1,1]:
		var point := surface(Vector2(side*5.3,25))
		_finishes.box(ground,point+Vector3.UP*3.7,Vector3(0.18,7.4,0.18),"iron",RUST,true)
		for i in range(4):
			_finishes.box(ground,point+Vector3.UP*(5.0+i*0.52),Vector3(1.9-i*0.36,0.11,0.15),"iron",STEEL)
		_block(point+Vector3.UP*7.36,Vector3(0.21,0.16,0.22),Color("#fd915d"),false,1.0)


func _structure(code: String, title: String, flat: Vector2, dimensions: Vector2, use: int,
		tint: Color, roof_pitch: bool, floors := 1) -> RegionalBuilding:
	var room := RegionalBuilding.new()
	room.name = code
	room.position = surface(flat)
	ground.add_child(room)
	room.construct(code,title,dimensions,floors,use,tint,roof_pitch,_finishes)
	buildings.append(room)
	return room


func _stock(room: RegionalBuilding, key: String, wood_label: String, contents: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _crate_seed ^ hash(room.code)
	var iron := rng.randi_range(0,1) == 1
	var dims := room.footprint
	var position := Vector3(dims.x * 0.26,0,-dims.y * 0.235)
	if room.floors == 2:
		position.x = minf(position.x,dims.x/2-2.64)
		if iron:
			position = Vector3(0,RegionalBuilding.STOREY,-dims.y*0.23)
	if _opened.has(room.code+"_iron_case"):
		_opened[key] = true
	room.crates.append(_crate(room.to_global(position),key,"铁制补给箱" if iron else wood_label,contents,iron))


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
	var terminal := _site(RelaySite.Role.STORY,key,title,at+Vector3.UP*1.17)
	terminal.mark(title,Vector3(0,0.51,0))
	if key == "quarry_log":
		_table(at,RUST)
		var ledger := _finishes.box(ground,at+Vector3(0.19,0.947,0.11),Vector3(0.44,0.054,0.33),
			"wood",Color("#8d765c"))
		ledger.rotation.y = -0.30
		for face in [-1.0,1.0]:
			_finishes.box(ledger,Vector3(face*0.105,0.031,0),Vector3(0.203,0.014,0.26),"floor",Color("#d4c69c"))
		_finishes.box(ground,at+Vector3(-0.54,0.99,-0.24),Vector3(0.23,0.157,0.31),"iron",STEEL)
		return
	var kit := STATION_FITTINGS.instantiate()
	var radio := kit.get_node("LoggingDeskAndRadio") as MeshInstance3D
	var stand := RelayGeometry.mesh(ground,radio.mesh,at+Vector3(2.448,0,2.52),null)
	stand.scale = Vector3(0.72,1.0,0.72)
	kit.free()
	_finishes.box(ground,at+Vector3.UP*0.867,Vector3(1.63,0.12,0.56),"wood",STEEL,true).hide()
	if key == "basin_relay":
		_finishes.box(ground,at+Vector3(-0.84,1.36,-0.25),Vector3(0.37,0.91,0.36),"iron",RUST)
		for i in range(6):
			_finishes.box(ground,at+Vector3(-0.84,1.14+i*0.065,-0.063),Vector3(0.219,0.025,0.021),"iron",STEEL)


func _table(at: Vector3, tint: Color) -> void:
	_block(at + Vector3.UP*0.83, Vector3(1.46,0.17,0.79), tint, true)
	for side in [-1,1]:
		_block(at + Vector3(side*0.57,0.40,0), Vector3(0.18,0.80,0.62), STEEL, true)


func _crate(at: Vector3, key: String, title: String, contents: Dictionary, iron: bool) -> RelaySite:
	var crate := _site(RelaySite.Role.CRATE,key,title,at+Vector3.UP*0.94)
	crate.contents = contents
	crate.mark(title,Vector3(0,0.30,0),Color("#b8d5cc") if iron else Color("#eab572"))
	if iron:
		var model := CRATE.instantiate() as Node3D
		model.position = at
		model.scale = Vector3.ONE*0.75
		ground.add_child(model)
		_block(at+Vector3.UP*0.35,Vector3(1.45,0.70,0.83),Color("#3e4034"),true).hide()
	else:
		_wood_crate(at, crate)
	return crate


func _wood_crate(at: Vector3, crate: RelaySite) -> void:
	var oak := Color("#b29974")
	var assembly := Node3D.new()
	assembly.position = at
	ground.add_child(assembly)
	_finishes.box(assembly,Vector3(0,0.058,0),Vector3(1.15,0.115,0.67),"wood",oak.darkened(0.18),true)
	for front in [-1.0,1.0]:
		for board in range(3):
			_finishes.box(assembly,Vector3(0,0.155+board*0.133,front*0.304),Vector3(1.15,0.126,0.058),
				"wood",oak.darkened((board%2)*0.09))
	for side in [-1.0,1.0]:
		_finishes.box(assembly,Vector3(side*0.552,0.288,0),Vector3(0.063,0.432,0.62),"wood",oak)
		for front in [-1.0,1.0]:
			_finishes.box(assembly,Vector3(side*0.481,0.288,front*0.343),Vector3(0.092,0.438,0.055),"wood",oak.darkened(0.19))
	_finishes.box(assembly,Vector3(0,0.261,0),Vector3(1.1,0.495,0.61),"wood",oak,true).hide()
	var lid := Node3D.new()
	lid.position = Vector3(0,0.52,-0.34)
	assembly.add_child(lid)
	for i in range(4):
		_finishes.box(lid,Vector3(0,0.013,0.093+i*0.17),Vector3(1.19,0.060,0.166),"wood",oak.lightened((i%2)*0.08))
	_finishes.box(lid,Vector3(0,-0.04,0.694),Vector3(0.17,0.137,0.038),"iron",STEEL)
	crate.lid = lid


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
