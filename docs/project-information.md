# 프로젝트 정보

## 프로젝트 개요

- 프로젝트명: `Dispatch Clicker`
- 장르: 데스크톱 컴패니언형 방치/클리커
- 핵심 테마: `파견`, `복귀`, `정산`, `머신 조립`, `파일럿 운용`
- 목표 플랫폼: `Steam PC`
- 목표 형태: 화면 하단 가로형 / 화면 측면 세로형을 모두 지원하는 작은 창모드 게임

## 기술 정보

- 엔진: `Godot 4.6`
- 언어: `GDScript`
- 보조 검증: `Python unittest`
- 현재 렌더링 설정: `mobile`

## 현재 프로젝트 구조

- `assets/`: 리소스 보관용 폴더
- `data/`: 게임 데이터 보관용 폴더
- `docs/`: 기획, 디자인, 구조, 구현 계획 문서
- `scenes/`: Godot 씬
- `scripts/`: GDScript 코드
- `tests/`: 구조 검증 테스트

## 현재 엔트리 포인트

- 메인 씬: `scenes/main/main.tscn`
- 앱 루트 스크립트: `scripts/core/app_root.gd`
- 오토로드: `scripts/autoload/game_state.gd`, `panel_manager.gd`, `dispatch_manager.gd`, `save_manager.gd`

## 현재 메인 씬 상태

- 현재 코드 기준: 브릿지 뷰 + 서브 패널 4개(격납고, 공작실, PC 터미널, 파견 관제) + 클리커 패널로 구성.
- 직접 파견 + 자동 파견 기본 플레이 루프 완성.
- 파츠 구매 → 조립 → 파견 → 귀환 → 수령 → 재투자 전체 사이클 동작.
- 저장/불러오기, 오프라인 진행 계산 구현 완료.
- 다음 구조 목표: 좌측 격납고 / 중앙 브릿지·파일럿 라운지 / 우측 관제실로 이어지는 파노라마 함선 캔버스. 관제실은 항성지도 팝업으로 행성을 고르고, 슬롯과 기체를 편성하는 구조.

## 문서 구조

- 시작 문서: [문서 인덱스](document-index.md)
- 시스템 기획: [Dispatch Clicker 기획서](dispatch-clicker-design.md)
- 화면/와이어프레임: [Dispatch Clicker 디자인 문서](dispatch-clicker-visual-design.md)
- 프로젝트 구조: [Godot 프로젝트 구조](godot-project-structure.md)
- 구현 계획: [Godot Bootstrap 구현 계획](plans/2026-05-21-godot-bootstrap.md)
- 현재 UX 구현 계획: [UI/UX 전면 재설계 계획](plans/2026-05-27-ux-redesign.md)
- 구현 상태: [구현된 기능](implemented-features.md)
- 작업 예정: [아직 없는 기능](missing-features.md)
- AI 작업 시작점: [AI 작업 가이드](ai-workflow.md)
- 현재 작업 순서: [현재 우선순위](current-priorities.md)

## 현재 검증 방식

- 테스트 파일: `tests/test_project_structure.py`
- 검증 목적:
  - 필수 프로젝트 파일 존재 여부 확인
  - `Godot 4.6` 프로젝트 표기 확인
- 실행 명령:
  - `python -m unittest tests.test_project_structure`

## 최근 기준 상태

- MVP 플레이 루프 및 자동 파견 기반 구현 완료.
- 파일럿 시스템, 파츠 개별 인스턴스(v3), 저장/불러오기, 오프라인 진행 구현 완료.
- 현재 작업: UI/UX 통합 재설계. 플립 패널 구조를 파노라마 함선 캔버스 + 카메라 이동 구조로 전환하는 단계이며, 관제실은 항성지도 팝업 기반 편성 구조로 정리 중이다. 기본 선택 위치는 마지막으로 고른 행성으로 복원한다.
- 다음 작업: 통합 재설계 완료 후 사운드 시스템.
- AI가 작업할 때는 `구현된 기능 → 아직 없는 기능 → 현재 우선순위` 순서로 파악하는 것이 가장 효율적이다.
