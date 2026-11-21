class_name SupplyPickup
extends Node3D

@export var supply_id: StringName
@export var kind: SupplyRules.Kind = SupplyRules.Kind.WOOD

@onready var marker: Node3D = $Marker
@onready var marker_height: float = marker.position.y

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	marker.position.y = marker_height + sin(_time * 2.0) * 0.11
	marker.rotate_y(delta * 0.7)
