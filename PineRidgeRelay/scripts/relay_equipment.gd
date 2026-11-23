class_name RelayEquipment
extends RefCounted

const IRON_PICK := preload("res://assets/world/stone_pick.glb")


static func iron_pick() -> Node3D:
	var model := IRON_PICK.instantiate() as Node3D
	var material := RelayGeometry.finish(Color("#a0b5ba"))
	material.metallic = 0.62
	for visual in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(visual.mesh.get_surface_count()):
			if visual.mesh.surface_get_material(surface).resource_name.begins_with("slate"):
				visual.set_surface_override_material(surface, material)
	return model


static func axe() -> Node3D:
	var node := Node3D.new()
	var wood := RelayGeometry.finish(Color("#8b664a"))
	var binding := RelayGeometry.finish(Color("#414e47"))
	var iron := RelayGeometry.finish(Color("#819196"))
	iron.metallic = 0.48
	RelayGeometry.box(node, Vector3(0,-0.23,0), Vector3(0.052,0.77,0.046), wood)
	RelayGeometry.box(node, Vector3(0,0.005,0), Vector3(0.062,0.19,0.057), binding)
	RelayGeometry.box(node, Vector3(0,-0.57,-0.041), Vector3(0.11,0.13,0.18), iron)
	var wedge := PrismMesh.new()
	wedge.size = Vector3(0.23,0.28,0.082)
	var edge := RelayGeometry.mesh(node, wedge, Vector3(0,-0.57,-0.17), iron)
	edge.rotation.z = PI * 0.50
	return node


static func carbine() -> Node3D:
	var node := Node3D.new()
	var wood := RelayGeometry.finish(Color("#856249"))
	var steel := RelayGeometry.finish(Color("#353f42"))
	steel.metallic = 0.52
	var grip := RelayGeometry.finish(Color("#4e554e"))
	RelayGeometry.box(node, Vector3(0,-0.22,0), Vector3(0.088,0.49,0.115), steel)
	RelayGeometry.box(node, Vector3(0,0.035,-0.035), Vector3(0.066,0.15,0.075), grip)
	RelayGeometry.box(node, Vector3(0,0.22,0.014), Vector3(0.080,0.22,0.15), wood)
	RelayGeometry.box(node, Vector3(0,0.34,0.043), Vector3(0.089,0.042,0.20), grip)
	RelayGeometry.box(node, Vector3(0,-0.21,-0.070), Vector3(0.076,0.18,0.10), wood)
	RelayGeometry.box(node, Vector3(0,-0.065,0.072), Vector3(0.061,0.112,0.09), grip)
	RelayGeometry.box(node, Vector3(0,-0.49,0.016), Vector3(0.044,0.29,0.048), steel)
	RelayGeometry.box(node, Vector3(0,-0.552,-0.032), Vector3(0.022,0.04,0.035), steel)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0,-0.65,0.016)
	node.add_child(muzzle)
	return node
