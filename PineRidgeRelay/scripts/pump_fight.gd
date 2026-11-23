class_name PumpFight
extends RefCounted

enum Outcome { ACTIVE, WON, LOST }

const BOSS_HEALTH := 720
const SPARE_ROUNDS := 240
const OVERLOAD_SECONDS := 6.0
const PULSE_RADIUS := 3.65
const PULSE_WARNING := 1.45
const PULSE_RESET := 7.7

var gun := RelayMagazine.new()
var reserve := SupplyRules.new()
var vitals := SurvivalRules.new()
var boss: RelayInfected
var outcome := Outcome.ACTIVE
var exposed_for := 0.0
var warning_for := 0.0
var _pulse_in := 3.0
var _pulse_point := Vector3.ZERO
var _marker: Node3D
var _pulse_material: StandardMaterial3D
var _pulse_core: StandardMaterial3D
var _flash_for := 0.0
var _player: RelayPlayer
var _raid: NightRaid


func _init(region: SurvivalRegion, player: RelayPlayer, raid: NightRaid) -> void:
	_player = player
	_raid = raid
	gun.damage = 8
	gun.rounds = gun.capacity
	reserve.add({SupplyRules.Kind.AMMO: SPARE_ROUNDS})
	boss = NightRaid.INFECTED_SCENE.instantiate()
	boss.pump_guard = true
	boss.elite_scale = 1.58
	boss.nest = -1
	boss.travel_speed = 2.45
	boss.health = BOSS_HEALTH
	boss.position = Vector3(0, 0.06, 12.6)
	boss.home = boss.position
	boss.rotation.y = PI
	region.infected.add_child(boss)
	raid.active.append(boss)
	raid.enemy_felled.connect(_defeated)
	_marker = Node3D.new()
	region.add_child(_marker)
	_build_warning()
	_marker.hide()


func boss_health() -> int:
	return maxi(0, boss.health) if is_instance_valid(boss) else 0


func pressured() -> bool:
	return boss_health() <= BOSS_HEALTH / 2


func shot_damage() -> int:
	return gun.damage * 2 if exposed_for > 0 else gun.damage


func vent(control: RelaySite) -> bool:
	if control.used or exposed_for > 0 or outcome != Outcome.ACTIVE:
		return false
	control.used = true
	control.sign.text = "已泄压"
	control.sign.modulate = Color("#9ca6a0")
	exposed_for = OVERLOAD_SECONDS
	boss.model.stagger()
	return true


func tick(delta: float) -> void:
	if outcome != Outcome.ACTIVE:
		return
	vitals.advance_hit_grace(delta)
	gun.tick(delta, reserve)
	_step_pulse(delta)
	if outcome != Outcome.ACTIVE:
		return
	if exposed_for > 0:
		exposed_for = maxf(exposed_for - delta, 0.0)
		boss.model.animate(delta, 0.0, false, 0.0, 0.0)
		return
	boss.last_seen_player = _player.global_position
	boss.travel_speed = 3.18 if pressured() else 2.45
	if boss.pursue(delta, _raid.has_clear_strike(boss)):
		_hurt(32 if pressured() else 24)


func _step_pulse(delta: float) -> void:
	if _flash_for > 0:
		_flash_for -= delta
		if _flash_for <= 0:
			_marker.hide()
	if warning_for > 0:
		warning_for = maxf(0.0, warning_for - delta)
		_pulse_core.albedo_color.a = 0.14 + 0.21 * (1.0 - warning_for / PULSE_WARNING)
		if warning_for == 0:
			var offset := _player.global_position - _pulse_point
			_pulse_material.albedo_color = Color("#fff2b3")
			_pulse_core.albedo_color = Color(1.0, 0.70, 0.35, 0.50)
			_flash_for = 0.22
			if Vector2(offset.x, offset.z).length() < PULSE_RADIUS:
				_hurt(42)
	elif pressured() and exposed_for == 0:
		_pulse_in -= delta
		if _pulse_in <= 0:
			_pulse_in = PULSE_RESET
			warning_for = PULSE_WARNING
			_pulse_point = Vector3(_player.global_position.x, 0.036, _player.global_position.z)
			_marker.position = _pulse_point
			_pulse_material.albedo_color = Color("#f38445")
			_marker.show()


func _build_warning() -> void:
	_pulse_material = RelayGeometry.finish(Color("#f38445"), 0.8)
	var ring := TorusMesh.new()
	ring.outer_radius = PULSE_RADIUS
	ring.inner_radius = PULSE_RADIUS - 0.14
	ring.rings = 32
	ring.ring_segments = 6
	RelayGeometry.mesh(_marker, ring, Vector3.ZERO, _pulse_material)
	_pulse_core = RelayGeometry.finish(Color(1, 0.26, 0.12, 0.18))
	_pulse_core.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pulse_core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var disk := CylinderMesh.new()
	disk.radial_segments = 32
	disk.top_radius = PULSE_RADIUS - 0.05
	disk.bottom_radius = disk.top_radius
	disk.height = 0.015
	RelayGeometry.mesh(_marker, disk, Vector3.DOWN * 0.008, _pulse_core)


func _hurt(points: int) -> void:
	vitals.damage_player(points)
	if vitals.player_health == 0:
		outcome = Outcome.LOST


func _defeated(enemy: RelayInfected) -> void:
	if enemy == boss and outcome == Outcome.ACTIVE:
		outcome = Outcome.WON
		warning_for = 0.0
		_marker.hide()


func dispose() -> void:
	_raid.enemy_felled.disconnect(_defeated)
