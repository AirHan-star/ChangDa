class_name MineableOre
extends StaticBody3D

const MINERALS := {
	SupplyRules.Kind.STONE: ["石矿", Color("#a2d9e7"), 3, 1, 3],
	SupplyRules.Kind.IRON_ORE: ["铁矿", Color("#db8770"), 6, 3, 4],
	SupplyRules.Kind.SULFUR: ["硫磺", Color("#e7cd64"), 5, 3, 4],
}

@export var kind := SupplyRules.Kind.STONE
var hardness: int
@onready var label: Label3D = $Nameplate


func _ready() -> void:
	var description: Array = MINERALS[kind]
	hardness = description[2]
	label.modulate = description[1]
	_update_label()
	if kind != SupplyRules.Kind.STONE:
		var tint := RelayGeometry.finish(description[1])
		for visual in $Model.find_children("*", "MeshInstance3D", true, false):
			for surface in range(visual.mesh.get_surface_count()):
				var original: Material = visual.mesh.surface_get_material(surface)
				if original != null and "ore" in original.resource_name.to_lower():
					visual.set_surface_override_material(surface, tint)


func mineral_name() -> String:
	return MINERALS[kind][0]


func required_power() -> int:
	return MINERALS[kind][3]


func yield_count() -> int:
	return MINERALS[kind][4]


func strike(power: int) -> bool:
	hardness = maxi(0, hardness - power)
	_update_label()
	return hardness == 0


func _update_label() -> void:
	label.text = "%s  %d" % [mineral_name(), hardness]
