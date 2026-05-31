# Living Ship Pivot 작업계획서

작성일: 2026-05-30

## 목적

현재 구현된 `Dispatch Clicker`를 새 기획 방향인 `작은 함선을 가꾸고 파일럿들과 함께 살아가는 캐릭터 운영 방치 게임`으로 전환하기 위한 요소별 작업계획서다.

목표는 기존 파견/조립/고용/ShipCanvas 구조를 버리는 것이 아니라, 그 위에 아래 축을 추가하는 것이다.

```text
다중 재화 → 시설 설치 → 파일럿 상태 변화 → 생활 행동 → 함선 공간 성장
```

## Superpowers 검토 결과

이 문서는 방향성과 범위 정리에는 충분하지만, `superpowers:writing-plans` 기준의 실행 계획으로는 아직 부족했다.  
보완해야 하는 핵심은 아래 네 가지다.

1. 각 단계가 어떤 파일을 수정하는지 명확하지 않다.
2. 세이브 마이그레이션, 오프라인 정산, 자동 재파견처럼 기존 루프와 충돌하기 쉬운 지점이 별도 체크포인트로 빠져 있지 않다.
3. `CP`라는 새 표현과 현재 코드/UI의 `CR`, `total_credits`, `credits_changed` 신호가 섞여 있어 단일 진실 공급원이 불명확하다.
4. 검증 기준은 있지만 실제 테스트 파일/명령/예상 결과가 없다.

따라서 이 문서는 `기획 전환 로드맵`으로 유지하되, 실제 구현 전에는 Phase별로 `docs/superpowers/plans/YYYY-MM-DD-...md` 형식의 세부 구현 계획을 별도로 작성한다.  
첫 구현 단위는 이 문서 하단의 `15. 첫 구현 단위 제안`을 `MVP 0`으로 보고, 그 범위만 세부 계획으로 분리하는 것이 좋다.

### 코드 기준 확인 사항

2026-05-30 현재 코드 기준으로 확인한 책임 경계는 아래와 같다.

| 영역 | 실제 파일 | 현재 책임 |
|---|---|---|
| 전역 상태/경제/고용/해금 | `scripts/autoload/game_state.gd` | `total_credits`, 기능 해금, 침대, 파일럿, 파츠, DispatchManager 래퍼 |
| 저장/마이그레이션 | `scripts/autoload/save_manager.gd` | `SAVE_VERSION := 4`, `total_credits`, 파일럿, 자동 슬롯, 격납고, 숙소 저장 |
| 자동 파견 | `scripts/dispatch/dispatch_manager.gd` | 자동 슬롯 상태, 수익 계산, 수령, 자동 재파견, 오프라인 fast-forward |
| 행성 데이터 | `data/planet_data.gd` | `sector_a`~`sector_t` 수치형 행성 데이터 |
| 파일럿 데이터 | `data/pilots_data.gd` | 티어, 비용, 보너스, 색상, flavor |
| 함선 캔버스/기지 시설 UI | `scripts/ui/ship_canvas.gd` | 숙소/브릿지/관제실/격납고, `FEATURE_DEFS` 기반 기지 시설 팝업 |
| 로밍 파일럿 | `scripts/ui/bridge_pilot.gd` | 좌우 랜덤 로밍, 클릭 말풍선 |
| 항성지도 | `scripts/ui/star_map_popup.gd` | 행성 카드, 상세, 직접/자동 파견 시작 |
| HUD | `scripts/ui/credit_hud.gd` | CR, 파견/귀환/수령 대기 상태 표시 |

### 실행 전 정리해야 할 문제

1. `CP`와 `CR` 표기
   - 코드와 UI는 현재 `CR`을 사용한다.
   - 새 기획 문서는 `CP`를 사용한다.
   - 결정이 필요하다. 추천은 내부 자원 ID를 `cp`로 두고, 화면 표기는 기존 플레이어 맥락을 살려 당분간 `CR`로 유지하는 것이다.

2. `total_credits`와 `resources["cp"]` 중복
   - 바로 `resources["cp"]`를 진실 공급원으로 바꾸면 기존 UI, 저장, 파츠, 해금, 자동 파견 호출부가 한 번에 흔들린다.
   - Phase 1에서는 `total_credits`를 호환 필드로 유지하고, `GameState.get_resource("cp")`, `add_resource("cp", amount)`, `pay_cost({"cp": n})`가 `total_credits`를 경유하도록 한다.
   - 모든 CP 사용처가 비용 딕셔너리로 바뀐 뒤에 `resources["cp"]`를 진실 공급원으로 승격한다.

3. 다중 보상 정산 시점
   - 자동 파견은 `_start_returning()`에서 `credits_earned`를 계산하고, `collect_auto_slot()`에서 지급한다.
   - 파일럿 피로/스트레스는 `수령`이 아니라 `복귀 완료` 시점에 반영하는 것이 자연스럽다.
   - 다만 보상은 기존 UX와 저장 안정성을 위해 `수령` 시점 지급을 유지한다.

4. 자동 재파견과 오프라인 정산
   - `_do_auto_redispatch()`는 현재 수령 로직과 유사하게 보상 지급 후 즉시 재출격한다.
   - `_fast_forward()`는 저장된 임무를 오프라인 시간만큼 진행시키지만 보상 계산은 CP만 처리한다.
   - 다중 보상 추가 시 `_start_returning()`, `_fast_forward()`, `_do_auto_redispatch()`, `collect_auto_slot()` 네 지점을 반드시 같은 규칙으로 맞춰야 한다.

5. 테스트 상태
   - `tests/test_ship_canvas_structure.py`에는 현재 `star_map_popup.gd`에 없는 과거 메서드명(`_open_ship_popup`, `_confirm_dispatch`) 검사가 남아 있다.
   - Living Ship 구현 전에 테스트를 현 코드에 맞게 갱신하거나, 새 테스트를 추가할 때 이 실패를 같이 정리해야 한다.

## 현재 구현 요약

현재 코드는 이미 피벗에 쓸 수 있는 기반을 일부 갖고 있다.

- `ShipCanvas`: 숙소 / 브릿지 / 관제실 / 하부 격납고 구조 구현
- `QuartersZone`: 숙소 침대 8개, 침대별 3인 슬롯, 침대 해금 구현
- `BridgePilot`: 고용된 파일럿이 숙소+브릿지 구간을 좌우 로밍
- `GameState`: 기능 해금, 파일럿 고용, 침대 배정, 행성 해금, 파츠 인벤토리 보유
- `DispatchManager`: 자동 파견 슬롯, 머신 조립, 파견/복귀/수령 루프 구현
- `StarMapPopup`: 행성 선택, 직접 파견, 자동 파견 베이 선택 구현
- `ShopPopup`: 파일럿 공고판/고용 구현
- `PartsShopPopup`: 파츠 구매와 클릭 강화 구현

다만 아직 핵심 구조는 `CP 단일 경제`, `행성별 CR 수익 스케일`, `파일럿 보너스 수치`, `침대 수용량`, `랜덤 로밍` 중심이다.  
새 방향에 필요한 `특수재료`, `생활 시설`, `파일럿 피로/기분/스트레스`, `시설 기반 행동`, `함선 공간 성장`은 아직 별도 시스템으로 존재하지 않는다.

