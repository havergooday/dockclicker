class_name CreatureVisualData

const DEFAULT_REGION := "scrap"

const REGION_VARIANTS: Dictionary = {
	"scrap": [
		{"name": "Scrap Slime", "body": Color(0.42, 0.78, 0.36), "core": Color(0.78, 1.00, 0.58), "mark": "●"},
		{"name": "Magnet Wisp", "body": Color(0.38, 0.62, 0.86), "core": Color(0.72, 0.90, 1.00), "mark": "◇"},
		{"name": "Rust Crawler", "body": Color(0.80, 0.46, 0.24), "core": Color(1.00, 0.74, 0.38), "mark": "✕"},
	],
	"trade": [
		{"name": "Signal Mite", "body": Color(0.46, 0.66, 1.00), "core": Color(0.90, 0.96, 1.00), "mark": "▸"},
		{"name": "Cargo Leech", "body": Color(0.74, 0.62, 0.34), "core": Color(1.00, 0.90, 0.56), "mark": "◆"},
		{"name": "Beacon Imp", "body": Color(0.44, 0.82, 0.82), "core": Color(0.84, 1.00, 0.94), "mark": "◎"},
	],
	"city_ruins": [
		{"name": "Concrete Spider", "body": Color(0.64, 0.66, 0.72), "core": Color(1.00, 0.38, 0.36), "mark": "✕"},
		{"name": "Neon Shade", "body": Color(0.48, 0.34, 0.84), "core": Color(0.94, 0.70, 1.00), "mark": "◇"},
		{"name": "Wire Husk", "body": Color(0.34, 0.46, 0.54), "core": Color(0.72, 0.92, 1.00), "mark": "⟡"},
	],
	"bio": [
		{"name": "Spore Pod", "body": Color(0.38, 0.84, 0.42), "core": Color(0.90, 1.00, 0.54), "mark": "●"},
		{"name": "Wing Bloom", "body": Color(0.98, 0.48, 0.64), "core": Color(1.00, 0.84, 0.92), "mark": "▸"},
		{"name": "Vine Eye", "body": Color(0.30, 0.62, 0.34), "core": Color(0.80, 1.00, 0.72), "mark": "◎"},
	],
}


static func get_variants(region_type: String) -> Array:
	return REGION_VARIANTS.get(region_type, REGION_VARIANTS[DEFAULT_REGION]) as Array


static func get_variant(region_type: String, tier: int) -> Dictionary:
	var variants := get_variants(region_type)
	if variants.is_empty():
		return {}
	var idx := clampi(tier, 0, variants.size() - 1)
	return variants[idx] as Dictionary
