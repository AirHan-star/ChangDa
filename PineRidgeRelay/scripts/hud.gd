class_name RelayHUD
extends CanvasLayer

signal recover_requested

const ACCENT := Color("#efbf75")
const MINT := Color("#a6e0b8")
const NIGHT_BLUE := Color("#a6c9fa")
const WARNING := Color("#f39282")
const CRITICAL_HEALTH := 25
const FLASH_DURATION := 0.62

@onready var mission: Label = $Screen/Brief/Mission
@onready var route: Label = $Screen/Brief/Route
@onready var prompt_panel: PanelContainer = $Screen/Prompt
@onready var prompt_label: Label = $Screen/Prompt/Text
@onready var phase_label: Label = $Screen/Survival/Content/Phase
@onready var region_label: Label = $Screen/Survival/Content/Region
@onready var player_health_label: Label = $Screen/PlayerVitals/Content/HealthLabel
@onready var player_health_bar: ProgressBar = $Screen/PlayerVitals/Content/HealthBar
@onready var raid_label: Label = $Screen/Survival/Content/Raid
@onready var gear: GearPanels = $Screen/Gear
@onready var aim: Label = $Screen/Aim
@onready var hurt_edges: ColorRect = $Screen/HurtEdges
@onready var _hurt_material: ShaderMaterial = hurt_edges.material
@onready var toast: Label = $Screen/Toast
@onready var result: ColorRect = $Screen/Result
@onready var result_title: Label = $Screen/Result/Card/Content/Title
@onready var result_detail: Label = $Screen/Result/Card/Content/Detail

var _toast_time := 0.0
var _flash_time := 0.0
var _critical_target := 0.0
var _critical_amount := 0.0
var _xp_bar := ProgressBar.new()
@onready var _controls: Label = $Screen/Controls
@onready var _original_controls := _controls.text


func _ready() -> void:
	$Screen/Result/Card/Content/Restart.pressed.connect(func(): recover_requested.emit())
	_xp_bar.custom_minimum_size.y = 5
	_xp_bar.show_percentage = false
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_bar.hide()
	$Screen/Survival/Content.add_child(_xp_bar)


func _process(delta: float) -> void:
	_update_hurt_edges(delta)
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			toast.hide()


func _update_hurt_edges(delta: float) -> void:
	if not hurt_edges.visible and _critical_target == 0.0 and _flash_time == 0.0:
		return
	_flash_time = maxf(0.0, _flash_time - delta)
	_critical_amount = move_toward(_critical_amount, _critical_target, 3.0 * delta)
	_hurt_material.set_shader_parameter(&"flash", smoothstep(0.0, FLASH_DURATION, _flash_time))
	_hurt_material.set_shader_parameter(&"critical", _critical_amount)
	hurt_edges.visible = _flash_time > 0.0 or _critical_amount > 0.0


func flash_damage() -> void:
	_flash_time = FLASH_DURATION
	_hurt_material.set_shader_parameter(&"flash", 1.0)
	hurt_edges.show()


func show_story(story: RelayStory) -> void:
	mission.text = RelayStory.STEPS[story.stage][0] if story.stage < RelayStory.STEPS.size() else RelayStory.FINISHED
	route.text = story.objective()


func show_player_health(points: int) -> void:
	_critical_target = 1.0 if points <= CRITICAL_HEALTH else 0.0
	player_health_label.text = "生命 %d / %d" % [points, SurvivalRules.PLAYER_MAX_HEALTH]
	player_health_bar.value = points
	player_health_bar.modulate = MINT if points > 55 else (ACCENT if points > CRITICAL_HEALTH else WARNING)


func show_survival(state: SurvivalRules, map_id: int, active: int, chasing: int) -> void:
	var second := ceili(state.remaining)
	var is_day := state.phase == SurvivalRules.Phase.DAY
	var phase_text := "白天" if is_day else "夜晚"
	phase_label.text = "第 %d 天  ·  %s  %02d:%02d" % [state.day, phase_text, floori(second / 60.0), second % 60]
	phase_label.modulate = ACCENT if is_day else NIGHT_BLUE
	region_label.text = RelayStory.MAP_NAMES[map_id]
	if is_day:
		raid_label.text = "夜间留意感染者"
	elif chasing > 0:
		raid_label.text = "感染者 %d  ·  %d 正在追你" % [active, chasing]
	else:
		raid_label.text = "感染者 %d  ·  在附近徘徊" % active
	raid_label.modulate = WARNING if chasing > 0 else Color.WHITE


func show_road(run: RoadRun) -> void:
	mission.text = "断线公路 · 肉鸽挑战"
	route.text = "走到掩体间拉开距离，完成 30 波"
	phase_label.text = "波次 %02d / %d" % [run.wave,RoadRun.WAVE_LIMIT]
	phase_label.modulate = ACCENT
	region_label.text = "等级 %d  ·  经验 %d / %d" % [run.level,run.experience,run.experience_needed()]
	raid_label.text = "剩余感染者 %d  ·  击杀 %d" % [run.remaining(),run.kills]
	if run.wave < RoadRun.WAVE_LIMIT:
		raid_label.text += "\n下一波 %.1f 秒" % maxf(0.0,run.next_wave_in)
	for boss in run.bosses:
		raid_label.text += "\n第 %d 波头目  %d / %d" % [boss.road_wave,boss.health,run.brute_health(boss.road_wave)]
	raid_label.modulate = WARNING if not run.bosses.is_empty() else Color.WHITE
	if run.surge_left > 0:
		raid_label.text += "\n热换弹 %.1f 秒" % run.surge_left
	_xp_bar.max_value = run.experience_needed()
	_xp_bar.value = run.experience


func finale_controls() -> void:
	_controls.text = "左键连发  ·  右键瞄准  ·  R 换弹\nE 操作泄压阀  ·  Esc 撤离"


func show_finale(fight: PumpFight) -> void:
	mission.text = RelayStory.STEPS[RelayStory.FINALE_READY][0]
	route.text = "击败回压工长，恢复公共频段"
	phase_label.text = "北压泵房"
	phase_label.modulate = ACCENT
	region_label.text = "%s  %d / %d" % [RelayStory.FINALE_BOSS, fight.boss_health(), PumpFight.BOSS_HEALTH]
	if fight.warning_for > 0.0:
		raid_label.text = "泄压冲击 · 快离开警戒区"
	elif fight.exposed_for > 0.0:
		raid_label.text = "稳压器停机 · %.1f 秒双倍伤害" % fight.exposed_for
	else:
		raid_label.text = "稳压器过载 · 当心脚下" if fight.pressured() else "两侧各有一个泄压阀"
	raid_label.modulate = WARNING if fight.warning_for > 0.0 else MINT
	_xp_bar.max_value = PumpFight.BOSS_HEALTH
	_xp_bar.value = fight.boss_health()


func road_mode(enabled: bool) -> void:
	_xp_bar.visible = enabled
	_controls.text = "按住左键连发  ·  右键瞄准  ·  R 换弹\nEsc 打开退出菜单" if enabled else _original_controls
	gear.road_mode(enabled)


func set_prompt(message: String) -> void:
	prompt_panel.visible = not message.is_empty()
	prompt_label.text = message


func notify(message: String, seconds := 2.2) -> void:
	toast.text = message
	toast.show()
	_toast_time = seconds


func show_recovery() -> void:
	set_prompt("")
	toast.hide()
	result_title.text = "你倒下了"
	result_title.add_theme_color_override(&"font_color", WARNING)
	result_detail.text = "保留背包和主线进度，于次日清晨醒来"
	result.show()
	$Screen/Result/Card/Content/Restart.grab_focus()