## 1. 경제 / 다중 재화

### 현재 구현

- `GameState.total_credits`가 사실상 유일한 범용 재화다.
- 해금, 파일럿 고용, 침대 해금, 파츠 구매, 강화가 모두 CR 비용을 사용한다.
- `SaveManager`는 `total_credits`와 `pending_credits`만 저장한다.

### 문제

CP만 있으면 모든 목표가 `돈을 더 많이 벌기`로 수렴한다.  
라운지, 식당, 의무실, 생활 시설을 추가해도 비용이 CP뿐이면 파견 지역 선택의 이유가 약하다.

### 변경 방향

`CP`는 범용 운영비로 유지하고, 특수재료를 추가한다.

초기 MVP 재화:

| 자원 | 역할 |
|---|---|
| CP | 기본 화폐, 고용, 기본 구매 |
| 합금판 | 공간/구조 확장 |
| 생활물자 | 라운지, 식당, 가구 |
| 회로칩 | 관제실, 자동화, 터미널 |

후속 재화:

| 자원 | 역할 |
|---|---|
| 생체샘플 | 의료/회복 |
| 에너지코어 | 고급 전력/후반 설비 |
| 기억파편 | 파일럿 개인 콘텐츠 |

### 작업 내용

1. `GameState`에 `resources: Dictionary` 추가
   - 예: `{ "cp": 100, "alloy": 0, "supplies": 0, "circuit": 0 }`
   - 기존 `total_credits`는 당장 제거하지 말고 `cp`와 동기화하거나 래퍼 함수로 감싼다.

2. 재화 조작 API 추가
   - `get_resource(id)`
   - `add_resource(id, amount)`
   - `can_pay(cost_dict)`
   - `pay_cost(cost_dict)`
   - `format_cost(cost_dict)`

3. 기존 CP 사용처를 단계적으로 `cost: Dictionary` 기반으로 전환
   - 기능 해금
   - 침대/구역 해금
   - 시설 설치
   - 고용
   - 파츠 구매

4. `SaveManager` 저장 버전 증가
   - v4 → v5
   - 기존 세이브의 `total_credits`를 `resources["cp"]`로 마이그레이션
   - `total_credits` 필드는 호환용으로 한동안 유지

5. HUD 확장
   - 기존 `CreditHUD`는 CP만 표시
   - 초반에는 CP + 주요 3재료를 작은 pill/row로 표시
   - 보상 수령 시 자원별 증감 연출을 추가

## 2. 파견 보상 / 행성 데이터

### 현재 구현

- `PlanetData.LIST`는 `sector_a`부터 `sector_t`까지 수치 스케일 중심이다.
- 각 행성은 `unlock_cost`, `enemy_hp`, `wave_size`, `credit_per_kill`, `max_slots`를 가진다.
- 자동 파견 수익은 머신/파일럿 보너스를 반영한 `credits_earned`만 저장한다.
- 직접 파견도 처치당 CP 보상 중심이다.

### 문제

행성이 난이도와 CP 수익만 다른 장소로 보인다.  
새 방향에서는 행성이 `필요한 재료를 얻으러 가는 장소`가 되어야 한다.

### 변경 방향

행성 데이터에 지역 타입과 재료 보상 테이블을 추가한다.

예:

```gdscript
{
    "id": "scrap_moon",
    "name": "폐기 위성",
    "region_type": "scrap",
    "primary_rewards": ["alloy", "cp"],
    "guaranteed_rewards": {"alloy": [2, 4], "cp": [80, 120]},
    "chance_rewards": [{"id": "circuit", "chance": 0.2, "amount": [1, 1]}],
}
```

### 작업 내용

1. 행성 ID/표시명 재정의
   - 기존 `섹터 A/B/C`는 임시명으로 유지 가능
   - MVP용으로 `폐기 위성`, `교역 항로`, `버려진 도시`, `생태 행성` 4개부터 의미 부여

2. `PlanetData`에 보상 필드 추가
   - `region_type`
   - `primary_rewards`
   - `guaranteed_rewards`
   - `chance_rewards`
   - `risk_level`
   - `stress_delta`
   - `fatigue_delta`

3. `DispatchManager`의 자동 파견 결과를 다중 보상으로 전환
   - `AutoSlot.credits_earned` 유지
   - `AutoSlot.rewards: Dictionary` 추가
   - 수령 시 `GameState.add_resource()`로 지급

4. 직접 파견 클리커 보상 확장
   - 처치 보상은 CP 유지
   - 웨이브 완료/복귀 시 행성별 특수재료 보장 지급
   - 고난이도 처치 드랍은 기존 파츠 드랍과 병행

5. `StarMapPopup` 정보 표시 변경
   - 현재 `적 HP`, `CR/킬`, `웨이브` 중심
   - 변경 후 `주요 보상`, `위험도`, `파일럿 피로/스트레스 영향` 표시

6. 잠긴 행성 미리보기 개선
   - 해금 비용뿐 아니라 대표 재료와 해금 목적을 보여준다.

## 3. 파일럿 상태 / 생활 데이터

### 현재 구현

- 파일럿 인스턴스는 `id`, `name`, `tier`, `bonus_type`, `bonus_value`, `portrait_color`, `status`를 가진다.
- 상태는 사실상 `idle` / `on_mission` 중심이다.
- 침대 배정은 있지만 피로 회복이나 기분 변화는 없다.

### 문제

파일럿이 `수익/속도 보너스가 붙은 슬롯 자원`처럼 동작한다.  
생활 게임으로 전환하려면 파견 결과가 파일럿 상태에 남아야 한다.

### 변경 방향

파일럿 인스턴스에 생활 상태값을 추가한다.

초기 MVP:

| 상태 | 범위 | 역할 |
|---|---|---|
| fatigue | 0~100 | 높을수록 파견 효율 감소, 휴식 필요 |
| stress | 0~100 | 위험 파견/연속 파견 누적으로 증가 |
| mood | 0~100 | 시설/휴식/선호 행동으로 회복 |

후속:

| 상태 | 역할 |
|---|---|
| injury | 부상 상태 |
| trust | 플레이어 신뢰도 |
| affinities | 행성/시설 선호 |
| relationships | 파일럿 간 관계 |

### 작업 내용

1. `hire_pilot()` / `create_custom_pilot()` 생성 데이터 확장
   - `fatigue: 0`
   - `stress: 0`
   - `mood: 70`
   - `traits: []`
   - `favorite_facilities: []`
   - `favorite_region_types: []`

2. `PilotsData`에 성격/취향 필드 추가
   - `personality`
   - `likes`
   - `dislikes`
   - `preferred_facilities`
   - `preferred_regions`

3. `SaveManager` 파일럿 직렬화 확장
   - 기존 세이브는 기본값으로 마이그레이션

4. 파견 시작 조건 보강
   - 피로 100이면 출격 불가 또는 강한 패널티
   - 피로 70 이상이면 확인 메시지 표시

