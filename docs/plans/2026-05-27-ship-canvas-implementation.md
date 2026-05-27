# Ship Canvas Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the flip-based UI entry point with a panoramic ship canvas and a control-room star map popup that can drive dispatch flow.

**Architecture:** Keep the legacy panel scenes available during transition, but move the main scene to a new ship canvas root. The ship canvas owns the three-zone layout and opens the star map popup as a modal overlay. The popup manages planet selection, bay selection, ship selection, and dispatch confirmation while reusing existing gameplay state and legacy panels only as transitional fallbacks.

**Tech Stack:** Godot 4.6, GDScript, scene-driven UI, existing `GameState`, `PanelManager`, and `DispatchManager`.

---

### Task 1: Replace the main entry scene with the new ship canvas

**Files:**
- Modify: `scenes/main/main.tscn`
- Create: `scenes/ui/ship_canvas.tscn`
- Create: `scripts/ui/ship_canvas.gd`
- Test: `tests/test_ship_canvas_structure.py`

**Step 1: Write the failing test**

The test is already added. It checks that the main scene uses `ship_canvas.tscn` and that the new ship canvas assets exist.

**Step 2: Run test to verify it fails**

Run: `python -m unittest tests.test_ship_canvas_structure -v`
Expected: FAIL because the new scene files are missing and `main.tscn` still references legacy panels.

**Step 3: Write minimal implementation**

Create a new `ship_canvas` scene with a three-zone layout and a control-room button that opens the star map popup.

**Step 4: Run test to verify it passes**

Run: `python -m unittest tests.test_ship_canvas_structure -v`
Expected: PASS.

### Task 2: Add the star map popup UI and flow hooks

**Files:**
- Create: `scenes/ui/star_map_popup.tscn`
- Create: `scripts/ui/star_map_popup.gd`
- Test: `tests/test_ship_canvas_structure.py`

**Step 1: Write the failing test**

The existing structure test already checks for the popup scene and the core flow methods.

**Step 2: Run test to verify it fails**

Run: `python -m unittest tests.test_ship_canvas_structure -v`
Expected: FAIL until the popup exists.

**Step 3: Write minimal implementation**

Implement planet list, default planet restoration, bay grid, ship popup, and confirmation popup.

**Step 4: Run test to verify it passes**

Run: `python -m unittest tests.test_ship_canvas_structure -v`
Expected: PASS.

### Task 3: Wire the popup into the ship canvas and document the transition

**Files:**
- Modify: `docs/dispatch-clicker-design.md`
- Modify: `docs/dispatch-clicker-visual-design.md`
- Modify: `docs/current-priorities.md`
- Modify: `docs/project-information.md`
- Modify: `CLAUDE.md`

**Step 1: Update docs**

Record the panoramic ship canvas as the current UI direction and note that the star map popup is implemented first.

**Step 2: Run structure and project tests**

Run: `python -m unittest tests.test_project_structure tests.test_ship_canvas_structure -v`
Expected: PASS.

