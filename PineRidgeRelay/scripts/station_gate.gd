class_name StationGate
extends StaticBody3D

@onready var shutter: Node3D = $Shutter
@onready var barrier: CollisionShape3D = $Collision


func set_upgrades(count: int) -> void:
	for i in range(count):
		shutter.get_node("Brace%d" % (i + 1)).show()
		$StatusLamps.get_node("Lamp%d" % (i + 1)).show()


func close_gate() -> void:
	barrier.set_deferred(&"disabled", false)
	create_tween().tween_property(shutter, "scale:y", 1.0, 0.36)


func break_gate() -> void:
	barrier.set_deferred(&"disabled", true)
	create_tween().tween_property(shutter, "rotation_degrees:z", -22.0, 0.4)
	create_tween().tween_property(shutter, "position:y", 0.58, 0.4)
