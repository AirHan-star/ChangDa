class_name RelaySite
extends Marker3D

enum Role { PORTAL, STORY, CRATE, BENCH, FURNACE }
var role: int
var key: String
var title: String
var contents: Dictionary
var sign: Label3D


func mark(label_text: String, offset: Vector3, tint := Color("#eab572")) -> void:
	sign = RelayGeometry.label(self, label_text, offset, tint)


func mark_looted() -> void:
	if is_instance_valid(sign):
		sign.text = title + " · 已搜空"
