extends "res://main.gd"


const LOG_ID = "ProdigalTechie-Modato:Main"

# Called when the node enters the scene tree for the first time.
func _on_EntitySpawner_players_spawned(players: Array) -> void:
	DebugService.log_data("%s: _on_EntitySpawner_players_spawned start" % LOG_ID)
	_players = players
	_camera.targets = players
	_floating_text_manager.players = _players

	# Ensure floating text manager has per-player counters initialized
	_floating_text_manager.players_add_stats_count = []
	for player in _players:
		_floating_text_manager.players_add_stats_count.push_back(0)

	
	EffectBehaviorService.update_active_effect_behaviors()

	if _players.size() > 1:
		_damage_vignette.active = false

	_players_ui.clear()
	for i in range(_players.size()):
		DebugService.log_data("%s: processing player %d" % [LOG_ID, i])
		var effects = RunData.get_player_effects(i)

		var player_ui = PlayerUIElements.new()
		var player_idx_string = str(i + 1)

		player_ui.player_index = i
		player_ui.player_life_bar = get_node("%%PlayerLifeBarContainerP%s/PlayerLifeBarP%s" % [player_idx_string, player_idx_string])
		player_ui.player_life_bar_container = get_node("%%PlayerLifeBarContainerP%s" % player_idx_string)
		player_ui.hud_container = get_node("%%LifeContainerP%s" % player_idx_string)
		player_ui.life_bar = get_node("%%UILifeBarP%s" % player_idx_string)
		player_ui.life_label = get_node("%%UILifeBarP%s/MarginContainer/LifeLabel" % player_idx_string)
		player_ui.xp_bar = get_node("%%UIXPBarP%s" % player_idx_string)
		player_ui.level_label = get_node("%%UIXPBarP%s/MarginContainer/LevelLabel" % player_idx_string)
		player_ui.gold = get_node("%%UIGoldP%s" % player_idx_string)

		_players_ui.push_back(player_ui)

		player_ui.update_hud(_players[i])
		player_ui.hud_visible = true
		player_ui.set_hud_position(i)

		_players[i].get_life_bar_remote_transform().remote_path = player_ui.player_life_bar_container.get_path()
		_players[i].current_stats.health = max(1, _players[i].max_stats.health * (effects[Keys.hp_start_wave_hash] / 100.0)) as int

		if effects[Keys.hp_start_next_wave_hash] != 100:
			_players[i].current_stats.health = max(1, _players[i].max_stats.health * (effects[Keys.hp_start_next_wave_hash] / 100.0)) as int
			effects[Keys.hp_start_next_wave_hash] = 100

		_players[i].check_hp_regen()

		_on_player_health_updated(_players[i], _players[i].current_stats.health, _players[i].max_stats.health)

		var _error = _players[i].connect("health_updated", self , "_on_player_health_updated")
		_error = _players[i].connect("healed", _floating_text_manager, "_on_player_healed")
		_error = _players[i].connect("died", self , "_on_player_died")
		_error = _players[i].connect("took_damage", _screenshaker, "_on_player_took_damage")
		_error = _players[i].connect("healed", self , "on_player_healed")
		_error = _players[i].connect("wanted_to_spawn_gold", self , "on_player_wanted_to_spawn_gold")

		var things_to_process_player_container: UIThingsToProcessPlayerContainer = _things_to_process_player_containers[i]
		things_to_process_player_container.show()
		_error = things_to_process_player_container.upgrades.connect("ui_element_mouse_entered", self , "on_ui_element_mouse_entered")
		_error = things_to_process_player_container.upgrades.connect("ui_element_mouse_exited", self , "on_ui_element_mouse_exited")
		_error = things_to_process_player_container.consumables.connect("ui_element_mouse_entered", self , "on_ui_element_mouse_entered")
		_error = things_to_process_player_container.consumables.connect("ui_element_mouse_exited", self , "on_ui_element_mouse_exited")

		connect_visual_effects(_players[i])

		var pct_val = RunData.get_player_effect(Keys.gain_pct_gold_start_wave_hash, i)
		var apply_pct_gold_wave = pct_val > 0

		if apply_pct_gold_wave:
			var val = RunData.get_player_gold(i) * (pct_val / 100.0)
			RunData.add_gold(val, i)
			if pct_val > 0:
				RunData.add_tracked_value(i, Keys.item_piggy_bank_hash, val)


	var temp_stats_updated = false
	for player_index in range(_players.size()):
		var effects = RunData.get_player_effects(player_index)
		if effects[Keys.stats_next_wave_hash].size() > 0:
			for stat_next_wave in effects[Keys.stats_next_wave_hash]:
				TempStats.add_stat(stat_next_wave[0], stat_next_wave[1], player_index)
				temp_stats_updated = true
			effects[Keys.stats_next_wave_hash].clear()

		if check_half_health_stats(player_index):
			temp_stats_updated = true

	if temp_stats_updated:
		RunData.call_deferred("_emit_stats_updated")

	DebugService.log_run_info()
	RunData.reset_weapons_dmg_dealt()
	RunData.reset_weapons_tracked_value_this_wave()
	RunData.reset_wave_caches()

