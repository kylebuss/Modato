extends Control

const DEBUG := false

# Explicit node references based on the new scene layout
# Accept any Control (PanelContainer or VBoxContainer) so both styled panel and plain vbox work
onready var _players_vbox: Control = null
# Back/Confirm were moved for flexible placement; BackButton exists at root in weapon-like layout
onready var _confirm_button: Button = get_node_or_null("MarginContainer/BottomButtons/ConfirmButton")
onready var _back_button: Button = get_node_or_null("BackButton")
onready var _character_panel = get_node_or_null("MarginContainer/VBoxContainer/DescriptionContainer/CharacterPanelUI")
onready var _item_panel = get_node_or_null("MarginContainer/VBoxContainer/DescriptionContainer/Panels/Panel1")

var _populated: bool = false
var portrait_tex = null
var _scene_title: String = ""

# Helpers to read dami-ModOptions settings for this mod (keep parity with other singletons)
func _get_mod_options() -> Dictionary:
	var node = get_node_or_null("/root/ModLoader/dami-ModOptions/ModsConfigInterface")
	if node:
		return node.get_settings("ProdigalTechie-Modato")
	return {}

func _mod_option_enabled(key: String, default = true) -> bool:
	var settings = _get_mod_options()
	if settings.has(key):
		return settings[key]
	return default