5. 파견 완료 시 상태 변화
   - 행성별 `fatigue_delta`, `stress_delta` 적용
   - 선호 행성/전문 행성은 스트레스 감소 또는 숙련도 증가

6. 수령 시점이 아니라 복귀 완료 시점에 상태 변화 적용할지 결정
   - 추천: 복귀 완료 시 적용
   - 수령은 보상 지급만 담당

## 4. 생활 AI / 로밍

### 현재 구현

- `BridgePilot`은 좌우 랜덤 이동만 한다.
- 클릭 시 랜덤 인사말 말풍선을 표시한다.
- 숙소+브릿지 전체를 하나의 로밍 범위로 사용한다.

### 문제

파일럿이 어디로 가는지, 왜 거기 있는지 의미가 없다.  
시설을 설치해도 행동 목적지가 없으면 함선이 살아있어 보이지 않는다.

### 변경 방향

`랜덤 로밍`을 `상태 기반 행동 선택`으로 바꾼다.

초기 행동:

| 행동 | 조건 | 목적지 |
|---|---|---|
| wander | 기본 | 임의 위치 |
| rest | fatigue 높음 | 소파/침대 |
| eat | mood 낮음 또는 식탁 존재 | 식탁/주방 |
| play | stress 높음 | 게임 콘솔 |
| recover | injury 또는 stress 높음 | 의료 키트/의무실 |
| check_board | 출격 대기 | 게시판/관제실 근처 |

### 작업 내용

1. `BridgePilot`에 행동 상태 추가
   - `current_activity`
   - `target_point`
   - `activity_until`

2. 시설 목적지 레지스트리 추가
   - `ShipCanvas` 또는 별도 `LivingShipManager`가 설치 시설의 사용 좌표를 제공
   - 예: `get_activity_points("rest")`

3. 행동 선택 로직 추가
   - 피로/스트레스/기분을 기준으로 후보 행동 가중치 계산
   - 사용 가능한 시설이 없으면 fallback으로 wander

4. 행동 중 말풍선 추가
   - 휴식: "잠깐만 쉬고 갈게요."
   - 식사: "오늘 메뉴 괜찮네요."
   - 스트레스 높음: "이번엔 좀 쉬고 싶어요."

5. 상태 회복 틱 추가
   - 시설 근처에서 일정 시간 머물면 피로/스트레스/기분 변화
   - 초반에는 5~10초 단위의 가벼운 틱으로 충분

## 5. 라운지 시설 시스템

### 현재 구현

- 브릿지/라운지 구역은 `ShipCanvas._make_bridge_zone()`에서 제목과 파일럿 로밍 레이어만 가진다.
- 별도 라운지 시설 슬롯이나 설치 UI는 없다.
- `기지 시설` 팝업은 기능 해금 목록만 표시한다.

### 문제

플레이어가 자원을 써서 함선을 바꾸는 중심 공간이 없다.  
새 방향의 핵심인 `빈 공간이 점점 복작복작해지는 변화`가 아직 구현되지 않았다.

### 변경 방향

라운지에 고정 시설 슬롯을 추가한다.

초기 슬롯:

| 슬롯 | 설치 후보 |
|---|---|
| wall | 게시판, 책장, 포스터 |
| rest | 소파, 벤치 |
| table | 식탁, 게임 테이블 |
| service | 커피 머신, 간이 주방, 의료 키트 |
| decor | 화분, 조명 |

### 작업 내용

1. 신규 데이터 파일 추가
   - `data/facility_data.gd`
   - 시설 ID, 이름, 슬롯 타입, 비용, 효과, 행동 포인트 타입 정의

2. `GameState`에 시설 설치 상태 추가
   - `lounge_slots: Dictionary`
   - 예: `{ "rest": "sofa_1", "table": "", "service": "" }`

3. 시설 설치/교체 API 추가
   - `install_facility(slot_id, facility_id)`
   - `remove_facility(slot_id)`
   - `get_installed_facility(slot_id)`

4. 시설 설치 UI 추가
   - 기존 `기지 시설` 팝업과 분리하거나 탭 추가
   - 추천: `기지 시설`은 구역 해금, `라운지 편집`은 시설 설치로 분리

5. 브릿지/라운지 화면에 시설 렌더링
   - 초기에는 버튼/패널 형태의 플레이스홀더로 충분
   - 시설마다 사용 좌표를 함께 정의

6. 시설 효과 적용
   - 소파: rest 행동 해금, fatigue 회복
   - 식탁: eat 행동 해금, mood 회복
   - 게임 콘솔: play 행동 해금, stress 감소
   - 의료 키트: recover 행동 해금, 경상 회복 준비

## 6. 함선 구역 성장

### 현재 구현

- 기능 해금은 `pc_terminal`, `quarters`, `pilot_workshop` 3개다.
- 숙소는 별도 존으로 이미 존재한다.
- 하부 데크 격납고와 상부 숙소/브릿지/관제실 구조가 구현되어 있다.
- 침대는 개별 해금이 가능하다.

### 문제

구역 해금이 메뉴 기능 해금에 가깝고, 실제 생활 구역 확장과 연결되어 있지 않다.

### 변경 방향

기능 해금을 `함선 구역 복구`로 재정의한다.

초기 구역:

| 구역 | 역할 |
|---|---|
| bridge | 기본 홈, 최소 관제 |
| lounge | 생활 시설 중심 |
| quarters | 파일럿 수용량 |
| hangar | 머신/파견 베이 |
| canteen | 식사 행동 강화 |
| medbay | 부상/스트레스 회복 |
| workshop | 머신 정비/파츠 |

### 작업 내용

1. `FEATURE_DEFS`를 `SHIP_AREA_DEFS` 또는 `BASE_FACILITY_DEFS`로 확장
   - 비용을 `cost: Dictionary`로 변경
   - 해금 효과를 데이터에 명시

2. 현재 기능 해금과 호환 유지
   - `pc_terminal`, `quarters`, `pilot_workshop`는 당장 삭제하지 않음
   - 신규 구역 해금이 기존 기능 해금을 포함하도록 연결

3. 잠긴 구역의 시각 표현
   - 숙소 잠김 시 현재처럼 진입 차단
   - 라운지/식당/의무실은 어두운 실루엣 또는 `복구 필요` 표시

4. 구역 해금과 행동 후보 연결
   - 식당 해금 → eat 행동 강화
   - 의무실 해금 → recover 행동 강화
   - 정비실 해금 → 머신 수리/효율 관리

## 7. 숙소 / 침대 시스템

### 현재 구현

- 숙소 구역과 침대 8개가 존재한다.
- 침대당 3명 슬롯을 가진다.
- 파일럿 고용은 숙소 수용량이 있어야 가능하다.
- 침대 해금은 CP만 사용한다.

### 문제

침대가 `고용 상한 증가` 기능에 머물러 있다.  
생활 게임에서는 침대/숙소가 피로 회복과 개인 애착의 기반이 되어야 한다.

### 변경 방향

침대를 수용량 + 회복 시설로 확장한다.

### 작업 내용

1. 침대별 회복 효과 추가
   - 대기 중이고 침대 배정된 파일럿은 fatigue가 천천히 감소
   - 침대가 없거나 미배정이면 회복량 감소

