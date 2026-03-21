extends "res://singletons/text.gd"

# Only override `text()` to add casing-aware lookup; inherit helpers from base.
func text(key: String, args: Array = [], arg_signs: Array = []) -> String:
	if key == "[EMPTY]":
		return ""

	# Try to resolve a real translation using multiple casings (original, lower, upper).
	var resolved = ""
	for cand in [key, key.to_lower(), key.to_upper()]:
		var t = tr(cand)
		if t != "" and t != cand:
			resolved = t
			break
	if resolved == "":
		resolved = tr(key)

	var text = resolved
	var before = ""
	var after = ""
	var sign_for_all_args = Sign.NEUTRAL
	var add_arg_front = false

	if args.size() > arg_signs.size() and arg_signs.size() > 0:
		sign_for_all_args = arg_signs[0]

	var args_needing_op = get_args_needing_operator(key.to_lower())
	var args_needing_percent = get_args_needing_percent(key.to_lower())

	# Use the resolved translation to detect presence of placeholders
	if args_needing_op.has(0) and text.find("{0}") == -1:
		add_arg_front = true

	if add_arg_front:
		if ProgressData.settings.language == "ja":
			text += " {0}"
		else:
			text = "{0} " + text

	for i in args.size():
		var checked_sign = sign_for_all_args

		if arg_signs.size() > 0:
			checked_sign = arg_signs[i]

		if checked_sign == Sign.POSITIVE:
			before = "[color=#" + ProgressData.settings.color_positive + "]"
			after = "[/color]"
		elif checked_sign == Sign.NEGATIVE:
			before = "[color=#" + ProgressData.settings.color_negative + "]"
			after = "[/color]"
		elif checked_sign == Sign.OVERRIDE:
			before = "[color=#" + Utils.CURSE_COLOR.to_html() + "]"
			after = "[/color]"
		elif checked_sign == Sign.NEUTRAL:
			before = ""
			after = ""

		text = text.replace("{" + str(i) + "}", before + get_value(args[i], args_needing_op.has(i), args_needing_percent.has(i)) + after)

	return text
