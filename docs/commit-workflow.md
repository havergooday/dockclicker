# 커밋 워크플로우

## 목적

이 문서는 커밋할 때 문서 갱신을 강제하는 로컬 Git hook 규칙을 설명한다.

## 적용된 규칙

저장소는 `.githooks/pre-commit` 훅을 사용한다.  
이 훅은 커밋 직전에 스테이징된 파일을 검사한다.

다음 범주의 파일이 바뀌면 문서 변경도 함께 있어야 한다.

- `scripts/`
- `scenes/`
- `data/`
- `assets/`
- `tests/`
- `project.godot`
- `icon.svg`

위 범주의 파일이 변경됐는데 `docs/` 아래 변경이 하나도 없으면 커밋이 차단된다.

## 왜 필요한가

- 구현과 문서 상태가 계속 어긋나는 것을 막기 위해
- AI와 사람이 모두 같은 규칙으로 작업하기 위해
- 프로젝트를 다시 열었을 때 최신 상태를 문서만 보고 복구할 수 있게 하기 위해

## 권장 갱신 문서

상황에 따라 아래 문서 중 하나 이상을 같이 갱신한다.

- [구현된 기능](implemented-features.md)
- [아직 없는 기능](missing-features.md)
- [현재 우선순위](current-priorities.md)
- [프로젝트 정보](project-information.md)
- [기술 결정 기록](technical-decisions.md)
- [시스템 문서](systems/README.md)

## 설정 방법

이 저장소는 로컬 Git 설정에서 아래 hooks 경로를 사용해야 한다.

`git config core.hooksPath .githooks`

## 작업 시 참고

프로젝트를 다시 열었을 때 작업 준비가 필요하면 아래 문서를 시작점으로 사용한다.

`여길 확인해서 작업 준비해: docs/start-here.md`