2. 침대 등급 또는 시설물 추가
   - 기본 침대
   - 편한 침대
   - 개인 캡슐
   - 후속으로 개인 취향 장식

3. 침대 상세 팝업 개선
   - 현재 파일럿 카드 표시
   - 추가 표시: 피로, 스트레스, 기분, 선호/불만

4. 파일럿 수용량 정책 재검토
   - 침대당 3명은 개발 편의상 좋지만 생활감은 약할 수 있음
   - MVP는 유지하고, 추후 개인실 해금으로 애착 축을 강화

## 8. 파일럿 고용 / 캐릭터성

### 현재 구현

- 고정 파일럿 풀이 많다.
- 파일럿은 티어, 비용, 보너스 타입, 짧은 flavor를 가진다.
- 공고판은 하루 갱신/유료 갱신 방식이다.
- 커스텀 파일럿 생성이 있다.

### 문제

파일럿 차이가 주로 `speed/credits` 수치 보너스다.  
새 방향에서는 성격과 생활 취향이 더 중요해야 한다.

### 변경 방향

파일럿 데이터의 중심을 전투/수익 보너스에서 생활 성향으로 확장한다.

### 작업 내용

1. `PilotsData`에 성격 필드 추가
   - `personality`
   - `trait_tags`
   - `preferred_facilities`
   - `preferred_region_types`
   - `talk_lines`

2. 고용 카드 표시 변경
   - 기존 보너스 설명 유지
   - 성격, 선호 시설, 선호 지역을 함께 표시

3. 커스텀 파일럿 생성 확장
   - 이름/색상 외 성격 선택
   - 초기에는 3개 성격 프리셋만 제공

4. 티어 구조 재검토
   - 높은 티어가 무조건 상위호환이면 애착이 약해진다.
   - 추천: 티어는 기본 능력, 성격/전문성은 별도 축으로 둔다.

## 9. 파츠 / 머신 / 격납고

### 현재 구현

- 파츠 개별 인스턴스, 옵션, 조립, 교체, 분해가 구현되어 있다.
- 격납고 베이, 머신 상태, 베이 팝업이 구현되어 있다.
- 자동 파견 슬롯은 머신+파일럿+행성 조합으로 동작한다.

### 문제

파츠/머신은 이미 꽤 무겁고, 새 방향의 중심인 생활/시설보다 앞서 나가 있다.  
여기서 더 파밍 RPG 쪽으로 확장하면 피벗 의도가 흐려질 수 있다.

### 변경 방향

파츠는 유지하되 역할을 `수익 최적화`에서 `파견 위험/재료/파일럿 부담 조절`로 넓힌다.

### 작업 내용

1. 머신 스탯에 생활 영향 추가
   - 안전성: 파일럿 스트레스/부상 확률 감소
   - 적재량: 특수재료 획득량 증가
   - 쾌적성: 장기 파견 피로 증가 감소

2. 파츠 옵션 확장
   - `fatigue_pct`
   - `stress_pct`
   - `material_yield_pct`
   - `risk_reduce_pct`

3. 격납고 팝업 표시 확장
   - 예상 CP 외 주요 재료 수급
   - 파일럿 피로/스트레스 예상 변화

4. 머신 수리/정비는 후순위
   - 의무실/라운지 피벗이 먼저
   - 정비실 해금 후 연결

## 10. UI / 정보 표시

### 현재 구현

- CP HUD, 항성지도, 기지 시설 팝업, 고용 팝업, 파츠 팝업이 있다.
- 많은 UI가 CP 단일 비용 문구를 직접 표시한다.

### 문제

다중 재화와 파일럿 상태가 들어오면 기존 UI가 즉시 부족해진다.  
정보량이 늘어나는 만큼, 어디에 무엇을 보여줄지 정해야 한다.

### 변경 방향

UI는 `모든 정보를 한 번에 표시`하지 말고, 화면별 역할을 분명히 한다.

| 화면 | 우선 정보 |
|---|---|
| 브릿지/라운지 | 파일럿 상태, 생활 행동, 시설 |
| 관제실/항성지도 | 행성별 재료, 위험도, 파견 편성 |
| 격납고 | 머신 상태, 예상 보상, 파일럿 부담 |
| 숙소 | 수용량, 피로 회복, 개인 상태 |
| HUD | CP + 핵심 재료 3종 |

### 작업 내용

1. 공통 비용 렌더링 헬퍼 추가
   - `{"cp": 300, "alloy": 4}` 같은 비용을 모든 UI에서 동일하게 표시

2. 자원 아이콘/색상 체계 정의
   - 초기에는 텍스트 약어 가능: `CP`, `AL`, `SUP`, `CHIP`

3. 파일럿 상태 compact 표시 컴포넌트 추가
   - 피로/스트레스/기분 3줄 또는 3개 작은 바

4. 기존 CP 문구 교체
   - 기지 시설 팝업
   - 침대 해금
   - 고용 카드
   - 파츠 구매
   - 행성 해금

## 11. 직접 파견 클리커

### 현재 구현

- 직접 파견 클리커는 행성 선택, 웨이브, 클릭 데미지/범위/콤보/자동공격 강화가 구현되어 있다.
- 현재 피벗에서는 직접 파견이 주인공 루프라기보다 초기 자금/긴급 개입/특수 획득 수단으로 재배치되어야 한다.

### 변경 방향

직접 파견은 초반에 `혼자 함선을 살리는 구간`으로 유지한다.  
중후반에는 `부족한 특수재료를 직접 캐러 가는 액션 개입` 또는 `위험 파견 보조` 역할로 둔다.

### 작업 내용

1. 직접 파견 보상에 특수재료 추가
2. 초반 튜토리얼 목표와 연결
   - 첫 직접 파견
   - 첫 생활물자 획득
   - 첫 소파 설치
   - 첫 파일럿 고용
3. 직접 파견 강화는 당분간 유지하되 우선순위 하향
4. 직접 파견 결과가 함선 복구와 연결되도록 결과 화면 개선

## 12. 진행 순서

### Phase 1: 데이터 기반 전환

목표: 기존 플레이 루프를 깨지 않고 다중 재화와 파일럿 상태 기반을 추가한다.

작업:

1. `resources` 추가 및 세이브 v5 마이그레이션
2. `PlanetData`에 보상 재료 필드 추가
3. 자동 파견 보상에 `rewards` 추가
4. HUD와 항성지도에 주요 재료 표시
5. 파일럿 인스턴스에 fatigue/stress/mood 추가

완료 기준:

- 자동 파견 수령 시 CP 외 재료가 들어온다.
- 기존 세이브가 깨지지 않는다.
- 파일럿 상태가 저장/로드된다.

### Phase 2: 라운지 시설 MVP

목표: 자원을 써서 함선 내부가 실제로 바뀌는 첫 경험을 만든다.

작업:

1. `facility_data.gd` 추가
2. 라운지 고정 슬롯 5개 추가
3. 소파/식탁/게임 콘솔/커피 머신/화분 구현
4. 시설 설치 UI 구현
5. 시설 설치 비용에 특수재료 사용

