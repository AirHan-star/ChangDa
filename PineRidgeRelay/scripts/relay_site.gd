class_name RelaySite
extends Marker3D

enum Role { PORTAL, STORY, CRATE, BENCH, FURNACE }
var role: int
var key: String
var title: String
var contents: Dictionary
var sign: Label3D
var lid: Node3D
var refill_seconds := 0


func mark(label_text: String, offset: Vector3, tint := Color("#eab572")) -> void:
	sign = RelayGeometry.label(self, label_text, offset, tint)


func update_refill(seconds: int) -> void:
	if refill_seconds == seconds:
		return
	refill_seconds = seconds
	if is_instance_valid(sign):
		sign.text = cooldown_text() if seconds > 0 else title
	if is_instance_valid(lid):
		lid.rotation.x = -1.15 if seconds > 0 else 0.0


func cooldown_text() -> String:
	return "%s · 补货 %02d:%02d" % [title,floori(refill_seconds/60.0),refill_seconds%60]
