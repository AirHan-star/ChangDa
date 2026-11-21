class_name NightRaid
extends RefCounted

const INFECTED_SCENE := preload("res://scenes/infected.tscn")
const MAX_ACTIVE := 4
const MAX_TOTAL := 10
const SPAWN_INTERVAL := 3.8
const HIT_DAMAGE := 3
const LANES: Array[float] = [-0.82, 0.0, 0.82]
const SWORD_RANGE := 2.55
const SWORD_CONE := 0.30

var spawned := 0
var active: Array[RelayInfected] = []
var _spawn_in := 0.0
var _parent: Node3D
var _gate: StationGate


func _init(parent: Node3D, gate: StationGate) -> void:
	_parent = parent
	_gate = gate


func tick(delta: float, survival: SurvivalRules) -> void:
	_spawn_in = maxf(0.0, _spawn_in - delta)
	if _spawn_in == 0.0 and spawned < MAX_TOTAL and active.size() < MAX_ACTIVE:
		_spawn()
		_spawn_in = SPAWN_INTERVAL

	var stop_z := _gate.global_position.z + 0.78
	var previous: Dictionary = {}
	for infected in active:
		var ahead: RelayInfected = previous.get(infected.lane)
		var goal := stop_z if ahead == null else ahead.global_position.z + 1.15
		if infected.advance(delta, goal, ahead == null):
			survival.damage_gate(HIT_DAMAGE)
			if survival.is_over():
				return
		previous[infected.lane] = infected


func strike(origin: Vector3, facing: Vector3, player_rid: RID) -> bool:
	var target: RelayInfected
	var best_distance := SWORD_RANGE * SWORD_RANGE
	var space := _parent.get_world_3d().direct_space_state
	for infected in active:
		var body := infected.global_position + Vector3.UP * 0.92
		var offset := body - origin
		var horizontal := Vector3(offset.x, 0.0, offset.z)
		var distance := offset.length_squared()
		if distance > best_distance or horizontal.normalized().dot(facing) < SWORD_CONE:
			continue
		var ray := PhysicsRayQueryParameters3D.create(origin, body, 1, [player_rid])
		if not space.intersect_ray(ray).is_empty():
			continue
		best_distance = distance
		target = infected
	if target == null:
		return false
	if target.take_sword_hit():
		active.erase(target)
		target.queue_free()
	return true


func _spawn() -> void:
	var counts := [0, 0, 0]
	for infected in active:
		counts[infected.lane] += 1
	var lane := counts.find(counts.min())
	var infected := INFECTED_SCENE.instantiate() as RelayInfected
	infected.lane = lane
	var distance := 18.0 + (spawned % 3) * 1.15
	for other in active:
		if other.lane == lane:
			distance = maxf(distance, other.global_position.z - _gate.global_position.z + 1.4)
	var destination := Vector3(_gate.global_position.x + LANES[lane], 0.06,
		_gate.global_position.z + distance)
	infected.position = _parent.to_local(destination)
	infected.rotation.y = PI
	_parent.add_child(infected)
	active.append(infected)
	spawned += 1