완료 기준:

- 플레이어가 특수재료로 소파를 설치할 수 있다.
- 설치된 시설이 브릿지/라운지에 보인다.
- 시설 설치 후 파일럿 행동 후보가 늘어난다.

### Phase 3: 생활 행동 MVP

목표: 파일럿이 무작위로 걷는 원형이 아니라 상태에 따라 시설을 찾아가게 만든다.

작업:

1. `BridgePilot` 행동 상태 추가
2. 시설 사용 좌표 제공
3. 피로/스트레스/기분 기반 행동 선택
4. 시설 사용 중 상태 회복 틱
5. 짧은 말풍선 반응 추가

완료 기준:

- 피곤한 파일럿이 소파/침대로 이동한다.
- 스트레스 높은 파일럿이 게임 콘솔을 사용한다.
- 행동 후 상태값이 실제로 변한다.

### Phase 4: 함선 공간 성장

목표: 시설이 늘어나는 것에서 구역이 열리는 단계로 확장한다.

작업:

1. `기지 시설` 팝업을 구역 복구 UI로 정리
2. 식당 또는 의무실 1개를 신규 구역으로 구현
3. 구역 해금 비용에 다중 재화 사용
4. 구역 해금이 생활 행동에 영향을 주도록 연결

완료 기준:

- 플레이어가 특정 재료를 목표로 파견 지역을 고른다.
- 구역 해금 후 파일럿 행동과 회복 방식이 바뀐다.

### Phase 5: 애착/관계

목표: 파일럿을 단순 운용 자원이 아니라 함선 구성원으로 느끼게 한다.

작업:

1. 파일럿 성격/취향 데이터 표시
2. 선호 시설 사용 시 mood/trust 보너스
3. 파일럿 말풍선 라인 확장
4. 관계/기억파편은 이 단계 후반에 설계

완료 기준:

- 같은 시설도 파일럿 성격에 따라 반응이 다르다.
- 플레이어가 효율 외 이유로 특정 파일럿을 챙기게 된다.

## 13. 우선순위 판단

가장 먼저 해야 할 것은 `다중 재화`와 `라운지 시설`이다.  
파일럿 관계나 긴 이벤트를 먼저 넣으면 보이는 변화 없이 텍스트만 늘어난다.

추천 순서:

1. 다중 재화
2. 행성별 재료 보상
3. 라운지 시설 슬롯
4. 파일럿 피로/스트레스/기분
5. 시설 기반 행동
6. 식당/의무실 구역
7. 관계/애착

이 순서가 좋은 이유는 매 단계마다 플레이어가 체감할 수 있는 변화가 생기기 때문이다.

```text
재료가 생김 → 재료를 얻으러 행성을 고름 → 시설을 설치함 → 파일럿이 시설을 씀 → 함선이 살아 보임
```

## 14. 리스크

### 범위 증가

생활 시뮬레이션은 쉽게 커진다.  
초기에는 욕구/관계/스케줄 전체를 만들지 말고 `상태 3개 + 시설 행동 4개`로 제한한다.

### UI 과밀

재료, 상태, 시설, 관계가 한 번에 들어오면 작은 창 UI가 복잡해진다.  
각 화면의 책임을 분리하고, HUD에는 핵심 재료만 표시한다.

### 기존 파츠 시스템 과잉

파츠 시스템이 이미 강하다.  
새 방향에서는 파츠를 더 복잡하게 만들기보다, 파일럿 부담과 재료 수급에 영향을 주는 보조 축으로 조정한다.

### 세이브 호환성

`GameState` 구조 변경이 크다.  
반드시 저장 버전을 올리고, 기존 `total_credits`, `hired_pilots`, `auto_slots`를 마이그레이션한다.

## 15. 첫 구현 단위 제안

가장 작은 검증 단위는 아래 묶음이다.

1. `resources` 추가
2. 행성 3개에 보장 재료 추가
3. 자동 파견 수령 시 재료 지급
4. HUD에 CP/합금판/생활물자/회로칩 표시
5. 라운지 소파 시설 1개 설치 가능
6. 소파 설치 후 파일럿이 휴식 행동을 선택

이 단위가 완성되면 새 방향의 핵심 질문을 바로 검증할 수 있다.

```text
플레이어가 돈이 아니라 함선 내부 변화를 위해 파견을 보내게 되는가?
```

## 16. MVP 0 세부 구현 체크리스트

`superpowers:writing-plans` 기준으로 첫 구현 단위를 더 작게 쪼갠 체크리스트다.  
이 섹션은 실제 구현 전 `docs/superpowers/plans/2026-05-30-living-ship-mvp0.md` 같은 별도 실행 계획으로 복사해도 된다.

### Task 1: 다중 자원 API 추가

**Files:**

- Modify: `scripts/autoload/game_state.gd`
- Modify: `scripts/autoload/save_manager.gd`
- Test: `tests/test_living_ship_resources.py`

**목표:** 기존 `total_credits` 호출부를 깨지 않고 다중 자원 API를 추가한다.

- [x] `GameState`에 비 CP 자원 저장소를 추가한다.

```gdscript
const RESOURCE_IDS: Array = ["cp", "alloy", "supplies", "circuit"]

var resources: Dictionary = {
	"alloy": 0,
	"supplies": 0,
	"circuit": 0,
}

signal resources_changed(resources: Dictionary)
signal resource_changed(resource_id: String, new_amount: int)
```

- [x] `cp`는 Phase 1 동안 `total_credits`와 매핑한다.

```gdscript
func get_resource(resource_id: String) -> int:
	if resource_id == "cp":
		return total_credits
	return int(resources.get(resource_id, 0))

func set_resource(resource_id: String, amount: int) -> void:
	var v := maxi(0, amount)
	if resource_id == "cp":
		total_credits = v
		credits_changed.emit(total_credits)
	else:
		resources[resource_id] = v
	resources_changed.emit(resources.duplicate())
	resource_changed.emit(resource_id, v)

func add_resource(resource_id: String, amount: int) -> void:
	set_resource(resource_id, get_resource(resource_id) + amount)

func can_pay(cost: Dictionary) -> bool:
	for id in cost.keys():
		if get_resource(str(id)) < int(cost[id]):
			return false
	return true

func pay_cost(cost: Dictionary) -> bool:
	if not can_pay(cost):
		return false
	for id in cost.keys():
		add_resource(str(id), -int(cost[id]))
	return true

func format_cost(cost: Dictionary) -> String:
	var parts: Array = []
	for id in cost.keys():
		var label := "CR" if str(id) == "cp" else str(id).to_upper()
		parts.append("%d %s" % [int(cost[id]), label])
	return " · ".join(parts)
```

- [x] `SaveManager.SAVE_VERSION`을 `5`로 올린다.

```gdscript
const SAVE_VERSION := 5
```

- [x] 저장 데이터에 `resources`를 추가한다.

```gdscript
"resources": GameState.resources.duplicate(),
```

- [x] 로드 시 v4 세이브를 v5 형태로 마이그레이션한다.

