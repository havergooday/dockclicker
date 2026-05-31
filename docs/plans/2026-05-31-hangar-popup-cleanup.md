# 격납고 팝업 정비 작업계획서

작성일: 2026-05-31

## 목적

문서상 7순위(UI/UX 통합 재설계) Phase 2-5 항목 "격납고 팝업: 파츠 인벤토리, 머신 조립, 함선 강화 구성"의
실제 갭을 정리한다. 코드 확인 결과 **머신 조립은 이미 완성**되어 있고, 실질 갭은 아래 세 가지다.

## 현황 분석 (코드 확인 완료)

| 기능 | 현재 위치 | 상태 |
|---|---|---|
| 머신 조립 | `hangar_bay_popup.gd` — empty 베이 → 슬롯 드로어 draft → "조립 완료"(`assemble_machine`) | ✅ 동작 |
| 파츠 교체/분해 | 동 팝업 `_build_part_selector` — 부위(body/weapon/legs)별 드로어 + 분해 환급 | ⚠️ 슬롯별만 |
| 파츠 인벤토리 전체 보기 | 없음 | ❌ 미구현 |
| 함선 강화(클릭DMG/자동공격/범위/콤보) | `parts_shop_popup.gd` "강화" 탭 = PC 터미널 | ✅ 동작 |
| 레거시 조립 패널 | `hangar_assembly.gd/.tscn` + `_open_assembly()` → `PanelManager.show_panel()` | 🗑️ 죽은 경로 |

## 결정 사항 (확정)

- **함선 강화 위치**: PC 터미널 유지 → 격납고 작업 범위에서 제외.
- **파츠 인벤토리 통합 뷰 형태**: 격납고 사이드 패널(`hangar_bay_detail`)에 "전체 파츠" 탭 추가.

## 작업 범위

### Phase 1 — 레거시 정리 (선행, 비파괴 검증 필수)
1. 삭제 전 참조 확인: `project.godot` 오토로드 + `PanelManager`/`main_panel`/`hangar_assembly` 참조처 전수 조사.
2. `hangar_bay_popup.gd`의 죽은 `_open_assembly()` 제거.
3. 미사용 플립 잔재 삭제(참조 0 확인 후): `hangar_assembly.gd/.tscn`, `panel_manager.gd`, `main_panel.gd` 등.
   - ⚠️ `PanelManager`가 오토로드면 의존 코드(`GameState.hangar_preselect_slot` 경로 등) 함께 정리.
   - `panel_clicker.gd`는 직접 파견 클리커로 **사용 중 → 유지**.
4. 검증: Godot 4.6.2 헤드리스 로드 `exit 0` + 단위 테스트 통과.

### Phase 2 — 파츠 인벤토리 통합 뷰
5. `GameState.get_inventory_summary()` — `part_inventory`를 부위·티어·옵션별 집계.
6. `hangar_bay_detail`에 "전체 파츠" 탭/섹션: 부위 그룹 + 옵션 태그 + 수량 + 일괄 분해.
7. 빈 베이가 없어도 보유 파츠 확인 가능하게.

### Phase 3 — 검증/문서
8. 구조 테스트 갱신 + 신규 `test_hangar_inventory_view`.
9. Godot 로드 + 단위 테스트 + `implemented-features.md`/`missing-features.md`/`current-priorities.md` 동기화.

## 영향 파일
- 주: `scripts/ui/hangar_bay_detail.gd`, `scripts/autoload/game_state.gd`
- 정리: `scripts/ui/hangar_bay_popup.gd`
- 삭제(참조 확인 후): 레거시 플립 잔재
- 테스트/문서

## 검증 기준
- `python -m unittest discover -s tests -p "test_*.py"` 통과
- `Godot_v4.6.2-stable_win64.exe --headless --path . --quit-after 3` → SCRIPT/Parse 에러 0, exit 0
