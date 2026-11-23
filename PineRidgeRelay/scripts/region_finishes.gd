class_name RegionFinishes
extends RefCounted

const TEXTURES := {
	"brick": preload("res://assets/regions/brick.png"),
	"concrete": preload("res://assets/regions/cast.png"),
	"plaster": preload("res://assets/regions/plaster.png"),
	"iron": preload("res://assets/regions/iron.png"),
	"roof": preload("res://assets/regions/roof.png"),
	"floor": preload("res://assets/regions/slab.png"),
	"wood": preload("res://assets/regions/wood_old.png"),
}
var _cache: Dictionary = {}


func paint(surface: String, tint := Color.WHITE) -> StandardMaterial3D:
	var id := "%s:%s" % [surface, tint.to_html()]
	if not _cache.has(id):
		var finish := RelayGeometry.finish(tint)
		if TEXTURES.has(surface):
			finish.albedo_texture = TEXTURES[surface]
			finish.uv1_triplanar = true
			finish.uv1_world_triplanar = true
			finish.uv1_scale = Vector3.ONE * (0.62 if surface == "floor" else 0.86)
			finish.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_cache[id] = finish
	return _cache[id]


func box(parent: Node3D, at: Vector3, size: Vector3, surface: String, tint: Color, collision := false) -> MeshInstance3D:
	return RelayGeometry.box(parent, at, size, paint(surface, tint), collision)