```gdscript
var res_raw = d.get("resources", {})
if res_raw is Dictionary:
	GameState.resources = (res_raw as Dictionary).duplicate()
else:
	GameState.resources = {"alloy": 0, "supplies": 0, "circuit": 0}
for id in ["alloy", "supplies", "circuit"]:
	if not GameState.resources.has(id):
		GameState.resources[id] = 0
GameState.total_credits = int(d.get("total_credits", GameState.get_resource("cp")))
```

- [x] 저장 트리거에 `resources_changed`를 연결한다.

```gdscript
GameState.resources_changed.connect(func(_resources: Dictionary): save())
```

- [x] 테스트를 추가한다.

```python
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME_STATE = ROOT / "scripts" / "autoload" / "game_state.gd"
SAVE_MANAGER = ROOT / "scripts" / "autoload" / "save_manager.gd"


class LivingShipResourcesTest(unittest.TestCase):
    def test_game_state_declares_resource_api(self):
        text = GAME_STATE.read_text(encoding="utf8")
        for token in [
            "var resources: Dictionary",
            "func get_resource(",
            "func add_resource(",
            "func can_pay(",
            "func pay_cost(",
            "func format_cost(",
            "signal resources_changed",
        ]:
            self.assertIn(token, text)

    def test_save_version_and_resources_are_persisted(self):
        text = SAVE_MANAGER.read_text(encoding="utf8")
        self.assertIn("const SAVE_VERSION := 5", text)
        self.assertIn('"resources"', text)
        self.assertIn("GameState.resources", text)


if __name__ == "__main__":
    unittest.main()
```

- [x] 실행 명령과 기대 결과를 확인한다.

```bash
python -m unittest tests/test_living_ship_resources.py
```

Expected: `OK`

### Task 2: 행성 보상 데이터 추가

**Files:**

- Modify: `data/planet_data.gd`
- Test: `tests/test_living_ship_planet_rewards.py`

**목표:** 기존 행성 ID를 유지하면서 MVP 행성 4개에 의미 있는 보상 필드를 붙인다.

- [x] 최소 4개 행성에 아래 필드를 추가한다.

```gdscript
"region_type": "scrap",
"primary_rewards": ["alloy", "cp"],
"guaranteed_rewards": {"alloy": [2, 4], "cp": [80, 120]},
"chance_rewards": [{"id": "circuit", "chance": 0.2, "amount": [1, 1]}],
"risk_level": 1,
"stress_delta": 3,
"fatigue_delta": 8,
```

- [x] 초반 행성 표시명은 아래처럼 바꾼다.

| 기존 ID | 표시명 | 역할 |
|---|---|---|
| `sector_a` | 폐기 위성 | 합금판 입문 |
| `sector_b` | 교역 항로 | 생활물자 입문 |
| `sector_c` | 버려진 도시 | 회로칩 입문 |
| `sector_d` | 생태 행성 | 후속 생체샘플 준비 |

- [x] 테스트를 추가한다.

```python
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
PLANET_DATA = ROOT / "data" / "planet_data.gd"


class LivingShipPlanetRewardsTest(unittest.TestCase):
    def test_mvp_planets_have_living_ship_reward_fields(self):
        text = PLANET_DATA.read_text(encoding="utf8")
        for token in [
            '"region_type"',
            '"primary_rewards"',
            '"guaranteed_rewards"',
            '"chance_rewards"',
            '"risk_level"',
            '"stress_delta"',
            '"fatigue_delta"',
            "폐기 위성",
            "교역 항로",
            "버려진 도시",
        ]:
            self.assertIn(token, text)


if __name__ == "__main__":
    unittest.main()
```

### Task 3: 자동 파견 다중 보상 계산

**Files:**

- Modify: `scripts/dispatch/dispatch_manager.gd`
- Modify: `scripts/autoload/save_manager.gd`
- Test: `tests/test_living_ship_auto_rewards.py`

**목표:** 자동 파견이 CP 외 재료를 계산하고 저장/로드/수령한다.

- [x] `AutoSlot`에 `rewards`를 추가한다.

```gdscript
var rewards: Dictionary = {}
```

- [x] `reset_mission_data()`에서 `rewards`를 비운다.

```gdscript
rewards = {}
```

- [x] 행성 보상 계산 헬퍼를 추가한다.

```gdscript
func _roll_planet_rewards(planet_id: String) -> Dictionary:
	var planet := GameState.get_planet(planet_id)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var out: Dictionary = {}
	var guaranteed: Dictionary = planet.get("guaranteed_rewards", {})
	for id in guaranteed.keys():
		var range_raw: Array = guaranteed[id]
		var min_v := int(range_raw[0])
		var max_v := int(range_raw[1])
		out[str(id)] = int(out.get(str(id), 0)) + rng.randi_range(min_v, max_v)
	for reward in planet.get("chance_rewards", []):
		var r: Dictionary = reward
		if rng.randf() <= float(r.get("chance", 0.0)):
			var amount: Array = r.get("amount", [1, 1])
			var rid := str(r.get("id", ""))
			out[rid] = int(out.get(rid, 0)) + rng.randi_range(int(amount[0]), int(amount[1]))
	return out
```

- [x] `_start_returning()`에서 `slot.credits_earned`와 `slot.rewards`를 함께 설정한다.

```gdscript
slot.credits_earned = base_credits
slot.rewards = _roll_planet_rewards(slot.planet)
slot.rewards["cp"] = int(slot.rewards.get("cp", 0)) + base_credits
```

- [x] `collect_auto_slot()`과 `_do_auto_redispatch()`는 `GameState.add_resource()`로 지급한다.

```gdscript
for id in slot.rewards.keys():
	GameState.add_resource(str(id), int(slot.rewards[id]))
```

- [x] `SaveManager._serialize_slots()`와 `apply_save_data()`에 `rewards`를 추가한다.

```gdscript
"rewards": s.rewards.duplicate(),
```

```gdscript
var rewards_raw = d.get("rewards", {})
slot.rewards = (rewards_raw as Dictionary).duplicate() if rewards_raw is Dictionary else {}
```

- [x] `_fast_forward()`에서도 `_start_returning()`과 동일한 보상 계산 규칙을 사용한다.

### Task 4: HUD와 항성지도 표시

**Files:**

- Modify: `scripts/ui/credit_hud.gd`
- Modify: `scripts/ui/star_map_popup.gd`
- Test: `tests/test_living_ship_ui_text.py`

**목표:** 플레이어가 새 재료의 존재와 행성별 목적을 알 수 있게 한다.

- [x] HUD는 기존 CR 표시 옆에 핵심 재료 3개를 추가한다.

```text
CR 1000 | AL 3 | SUP 0 | CHIP 1 | 파견 0/1 | 귀환 0 | 대기 0
```

- [x] `CreditHUD`는 `resources_changed`와 `resource_changed`에 반응한다.

```gdscript
GameState.resources_changed.connect(func(_resources: Dictionary): _refresh_resources())
GameState.resource_changed.connect(func(_id: String, _amount: int): _refresh_resources())
```

- [x] `StarMapPopup._rebuild_detail()`은 기존 전투 수치와 함께 주요 보상/위험/피로/스트레스 정보를 표시한다.

