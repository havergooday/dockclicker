import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
PARTS_SHOP = ROOT / "scripts" / "ui" / "parts_shop_popup.gd"
SHOP_POPUP = ROOT / "scripts" / "ui" / "shop_popup.gd"


class PanelShopLayoutTest(unittest.TestCase):
    def test_parts_shop_popup_exists_and_has_open_close(self):
        self.assertTrue(PARTS_SHOP.exists())
        text = PARTS_SHOP.read_text(encoding="utf8")
        self.assertIn("func open_popup(", text)
        self.assertIn("func close_popup(", text)

    def test_parts_shop_popup_has_upgrade_tab(self):
        text = PARTS_SHOP.read_text(encoding="utf8")
        self.assertIn("upgrade", text.lower())

    def test_shop_popup_exists_and_has_open_close(self):
        self.assertTrue(SHOP_POPUP.exists())
        text = SHOP_POPUP.read_text(encoding="utf8")
        self.assertIn("func open_popup(", text)
        self.assertIn("func close_popup(", text)

    def test_shop_popup_handles_pilot_hiring(self):
        text = SHOP_POPUP.read_text(encoding="utf8")
        self.assertIn("GameState.hire_pilot(", text)


if __name__ == "__main__":
    unittest.main()
