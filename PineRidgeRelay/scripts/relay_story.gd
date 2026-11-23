class_name RelayStory
extends RefCounted

const ROAD_MAP := 4
const FINALE_MAP := 5
const FINALE_BOSS := "回压工长"
const RELAY_REPAIR := 3
const FINALE_READY := 4
const MAP_NAMES := ["松岭气象站", "灰脊采石场", "沉钟旧城", "黄烟盆地", "断线公路", "北压泵房"]
const STEPS := [
	["第一章 · 停在凌晨的电报", "在气象站里找接收员沈苇", "npc_shen",
		"沈苇给了你灰脊采石场的坐标。夜班机修工梁砾在工棚等消息。采石场传送已开放。"],
	["第二章 · 灰脊最后一班", "到采石场工棚找梁砾", "npc_liang",
		"梁砾把撤离名单交给了你。去沉钟旧城的调度站路口找许岑。旧城传送已开放。"],
	["第三章 · 没有列车的车站", "去旧城调度站附近的路口找许岑", "npc_xu",
		"许岑指出了被隔断的广播线路。黄烟盆地的池照还在守中继，带一份生铁去见她。盆地传送已开放。"],
	["第四章 · 请报告你的位置", "带一份生铁到盆地中继棚找池照", "npc_chi",
		"池照修好了中继，但泵房的报警信号占住了频段。再次和池照对话，就能从检修线进入北压泵房。"],
	["终章 · 让松岭回话", "与池照对话进入北压泵房，击败回压工长", "npc_chi",
		"泵房报警停了。沈苇在公共频段逐个呼叫撤离名单上的人，收到八个回应。松岭中继继续值守。"],
]
const FINISHED := "余讯已发 · 继续生存"
const LINES := [
	["凌晨三点，撤离广播突然静了。我还是照着名单点了一遍名，只有灰脊回了两个短音。",
		"拿上这组坐标。工棚里有个叫梁砾的机修工。如果他还守着交接簿，就问他最后一班车往哪开。"],
	["别扶我，腿已经包扎好了，让我在箱子上靠一会儿。最后三辆车给了医院，司机都在这页签过字。",
		"去旧城调度站外的路口。许岑穿有反光条的外套。告诉他，灰脊的人还在等回信。"],
	["我看到车过了路口。后来调度站的闸门都锁上了，扬声器一遍遍报着原地待命。",
		"盆地的池照还守着备用线路。她说中继缺一份生铁做触点，灰脊有铁矿，气象站的熔炉能炼。"],
	["你把手松开，我来装触点。好，调度名单传过来了……等等，公共频段全是北压泵房的报警。",
		"老工长一直背着那套稳压器。感染后它还挂在他身上。压住泵房，外面的人才能听见信号。"],
	["检修线还能走。我把一把卡宾枪和弹药留在入口，只够这趟用。进屋后留意两侧泄压阀，它们能让稳压器短暂停机。",
		"听到泄压警报就离开脚下的警戒区。准备好了吗？你点头，我就接通检修线。"],
]
const WAITING := [
	"我继续守频。你在外面听见呼叫，就记下对方的位置。",
	"交接簿给你了。我守着这里，万一还有司机折回来。",
	"我在路口给车队留了一个灯。天黑以后，从建筑边上绕过去。",
	"沈苇已经在公共频段呼叫了。听，那边有人在问松岭的路。",
]
const NOTES := {
	"station_radio": "凌晨三点的值班纸上画了两道短线，旁边写着灰脊。",
	"quarry_log": "最后三辆车的登记栏写着医院优先。下半页还有几个签名。",
	"city_dispatch": "调度录音截在一句原地待命，之后只剩下继电器的响声。",
	"basin_relay": "公共频段和北压泵房的报警线路并在同一组继电器上。",
}
var stage := 0


func unlocked(map_id: int) -> bool:
	return map_id >= 0 and map_id < ROAD_MAP and map_id <= stage


func objective() -> String:
	return STEPS[stage][1] if stage < STEPS.size() else "中继保持在线 · 可自由往返与采集"


func current_target() -> String:
	return STEPS[stage][2] if stage < STEPS.size() else ""


func advance(target: String, rules: SupplyRules) -> bool:
	if stage >= FINALE_READY or target != current_target():
		return false
	if stage == RELAY_REPAIR and not rules.pay({SupplyRules.Kind.IRON: 1}):
		return false
	stage += 1
	return true


func complete_finale() -> void:
	if stage == FINALE_READY:
		stage += 1