```gdscript
var rewards := ", ".join(planet.get("primary_rewards", []))
_detail_info_label.text = "%s\n\n주요 보상  %s\n위험도  %d\n피로  +%d\n스트레스  +%d\n\n적 HP  %d\nCR/킬  %d\n웨이브  %d" % [
	str(planet.get("name", "")),
	rewards,
	int(planet.get("risk_level", 0)),
	int(planet.get("fatigue_delta", 0)),
	int(planet.get("stress_delta", 0)),
	int(planet.get("enemy_hp", 0)),
	int(planet.get("credit_per_kill", 0)),
	int(planet.get("wave_size", 0)),
]
```

### Task 5: 소파 1개 설치 MVP

**Files:**

- Create: `data/facility_data.gd`
- Modify: `scripts/autoload/game_state.gd`
- Modify: `scripts/autoload/save_manager.gd`
- Modify: `scripts/ui/ship_canvas.gd`
- Test: `tests/test_living_ship_facilities.py`

**목표:** 특수재료를 쓰면 브릿지/라운지 화면에 시설이 생기는 첫 체감 변화를 만든다.

- [x] 시설 데이터 파일을 만든다.

```gdscript
class_name FacilityData

const LIST: Array = [
	{
		"id": "sofa_1",
		"name": "낡은 소파",
		"slot_type": "rest",
		"cost": {"cp": 120, "supplies": 3},
		"activity": "rest",
		"effects": {"fatigue_recover": 2},
		"use_point": Vector2(1540, 198),
	},
]
```

- [x] `GameState`에 라운지 슬롯과 설치 API를 추가한다.

```gdscript
var lounge_slots: Dictionary = {
	"wall": "",
	"rest": "",
	"table": "",
	"service": "",
	"decor": "",
}

func install_facility(slot_id: String, facility_id: String) -> bool:
	var facility := get_facility_data(facility_id)
	if facility.is_empty():
		return false
	if str(facility.get("slot_type", "")) != slot_id:
		return false
	if not pay_cost(facility.get("cost", {})):
		return false
	lounge_slots[slot_id] = facility_id
	facilities_changed.emit()
	return true

func get_installed_facility(slot_id: String) -> String:
	return str(lounge_slots.get(slot_id, ""))
```

- [x] `ShipCanvas`의 브릿지/라운지 구역에 설치된 소파를 렌더링한다.
  - 초기에는 `PanelContainer` 또는 `Button` 형태의 플레이스홀더로 충분하다.
  - 단, 클릭 가능한 설치 UI와 실제 렌더링은 분리한다.

- [x] 저장 데이터에 `lounge_slots`를 추가한다.

### Task 6: 소파 기반 휴식 행동 최소 구현

**Files:**

- Modify: `scripts/ui/bridge_pilot.gd`
- Modify: `scripts/ui/ship_canvas.gd`
- Test: `tests/test_living_ship_activity_hooks.py`

**목표:** 시설 설치 후 파일럿 행동 후보가 실제로 늘어난다.

- [x] `BridgePilot`에 활동 상태 필드를 추가한다.

```gdscript
var current_activity: String = "wander"
var target_point: Vector2 = Vector2.ZERO
var activity_until: float = 0.0
```

- [x] `ShipCanvas`는 설치 시설의 사용 좌표를 제공한다.

```gdscript
func get_activity_points(activity: String) -> Array:
	var points: Array = []
	for slot_id in GameState.lounge_slots.keys():
		var facility_id := GameState.get_installed_facility(str(slot_id))
		if facility_id == "":
			continue
		var facility := GameState.get_facility_data(facility_id)
		if str(facility.get("activity", "")) == activity:
			points.append(facility.get("use_point", Vector2.ZERO))
	return points
```

- [x] 파일럿이 피곤하면 `rest` 후보를 선택하게 한다.
  - MVP에서는 `fatigue >= 50`이고 `rest` 포인트가 있으면 소파로 이동하는 단순 규칙으로 시작한다.
  - 피로 상태 데이터가 Task 6보다 늦어지면 임시로 `pilot_data.get("fatigue", 0)` 기본값만 읽는다.

### Task 7: 파일럿 생활 상태 기본값과 복귀 델타

**Files:**

- Modify: `scripts/autoload/game_state.gd`
- Modify: `scripts/autoload/save_manager.gd`
- Modify: `scripts/dispatch/dispatch_manager.gd`
- Test: `tests/test_living_ship_pilot_state.py`

**목표:** 소파 휴식 행동과 행성 피로/스트레스 값을 실제 파일럿 데이터에 연결한다.

- [x] 새로 고용/생성되는 파일럿에 `fatigue`, `stress`, `mood` 기본값을 추가한다.
- [x] 파일럿별 `preferred_regions`, `favorite_facilities` 저장 필드를 추가한다.
- [x] 기존 세이브의 파일럿 데이터는 기본 생활 상태로 마이그레이션한다.
- [x] `apply_pilot_state_delta()`로 상태 변경을 0~100 범위에 고정하고 `pilot_status_changed`를 발생시킨다.
- [x] 자동 파견 복귀 완료 시 행성의 `fatigue_delta`, `stress_delta`를 적용한다.

### Task 8: 휴식 행동 회복 틱과 반응

**Files:**

- Modify: `scripts/ui/bridge_pilot.gd`
- Test: `tests/test_living_ship_activity_hooks.py`

**목표:** 파일럿이 소파를 찾아가는 것에서 끝나지 않고, 시설 사용이 실제 생활 상태 변화로 이어지게 한다.

- [x] `rest` 활동 중 목적지에 도착하면 휴식 말풍선을 표시한다.
- [x] 휴식 중 5초 단위로 `fatigue -2`, `mood +1`을 적용한다.
- [x] 상태 변화는 `GameState.apply_pilot_state_delta()`를 통해 저장/화면 갱신 흐름을 탄다.

### Task 9: 침대/소파 배치 이동 MVP

**Files:**

- Modify: `scripts/autoload/game_state.gd`
- Modify: `scripts/autoload/save_manager.gd`
- Modify: `scripts/ui/ship_canvas.gd`
- Modify: `scripts/ui/quarters_zone.gd`
- Test: `tests/test_living_ship_placement.py`

**목표:** 옵션창에서 배치 이동을 켜고, 태그가 맞는 구역 안에서 침대와 소파를 grid 스냅으로 옮길 수 있게 한다.

- [x] 옵션창에 `배치 이동` 토글을 추가한다.
- [x] 침대는 `quarters`, 소파는 `lounge` 태그로 구분한다.
- [x] 침대는 숙소 영역, 소파는 라운지 영역 안으로만 저장되도록 제한한다.
- [x] 배치 위치는 32px grid로 스냅한다.
- [x] 배치 위치를 `placeable_positions`로 저장/로드한다.
- [x] 소파를 옮기면 파일럿 휴식 목적지도 새 위치를 사용한다.

### Task 10: 게임기 기반 스트레스 해소 행동 MVP

**Files:**

