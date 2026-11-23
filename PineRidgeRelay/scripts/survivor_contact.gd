class_name SurvivorContact
extends RefCounted
## Holds each stance foot in world space and samples the floor under the sole.

const MAX_CORRECTION := 0.17

var _latched := false
var _anchor := Vector3.ZERO
var _blend := 0.0
var _lift := 0.0
var _normal := Vector3.UP
var floor_angles := Vector2.ZERO


func reset() -> void:
	_latched = false
	_blend = 0.0
	_lift = 0.0
	_normal = Vector3.UP
	floor_angles = Vector2.ZERO


func place(body: Transform3D, nominal: Vector3, planted: bool, on_ground: bool,
		delta: float, space: PhysicsDirectSpaceState3D) -> Vector3:
	if not on_ground:
		_latched = false
		_blend = 0.0
		_lift = move_toward(_lift, 0.0, delta * 2.2)
		floor_angles = floor_angles.move_toward(Vector2.ZERO, delta * 4.2)
		return nominal + Vector3.UP * _lift

	var target := body * nominal
	if planted and not _latched:
		_anchor = target
	_latched = planted
	var weight := 1.0 if planted else 0.0
	_blend = move_toward(_blend, weight, delta * (24.0 if planted else 14.0))
	var offset := _anchor - target
	offset.y = 0.0
	target += offset.limit_length(MAX_CORRECTION) * _blend

	var base := Vector3(target.x, body.origin.y, target.z)
	var ray := PhysicsRayQueryParameters3D.create(base + Vector3.UP * 0.23, base - Vector3.UP * 0.25, 9)
	var floor_hit := space.intersect_ray(ray)
	var lift := 0.0
	var surface := Vector3.UP
	if not floor_hit.is_empty() and floor_hit.normal.y > 0.78:
		lift = clampf(floor_hit.position.y - base.y, -MAX_CORRECTION, MAX_CORRECTION)
		surface = floor_hit.normal
	_lift = move_toward(_lift, lift, delta * 1.95)
	_normal = _normal.lerp(surface, minf(delta * 20.0, 1.0)).normalized()
	var local_normal := body.basis.inverse() * _normal
	floor_angles = Vector2(atan2(local_normal.z, local_normal.y), atan2(-local_normal.x, local_normal.y))
	var result := body.affine_inverse() * target
	result.y = nominal.y + _lift
	return result
