extends "res://ui/menus/run/character_selection.gd"

func _on_selections_completed() -> void:
	print("[ModCharacterSelection] _on_selections_completed called")
	# replicate base behaviour of adding selected characters
	for player_index in range(RunData.get_player_count()):
		var character = _player_characters[player_index]
		RunData.add_character(character, player_index)

	if Utils.on_nintendo_nx_or_ounce and RunData.is_coop_run:
		OS.set_max_controller_count(RunData.get_player_count())

	# Instead of going straight to weapon selection, open customization screen
	if RunData.some_player_has_weapon_slots():
		print("[ModCharacterSelection] opening customize_stats.tscn")
		var packed = preload("res://mods-unpacked/ProdigalTechie-Modato/extensions/ui/menus/run/customize_stats.tscn")
		var err = get_tree().change_scene_to(packed)
		print("[ModCharacterSelection] change_scene_to result:", err)
	else:
		RunData.add_starting_items_and_weapons()
		_change_scene(MenuData.difficulty_selection_scene)
