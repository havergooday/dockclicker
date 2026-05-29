class_name HangarHelpers


static func vspacer() -> Control:
	var s := Control.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


static func add_lbl(parent: Control, text: String, font_sz: int,
		align: HorizontalAlignment, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.horizontal_alignment = align
	lbl.modulate = col
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if align == HORIZONTAL_ALIGNMENT_LEFT:
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(lbl)


static func card_sty(col: Color, hover: bool, glowing: bool, selected: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if selected:
		s.bg_color     = Color(0.08, 0.12, 0.22, 0.96)
		s.border_color = col.lightened(0.25)
		s.set_border_width_all(2)
	elif hover:
		s.bg_color     = Color(0.06, 0.09, 0.17, 0.96)
		s.border_color = col.lightened(0.18) if not glowing else col
		s.set_border_width_all(2 if glowing else 1)
	else:
		s.bg_color     = Color(0.04, 0.06, 0.13, 0.96)
		s.border_color = col if glowing else col.darkened(0.38)
		s.set_border_width_all(2 if glowing else 1)
	s.set_corner_radius_all(5)
	return s


static func status_color(state: String) -> Color:
	match state:
		"empty":       return Color(0.70, 0.72, 0.78)
		"assembling":  return Color(0.95, 0.65, 0.20)
		"offline":     return Color(0.72, 0.22, 0.22)
		"returned":    return Color(0.28, 1.00, 0.48)
		"on_mission":  return Color(0.30, 0.62, 1.00)
		"returning":   return Color(1.00, 0.78, 0.22)
		"locked":      return Color(0.42, 0.44, 0.54)
		_:             return Color(0.60, 0.60, 0.65)


static func border_color(state: String) -> Color:
	match state:
		"locked":      return Color(0.33, 0.35, 0.48)
		"empty":       return Color(0.34, 0.48, 0.62)
		"assembling":  return Color(0.70, 0.48, 0.14)
		"offline":     return Color(0.55, 0.18, 0.18)
		"on_mission":  return Color(0.28, 0.58, 0.95)
		"returning":   return Color(0.95, 0.74, 0.20)
		"returned":    return Color(0.26, 0.95, 0.46)
		_:             return Color(0.45, 0.45, 0.55)


static func state_label(state: String) -> String:
	match state:
		"locked":      return "LOCKED"
		"empty":       return "EMPTY"
		"assembling":  return "ASSEMBLING"
		"offline":     return "OFFLINE"
		"on_mission":  return "ON MISSION"
		"returning":   return "RETURNING"
		"returned":    return "RETURNED"
		_:             return state.to_upper()


static func sprite_bg(machine: Dictionary, state: String) -> Color:
	if machine.is_empty() or machine.get("body", 0) == 0:
		return Color(0.08, 0.10, 0.16)
	var avg: float = (int(machine.get("body", 1)) + int(machine.get("weapon", 1)) + int(machine.get("legs", 1))) / 3.0
	var base := Color(0.12, 0.24, 0.40).lerp(Color(0.10, 0.42, 0.62), (avg - 1.0) / 2.0)
	return base.darkened(0.45) if state in ["on_mission", "returning"] else base


static func fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	for i: int in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out


static func fmt_time(end_time: float) -> String:
	var now := Time.get_unix_time_from_system()
	var total := maxi(0, int(round(end_time - now)))
	var m := total / 60
	var s := total % 60
	return "%02d:%02d" % [m, s]
