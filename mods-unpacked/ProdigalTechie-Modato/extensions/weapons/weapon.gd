extends "res://weapons/weapon.gd"

# Mod override to avoid core assertion by trimming attack history to a higher safe cap
const MOD_MAX_ATTACK_COUNT_HISTORY := 20

func on_weapon_hit_something(_thing_hit: Node, damage_dealt: int, hitbox) -> void:
	# Similar logic to core, but ensure we never grow beyond MOD_MAX_ATTACK_COUNT_HISTORY
	RunData.add_weapon_dmg_dealt(weapon_pos, damage_dealt, _parent.player_index)
	if hitbox == null:
		return
	var attack_id: int = hitbox.player_attack_id
	if attack_id < 0:
		return
	var attack_hit_count = _hit_count_by_attack_id.get(attack_id, 0)
	attack_hit_count += 1
	_hit_count_by_attack_id[attack_id] = attack_hit_count

	if current_stats is MeleeWeaponStats:
		ChallengeService.try_complete_challenge(ChallengeService.chal_unstoppable_force_hash, attack_hit_count)

	# Trim old entries using core's window size first
	var remove_until_attack_id := attack_id - MAX_ATTACK_COUNT_HISTORY + 1
	for old_attack_id in range(_oldest_attack_id, remove_until_attack_id):
		_hit_count_by_attack_id.erase(old_attack_id)
		_kill_count_by_attack_id.erase(old_attack_id)
	_oldest_attack_id = remove_until_attack_id

	# Extra safety: trim to mod cap if necessary
	while _hit_count_by_attack_id.size() > MOD_MAX_ATTACK_COUNT_HISTORY:
		_hit_count_by_attack_id.erase(_oldest_attack_id)
		_kill_count_by_attack_id.erase(_oldest_attack_id)
		_oldest_attack_id += 1

	while _kill_count_by_attack_id.size() > MOD_MAX_ATTACK_COUNT_HISTORY:
		_kill_count_by_attack_id.erase(_oldest_attack_id)
		_oldest_attack_id += 1

	# Do not run the original asserts from core; we've enforced bounds above

	for effect in effects:
		if effect.key_hash == Keys.break_on_hit_hash:
			if Utils.get_chance_success(effect.value / 100.0):
				emit_signal("wanted_to_break", self , effect.value2)


func update_sprite(new_sprite: Texture) -> void:
	# Guard against Nil textures from core: only set sprite.texture when a valid
	# texture is returned by SkinManager. This avoids assigning `null` and later
	# causing errors when code expects a valid Texture.
	if new_sprite == null:
		return
	var tex = SkinManager.get_skin(new_sprite)
	if tex == null:
		return
	sprite.texture = tex
