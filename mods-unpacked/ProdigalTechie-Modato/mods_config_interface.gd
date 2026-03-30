extends Node


signal setting_changed(setting_name, value, mod_name)

const LOG_NAME = "ProdigalTechie-Modato:ModsConfigInterface"

var mod_configs := {}

func _ready():
	# Load this mod's manifest config_defaults as the settings source
	var dir = ModLoaderMod.get_unpacked_dir() + "ProdigalTechie-Modato/"
	var manifest_path = dir + "manifest.json"
	var manifest = {}
	var f = File.new()
	if f.file_exists(manifest_path):
		var err = f.open(manifest_path, File.READ)
		if err == OK:
			var data = f.get_as_text()
			manifest = JSON.parse(data).result if data.length() > 0 else {}
		f.close()

	var defaults: Dictionary = {}
	if manifest.has("extra") and manifest.extra.has("godot") and manifest.extra.godot.has("config_defaults"):
		defaults = manifest.extra.godot.config_defaults

	# Store settings under this mod's dir name to mimic dami-ModOptions API
	mod_configs["ProdigalTechie-Modato"] = defaults


func get_settings(mod_name: String) -> Dictionary:
	if mod_configs.has(mod_name):
		return mod_configs[mod_name]
	return {}


func on_setting_changed(setting_name: String, value, mod_name: String) -> void:
	if not mod_configs.has(mod_name):
		mod_configs[mod_name] = {}
	mod_configs[mod_name][setting_name] = value
	emit_signal("setting_changed", setting_name, value, mod_name)
