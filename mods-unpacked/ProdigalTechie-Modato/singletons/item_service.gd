# Extend base ItemService and reference the tree stats resource for detection
extends "res://singletons/item_service.gd"
onready var _tree_stats_res: Resource = preload("res://entities/units/neutral/tree_stats.tres")

# Helpers to read dami-ModOptions settings for this mod
func _get_mod_options() -> Dictionary:
	var paths = ["/root/ModLoader/ProdigalTechie-Modato/ModsConfigInterface"]
	for p in paths:
		var node = get_node_or_null(p)
		if node:
			return node.get_settings("ProdigalTechie-Modato")
	return {}

func _mod_option_enabled(key: String, default = true) -> bool:
	var settings = _get_mod_options()
	if settings.has(key):
		return settings[key]
	return default

func get_consumable_to_drop(unit: Unit, item_chance: float) -> ConsumableData:
	var luck := 0.0
	for player_index in RunData.get_player_count():
		luck += Utils.get_stat(Keys.stat_luck_hash, player_index) / 100.0

	var consumable_drop_chance := min(1.0, unit.stats.base_drop_chance * (1.0 + luck))
	if RunData.current_wave > RunData.nb_of_waves:
		consumable_drop_chance /= (1.0 + RunData.get_endless_factor())

	if unit.stats == _tree_stats_res:
			consumable_drop_chance = max(consumable_drop_chance, 0.5)

	if DebugService.always_drop_crates:
		consumable_drop_chance = 1.0
		item_chance = 1.0

	var consumable_to_drop: ConsumableData = null
	if Utils.get_chance_success(consumable_drop_chance) or unit.stats.always_drop_consumables:
		var consumable_tier: int = Utils.randi_range(unit.stats.min_consumable_tier, unit.stats.max_consumable_tier)

		# If this is a Tree, enforce 50% crate / 50% fruit by overriding item_chance
		if unit.stats == _tree_stats_res:
			item_chance = 0.50

		if Utils.get_chance_success(item_chance):
			# Tree-specific crate behavior: when a crate spawns from a Tree
			# give Legendary with 20% chance on wave 8+, otherwise Common
			if unit.stats == _tree_stats_res and _mod_option_enabled("enable_tree_legendary", true):
				var r_tree = randf()
				if RunData.current_wave >= 8 and r_tree < 0.5:
					var legendary_tree_chance = randf()
					if legendary_tree_chance < 0.4:
						consumable_to_drop = get_consumable_for_tier(Tier.LEGENDARY)
					else:
						consumable_to_drop = get_consumable_for_tier(Tier.UNCOMMON)
				else:
					if r_tree < 0.5:
						consumable_to_drop = get_consumable_for_tier(Tier.UNCOMMON)
					else:
						consumable_to_drop = get_consumable_for_tier(Tier.COMMON)

			# Make Looters drop 70% Uncommon (crate) and 30% Legendary crates when enabled (only wave 8+)
			if _mod_option_enabled("enable_looter_legendary", true) and unit is Looter:
				consumable_to_drop = get_consumable_for_tier(Tier.UNCOMMON)
				var r_looter = randf()
				if RunData.current_wave >= 8 and r_looter < 0.3:
					consumable_to_drop = get_consumable_for_tier(Tier.LEGENDARY)
				
					
			# Preserve base game's boss legendary behavior during normal (non-endless) waves
			if consumable_to_drop == null and unit is Boss and RunData.current_wave <= RunData.nb_of_waves:
				consumable_tier = Tier.LEGENDARY

			# Only apply the mod's boss legendary-crate behavior during endless waves
			if _mod_option_enabled("enable_legendary_crates", true) and RunData.current_wave > RunData.nb_of_waves:
				if unit is Boss:
					var r = randf()
					if r < 0.6:
						consumable_tier = Tier.UNCOMMON
					elif r < 0.9:
						consumable_tier = Tier.LEGENDARY
					else:
						consumable_to_drop = get_consumable_for_tier(Tier.COMMON)
						for player_index in RunData.get_player_count():
							RunData.add_tracked_value(player_index, Keys.item_fruit_basket_hash, 1)

		if consumable_to_drop == null:
			consumable_to_drop = get_consumable_for_tier(consumable_tier)

	elif Utils.get_chance_success(RunData.sum_all_player_effects(Keys.enemy_fruit_drops_hash) / 100.0):
		consumable_to_drop = get_consumable_for_tier(Tier.COMMON)
		for player_index in RunData.get_player_count():
			RunData.add_tracked_value(player_index, Keys.item_fruit_basket_hash, 1)

	return consumable_to_drop