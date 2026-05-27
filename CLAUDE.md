# Dispatch Clicker — Claude Code Context

## Project

Desktop companion idle/clicker game (파견·복귀·정산·머신 조립·파일럿 운용).  
Target: **Steam PC** · Engine: **Godot 4.6 / GDScript**  
Validation: `python -m unittest tests.test_project_structure`

## Current State — Core gameplay loop complete

| Exists | Not yet |
|---|---|
| ShipCanvas panoramic canvas (3 zones, tab nav, drag pan) | SD 캐릭터 픽셀 아트 스프라이트 |
| HangarZone (bay grid right-aligned, state detail panel) | BGM/SFX 사운드 |
| StarMapPopup (planet grid, slot 4-row grid, bay popup) | 상태 표시줄 위치 옵션 |
| Panel flip navigation + history stack (legacy, still used) | 메크 스프라이트 조합 시스템 |
| Direct dispatch clicker (planet select, wave, upgrade) | 자동 재파견 다중 사이클 오프라인 |
| Auto dispatch (16 slots, timer, offline progress) | 시설/기지 확장 시스템 |
| Pilot system (instances, hire, custom, bridge roaming) | 가로형/세로형 전환 로직 |
| Parts individual instance system (v3, save migration) | 스팀 배포 설정 |
| Workshop (5-col assembly + inventory tab) | Bay detail popup UX (재설계 논의 예정) |
| Hangar panel (management hub, legacy panel_hangar.gd) | |
| Dispatch panel (2-state layout, anchor tween, all-slot scroll) | |
| Save/load (JSON v3, offline passthrough) | |
| Global credit HUD (floating pill), bridge util panel | |
| PC terminal (left menu: parts / upgrade / pilot) | |

## Navigation Structure (current implementation)

Primary: `ShipCanvas` panoramic canvas — `격납고 / 브릿지 / 관제실` tabs + right-click drag.

| Zone | File | Status |
|---|---|---|
| 격납고 | `scripts/ui/hangar_zone.gd` | ✓ Implemented — bay grid, state detail panel |
| 브릿지/파일럿 라운지 | `ship_canvas.gd` inline | Placeholder content |
| 관제실 | `ship_canvas.gd` inline + `star_map_popup.tscn` | ✓ Implemented — star map popup |

Workshop functions will open as hangar popups; shop/hiring as control-room popups (Phase 3, not yet migrated). Legacy panel flip panels (`panel_hangar`, `panel_workshop`, `panel_shop`, `panel_dispatch`) still exist and are used for some flows.

## Legacy Panel Structure (still active, pending migration)

Click interactive objects on bridge to flip into panels:

| Object | Panel | Role |
|---|---|---|
| 격납고 문 | 격납고 | Return unit collection, credit receipt |
| 공작실 입구 | 공작실 | Assemble mech from parts |
| PC 터미널 | 상점 | Buy parts, hire pilots |
| 관제 콘솔 | 파견 관제 | Mission board, unit assignment, sortie |

## Next Priorities

1. **UI/UX 통합 재설계** — `docs/plans/2026-05-27-ux-redesign.md`
2. **BGM/SFX** — AudioServer 버스 설정, 클릭·수령·파견음 SFX
3. 행성별 고유 생물 그래픽, 플레이어 기체 추가 업그레이드
4. 자동 파견 수익 상세 내역, 전원 출격 버튼

## Reference Docs (read when the task requires it)

- Game design: `docs/dispatch-clicker-design.md`
- UI / wireframes: `docs/dispatch-clicker-visual-design.md`
- Current UX redesign plan: `docs/plans/2026-05-27-ux-redesign.md`
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
