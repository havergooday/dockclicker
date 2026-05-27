# PC Terminal Layout Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the current PC terminal tab layout with the approved left-menu terminal layout for parts, upgrades, pilots, and custom pilot creation.

**Architecture:** Keep the existing `panel_shop.tscn` shell and rebuild `scripts/ui/panel_shop.gd` around a persistent left menu plus category-specific content builders. Parts/upgrades use a full-width list layout; pilots use split list/detail panes; custom creation expands the right-hand workspace into preview and form panes.

**Tech Stack:** Godot 4.6, GDScript, Python `unittest`

---

### Task 1: Add regression coverage for the approved terminal structure

**Files:**
- Create: `tests/test_panel_shop_layout.py`
- Modify: `scripts/ui/panel_shop.gd`

**Step 1: Write the failing test**

Add assertions that `panel_shop.gd` contains:
- category ids `parts`, `upgrade`, `pilot`
- menu width constant for the left menu
- dedicated builder functions for custom pilot creation layout

**Step 2: Run test to verify it fails**

Run: `python -m unittest tests.test_panel_shop_layout -v`

**Step 3: Write minimal implementation**

Refactor `panel_shop.gd` so the expected categories/constants/builders exist.

**Step 4: Run test to verify it passes**

Run: `python -m unittest tests.test_panel_shop_layout -v`

### Task 2: Implement the approved PC terminal layout

**Files:**
- Modify: `scripts/ui/panel_shop.gd`

**Step 1: Build persistent left navigation**

Create a fixed-width left menu with:
- `파츠`
- `함선 강화`
- `파일럿`
- divider
- disabled future entries `시설`, `꾸밈`

**Step 2: Implement parts and upgrade list views**

Use a shared list-row visual language for:
- full-width parts rows grouped by `body`, `weapon`, `legs`
- upgrade rows for active and future ship upgrades

**Step 3: Implement pilot split layout**

Create:
- pilot list column
- pilot detail column
- custom pilot CTA inside the list column

**Step 4: Implement custom pilot expanded workspace**

Split remaining width into:
- preview pane
- input form pane

### Task 3: Sync status docs and verify

**Files:**
- Modify: `docs/current-priorities.md`
- Modify: `docs/implemented-features.md`
- Modify: `docs/missing-features.md`

**Step 1: Update docs**

Reflect the approved menu-based PC terminal layout and the custom pilot creation workspace.

**Step 2: Run verification**

Run:
- `python -m unittest tests.test_panel_shop_layout tests.test_project_structure -v`

