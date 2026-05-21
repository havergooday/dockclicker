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

## 현재 확인 가능한 화면 구조

- 가로형 기준 3구역 뼈대 존재
- `Hangar`
- `Operations Panel`
- `Bridge Lounge`
- 실제 기능은 없지만 레이아웃 자리와 진입 구조는 준비됨

## 테스트 및 검증 구현 완료

- 구조 검증 테스트 [tests/test_project_structure.py](D:/Project/side/dockclicker/tests/test_project_structure.py) 작성 완료
- 필수 파일 존재 여부 검증 가능
- `Godot 4.6` 표기 검증 가능

## 현재 상태 요약

- 플레이 가능한 게임 기능은 아직 거의 없다.
- 대신 기획, 디자인, 프로젝트 구조, 기본 엔트리 포인트, 검증 체계가 준비된 상태다.
- 즉, `개발 착수 전 기반 정리` 단계는 완료되었다.
