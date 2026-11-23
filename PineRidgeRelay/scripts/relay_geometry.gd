class_name RelayGeometry
extends RefCounted


static func finish(color: Color, glow := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	if glow > 0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material


static func box(parent: Node3D, at: Vector3, size: Vector3, material: Material, solid := false) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var visual := mesh(parent, shape, at, material)
	if solid:
		var hull := BoxShape3D.new()
		hull.size = size
		body(visual, hull)
	return visual


static func mesh(parent: Node3D, shape: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = shape
	visual.material_override = material
	visual.position = at
	parent.add_child(visual)
	return visual


static func body(parent: Node3D, hull: Shape3D) -> void:
	var solid := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = hull
	solid.add_child(collision)
	parent.add_child(solid)


static func label(parent: Node3D, line: String, at: Vector3, tint := Color("#ddcc9e")) -> Label3D:
	var sign := Label3D.new()
	sign.position = at
	sign.text = line
	sign.font = preload("res://assets/relay_ui.otf")
	sign.font_size = 46
	sign.pixel_size = 0.0085
	sign.outline_size = 9
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = tint
	sign.no_depth_test = false
	parent.add_child(sign)
	return sign