func _ready() -> void:
	print("[CustomizeStats] _ready")

	# Apply a mod-local text patch so translations with {0} placeholders
	# from this mod are resolved even if key casing differs from base.
	var mod_text_patch_path = "res://mods-unpacked/ProdigalTechie-Modato/extensions/text_patch.gd"
	if ResourceLoader.exists(mod_text_patch_path):
		# set_script replaces the Text singleton's script at runtime
		Text.set_script(load(mod_text_patch_path))

	# Gate scene on mod option: only show this screen when enabled in ModOptions
	if not _mod_option_enabled("enable_effect_customization", true):
		if DEBUG:
			print("[CustomizeStats] effect customization disabled via mod options — skipping to weapon selection to preserve base flow")
		get_tree().change_scene(MenuData.weapon_selection_scene)
		return

	# Ensure onready nodes are present (scene may be instanced from editor or from code)
	if _players_vbox == null:
		# quick scan: if scene already contains a PlayersVBox anywhere under MarginContainer, use it
		var margin_root = get_node_or_null("MarginContainer")
		if margin_root:
			# prefer finding a styled PlayersPanel first (we keep the panel); fall back to PlayersVBox
			var found_panel = margin_root.find_node("PlayersPanel", true, false)
			if found_panel:
				_players_vbox = found_panel
			else:
				var found = margin_root.find_node("PlayersVBox", true, false)
				if found and found is VBoxContainer:
					_players_vbox = found

		# try multiple possible inventory paths (original mod layout or weapon-selection copy)
		if _players_vbox == null:
			_players_vbox = get_node_or_null("MarginContainer/VBoxContainer/Inventories/Inventory1/Scroll/PlayersVBox")
		if _players_vbox == null:
			# prefer adding PlayersVBox under a ScrollContainer if present
			var inv_owner = get_node_or_null("MarginContainer/VBoxContainer/Inventories/Inventory1")
			if inv_owner:
				var scrollc = null
				for n in ["Scroll", "ScrollInventory", "ScrollContainer", "ScrollBoxInventory"]:
					scrollc = inv_owner.get_node_or_null(n)
					if scrollc:
						break
				if scrollc:
					_players_vbox = scrollc.get_node_or_null("PlayersVBox")
					if _players_vbox == null:
						_players_vbox = VBoxContainer.new()
						_players_vbox.name = "PlayersVBox"
						scrollc.add_child(_players_vbox)
				else:
					# fallback to older Inventory node layout
					var inv_node = get_node_or_null("MarginContainer/VBoxContainer/Inventories/Inventory1/ScrollInventory/Inventory")
					if inv_node:
						_players_vbox = inv_node.get_node_or_null("PlayersVBox")
						if _players_vbox == null:
							_players_vbox = VBoxContainer.new()
							_players_vbox.name = "PlayersVBox"
							inv_node.add_child(_players_vbox)
		if _players_vbox == null:
			var inv_node = get_node_or_null("MarginContainer/VBoxContainer/Inventories/Inventory1/Inventory")
			if inv_node:
				_players_vbox = inv_node.get_node_or_null("PlayersVBox")
				if _players_vbox == null:
					_players_vbox = VBoxContainer.new()
					_players_vbox.name = "PlayersVBox"
					inv_node.add_child(_players_vbox)
	# Final fallback: attach a PlayersVBox under the Inventories container if present
	if _players_vbox == null:
		var invs = get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/Inventories")
		if invs:
			_players_vbox = VBoxContainer.new()
			_players_vbox.name = "PlayersVBox"
			_players_vbox.rect_min_size = Vector2(0, 200)
			invs.add_child(_players_vbox)
	if _confirm_button == null:
		_confirm_button = get_node_or_null("MarginContainer/BottomButtons/ConfirmButton")
	if _back_button == null:
		_back_button = get_node_or_null("BackButton")
	# ensure backwards-compatible signal handler name expected by some scenes
	# some tscn copies connect to _on_BackButton_pressed (capital B); provide alias

	if _character_panel == null:
		# try difficulty_selection-style naming
		_character_panel = get_node_or_null("MarginContainer/VBoxContainer/DescriptionContainer/CharacterPanel")
		if _character_panel == null:
			_character_panel = get_node_or_null("MarginContainer/VBoxContainer/DescriptionContainer/CharacterPanelUI")
	if _item_panel == null:
		# try difficulty_selection-style WeaponPanel first, then legacy Panels/Panel1
		_item_panel = get_node_or_null("MarginContainer/VBoxContainer/DescriptionContainer/WeaponPanel")
		if _item_panel == null:
			_item_panel = get_node_or_null("MarginContainer/VBoxContainer/DescriptionContainer/Panels/Panel1")

	# If a PlayersVBox exists but isn't placed beside the CharacterPanel in the DescriptionContainer,
	# reparent it at runtime so editable effects appear next to the character.
	var desc = get_node_or_null("MarginContainer/VBoxContainer/DescriptionContainer")
	if desc and _players_vbox:
		var current_parent = _players_vbox.get_parent()
		if current_parent != desc:
			if current_parent:
				current_parent.remove_child(_players_vbox)
			desc.add_child(_players_vbox)
			# ensure it is visible and sized appropriately
			_players_vbox.visible = true
			_players_vbox.rect_min_size = Vector2(0, 475)

	# Connect signals (scene also connects them, but ensure connection when instanced at runtime)
	if _confirm_button:
		if not _confirm_button.is_connected("pressed", self , "_on_confirm_pressed"):
			_confirm_button.connect("pressed", self , "_on_confirm_pressed")
	else:
		if DEBUG:
			print("[CustomizeStats] ConfirmButton not found (will create in layout)")

	if _back_button:
		if not _back_button.is_connected("pressed", self , "_on_back_pressed"):
			_back_button.connect("pressed", self , "_on_back_pressed")
	else:
		push_error("[CustomizeStats] BackButton not found")

	# Localize title and button labels using keys consistent with the rest of the project
	var title_node = get_node_or_null("MarginContainer/VBoxContainer/Title")
	if title_node:
		title_node.text = tr("CUSTOMIZE_CHARACTER_EFFECTS")
		_scene_title = title_node.text
	else:
		_scene_title = tr("CUSTOMIZE_CHARACTER_EFFECTS")

	if _back_button:
		_back_button.text = tr("MENU_BACK")
	if _confirm_button:
		# use a 'continue' label that matches other game flows and uses translations
		_confirm_button.text = tr("MENU_CONTINUE")

	call_deferred("_populate")
	call_deferred("_layout_confirm_button")

