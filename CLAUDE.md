# Dispatch Clicker — Claude Code Context

## Project

Desktop companion idle/clicker game (파견·복귀·정산·머신 조립·파일럿 운용).  
Target: **Steam PC** · Engine: **Godot 4.6 / GDScript**  
Validation: `python -m unittest tests.test_project_structure`

## Current State — Feature freeze

| Exists | Not yet |
|---|---|
| ShipCanvas panoramic canvas (3 zones, tab nav, drag pan) | SD character pixel-art sprites |
| HangarZone (bay grid, state detail panel) | BGM/SFX sound |
| StarMapPopup (planet grid, slot 4-row grid, bay popup) | Status bar position options |
| Direct dispatch clicker (planet select, wave, upgrade) | Window ratio/vertical layout switching |
| Auto dispatch (slots, timer, offline progress) | Steam packaging polish |
| Pilot system (instances, hire, custom, bridge roaming) | |
| Parts individual instance system (save migration) | |
| Workshop (assembly + inventory tab) | |
| Save/load (JSON, offline passthrough) | |
| Global credit HUD, bridge util panel | |
| PC terminal (left menu: parts / upgrade / pilot / facility) | |

## Navigation Structure (current implementation)

Primary: `ShipCanvas` panoramic canvas — `격납고 / 브릿지 / 관제실` tabs + right-click drag.

| Zone | File | Status |
|---|---|---|
| 격납고 | `scripts/ui/hangar_zone.gd` | ✓ Implemented — bay grid, state detail panel |
| 브릿지/파일럿 라운지 | `ship_canvas.gd` inline | Placeholder content |
| 관제실 | `ship_canvas.gd` inline + `star_map_popup.tscn` | ✓ Implemented — star map popup |

Workshop functions open as hangar popups; shop/hiring open as control-room popups. Legacy panel flip scenes are removed.

## Next Priorities

1. Debugging and regression fixes
2. Legacy scene/script removal
3. Documentation sync after deletions
4. Guardrails for removed features

## Reference Docs (read when the task requires it)

- Game design: `docs/dispatch-clicker-design.md`
- UI / wireframes: `docs/dispatch-clicker-visual-design.md`
- Folder/file responsibility: `docs/godot-project-structure.md`
- Technical decisions (already settled): `docs/technical-decisions.md`
- System designs: `docs/systems/`

## Status Docs (always keep in sync with code)

- `docs/implemented-features.md` — what is done
- `docs/missing-features.md` — what is not done yet
- `docs/current-priorities.md` — what to work on next
- `docs/project-information.md` — current project baseline

## Commit Protocol

**Run every time the user requests a commit — no need to be told.**

1. `git diff --cached --name-only` — see what is staged
2. If any file under `scripts/`, `scenes/`, `data/`, `assets/`, `tests/`, or `project.godot` / `icon.svg` is staged:
   - Update the relevant status docs (see mapping below)
   - Stage the doc changes before committing
3. Commit

**Which doc to update:**

| What changed | Update these docs |
|---|---|
| Feature added | `implemented-features.md` ← add · `missing-features.md` ← remove |
| Feature removed or replaced | reverse of above |
| Next steps shifted | `current-priorities.md` |
| Technical decision finalised | `technical-decisions.md` |
| Folder / file structure changed | `docs/godot-project-structure.md` |
| System design updated | `docs/systems/<system>.md` |

## Code Placement

- UI scripts → `scripts/ui/`
- Dispatch / settlement logic → `scripts/dispatch/` (planned)
- Scenes → `scenes/<area>/`
