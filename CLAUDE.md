# Dispatch Clicker — Claude Code Context

## Project

Desktop companion idle/clicker game (파견·복귀·정산·머신 조립·파일럿 운용).  
Target: **Steam PC** · Engine: **Godot 4.6 / GDScript**  
Validation: `python -m unittest tests.test_project_structure`

## Current State — Core gameplay loop complete

| Exists | Not yet |
|---|---|
| Panel flip navigation + history stack | SD 캐릭터 픽셀 아트 스프라이트 |
| Direct dispatch clicker (planet select, wave, upgrade) | BGM/SFX 사운드 |
| Auto dispatch (3 slots, timer, offline progress) | 상태 표시줄 위치 옵션 |
| Pilot system (instances, hire, custom, bridge roaming) | 메크 스프라이트 조합 시스템 |
| Parts individual instance system (v3, save migration) | 자동 재파견 다중 사이클 오프라인 |
| Workshop (5-col assembly + inventory tab) | 시설/기지 확장 시스템 |
| Hangar (16-slot scroll grid, bay cards) | 가로형/세로형 전환 로직 |
| Save/load (JSON v3, offline passthrough) | PC 터미널 강화·파츠 탭 레이아웃 미확정 |
| Global credit HUD (floating pill), bridge util panel | 스팀 배포 설정 |

## Panel Structure (confirmed design)

Main ship view = bridge (pilots idle here). Click interactive objects to flip into panels:

| Object | Panel | Role |
|---|---|---|
| 격납고 문 | 격납고 | Return unit collection, credit receipt |
| 공작실 입구 | 공작실 | Assemble mech from parts |
| PC 터미널 | 상점 | Buy parts, hire pilots |
| 관제 콘솔 | 파견 관제 | Mission board, unit assignment, sortie |

## Next Priorities

1. **PC 터미널 강화·파츠 탭 레이아웃** — 2컬럼 구조 확정, 시각 언어 미정 (참고 게임 리서치 후 결정)
2. BGM/SFX — AudioServer 버스 설정, 클릭·수령·파견음 SFX
3. 행성별 고유 생물 그래픽, 플레이어 기체 추가 업그레이드
4. 자동 파견 수익 상세 내역, 전원 출격 버튼

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
