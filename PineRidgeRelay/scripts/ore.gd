class_name MineableOre
extends Node3D

const YIELD := 3

var hardness := 3
@onready var label: Label3D = $Nameplate
@onready var visual: Node3D = $Model


func strike(power: int) -> bool:
	hardness = maxi(0, hardness - power)
	label.text = "石矿 %d" % hardness
	var strength := 1.0 if hardness == 2 else 0.82
	visual.scale = Vector3(strength, strength, strength)
	return hardness == 0
