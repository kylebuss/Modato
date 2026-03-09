extends "res://mods-unpacked/ProdigalTechie-Modato/extensions/ui/menus/run/character_selection.gd"

onready var _character_panel: ItemPanelUI = get_node_or_null("MarginContainer/VBoxContainer/DescriptionContainer/CharacterPanel")
onready var _stats: GridContainer = get_node_or_null("MarginContainer/VBoxContainer/DescriptionContainer/GridContainer")
onready var _continue: Button = get_node_or_null("MarginContainer/VBoxContainer/Button")
onready var _back: Button = get_node_or_null("%BackButton")

var player_index = 0

func _ready() -> void:
	if is_instance_valid(_character_panel):
		_character_panel.set_data(RunData.players_data[player_index].current_character, player_index)
		_character_panel.visible = not RunData.is_coop_run
	if is_instance_valid(_run_options_panel):
		_run_options_panel.hide()
	if is_instance_valid(_inventories):
		_inventories.hide()
	
	#add customizeable stats
	for effect in RunData.players_data[player_index].current_character.effects:
		var new_stat_label = Label.new()

		# build label text safely
		if effect.key and effect.key is String:
			if effect.key.to_lower().begins_with("effect_increase") or effect.key.to_lower().begins_with("effect_reduce"):
				new_stat_label.text = tr(effect.key.to_lower()).format({"0": tr(effect.stat_displayed.to_upper())}).trim_prefix("% ")
			elif effect.key.begins_with("stat"):
				new_stat_label.text = tr("stat").format({"0": tr(effect.key.to_upper())})
			elif effect.key == "items_price":
				new_stat_label.text = tr("items_price")
			elif effect.key.begins_with("item"):
				new_stat_label.text = tr("item").format({"0": tr(effect.key.to_upper())})
			elif effect.key == "next_level_xp_needed" or effect.key == "pacifist":
				new_stat_label.text = tr(effect.key)
			elif effect.key.to_upper() == "EFFECT_WEAPON_CLASS_BONUS":
				new_stat_label.text = tr(effect.key.to_upper()).format({"0": "+", "1": tr(effect.stat_displayed_name.to_upper()), "2": tr("WEAPON_CLASS_" + effect.set_id.trim_prefix("set_").to_upper())}).trim_prefix("+ ")
			elif effect.key.to_upper().begins_with("WEAPON_CLASS_"):
				new_stat_label.text = tr("weapon_class").format({"0": tr(effect.key.to_upper())})
			elif effect.key == "structure":
				new_stat_label.text = tr("structure")
			elif effect.key == "":
				new_stat_label.text = tr("EFFECT_MELEE_WEAPON_BONUS").format({"0": "+", "1": tr(effect.stat_displayed_name.to_upper())}).trim_prefix("+ ")
			else:
				new_stat_label.text = tr(effect.key.to_upper())

		# add label only if _stats exists
		if is_instance_valid(_stats):
			_stats.add_child(new_stat_label)

		var new_stat = LineEdit.new()
		new_stat.connect("text_changed", self , "on_stat_changed", [effect])
		new_stat.text = str(effect.value)
		if is_instance_valid(_stats):
			_stats.add_child(new_stat)
	
	if is_instance_valid(_continue):
		_continue.text = tr("continue_button")
		_continue.connect("button_up", self , "on_continue_pressed")

	if is_instance_valid(_back):
		_back.text = tr("MENU_BACK")
		_back.connect("button_up", self , "_go_back_char_select")

func manage_back(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		RunData.apply_weapon_selection_back()

func update_info_panel(_item_info: ItemParentData) -> void:
	pass

func is_char_screen() -> bool:
	return false

func is_locked_elements_displayed() -> bool:
	return false

func on_stat_changed(newValue: String, effect) -> void:
	#customize stat
	var oldValue = effect.value
	effect.value = int(newValue)
	var perm_only = effect.text_key.to_upper() == "EFFECT_GAIN_STAT_FOR_EVERY_PERM_STAT"
	var stat_link = "EFFECT_GAIN_STAT_FOR_EVERY_STAT"
	
	if effect.custom_key != "":
		RunData.players_data[player_index].effects[effect.custom_key].erase([effect.key, oldValue])
		RunData.players_data[player_index].effects[effect.custom_key].push_back([effect.key, effect.value])
	elif effect.key == "effect_reduce_stat_gains" or effect.key == "effect_increase_stat_gains":
		RunData.players_data[player_index].effects["gain_" + effect.stat_displayed] = effect.value
	elif effect.text_key == stat_link:
		RunData.players_data[player_index].effects["stat_links"].erase([effect.key, oldValue, effect.stat_scaled, effect.nb_stat_scaled, perm_only])
		RunData.players_data[player_index].effects["stat_links"].push_back([effect.key, effect.value, effect.stat_scaled, effect.nb_stat_scaled, perm_only])
	elif effect.key == "EFFECT_WEAPON_CLASS_BONUS":
		RunData.players_data[player_index].effects["weapon_class_bonus"].erase([effect.set_id, effect.stat_name, oldValue])
		RunData.players_data[player_index].effects["weapon_class_bonus"].push_back([effect.set_id, effect.stat_name, effect.value])
	elif effect.key == "weapon_slot":
		RunData.players_data[player_index].effects["weapon_slot"] = 6 # set to default
		RunData.players_data[player_index].effects["weapon_slot"] += effect.value
	else:
		RunData.players_data[player_index].effects[effect.key] = int(newValue)
	
	update_info_panel(RunData.players_data[player_index].current_character)
	if is_instance_valid(_character_panel):
		_character_panel.set_data(RunData.players_data[player_index].current_character, player_index)
		_character_panel.visible = not RunData.is_coop_run
	
func on_continue_pressed() -> void:
	if RunData.players_data[player_index].effects["weapon_slot"] == 0:
		var _error = get_tree().change_scene(MenuData.difficulty_selection_scene)
	else:
		var _error = get_tree().change_scene(MenuData.weapon_selection_scene)

func _go_back_char_select() -> void:
	for player in RunData.get_player_count():
		Utils.last_elt_selected[player] = RunData.get_player_character(player)
	RunData.revert_all_selections()
	_change_scene(MenuData.character_selection_scene)
