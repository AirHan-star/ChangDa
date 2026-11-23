class_name SupplyPickup
extends Node3D

@export var supply_id: StringName
@export var kind: SupplyRules.Kind = SupplyRules.Kind.WOOD

@onready var marker := get_node_or_null("Marker") as Node3D
@onready var marker_height: float = marker.position.y if marker != null else 0.0

var _time := 0.0


func _process(delta: float) -> void:
	if marker == null:
		return
	_time += delta
	marker.position.y = marker_height + sin(_time * 2.0) * 0.11
	marker.rotate_y(delta * 0.7)
