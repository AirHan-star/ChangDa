class_name RelayLighting
extends Node3D

@onready var sun: DirectionalLight3D = $"../Sun"
@onready var environment: Environment = $"../WorldEnvironment".environment

var _night_mix := -1.0


func update_light(phase: SurvivalRules.Phase, left: float) -> void:
	var shade := 1.0
	if phase == SurvivalRules.Phase.DAY:
		shade = 1.0 - smoothstep(0.0, 20.0, left)
	if is_equal_approx(shade, _night_mix):
		return
	_night_mix = shade
	sun.light_energy = lerpf(1.22, 0.46, shade)
	sun.light_color = Color("#ffe0b5").lerp(Color("#839ad7"), shade)
	environment.ambient_light_energy = lerpf(0.65, 0.48, shade)
	environment.ambient_light_color = Color("#bdd6d1").lerp(Color("#7f95c0"), shade)
	environment.fog_light_color = Color("#96ada3").lerp(Color("#25344d"), shade)
	environment.fog_density = lerpf(0.012, 0.017, shade)
	environment.background_energy_multiplier = lerpf(1.0, 0.23, shade)
