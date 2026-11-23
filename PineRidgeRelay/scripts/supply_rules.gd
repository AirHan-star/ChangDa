class_name SupplyRules
extends RefCounted

signal changed

enum Kind { WOOD, CAN, STONE, IRON_ORE, SULFUR, IRON, POWDER, AMMO }
enum Tool { WOOD_PICK, STONE_PICK, STONE_SWORD, IRON_PICK, IRON_AXE, CARBINE }
enum Station { HAND, BENCH, FURNACE }
enum Recipe { WOOD_PICK, STONE_PICK, STONE_SWORD, BENCH, FURNACE, IRON, POWDER, IRON_PICK, IRON_AXE, CARBINE, AMMO }

const ITEMS := ["木料", "罐头", "石材", "铁矿", "硫磺", "生铁", "火药", "弹药"]
const TOOLS := ["木镐", "石镐", "石剑", "铁镐", "铁斧", "信号卡宾枪"]
const STATIONS := ["随身", "工作台", "熔炉"]
# Each entry contains its name, workstation, costs, and either an item stack, a tool, or a structure.
const RECIPES := [
	["木镐", Station.HAND, {Kind.WOOD: 2}, {}, Tool.WOOD_PICK],
	["石镐", Station.HAND, {Kind.WOOD: 2, Kind.STONE: 2}, {}, Tool.STONE_PICK],
	["石剑", Station.HAND, {Kind.WOOD: 1, Kind.STONE: 2}, {}, Tool.STONE_SWORD],
	["工作台", Station.HAND, {Kind.WOOD: 4}, {}, -1, Station.BENCH],
	["熔炉", Station.BENCH, {Kind.WOOD: 2, Kind.STONE: 6}, {}, -1, Station.FURNACE],
	["生铁", Station.FURNACE, {Kind.IRON_ORE: 2, Kind.WOOD: 1}, {Kind.IRON: 1}, -1],
	["火药", Station.FURNACE, {Kind.SULFUR: 2}, {Kind.POWDER: 1}, -1],
	["铁镐", Station.BENCH, {Kind.IRON: 2, Kind.WOOD: 1}, {}, Tool.IRON_PICK],
	["铁斧", Station.BENCH, {Kind.IRON: 2, Kind.WOOD: 1}, {}, Tool.IRON_AXE],
	["信号卡宾枪", Station.BENCH, {Kind.IRON: 3, Kind.WOOD: 2}, {}, Tool.CARBINE],
	["弹药", Station.BENCH, {Kind.POWDER: 1, Kind.IRON: 1}, {Kind.AMMO: 6}, -1],
]

var inventory: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
var tools: Array[int] = []
var stations: Array[int] = []


func carried(kind: int) -> int:
	return inventory[kind]


func has_tool(tool: int) -> bool:
	return tools.has(tool)


func has_station(station: int) -> bool:
	return station == Station.HAND or stations.has(station)


func mining_power(tool: int) -> int:
	if not has_tool(tool):
		return 0
	match tool:
		Tool.WOOD_PICK: return 1
		Tool.STONE_PICK: return 3
		Tool.IRON_PICK: return 5
	return 0


func best_pick() -> int:
	for tool in [Tool.IRON_PICK, Tool.STONE_PICK, Tool.WOOD_PICK]:
		if has_tool(tool):
			return tool
	return -1


func can_pay(costs: Dictionary) -> bool:
	for kind in costs:
		if carried(kind) < costs[kind]:
			return false
	return true


func pay(costs: Dictionary) -> bool:
	if not can_pay(costs):
		return false
	for kind in costs:
		inventory[kind] -= costs[kind]
	changed.emit()
	return true


func add(stack: Dictionary) -> void:
	for kind in stack:
		inventory[kind] += stack[kind]
	changed.emit()


func consume_ration() -> bool:
	return pay({Kind.CAN: 1})


func recipe_owned(id: int) -> bool:
	var recipe: Array = RECIPES[id]
	return has_tool(recipe[4]) or (recipe.size() > 5 and has_station(recipe[5]))


func craft(id: int, station: int) -> bool:
	if id < 0 or id >= RECIPES.size():
		return false
	var recipe: Array = RECIPES[id]
	if recipe[1] != station or not has_station(station) or recipe_owned(id) or not can_pay(recipe[2]):
		return false
	for kind in recipe[2]:
		inventory[kind] -= recipe[2][kind]
	for kind in recipe[3]:
		inventory[kind] += recipe[3][kind]
	if recipe[4] >= 0:
		tools.append(recipe[4])
	if recipe.size() > 5:
		stations.append(recipe[5])
	changed.emit()
	return true


func restore(data: Dictionary) -> void:
	var items: Array = data.get("items", [])
	for i in range(mini(inventory.size(), items.size())):
		inventory[i] = clampi(int(items[i]), 0, 100000)
	tools.clear()
	for id in data.get("tools", []):
		if int(id) >= 0 and int(id) < TOOLS.size() and not tools.has(int(id)):
			tools.append(int(id))
	stations.clear()
	for id in data.get("stations", []):
		if int(id) in [Station.BENCH, Station.FURNACE] and not stations.has(int(id)):
			stations.append(int(id))