func _populate() -> void:
	if _players_vbox == null:
		print("[CustomizeStats] PlayersVBox not found in scene; aborting populate")
		push_error("[CustomizeStats] PlayersVBox not found in scene; aborting populate")
		return

	if _populated:
		if DEBUG:
			print("[CustomizeStats] already populated; skipping")
		return

	for child in _players_vbox.get_children():
		child.queue_free()

	var player_count = RunData.get_player_count()
	print("[CustomizeStats] populating for player_count:", player_count)
	# ensure PlayersVBox has visible size
	_players_vbox.rect_min_size = Vector2(0, max(200, player_count * 140))
	for player_index in range(player_count):
		# preload body font once per player to reuse in labels/spins
		var body_font_path = "res://resources/fonts/actual/base/font_26.tres"
		var body_font = null
		if ResourceLoader.exists(body_font_path):
			body_font = load(body_font_path)
		var section = PanelContainer.new()
		section.name = "PlayerSection_%d" % player_index
		section.rect_min_size = Vector2(0, 140)
		var style = StyleBoxFlat.new()
		# dark panel style to match CharacterPanel look-and-feel
		style.bg_color = Color(0.12, 0.12, 0.14, 0.95)
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_color = Color(0, 0, 0, 0.9)
		# add padding inside the panel
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		section.add_stylebox_override("panel", style)

		var inner = VBoxContainer.new()
		inner.name = "Inner_%d" % player_index
		inner.anchor_left = 0.0
		inner.anchor_right = 1.0
		# Main row: portrait on the left, details (title + stats) on the right
		var main_row = HBoxContainer.new()
		main_row.name = "MainRow_%d" % player_index

		# Per-player list only contains stat/details — portrait shows in the left character panel only

		var details = VBoxContainer.new()
		details.name = "Details_%d" % player_index
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var title = Label.new()
		title.name = "PlayerTitle_%d" % player_index
		# Use the scene title for the editable panel header (cleaner look)
		title.text = _scene_title
		title.align = Label.ALIGN_LEFT
		title.valign = Label.VALIGN_TOP
		title.rect_min_size = Vector2(0, 28)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_color_override("font_color", Color(0.95, 0.95, 0.95))
		var hdr_font_path = "res://resources/fonts/actual/base/font_60_outline.tres"
		if ResourceLoader.exists(hdr_font_path):
			var hdr_font = load(hdr_font_path)
			if hdr_font:
				title.add_font_override("font", hdr_font)
		details.add_child(title)

		# Container for stat rows (keeps them visually grouped to the right of portrait)
		var stats_container = VBoxContainer.new()
		stats_container.name = "Stats_%d" % player_index
		stats_container.set("custom_constants/separation", 6)
		details.add_child(stats_container)

		main_row.add_child(details)
		inner.add_child(main_row)

		# per-player portrait loading intentionally omitted here; left-hand CharacterPanelUI will display the portrait

		# Prefer showing the character's built-in effects (defined in the character resource)
		var character = RunData.players_data[player_index].current_character
		if character:
			var char_effects = character.get("effects")
			if char_effects and char_effects.size() > 0:
					for eff_res in char_effects:
						var key_str = eff_res.key
						var val = eff_res.value
						if typeof(val) == TYPE_INT or typeof(val) == TYPE_REAL:
							var h = HBoxContainer.new()
							# left-align spinbox and add spacing between label and spin
							h.set("custom_constants/separation", 12)
							h.name = "StatRow_%s" % str(key_str)
							var lab = Label.new()
							lab.name = "StatLabel_%s" % str(key_str)
							lab.add_color_override("font_color", Color(0.95, 0.95, 0.95))
							# ensure labels reserve space so spins align
							lab.rect_min_size = Vector2(140, 0)
							if body_font:
								lab.add_font_override("font", body_font)
							var key_hash = Keys.generate_hash(key_str) if key_str != "" else 0
							var name = Keys.hash_to_string.get(key_hash, key_str)
							lab.text = _translated_label(name)
							lab.size_flags_horizontal = 0
							var spin = SpinBox.new()
							spin.name = "StatSpin_%s" % str(key_hash)
							spin.min_value = -1000000
							spin.max_value = 1000000
							spin.step = 1
							spin.value = val
							spin.rect_min_size = Vector2(80, 0)
							# keep spin left-aligned (don't expand)
							spin.size_flags_horizontal = 0
							spin.connect("value_changed", self , "_on_value_changed", [player_index, key_hash])
							if body_font:
								spin.add_font_override("font", body_font)
							h.add_child(spin)

							# then the label expands to fill remaining space
							lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
							lab.rect_min_size = Vector2(0, 0)
							h.add_child(lab)
							# add stat row to the right-hand stats container for cleaner layout
							stats_container.add_child(h)
		else:
			# fallback to player's runtime effects dictionary
			var effects = RunData.players_data[player_index].effects
			for key in effects.keys():
				var val = effects[key]
				if typeof(val) == TYPE_INT or typeof(val) == TYPE_REAL:
					var h = HBoxContainer.new()
					# left-align spinbox and add spacing between label and spin
					h.set("custom_constants/separation", 12)
					h.name = "StatRow_%s" % str(key)
					var lab = Label.new()
					lab.name = "StatLabel_%s" % str(key)
					lab.add_color_override("font_color", Color(0.95, 0.95, 0.95))
					lab.rect_min_size = Vector2(140, 0)
					if body_font:
						lab.add_font_override("font", body_font)
					var name = Keys.hash_to_string.get(key, str(key))
					lab.text = _translated_label(name)
					lab.size_flags_horizontal = 0
					var spin = SpinBox.new()
					spin.name = "StatSpin_%s" % str(key)
					spin.min_value = -1000000
					spin.max_value = 1000000
					spin.step = 1
					spin.value = val
					spin.rect_min_size = Vector2(80, 0)
					# keep spin left-aligned (don't expand)
					spin.size_flags_horizontal = 0
					spin.connect("value_changed", self , "_on_value_changed", [player_index, key])
					if body_font:
						spin.add_font_override("font", body_font)
					h.add_child(spin)

					# then the label expands to fill remaining space
					lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					lab.rect_min_size = Vector2(0, 0)
					h.add_child(lab)
					# add to stats container to keep layout consistent
					stats_container.add_child(h)

		section.add_child(inner)
		_players_vbox.add_child(section)

	# Populate the left/right panels to visually match the weapon scene using the first player
	if player_count > 0:
		var first_char = RunData.players_data[0].current_character
		# shared portrait variable for the left/right panels
		var panel_portrait = null
		if _character_panel and first_char:
			# try to load a portrait texture for the character (local to this block)
			panel_portrait = null
			for prop_name in ["portrait", "portrait_texture", "portrait_path", "icon", "sprite"]:
				if first_char.has_method("get"):
					var pr = first_char.get(prop_name)
					if pr:
						if typeof(pr) == TYPE_OBJECT and pr is Texture:
							panel_portrait = pr
							break
						elif typeof(pr) == TYPE_STRING:
							var t2 = load(pr)
							if t2 and t2 is Texture:
								panel_portrait = t2
								break
			# fallback icon
			if panel_portrait == null:
				panel_portrait = load("res://items/global/random_icon.png") if ResourceLoader.exists("res://items/global/random_icon.png") else null
			# character panel: populate full character data (name, details, items)
			if first_char:
				_character_panel.set_data(first_char, 0)
				# Additional fallbacks: if the panel's internal nodes don't get populated by set_data,
				# try to set name and portrait directly into commonly-named child nodes.
				# Name label: common node names
				var name_text = null
				for p in ["name", "display_name", "my_id", "title"]:
					if first_char.has_method("get"):
						var v = first_char.get(p)
						if v:
							name_text = str(v)
							break
				var name_node = _character_panel.find_node("Name", true, false)
				if name_node == null:
					for alt in ["TitleLabel", "CharName", "NameLabel", "LabelName", "Label"]:
						name_node = _character_panel.find_node(alt, true, false)
						if name_node:
							break
				if name_node and name_text:
					if name_node is Label:
						name_node.text = name_text
				# Portrait node: try TextureRect or Sprite
				var portrait_node = _character_panel.find_node("Portrait", true, false)
				if portrait_node == null:
					for alt in ["Sprite", "PortraitTexture", "Icon", "PortraitRect", "TextureRect", "portrait"]:
						portrait_node = _character_panel.find_node(alt, true, false)
						if portrait_node:
							break
				if portrait_node:
					var ptex = panel_portrait
					if ptex == null:
						for prop_name in ["portrait", "portrait_texture", "portrait_path", "icon", "sprite"]:
							if first_char.has_method("get"):
								var pr2 = first_char.get(prop_name)
								if pr2:
									if typeof(pr2) == TYPE_OBJECT and pr2 is Texture:
										ptex = pr2
										break
									elif typeof(pr2) == TYPE_STRING and ResourceLoader.exists(pr2):
										var t3 = load(pr2)
										if t3 and t3 is Texture:
											ptex = t3
											break
					# Apply texture to common node types
					if ptex:
						if portrait_node is TextureRect:
							portrait_node.texture = ptex
						elif portrait_node is Sprite:
							portrait_node.texture = ptex
				# if we found an explicit portrait texture, override the panel's Sprite if present
				if panel_portrait != null:
					var spr = _character_panel.find_node("Sprite", true, false)
					if spr and spr is Sprite:
						spr.texture = panel_portrait
				# ensure the random/question icon is hidden for mod panels (mod-only change)
				var rnd = _character_panel.find_node("random_icon_container", true, false)
				if rnd:
					rnd.visible = false
				# remove dark overlay so portrait panel reads clearly in this mod scene
				if _character_panel.has_method("set_self_modulate") == false:
					_character_panel.self_modulate = Color(1, 1, 1, 0)
				else:
					_character_panel.self_modulate = Color(1, 1, 1, 0)

		if _item_panel and first_char:
			# item panel: show editable character stats (no portrait here)
			var item_char_id = null
			if first_char.has_method("get"):
				item_char_id = first_char.get("my_id")
			_item_panel.set_custom_data(str(item_char_id if item_char_id != null else "Character"), null)
			# hide random icon container on the item panel as well
			for p2 in ["random_icon_container", "random_icon_container/random_icon", "CenterContainer/random_icon_container"]:
				var rndc2 = _item_panel.get_node_or_null(p2)
				if rndc2:
					rndc2.visible = false
			# ensure item panel not darkened
			_item_panel.self_modulate = Color(1, 1, 1, 0)


	if DEBUG:
		print("[CustomizeStats] PlayersVBox children count:", _players_vbox.get_child_count())
		for i in range(_players_vbox.get_child_count()):
			var child = _players_vbox.get_child(i)
			print("[CustomizeStats] PlayersVBox child[", i, "]:", child.name, "children:", child.get_child_count())

	if player_count == 0:
		var label = Label.new()
		label.text = tr("No players to customize")
		_players_vbox.add_child(label)

	_populated = true

