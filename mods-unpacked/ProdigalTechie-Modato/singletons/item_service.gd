extends "res://singletons/item_service.gd"

func get_consumable_to_drop(unit: Unit, item_chance: float) -> ConsumableData:
	var luck := 0.0
	for player_index in RunData.get_player_count():
		luck += Utils.get_stat(Keys.stat_luck_hash, player_index) / 100.0

	var consumable_drop_chance := min(1.0, unit.stats.base_drop_chance * (1.0 + luck))
	if RunData.current_wave > RunData.nb_of_waves:
		consumable_drop_chance /= (1.0 + RunData.get_endless_factor())

	if DebugService.always_drop_crates:
		consumable_drop_chance = 1.0
		item_chance = 1.0

	var consumable_to_drop: ConsumableData = null
	if Utils.get_chance_success(consumable_drop_chance) or unit.stats.always_drop_consumables:
		var consumable_tier: int = Utils.randi_range(unit.stats.min_consumable_tier, unit.stats.max_consumable_tier)

		if Utils.get_chance_success(item_chance):
			if unit is Boss:
				consumable_tier = Tier.LEGENDARY
			else:
				consumable_tier = Tier.UNCOMMON

		consumable_to_drop = get_consumable_for_tier(consumable_tier)

	elif Utils.get_chance_success(RunData.sum_all_player_effects(Keys.enemy_fruit_drops_hash) / 100.0):
		consumable_to_drop = get_consumable_for_tier(Tier.COMMON)
		for player_index in RunData.get_player_count():
			RunData.add_tracked_value(player_index, Keys.item_fruit_basket_hash, 1)

	return consumable_to_drop