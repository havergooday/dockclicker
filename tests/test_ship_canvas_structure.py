import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
MAIN_SCENE = ROOT / "scenes" / "main" / "main.tscn"
SHIP_CANVAS_SCENE = ROOT / "scenes" / "ui" / "ship_canvas.tscn"
STAR_MAP_SCENE = ROOT / "scenes" / "ui" / "star_map_popup.tscn"
STAR_MAP_SCRIPT = ROOT / "scripts" / "ui" / "star_map_popup.gd"
SHIP_CANVAS_SCRIPT = ROOT / "scripts" / "ui" / "ship_canvas.gd"
HANGAR_BAY_POPUP_SCRIPT = ROOT / "scripts" / "ui" / "hangar_bay_popup.gd"
HANGAR_BAY_DETAIL_SCRIPT = ROOT / "scripts" / "ui" / "hangar_bay_detail.gd"
GAME_STATE_SCRIPT = ROOT / "scripts" / "autoload" / "game_state.gd"
CURRENT_PRIORITIES = ROOT / "docs" / "current-priorities.md"
IMPLEMENTED_FEATURES = ROOT / "docs" / "implemented-features.md"


class ShipCanvasStructureTest(unittest.TestCase):
    def test_main_scene_uses_ship_canvas_root(self):
        text = MAIN_SCENE.read_text(encoding="utf8")
        self.assertIn("ship_canvas.tscn", text)
        self.assertNotIn("panel_dispatch.tscn", text)
        self.assertNotIn("panel_hangar.tscn", text)
        self.assertNotIn("panel_shop.tscn", text)
        self.assertNotIn("panel_workshop.tscn", text)

    def test_new_ship_canvas_and_star_map_assets_exist(self):
        self.assertTrue(SHIP_CANVAS_SCENE.exists())
        self.assertTrue(STAR_MAP_SCENE.exists())
        self.assertTrue(STAR_MAP_SCRIPT.exists())

    def test_star_map_script_declares_core_flow_methods(self):
        text = STAR_MAP_SCRIPT.read_text(encoding="utf8")
        self.assertIn("func open_for_control_room()", text)
        self.assertIn("func _select_planet(", text)
        self.assertIn("func _show_bay_panel(", text)
        self.assertIn("func _show_dispatch_confirm(", text)
        self.assertIn("func _dispatch_from_bay(", text)

    def test_game_state_exposes_auto_dispatch_wrapper(self):
        text = GAME_STATE_SCRIPT.read_text(encoding="utf8")
        self.assertIn("func start_auto_dispatch(", text)

    def test_star_map_has_dispatch_and_collect_all_buttons(self):
        text = STAR_MAP_SCRIPT.read_text(encoding="utf8")
        for token in [
            "▶▶ 전원 출격",
            "◉◉ 전원 수령",
            "func _on_dispatch_all_pressed(",
            "func _on_collect_all_pressed(",
            "slot.state == \"returned\" and slot.planet == _selected_planet_id",
            "GameState.collect_auto_slot(",
            "GameState.start_auto_dispatch(",
        ]:
            self.assertIn(token, text)

    def test_star_map_blocks_exhausted_pilots_and_warns_high_fatigue(self):
        text = STAR_MAP_SCRIPT.read_text(encoding="utf8")
        for token in [
            "fatigue >= 100",
            "피로 최대, 출격 불가",
            "fatigue >= 70",
            "피로 경고",
            "고피로",
            "skipped_exhausted",
            "high_fatigue_count",
        ]:
            self.assertIn(token, text)

    def test_ship_canvas_uses_feature_costs_for_workshop_toast_and_hint(self):
        game_state = GAME_STATE_SCRIPT.read_text(encoding="utf8")
        canvas = SHIP_CANVAS_SCRIPT.read_text(encoding="utf8")
        self.assertIn("func get_feature_cost(", game_state)
        self.assertIn('GameState.get_feature_cost("pilot_workshop")', canvas)
        self.assertIn("공작실 해금 비용", canvas)
        self.assertIn("상단 ▼ 격납고 [잠] 버튼", canvas)
        self.assertNotIn("nav bar 아래쪽", canvas)

    def test_ship_canvas_auto_dispatch_monitor_removed(self):
        # AUTO CCTV(자동 파견 모니터) 패널은 제거됨 — 재추가 방지 가드
        canvas = SHIP_CANVAS_SCRIPT.read_text(encoding="utf8")
        for token in [
            "AUTO CCTV",
            "_build_dispatch_monitor_panel",
            "_refresh_dispatch_monitor",
            "_build_dispatch_monitor_row",
            "DISPATCH_MONITOR_MAX_ROWS",
        ]:
            self.assertNotIn(token, canvas)

    def test_star_map_announces_unlockable_planets(self):
        text = STAR_MAP_SCRIPT.read_text(encoding="utf8")
        for token in [
            "func _find_unlockable_planets(",
            "func _notify_unlockable_planets(",
            "GameState.credits_changed.connect",
            "GameState.resources_changed.connect",
            "해금 가능",
            "GameState.unlock_planet(planet_id)",
        ]:
            self.assertIn(token, text)

    def test_hangar_bay_popup_transition_is_completed_and_documented(self):
        popup = HANGAR_BAY_POPUP_SCRIPT.read_text(encoding="utf8")
        for token in [
            "const PANEL_W_RATIO := 0.60",
            "var _selector_panel: PanelContainer",
            "func _build_equipment_slot(",
            "TextureRect.new()",
            'sprite.texture = _part_sprite_texture',
            '_open_selector("part", part_key)',
            "GameState.replace_machine_part",
            "GameState.remove_machine_part",
            "정비 예정",
            "운용 상태",
        ]:
            self.assertIn(token, popup)
        self.assertNotIn("func _on_repair_pressed()", popup)

        priorities = CURRENT_PRIORITIES.read_text(encoding="utf8")
        self.assertIn("베이 상세 팝업 전환 완료", priorities)
        self.assertNotIn("베이 상세 팝업 전환 작업 중", priorities)

    def test_hangar_bay_detail_uses_machine_disassembly_for_offline_slots(self):
        detail = HANGAR_BAY_DETAIL_SCRIPT.read_text(encoding="utf8")
        for token in [
            "머신 분해",
            "GameState.disassemble_machine(slot_idx)",
            "on_hide.call()",
            "배정 파일럿",
            "조립 편집",
            "파견 중인 베이는 읽기 전용입니다.",
            "수령 대기",
            "일괄 분해",
            "GameState.disassemble_part_group(",
        ]:
            self.assertIn(token, detail)
        self.assertNotIn("🔧 수리", detail)
        self.assertNotIn("자동 파견은 추후 업데이트 예정입니다.", detail)

    def test_game_state_exposes_part_inventory_change_signal(self):
        text = GAME_STATE_SCRIPT.read_text(encoding="utf8")
        for token in [
            "signal part_inventory_changed",
            "func disassemble_part_group(",
            "part_inventory_changed.emit()",
        ]:
            self.assertIn(token, text)

    def test_docs_do_not_keep_stale_progression_values(self):
        implemented = IMPLEMENTED_FEATURES.read_text(encoding="utf8")
        priorities = CURRENT_PRIORITIES.read_text(encoding="utf8")
        combined = implemented + "\n" + priorities
        self.assertIn("공작실·파일럿(800 CR)", implemented)
        self.assertIn("행성 해금 가능 알림", implemented)
        self.assertNotIn("공작실·파일럿(1,000 CR)", combined)
        self.assertNotIn("초기 자금 1,000,000 CR", combined)
        self.assertNotIn("자동 재파견 다중 사이클 오프라인 계산은 미구현", combined)


if __name__ == "__main__":
    unittest.main()
