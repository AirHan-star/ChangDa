class_name RelaySave
extends RefCounted

const SLOT := "user://long-survival.save"
const BACKUP := "user://long-survival.backup"
const TEMP := "user://long-survival.pending"


static func load_game() -> Dictionary:
	for path in [SLOT, BACKUP]:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var value: Variant = file.get_var()
		if value is Dictionary and value.get("version") == 1:
			return value
	return {}


static func store(data: Dictionary) -> bool:
	var file := FileAccess.open(TEMP, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(data)
	var written := file.get_error() == OK
	file.close()
	if not written:
		return false
	var slot_path := ProjectSettings.globalize_path(SLOT)
	var backup_path := ProjectSettings.globalize_path(BACKUP)
	if FileAccess.file_exists(SLOT):
		if DirAccess.rename_absolute(slot_path, backup_path) != OK:
			return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP), slot_path) == OK:
		return true
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(backup_path, slot_path)
	return false
