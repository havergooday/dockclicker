# START HERE

## 목적

AI가 프로젝트를 새로 로드했을 때, 이 문서 하나만 읽고 바로 작업 준비를 시작할 수 있도록 만든 진입 문서다.

## 사용 문구

작업 시작 시 아래처럼 지시하면 된다.

`여길 확인해서 작업 준비해: docs/start-here.md`

## 읽기 순서

1. [문서 인덱스](D:/Project/side/dockclicker/docs/document-index.md)
2. [프로젝트 정보](D:/Project/side/dockclicker/docs/project-information.md)
3. [구현된 기능](D:/Project/side/dockclicker/docs/implemented-features.md)
4. [아직 없는 기능](D:/Project/side/dockclicker/docs/missing-features.md)
5. [AI 작업 가이드](D:/Project/side/dockclicker/docs/ai-workflow.md)
6. [현재 우선순위](D:/Project/side/dockclicker/docs/current-priorities.md)

## 작업 종류별 추가 문서

- 게임 규칙/시스템 작업:
  - [Dispatch Clicker 기획서](D:/Project/side/dockclicker/docs/dispatch-clicker-design.md)
  - [시스템 문서 인덱스](D:/Project/side/dockclicker/docs/systems/README.md)

- UI/화면 작업:
  - [Dispatch Clicker 디자인 문서](D:/Project/side/dockclicker/docs/dispatch-clicker-visual-design.md)

- 구조/리팩터링 작업:
  - [Godot 프로젝트 구조](D:/Project/side/dockclicker/docs/godot-project-structure.md)
  - [기술 결정 기록](D:/Project/side/dockclicker/docs/technical-decisions.md)
  - [커밋 워크플로우](D:/Project/side/dockclicker/docs/commit-workflow.md)

## 현재 한 줄 상태

프로젝트는 `Godot 4.6 기반 부트스트랩 완료, 실제 MVP 구현 전` 상태다.

## 지금 당장 가장 자연스러운 다음 작업

- 메인 UI 구체화
- 직접 파견 MVP 루프 구현
- 저장 구조 초안 결정

## 작업 전 기억할 규칙

- 코드나 씬, 데이터, 테스트, 프로젝트 설정을 바꿨다면 문서도 같이 갱신해야 한다.
- 커밋 시 `.githooks/pre-commit` 훅이 이를 검사한다.
