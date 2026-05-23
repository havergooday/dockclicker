# 구현된 기능

## 개요

이 문서는 현재 저장소에 실제로 반영된 기능, 구조, 문서를 정리한다.  
여기서 말하는 `구현된 기능`은 플레이 가능한 게임 기능뿐 아니라, 프로젝트 운영에 필요한 문서/구조/검증도 포함한다.

## 문서화 완료

- 파견 중심 게임 기획 문서 작성 완료
- 가로형/세로형 와이어프레임 및 비주얼 방향 문서 작성 완료
- Godot 프로젝트 구조 문서 작성 완료
- Godot 부트스트랩 구현 계획 문서 작성 완료
- 문서 허브 및 상태 문서 작성 완료

## 프로젝트 구조 구현 완료

- `Godot 4.6` 프로젝트 파일 생성 완료
- 기본 아이콘 파일 생성 완료
- `assets/`, `data/`, `docs/`, `scenes/`, `scripts/`, `tests/` 폴더 구조 생성 완료
- Python 캐시 및 Godot 생성물 무시용 `.gitignore` 설정 완료

## 코드/씬 스캐폴드 구현 완료

- 메인 씬 [scenes/main/main.tscn](D:/Project/side/dockclicker/scenes/main/main.tscn) 생성 완료
- 앱 루트 스크립트 [scripts/core/app_root.gd](D:/Project/side/dockclicker/scripts/core/app_root.gd) 생성 완료
- 전역 상태 오토로드 [scripts/autoload/game_state.gd](D:/Project/side/dockclicker/scripts/autoload/game_state.gd) 생성 완료
- 중앙 패널 스크립트 자리 [scripts/ui/main_panel.gd](D:/Project/side/dockclicker/scripts/ui/main_panel.gd) 생성 완료

## 패널 플립 내비게이션 시스템 구현 완료

- `PanelManager` autoload — 패널 전환 총괄, 세로 Tween 플립 (0.12s × 2)
- 브릿지 뷰 (`scenes/ui/bridge_view.tscn`) — 인터랙션 오브젝트 4개(격납고 문, 공작실 입구, PC 터미널, 관제 콘솔), 유틸 바(설정·사운드·최소화)
- 서브 패널 4개 — 각 패널별 구분 색상, 뒤로가기 버튼
  - 격납고 (`scenes/ui/panel_hangar.tscn`) — 스틸 블루
  - 공작실 (`scenes/ui/panel_workshop.tscn`) — 앰버
  - 상점 (`scenes/ui/panel_shop.tscn`) — 틸
  - 파견 관제 (`scenes/ui/panel_dispatch.tscn`) — 퍼플
- ESC 키로 어느 서브 패널에서든 브릿지로 복귀
- `scenes/main/main.tscn` — 구 3칸 레이아웃 제거, 5개 패널 인스턴스 구조로 재구성

## 테스트 및 검증 구현 완료

- 구조 검증 테스트 [tests/test_project_structure.py](D:/Project/side/dockclicker/tests/test_project_structure.py) 작성 완료
- 필수 파일 존재 여부 검증 가능
- `Godot 4.6` 표기 검증 가능

## 도커형 창 구성 완료

- 테두리 없는 창 (`borderless`) — 제목 표시줄 제거
- 항상 위 (`always_on_top`) — 다른 창 위에 유지
- 크기 고정 (`resizable=false`)
- 시작 시 화면 하단 중앙 자동 배치
- 빈 영역 드래그로 창 위치 이동 (`_unhandled_input` 기반)

## 직접 파견 클리커 시스템 구현 완료

- `GameState` 확장 — `pending_credits`, `player_status` (idle/on_mission/returned), 관련 시그널 3개
- 파견 관제 패널 (`scripts/ui/panel_dispatch.gd`) — 직접 출격 버튼, 상태별 버튼 활성화 제어
- 클리커 화면 (`scenes/ui/panel_clicker.tscn`, `scripts/ui/panel_clicker.gd`) — 외계생물 클릭, HP 바, 처치 시 보류 크레딧 적립, 복귀 버튼
- 격납고 패널 (`scripts/ui/panel_hangar.gd`) — 플레이어 슬롯 상태 표시(대기중/임무중/귀환완료), 수령 버튼
- 재화 HUD (`scenes/ui/credit_hud.tscn`, `scripts/ui/credit_hud.gd`) — 모든 패널에서 항상 표시, 수령 시 숫자 주르륵 증가, 재화 아이콘 날아가는 연출

**플레이 루프:** 브릿지 → 파견 관제(관제 콘솔 클릭) → 직접 출격 → 클리커(외계생물 클릭 → 크레딧 누적) → 복귀 → 격납고(귀환완료 수령) → 재화 HUD 수치 증가

## 현재 상태 요약

- MVP 직접 파견 플레이 루프 구현 완료.
- 브릿지 → 관제 → 클리커 → 격납고 → 재화 수령 흐름이 연결됨.
- 공작실, 상점 패널은 아직 플레이스홀더.
