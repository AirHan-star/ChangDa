class_name RelayStory
extends RefCounted

const ROAD_MAP := 4
const MAP_NAMES := ["松岭气象站", "灰脊采石场", "沉钟旧城", "黄烟盆地", "断线公路"]
const STEPS := [
	["第一章 · 停在凌晨的电报", "在气象站内调查通讯台", "station_radio",
		"撤离广播在凌晨三点断了。通讯台里还留着一条工单：灰脊采石场有通往旧城的中继坐标。采石场传送已开放。"],
	["第二章 · 灰脊最后一班", "到灰脊采石场的工棚查看交接簿", "quarry_log",
		"工人把最后几辆撤离车让给了医院。交接簿夹着旧城调度站的通行坐标。旧城传送已开放。"],
	["第三章 · 没有列车的车站", "在沉钟旧城的调度站调查录音", "city_dispatch",
		"录音里有人反复读着同一张名单。黄烟盆地的应急中继还在待机，所需的备件里缺了一份生铁。盆地传送已开放。"],
	["第四章 · 请报告你的位置", "带一份生铁到黄烟盆地修复应急中继", "basin_relay",
		"中继重新发出广播：这里是松岭，听见请回话。静默过后，有人报出了一个陌生的地名。主线完成，可以继续生存。"],
]
const FINISHED := "余讯已发 · 继续生存"
var stage := 0


func unlocked(map_id: int) -> bool:
	return map_id >= 0 and map_id < ROAD_MAP and map_id <= stage


func objective() -> String:
	return STEPS[stage][1] if stage < STEPS.size() else "中继保持在线 · 可自由往返与采集"


func advance(target: String, rules: SupplyRules) -> String:
	if stage >= STEPS.size() or target != STEPS[stage][2]:
		return "这里的线索已记录"
	if stage == 3 and not rules.pay({SupplyRules.Kind.IRON: 1}):
		return "修复中继需要一份生铁。铁矿可在灰脊找到，回气象站熔炼。"
	var message: String = STEPS[stage][3]
	stage += 1
	return message
