# 화면·설정 사양

## 메인 화면

단일 창, 단일 화면이다. 기본 크기는 `1000 × 680pt`, 최소 크기는 `820 × 520pt`로 둔다.

```text
┌─────────────────────────────────────────────────────────────┐
│ RAM Monitor                                      Search     │
├──────────────────────┬──────────────────────────────────────┤
│                      │ Work unit          RAM          CPU  │
│   230pt pie chart    │ ▸ Google Chrome   3.2 GB      18%  │
│                      │ ▸ Xcode            2.1 GB       9%  │
│   top 8 legend       │ ▾ RAM Monitor      82 MB       1%  │
│                      │    RAMMonitor       80 MB       1%  │
│   total / mode       │    helper            2 MB       0%  │
└──────────────────────┴──────────────────────────────────────┘
```

- 좌측 36%: 지름 약 `230pt`의 RAM 파이 차트와 범례
- 우측 64%: 하나로 통합한 작업 그룹 목록
- 창이 좁아져도 차트 영역은 최소 `300pt`를 유지한다.

## 파이 차트

- Swift Charts의 `SectorMark`를 사용한다.
- 그룹 색상은 표시 순위가 유지되는 동안 안정적으로 유지한다.
- 범례는 상위 8개 작업, `Other`, 모드별 시스템 조각을 표시한다.
- 중앙에는 분모와 현재 측정 모드를 표시한다.
- Physical Footprint: `Physical RAM`과 전체 RAM 용량
- Resident Size: `Measured process total`과 측정 합계
- 조각에 마우스를 올리면 이름, 바이트 값, 분모 대비 백분율을 표시한다.
- 색만으로 구분하지 않고 모든 조각에 텍스트 범례와 접근성 라벨을 제공한다.

## 작업 목록

항상 표시하는 열:

- Work unit
- RAM
- CPU

설정으로 표시하는 열:

- Threads: 기본 켜짐
- PID: 기본 꺼짐
- Processes: 기본 꺼짐
- Architecture: 기본 꺼짐

기본 정렬은 RAM 내림차순이다. 열 머리글을 누르면 RAM, CPU, 이름, Processes 기준으로 정렬하고 같은 머리글을 다시 누르면 방향을 바꾼다.

그룹 행의 disclosure 버튼을 누르면 subprocess가 같은 열 구조로 펼쳐진다. subprocess에도 선택한 RAM 모드가 그대로 적용된다.

검색은 그룹 이름과 subprocess 이름을 실시간으로 필터링한다. 검색 결과에 포함된 subprocess가 있으면 부모 그룹도 남긴다.

## 설정

### General

| 키 | 선택지 | 기본값 |
|---|---|---|
| `memoryMetric` | Physical Footprint / Resident Size | `physicalFootprint` |
| `refreshInterval` | 1 / 2 / 3 / 5 / 10초 | `2` |
| `numberFormat` | Decimal / Binary | `decimal` |
| `defaultSortOrder` | RAM / CPU / Name | `memory` |
| `launchAtLogin` | 켜짐 / 꺼짐 | `false` |

### Columns

| 키 | 기본값 |
|---|---|
| `showThreadsColumn` | `true` |
| `showPIDColumn` | `false` |
| `showProcessCountColumn` | `false` |
| `showArchitectureColumn` | `false` |

CPU와 RAM 열은 끌 수 없다. 설정은 `UserDefaults`에 저장하고 로그인 시 실행은 `SMAppService.mainApp`으로 등록한다.

## 상태와 오류 표시

- 첫 샘플: RAM은 즉시 표시하고 CPU는 `—`로 표시한다.
- 일부 프로세스 접근 실패: 해당 값만 `—`로 표시한다.
- 모든 프로세스 열거 실패: 기존 목록을 지우지 않고 상단에 `Unable to refresh processes`를 표시한다.
- 검색 결과 없음: `No matching work units`를 표시한다.
- 로그인 시 실행 등록 실패: 토글을 원래 값으로 되돌리고 설정 화면에 오류를 표시한다.
- 데이터가 오래됨: 두 번 연속 갱신 실패 시 마지막 성공 시각을 표시한다.

## 기본 상호작용

- `⌘F`: 검색
- `⌘,`: 설정
- 위·아래 화살표: 그룹 선택 이동
- 왼쪽·오른쪽 화살표: 그룹 접기·펼치기
- VoiceOver 읽기 순서: 그룹명 → RAM → CPU → 선택 열 → subprocess 수
