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

- 메인 씬: [scenes/main/main.tscn](D:/Project/side/dockclicker/scenes/main/main.tscn)
- 앱 루트 스크립트: [scripts/core/app_root.gd](D:/Project/side/dockclicker/scripts/core/app_root.gd)
- 전역 상태 오토로드: [scripts/autoload/game_state.gd](D:/Project/side/dockclicker/scripts/autoload/game_state.gd)

## 현재 메인 씬 상태

- 가로형 메인 레이아웃의 최소 뼈대만 존재한다.
- `Hangar`, `Operations Panel`, `Bridge Lounge` 3구역 자리가 잡혀 있다.
- 실제 파견 플레이, 정산, 캐릭터 연출, 레이아웃 전환 로직은 아직 없다.

## 문서 구조

- 시작 문서: [문서 인덱스](D:/Project/side/dockclicker/docs/document-index.md)
- 시스템 기획: [Dispatch Clicker 기획서](D:/Project/side/dockclicker/docs/dispatch-clicker-design.md)
- 화면/와이어프레임: [Dispatch Clicker 디자인 문서](D:/Project/side/dockclicker/docs/dispatch-clicker-visual-design.md)
- 프로젝트 구조: [Godot 프로젝트 구조](D:/Project/side/dockclicker/docs/godot-project-structure.md)
- 구현 계획: [Godot Bootstrap 구현 계획](D:/Project/side/dockclicker/docs/plans/2026-05-21-godot-bootstrap.md)
- 구현 상태: [구현된 기능](D:/Project/side/dockclicker/docs/implemented-features.md)
- 작업 예정: [아직 없는 기능](D:/Project/side/dockclicker/docs/missing-features.md)
- AI 작업 시작점: [AI 작업 가이드](D:/Project/side/dockclicker/docs/ai-workflow.md)
- 현재 작업 순서: [현재 우선순위](D:/Project/side/dockclicker/docs/current-priorities.md)

## 현재 검증 방식

- 테스트 파일: [tests/test_project_structure.py](D:/Project/side/dockclicker/tests/test_project_structure.py)
- 검증 목적:
  - 필수 프로젝트 파일 존재 여부 확인
  - `Godot 4.6` 프로젝트 표기 확인
- 실행 명령:
  - `python -m unittest tests.test_project_structure`

## 최근 기준 상태

- 프로젝트는 초기 부트스트랩 단계다.
- 핵심 문서와 기본 Godot 구조가 준비되어 있다.
- 이후 작업은 실제 파견 MVP 루프와 UI 구체화 방향으로 이어질 수 있다.
- AI가 작업할 때는 `문서 인덱스 → 프로젝트 정보 → 구현된 기능 → 아직 없는 기능 → AI 작업 가이드 → 현재 우선순위` 순서가 가장 효율적이다.
