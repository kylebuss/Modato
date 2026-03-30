extends "res://ui/menus/ingame/pause_menu.gd"

var modato_option_tab = load("res://mods-unpacked/ProdigalTechie-Modato/mod_options_tab/mod_options_tab.tscn")


func _ready():
	var button_container = _menu_options.get_node_or_null("Buttons/HBoxContainer2")
	var button_controller = _menu_options.get_node_or_null("Buttons")

	var last_button_index = button_container.get_child_count() - 2

	var last_button = button_container.get_child(last_button_index)
	var mod_options_button = last_button.duplicate()
	mod_options_button.name = "ButtonModOptions"
	button_container.add_child_below_node(last_button, mod_options_button)
	mod_options_button.connect("pressed", button_controller, "_change_tab", [last_button_index])
	mod_options_button.text = "Modato"

	var icon_path = "res://mods-unpacked/ProdigalTechie-Modato/assets/mods_icon.png"
	if File.new().file_exists(ProjectSettings.globalize_path(icon_path)):
		mod_options_button.icon = load(icon_path)

	button_controller.buttons_tab_np.push_back(mod_options_button.get_path())
	button_controller.tab_container.add_child(modato_option_tab.instance())
	button_controller.buttons_tab.push_back(mod_options_button)
