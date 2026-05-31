import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME_STATE = ROOT / "scripts" / "autoload" / "game_state.gd"
SAVE_MANAGER = ROOT / "scripts" / "autoload" / "save_manager.gd"
SHIP_CANVAS = ROOT / "scripts" / "ui" / "ship_canvas.gd"
QUARTERS_ZONE = ROOT / "scripts" / "ui" / "quarters_zone.gd"
FACILITY_DATA = ROOT / "data" / "facility_data.gd"


class LivingShipPlacementTest(unittest.TestCase):
    def test_game_state_declares_placeable_positions_and_region_tags(self):
        text = GAME_STATE.read_text(encoding="utf8")
        for token in [
            "var placeable_positions: Dictionary = {}",
            "signal placeable_positions_changed",
            "const PLACEABLE_GRID_SIZE := 16.0",
            'func set_placeable_position(placeable_id: String, region_tag: String, pos: Vector2) -> bool:',
            'func get_placeable_position(placeable_id: String, fallback: Vector2) -> Vector2:',
            'func ensure_placeable_position(placeable_id: String, region_tag: String, pos: Vector2) -> void:',
            'func clamp_placeable_position(placeable_id: String, region_tag: String, pos: Vector2) -> Vector2:',
            'func can_place_at(placeable_id: String, region_tag: String, pos: Vector2) -> bool:',
            'func get_placement_bounds(region_tag: String) -> Rect2:',
            'func _placeable_size(placeable_id: String, region_tag: String) -> Vector2:',
            'func _is_placeable_cell_free(placeable_id: String, region_tag: String, candidate: Vector2) -> bool:',
            'func _placement_bounds(region_tag: String) -> Rect2:',
            '"quarters": return Rect2(Vector2(0.0, 0.0), Vector2(1200.0, 288.0))',
            '"lounge": return Rect2(Vector2(1200.0, 80.0), Vector2(1216.0, 208.0))',
            'var size := _placeable_size(placeable_id, region_tag)',
            'bounds.position.x + bounds.size.x - size.x',
            'bounds.position.y + bounds.size.y - size.y',
            '_is_placeable_cell_free(placeable_id, region_tag, clamped)',
            'candidate_rect.intersects(Rect2(other_pos, other_size))',
            "snapped(Vector2(PLACEABLE_GRID_SIZE, PLACEABLE_GRID_SIZE))",
            "return Vector2(128.0, 64.0)",
            "return Vector2(144.0, 56.0)",
        ]:
            self.assertIn(token, text)

    def test_sofa_default_position_is_on_grid(self):
        text = FACILITY_DATA.read_text(encoding="utf8")
        self.assertIn('"use_point": Vector2(1536, 192)', text)

    def test_save_manager_persists_placeable_positions(self):
        text = SAVE_MANAGER.read_text(encoding="utf8")
        for token in [
            "GameState.placeable_positions_changed.connect",
            '"placeable_positions":',
            "GameState.placeable_positions.duplicate(true)",
            'd.get("placeable_positions", {})',
            "GameState.placeable_positions =",
        ]:
            self.assertIn(token, text)

    def test_options_toggle_enables_drag_placement(self):
        text = SHIP_CANVAS.read_text(encoding="utf8")
        for token in [
            "var _placement_edit_btn: Button = null",
            'GameState.ui_edit_mode_changed.connect',
            'GameState.set_ui_edit_mode',
            '"배치 이동"',
            "func _refresh_placement_edit_ui()",
            "func _make_placeable_drag_handle(",
            'card.add_child(_make_placeable_drag_handle(placeable_id, "lounge"))',
            '"lounge"',
            "GameState.set_placeable_position",
            "_grid_overlay",
            "func _draw_grid_overlay(",
            "queue_redraw()",
        ]:
            self.assertIn(token, text)

    def test_quarters_zone_uses_draggable_bed_positions(self):
        text = QUARTERS_ZONE.read_text(encoding="utf8")
        for token in [
            'GameState.placeable_positions_changed.connect',
            'GameState.ensure_placeable_position("bed_%d" % i, "quarters", default_pos)',
            'GameState.get_placeable_position("bed_%d" % i',
            'btn.set_meta("placeable_id", "bed_%d" % bed_idx)',
            'btn.set_meta("region_tag", "quarters")',
            "GameState.ui_edit_mode",
            "GameState.set_placeable_position",
            "GameState.clamp_placeable_position",
            "if GameState.can_place_at(placeable_id, region_tag, candidate):",
            "btn.position = candidate",
            '"점유 %d / 3" % occupied',
        ]:
            self.assertIn(token, text)

    def test_sofa_drag_is_clamped_to_grid_and_stops_at_blocked_cells(self):
        text = SHIP_CANVAS.read_text(encoding="utf8")
        for token in [
            "GameState.clamp_placeable_position",
            "if GameState.can_place_at(placeable_id, region_tag, candidate):",
            "node.position = candidate - local_origin",
            'GameState.ensure_placeable_position(placeable_id, "lounge", use_point)',
            "Vector2(1200.0, 80.0)",
            "node.position + local_origin",
            "- local_origin",
        ]:
            self.assertIn(token, text)

    def test_placement_mode_shows_toast_and_drag_tint_feedback(self):
        canvas_text = SHIP_CANVAS.read_text(encoding="utf8")
        for token in [
            '"배치 이동 모드 — 시설·침대를 끌어다 놓으세요"',
            '"배치 완료"',
            "node.modulate = Color(1, 1, 1)",
            "node.modulate = Color(1.0, 0.45, 0.45, 0.80)",
        ]:
            self.assertIn(token, canvas_text)
        qz_text = QUARTERS_ZONE.read_text(encoding="utf8")
        for token in [
            "btn.modulate = Color(1, 1, 1)",
            "btn.modulate = Color(1.0, 0.45, 0.45, 0.80)",
        ]:
            self.assertIn(token, qz_text)

    def test_grid_overlay_is_drawn_when_edit_mode_is_enabled(self):
        text = SHIP_CANVAS.read_text(encoding="utf8")
        for token in [
            "var _grid_overlay: Control = null",
            "_grid_overlay.draw.connect(_draw_grid_overlay)",
            "if not GameState.ui_edit_mode:",
            '_draw_grid_region("quarters",',
            '_draw_grid_region("lounge",',
            'func _draw_grid_region(region_tag: String, line_color: Color, fill_color: Color) -> void:',
            "GameState.get_placement_bounds(region_tag)",
            "_grid_overlay.draw_rect(bounds, fill_color, true)",
            "range(int(bounds.position.x), int(bounds.end.x) + 1, step)",
            "range(int(bounds.position.y), int(bounds.end.y) + 1, step)",
        ]:
            self.assertIn(token, text)


if __name__ == "__main__":
    unittest.main()
