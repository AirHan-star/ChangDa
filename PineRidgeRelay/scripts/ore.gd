class_name MineableOre
extends StaticBody3D

const YIELD := 3

var hardness := 3
@onready var label: Label3D = $Nameplate


func strike(power: int) -> bool:
	hardness = maxi(0, hardness - power)
	label.text = "石矿 %d" % hardness
	# Keep the boulder and its fitted hulls aligned when only partially mined.
	return hardness == 0
