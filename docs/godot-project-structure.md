# Godot 프로젝트 구조

## 방향

이 프로젝트는 `출시형 구조 + MVP 범위` 원칙으로 시작한다.  
즉, 폴더 구조와 책임 분리는 처음부터 확장 가능하게 잡되, 실제 구현 범위는 작은 파견 운영 MVP에 맞춰 최소로 유지한다.

## 기준

- 엔진: Godot 4.6 2D
- 목표 플랫폼: Steam PC
- 사용 형태: 데스크톱 컴패니언형 창모드 게임
- 레이아웃: 가로형 / 세로형 대응
- 우선순위: 낮은 자원 사용, 단순한 구조, 추후 확장 가능성

## 루트 구조

- `assets/`: 스프라이트, 폰트, 오디오 등 리소스
- `data/`: 파견 지역, 머신, 파일럿 등 데이터 정의
- `docs/`: 기획, 디자인, 구현 계획 문서
- `scenes/`: Godot 씬 파일
- `scripts/`: GDScript 코드
- `tests/`: 구조 및 순수 로직 검증

## 스크립트 구조

- `scripts/autoload/`: 전역 상태 및 저장 진입점
- `scripts/core/`: 앱 루트, 공통 흐름, 모드 전환
- `scripts/ui/`: 운영 패널 및 UI 제어
- `scripts/characters/`: 파일럿/SD 캐릭터 관련 로직
- `scripts/dispatch/`: 파견, 복귀, 정산 로직

## 씬 구조

- `scenes/main/`: 메인 앱 씬
- `scenes/ui/`: 모든 UI 패널 씬 (브릿지, 격납고 조립 팝업, PC 터미널, 파견 관제, 클리커, ShipCanvas, StarMapPopup 등)

## ShipCanvas 구역 구조 (현재 우선 구조)

패널 플립 대신 가로 파노라마 함선 뷰로 전환 중. `ship_canvas.gd` + `scenes/ui/ship_canvas.tscn`이 메인.

| 파일 | 역할 |
|---|---|
| `scripts/ui/ship_canvas.gd` | ShipCanvas 루트 (스크롤, 네비게이션 탭, 3구역 빌드) |
| `scripts/ui/hangar_zone.gd` | 격납고 구역 (베이 그리드, 상세 패널, 귀환 수령) |
| `scripts/ui/star_map_popup.gd` | 항성지도 팝업 (관제실에서 호출) |

## 초기 MVP 범위 (완료)

아래 항목으로 시작해 현재 전체 구현됨.

- 메인 창 1개, 가로형 기본 레이아웃
- 패널 플립 내비게이션 + 히스토리 스택
- 브릿지, 격납고 조립 팝업, PC 터미널, 파견 관제, 직접 파견 클리커 패널
- 전역 상태 오토로드 (GameState, PanelManager, DispatchManager, SaveManager)
- 직접/자동 파견 루프, 머신·파일럿 시스템, 저장/불러오기

## 이후 확장

- 현재는 기능 추가를 멈춘 상태다.
- 이후 작업은 버그 수정, 레거시 삭제, 문서/테스트 정합성 유지다.
