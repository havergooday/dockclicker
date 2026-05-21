# Dispatch Clicker — Claude Code Context

## Project

Desktop companion idle/clicker game (파견·복귀·정산·머신 조립·파일럿 운용).  
Target: **Steam PC** · Engine: **Godot 4.6 / GDScript**  
Validation: `python -m unittest tests.test_project_structure`

## Current State — Design complete, pre-implementation

| Exists | Not yet |
|---|---|
| Folder structure, scene scaffold, autoload | All gameplay (panel flip, clicker, dispatch, UI) |
| Full game design: panel structure, clicker mechanics, dispatch flow | Any playable feature |
| `scripts/autoload/game_state.gd` (`layout_mode`, `total_credits`) | Panel UIs, data files, save system |

## Panel Structure (confirmed design)

Main ship view = bridge (pilots idle here). Click interactive objects to flip into panels:

| Object | Panel | Role |
|---|---|---|
| 격납고 문 | 격납고 | Return unit collection, credit receipt |
| 공작실 입구 | 공작실 | Assemble mech from parts |
| PC 터미널 | 상점 | Buy parts, hire pilots |
| 관제 콘솔 | 파견 관제 | Mission board, unit assignment, sortie |

## Next Priorities

1. **Pending discussion**: return/settlement screen design (blocks 격납고 panel impl)
2. Main view interactive objects + panel flip system
3. Direct dispatch clicker: alien creatures, click damage, credit drop
4. 격납고 panel: credit collection interaction
5. PC terminal + 공작실 panels: basic shop and assembly UI

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