- Modify: `data/facility_data.gd`
- Modify: `scripts/ui/ship_canvas.gd`
- Modify: `scripts/ui/bridge_pilot.gd`
- Test: `tests/test_living_ship_facilities.py`
- Test: `tests/test_living_ship_activity_hooks.py`

**목표:** 소파의 휴식 행동 다음 단계로, 스트레스가 높은 파일럿이 라운지 게임기를 사용해 상태를 회복하게 한다.

- [x] `game_console_1` 시설 데이터를 추가한다.
  - 슬롯: `table`
  - 비용: `{"cp": 150, "supplies": 1, "circuit": 2}`
  - 활동: `play`
  - 효과: `stress_recover`

- [x] 관제실에 `라운지: 낡은 게임기 설치` 버튼을 추가한다.
- [x] 설치된 게임기는 기존 라운지 시설 렌더링/배치 시스템을 재사용한다.
- [x] `BridgePilot`이 `stress >= 50`이고 `play` 포인트가 있으면 게임기 위치로 이동한다.
- [x] `play` 활동 중 도착 말풍선을 표시한다.
- [x] `play` 활동 중 5초 단위로 `stress -2`, `mood +1`을 적용한다.

### Task 11: 커피 머신 기반 기분 회복 행동 MVP

**Files:**

- Modify: `data/facility_data.gd`
- Modify: `scripts/ui/ship_canvas.gd`
- Modify: `scripts/ui/bridge_pilot.gd`
- Test: `tests/test_living_ship_facilities.py`
- Test: `tests/test_living_ship_activity_hooks.py`

**목표:** 피로/스트레스 외에 기분이 낮은 파일럿이 생활 시설을 찾아가 mood를 회복하는 흐름을 만든다.

- [x] `coffee_machine_1` 시설 데이터를 추가한다.
  - 슬롯: `service`
  - 비용: `{"cp": 180, "supplies": 4, "circuit": 1}`
  - 활동: `eat`
  - 효과: `mood_recover`

- [x] 관제실 `시설관리` 화면에서 낡은 커피 머신을 설치할 수 있게 한다.
- [x] 설치된 커피 머신은 기존 라운지 시설 렌더링/배치 시스템을 재사용한다.
- [x] `BridgePilot`이 `mood <= 40`이고 `eat` 포인트가 있으면 커피 머신 위치로 이동한다.
- [x] `eat` 활동 중 도착 말풍선을 표시한다.
- [x] `eat` 활동 중 5초 단위로 `mood +2`를 적용한다.

### Task 12: 시설관리 화면과 해금 확인 팝업

**Files:**

- Create: `scripts/ui/facility_management_popup.gd`
- Modify: `scripts/ui/ship_canvas.gd`
- Modify: `scripts/ui/hangar_zone.gd`
- Test: `tests/test_living_ship_facility_management.py`
- Test: `tests/test_living_ship_facilities.py`

**목표:** 관제실 개별 시설 설치 버튼을 `시설관리` 화면으로 통합하고, 숙소/Bay 해금은 진행 확인 팝업을 거치게 한다.

- [x] `시설관리` 팝업을 추가한다.
  - 기존 `파츠` 팝업처럼 좌측 목록/우측 상세 구조를 사용한다.
  - `생활시설` 탭에서 라운지 시설을 설치한다.
  - `구역해금` 탭에서 주요 기능 해금을 확인한다.

- [x] 관제실에 `시설관리` 버튼을 추가한다.
- [x] 기존 관제실 개별 라운지 설치 버튼을 `시설관리` 화면으로 통합한다.
- [x] 숙소 해금 시 확인 팝업을 표시하고, 확인 시에만 해금을 진행한다.
- [x] Bay/격납고 해금 시 확인 팝업을 표시하고, 확인 시에만 해금을 진행한다.
- [x] 생활선 구조 테스트와 Godot headless 문법 검증을 통과한다.

### Task 13: 침대 회복 효과 최소 구현

**Files:**

- Modify: `scripts/autoload/game_state.gd`
- Test: `tests/test_living_ship_pilot_state.py`

**목표:** 숙소 침대에 배정된 파일럿이 시간이 지나면 피로를 회복하고 기분이 좋아지게 만든다.

- [x] `GameState`에 침대 회복 누적 틱을 추가한다.
- [x] 5초마다 침대 배정된 `idle` 파일럿의 `fatigue`를 1 줄이고 `mood`를 1 올린다.
- [x] 상태 변화는 `apply_pilot_state_delta()`를 거쳐 `pilot_status_changed`로 UI가 갱신되게 한다.
- [x] `tests/test_living_ship_pilot_state.py`에 회복 틱 존재를 검증하는 항목을 추가한다.
- [x] 생활선 테스트와 Godot headless 문법 검증을 통과한다.

## 17. 논의가 필요한 결정

아래는 구현 전에 결정하면 리워크를 줄일 수 있는 항목이다.

1. 화면 표기명을 `CR`로 유지할지, 문서처럼 `CP`로 바꿀지
   - 추천: 내부 ID `cp`, 화면 표기 `CR` 유지

2. 행성 ID를 `sector_a` 그대로 둘지, `scrap_moon` 같은 의미형 ID로 바꿀지
   - 추천: 세이브 호환성을 위해 Phase 1에서는 `sector_a` 유지, 표시명만 변경

3. 파일럿 상태 변화 시점
   - 추천: 피로/스트레스는 복귀 완료 시점, 보상 지급은 수령 시점

4. `기지 해금`과 `시설관리`를 같은 화면에서 둘지 분리할지
   - 추천: `기지 해금`은 구역 복구/확장, `시설관리`는 설치/교체로 분리

5. 테스트 갱신 범위
   - 현재 `tests/test_ship_canvas_structure.py`는 과거 메서드명을 기대한다.
   - 추천: Living Ship MVP 착수 첫 커밋에서 이 테스트를 현재 `star_map_popup.gd` 메서드명 기준으로 바로잡는다.

## 18. 구현 순서 수정안

기존 Phase 순서는 방향성으로는 좋지만, 실제 구현은 아래 순서가 더 안전하다.

1. 테스트 정리
   - 현재 실패 가능성이 있는 구조 테스트를 코드와 맞춘다.

2. 자원 API 추가
   - `total_credits` 호환 유지
   - `resources`는 우선 비 CP 재료 저장소로 시작

3. 행성 보상 데이터 추가
   - 기존 ID 유지
   - 표시명과 보상 필드만 확장

4. 자동 파견 보상 계산/저장/수령 확장
   - `_start_returning()`
   - `_fast_forward()`
   - `collect_auto_slot()`
   - `_do_auto_redispatch()`

5. HUD/항성지도 표시
   - 기능은 생겼는데 보이지 않는 상태를 피한다.

6. 소파 시설 1개 설치
   - 데이터, 저장, 설치 UI, 캔버스 렌더링

7. 휴식 행동 최소 연결
   - 상태 AI 전체가 아니라 `소파가 있으면 피곤한 파일럿이 찾아간다`만 먼저 검증한다.

이 순서로 가면 매 커밋마다 기존 게임이 실행 가능한 상태를 유지하면서 새 방향의 핵심 질문을 검증할 수 있다.
