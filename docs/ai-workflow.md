# AI 작업 가이드

## 목적

이 문서는 AI가 이 프로젝트에서 작업할 때 어떤 문서를 먼저 읽고, 어떤 기준으로 수정 범위를 잡아야 하는지 안내하는 운영 문서다.

## 시작 순서

1. [문서 인덱스](D:/Project/side/dockclicker/docs/document-index.md)
문서 전체 구조와 이동 경로를 먼저 확인한다.

2. [프로젝트 정보](D:/Project/side/dockclicker/docs/project-information.md)
현재 엔진 버전, 엔트리 포인트, 검증 방식, 프로젝트 상태를 확인한다.

3. [구현된 기능](D:/Project/side/dockclicker/docs/implemented-features.md)
이미 존재하는 구조와 문서화된 범위를 확인한다.

4. [아직 없는 기능](D:/Project/side/dockclicker/docs/missing-features.md)
작업 후보와 미구현 범위를 확인한다.

5. 필요 시 아래 문서를 추가로 읽는다.
- 시스템 설계가 필요하면 [Dispatch Clicker 기획서](D:/Project/side/dockclicker/docs/dispatch-clicker-design.md)
- 화면/UI 작업이면 [Dispatch Clicker 디자인 문서](D:/Project/side/dockclicker/docs/dispatch-clicker-visual-design.md)
- 폴더/파일 책임이 필요하면 [Godot 프로젝트 구조](D:/Project/side/dockclicker/docs/godot-project-structure.md)
- 현재 구현 단계 계획을 확인하려면 [현재 우선순위](D:/Project/side/dockclicker/docs/current-priorities.md)

## 현재 기준 사실상 소스 오브 트루스

- 게임 시스템 방향: `dispatch-clicker-design.md`
- 화면 구조와 비주얼 방향: `dispatch-clicker-visual-design.md`
- 프로젝트 구조와 폴더 책임: `godot-project-structure.md`
- 실제 저장소 반영 상태: `implemented-features.md`
- 아직 없는 작업 범위: `missing-features.md`
- 당장 진행할 작업 순서: `current-priorities.md`

## 수정 원칙

- 새 기능을 추가할 때는 먼저 기존 문서와 충돌하는지 확인한다.
- 구현 상태가 바뀌면 `implemented-features.md` 와 `missing-features.md` 를 함께 갱신한다.
- 작업 흐름이나 시작 순서가 바뀌면 `document-index.md` 와 이 문서를 갱신한다.
- 프로젝트 구조가 바뀌면 `godot-project-structure.md` 를 갱신한다.
- 게임 규칙이나 시스템 구조가 바뀌면 `dispatch-clicker-design.md` 를 갱신한다.
- UI 구조나 와이어프레임 방향이 바뀌면 `dispatch-clicker-visual-design.md` 를 갱신한다.

## 코드 작업 기준

- 메인 엔트리 씬은 [scenes/main/main.tscn](D:/Project/side/dockclicker/scenes/main/main.tscn) 이다.
- 앱 루트는 [scripts/core/app_root.gd](D:/Project/side/dockclicker/scripts/core/app_root.gd) 다.
- 전역 상태 시작점은 [scripts/autoload/game_state.gd](D:/Project/side/dockclicker/scripts/autoload/game_state.gd) 다.
- UI 관련 코드는 `scripts/ui/` 아래에 둔다.
- 파견/정산 로직은 추후 `scripts/dispatch/` 로 분리할 것을 전제로 한다.

## 검증 기준

- 구조 변경 후에는 `python -m unittest tests.test_project_structure` 를 실행한다.
- 새 문서나 필수 엔트리 파일을 추가했다면 구조 테스트에도 반영한다.
- 실제 Godot 에디터 동작 검증이 필요한 단계가 오면 별도 실행 검증 절차를 추가한다.

## 현재 작업 단계

- 지금은 `기획 및 프로젝트 부트스트랩 완료, 실제 MVP 구현 전` 단계다.
- 가장 자연스러운 다음 작업은 `메인 UI 구체화` 또는 `직접 파견 MVP 루프` 구현이다.
