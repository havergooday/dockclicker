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
- `docs/`: 기획, 디자인, 구조, 구현, 상태 문서
- `scenes/`: Godot 씬
- `scripts/`: GDScript 코드
- `tests/`: 구조 검증 테스트

## 현재 엔트리 포인트

- 메인 씬: `scenes/main/main.tscn`
- 앱 루트 스크립트: `scripts/core/app_root.gd`
- 오토로드: `scripts/autoload/game_state.gd`, `panel_manager.gd`, `dispatch_manager.gd`, `save_manager.gd`

## 현재 메인 씬 상태

- 현재 코드 기준: `ShipCanvas` + 클리커 패널 + 글로벌 HUD로 구성.
- `ShipCanvas` 안에서 좌측 격납고 / 중앙 브릿지·파일럿 라운지 / 우측 관제실 3구역을 배치한 상태가 현재 기준선이다.
- 관제실의 `항성지도` 팝업, 격납고 베이 팝업, 시설관리 팝업, 상점/고용 팝업 흐름은 구현되어 있다.
- 직접 파견 + 자동 파견 기본 플레이 루프, 저장/불러오기, 오프라인 진행 계산은 모두 구현 완료다.
- 현재 작업 범위는 기능 추가가 아니라 디버깅, 레거시 삭제, 문서 동기화다.

## 문서 구조

- 시작 문서: [문서 인덱스](document-index.md)
- 시스템 기획: [Dispatch Clicker 기획서](dispatch-clicker-design.md)
- 화면/와이어프레임: [Dispatch Clicker 디자인 문서](dispatch-clicker-visual-design.md)
- 프로젝트 구조: [Godot 프로젝트 구조](godot-project-structure.md)
- 기준 문서: [Godot Bootstrap 구현 계획](plans/2026-05-21-godot-bootstrap.md)
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

- 현재 저장소는 기능 개발을 멈춘 고정 상태다.
- 남은 작업은 버그 수정, 기능 삭제, 레거시 문서 정리, 구조 검증이다.
- AI가 작업할 때는 `구현된 기능 -> 아직 없는 기능 -> 현재 우선순위` 순서로 파악하는 것이 가장 효율적이다.