# Allow harvesting to grow infinitely
func _on_HarvestingTimer_timeout() -> void:
	DebugService.log_data("%s: _on_HarvestingTimer_timeout start" % LOG_ID)
	for player_index in range(RunData.get_player_count()):
		DebugService.log_data("%s: harvesting for player %d" % [LOG_ID, player_index])
		var harvesting_stat = Utils.get_stat(Keys.stat_harvesting_hash, player_index)
		if harvesting_stat <= 0:
			continue
		
		var harvesting_growth = RunData.get_player_effect(Keys.harvesting_growth_hash, player_index)
		var val = ceil(harvesting_stat * (harvesting_growth / 100.0))

		var has_crown = false
		var crown_value = 0

		var items = RunData.get_player_items_ref(player_index)
		for item in items:
			if item.my_id_hash == Keys.item_crown_hash:
				has_crown = true
				crown_value = item.effects[0].value
				break

		if has_crown:
			RunData.add_tracked_value(player_index, Keys.item_crown_hash, ceil(harvesting_stat * (crown_value / 100.0)) as int)

		if val > 0:
			RunData.add_stat(Keys.stat_harvesting_hash, val, player_index)
			RunData.call_deferred("_emit_stats_updated")


# Override level-up handling to add safety guards (avoid modifying base Brotato files)
func on_levelled_up(player_index: int) -> void:
	DebugService.log_data("%s: on_levelled_up for player %d" % [LOG_ID, player_index])
	# Play sound if available
	if typeof(level_up_sound) != TYPE_NIL:
		SoundManager.play(level_up_sound, 0, 0, true)

	var level = RunData.get_player_level(player_index)

	# Safely add visual upgrade element if containers exist
	if _things_to_process_player_containers and player_index >= 0 and player_index < _things_to_process_player_containers.size():
		var things_container = _things_to_process_player_containers[player_index]
		if things_container and things_container.upgrades:
			things_container.upgrades.add_element(ItemService.get_icon(Keys.icon_upgrade_to_process_hash), level)

	# Push upgrade to process list (ensure list exists)
	var upgrade_to_process = UpgradesUI.UpgradeToProcess.new()
	upgrade_to_process.level = level
	upgrade_to_process.player_index = player_index
	if _upgrades_to_process and player_index >= 0 and player_index < _upgrades_to_process.size():
		_upgrades_to_process[player_index].push_back(upgrade_to_process)

	# Update UI label if present
	if _players_ui and player_index >= 0 and player_index < _players_ui.size() and _players_ui[player_index] != null:
		var ui_elem = _players_ui[player_index]
		if ui_elem.has_method("update_level_label"):
			ui_elem.update_level_label()

	# Apply stat changes from level up
	RunData.add_stat(Keys.stat_max_hp_hash, 1, player_index)
	for stat_level_up in RunData.get_player_effect(Keys.stats_on_level_up_hash, player_index):
		assert(stat_level_up[0] is int)
		RunData.add_stat(stat_level_up[0], stat_level_up[1], player_index)

		if stat_level_up[0] == Keys.stat_lifesteal_hash:
			RunData.add_tracked_value(player_index, Keys.item_decomposing_flesh_hash, stat_level_up[1])
		elif stat_level_up[0] == Keys.stat_hp_regeneration_hash:
			RunData.add_tracked_value(player_index, Keys.item_baby_squid_hash, stat_level_up[1])
		elif stat_level_up[0] == Keys.stat_curse_hash:
			var val = stat_level_up[1]
			if RunData.get_player_character(player_index).my_id_hash == Keys.character_creature_hash:
				val -= 1
			if val > 0:
				RunData.add_tracked_value(player_index, Keys.item_barnacle_hash, 1)