func _on_value_changed(value: float, player_index: int, key: int) -> void:
	RunData.players_data[player_index].effects[key] = value


func _layout_confirm_button() -> void:
	if not _confirm_button:
		# try to re-resolve the node first
		_confirm_button = get_node_or_null("MarginContainer/BottomButtons/ConfirmButton")
		# if still missing, we'll create one below
	# Prefer placing the confirm button centered under the DescriptionContainer
	var margin = get_node_or_null("MarginContainer")
	if margin == null:
		return
	var vbox = margin.get_node_or_null("VBoxContainer")
	if vbox == null:
		return
	# Create or find a center container inside the main vbox
	var center_node = vbox.get_node_or_null("ConfirmCenterBox")
	if center_node == null:
		center_node = HBoxContainer.new()
		center_node.name = "ConfirmCenterBox"
		center_node.alignment = 1
		center_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Put it after the DescriptionContainer if possible
		var desc_idx = -1
		for i in range(vbox.get_child_count()):
			if vbox.get_child(i).name == "DescriptionContainer":
				desc_idx = i
				break
		if desc_idx >= 0 and desc_idx < vbox.get_child_count() - 1:
			vbox.add_child(center_node)
			vbox.move_child(center_node, desc_idx + 1)
		else:
			vbox.add_child(center_node)
	# Reparent the confirm button into center_node for centered layout
	# If Confirm button doesn't exist yet, create one matching Back button size/flags
	if _confirm_button == null:
		var back = _back_button
		var new_btn = Button.new()
		new_btn.name = "ConfirmButton"
		new_btn.text = tr("MENU_CONTINUE") + " →"
		if back:
			new_btn.rect_min_size = back.rect_min_size
			new_btn.size_flags_horizontal = back.size_flags_horizontal
			# copy visual theme from the Back button to match styling
			if back.get_theme() != null:
				new_btn.theme = back.get_theme()
		_confirm_button = new_btn

	# copy theme/sizing from Back button for existing ConfirmButton as well
	var back = _back_button
	if back and _confirm_button:
		if back.get_theme() != null:
			_confirm_button.theme = back.get_theme()
		_confirm_button.rect_min_size = back.rect_min_size
		_confirm_button.size_flags_horizontal = back.size_flags_horizontal

	var parent = _confirm_button.get_parent()
	if parent != center_node:
		if parent:
			parent.remove_child(_confirm_button)
		center_node.add_child(_confirm_button)
		_confirm_button.size_flags_horizontal = Control.SIZE_FILL

	# ensure Confirm button is connected to the handler
	if not _confirm_button.is_connected("pressed", self , "_on_confirm_pressed"):
		_confirm_button.connect("pressed", self , "_on_confirm_pressed")

func _on_confirm_pressed() -> void:
	# proceed to weapon selection
	get_tree().change_scene(MenuData.weapon_selection_scene)

func _on_back_pressed() -> void:
	# go back to character selection
	get_tree().change_scene(MenuData.character_selection_scene)


func _on_BackButton_pressed() -> void:
	_on_back_pressed()


func _on_ConfirmButton_pressed() -> void:
	_on_confirm_pressed()


func _pretty_label(s: String) -> String:
	# Convert keys like "stat_luck" -> "Stat luck" or nicer display
	if s == null:
		return ""
	var parts = s.split("_")
	for i in range(parts.size()):
		parts[i] = parts[i].capitalize()
	return " ".join(parts)


func _translated_label(name: String) -> String:
	if name == null:
		return ""
	var key = name.to_upper()
	# prefer direct translation key if present, otherwise pretty print
	var translated = tr(key)
	if translated == key or translated == "":
		# fall back to prettified label
		return _pretty_label(name)
	return translated
