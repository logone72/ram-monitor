# 개발 구조

## 방향

RAM Monitor는 `actor service + @Observable view model + SwiftUI views` 구조로 새로 구현한다. 단일 구현을 위한 protocol, factory, repository 계층은 만들지 않는다. 제품 사양은 `docs/`, 저수준 호출 사양은 [`system-api.md`](system-api.md)를 source of truth로 삼는다.

```text
ProcessSampler actor
  └─ [ProcessSample] + SystemMemorySample
             ↓
SnapshotBuilder (순수 계산)
  └─ 그룹핑 + RAM 집계 + 차트 조각
             ↓
MonitorModel (@MainActor @Observable)
  └─ 갱신 + 검색 + 정렬 + 화면 상태
             ↓
SwiftUI MonitorView + SettingsView
```

## 새 프로젝트 구조

아래 경로는 이 저장소 루트를 기준으로 한다.

```text
AGENTS.md
CLAUDE.md -> AGENTS.md
.gitignore
.swift-format
.swiftlint.yml
Brewfile
Makefile
.githooks/
├── pre-commit
└── commit-msg
RAMMonitor.xcodeproj
RAMMonitor/
├── RAMMonitorApp.swift
├── UITestSample.swift (Debug UI 테스트 전용)
├── Models/
│   └── MonitorModels.swift
├── Services/
│   ├── ProcessSampler.swift
│   └── SnapshotBuilder.swift
├── ViewModels/
│   └── MonitorModel.swift
└── Views/
    ├── MonitorView.swift
    ├── MemoryPieChart.swift
    ├── ProcessGroupRow.swift
    ├── SummaryScrollConfiguration.swift
    └── SettingsView.swift
RAMMonitorTests/
├── SnapshotBuilderTests.swift
├── MonitorModelTests.swift
├── MemoryLayoutTests.swift
├── LoginItemTests.swift
└── ProcessSamplerIntegrationTests.swift
RAMMonitorUITests/
└── RAMMonitorUITests.swift
scripts/
└── build-release.sh
.github/workflows/
├── ci.yml
└── release.yml
LICENSE
README.md
```

작은 표시 helper는 사용하는 View 파일 안에 둔다. 두 화면 이상에서 실제로 중복될 때만 별도 파일로 옮긴다.

헤더와 행의 열 너비·간격은 `ProcessGroupRow.swift`의 `WorkListLayout`을 공유한다. 갱신 주기는 `MonitorSettings.refreshIntervals`, 차트 안쪽 반지름은 `MemoryPieChart`의 한 상수를 표시와 클릭 판정에 함께 사용한다. 차트 조각은 `ChartSlice.Identity.group(groupID)` 또는 `.other` 하나로 식별하며 종류를 따로 저장하지 않는다.

개발 명령과 자동 검증의 계약은 [`harness.md`](harness.md)를 따른다. 사람, Git hook, CI는 모두 `Makefile`의 같은 명령을 호출한다.

## 구성요소

### `MonitorModels.swift`

`ProcessSample`, `ProcessGroup`, `SystemMemorySample`, `MemoryMetric`, `SortOrder`, `ChartSlice`, `MonitorSnapshot`, `MonitorSettings`를 정의한다. 모든 시스템 수집 결과는 값 타입이며 `Sendable`이다.

### `ProcessSampler.swift`

`actor ProcessSampler` 하나가 다음 상태와 시스템 호출을 소유한다.

```swift
actor ProcessSampler {
  func sample() throws -> RawMonitorSample
}

struct RawMonitorSample: Sendable {
  let processes: [ProcessSample]
  let systemMemory: SystemMemorySample
  let sampledAt: Date
}
```

- 프로세스 열거, 경로, PPID, 시작 시각
- Physical Footprint, Resident Size, CPU 누적 시간, thread 수, architecture
- 전체 물리 RAM 용량(사용하지 않는 VM 통계는 수집하지 않음)
- `(pid, startTime)`별 이전 CPU 샘플
- 실행 경로별 Bundle 정보 캐시

정확한 SDK 타입, pointer 변환, 버퍼 크기, 반환값 판정, CPU tick 계산, race 처리 규칙은 [`system-api.md`](system-api.md)를 따른다.

### `SnapshotBuilder.swift`

시스템 호출 없이 입력을 결과 화면 모델로 바꾸는 순수 계산만 담당한다.

```swift
enum SnapshotBuilder {
  static func build(
    raw: RawMonitorSample,
    metric: MemoryMetric,
    topSliceCount: Int = 8
  ) -> MonitorSnapshot
}
```

그룹핑, 합계, subprocess 정렬, 파이 차트 회계는 이 함수로 모은다. 테스트는 합성 입력만 사용하므로 실행 중인 Mac의 상태에 영향을 받지 않는다.

### `MonitorModel.swift`

```swift
@Observable
@MainActor
final class MonitorModel {
  var snapshot: MonitorSnapshot?
  var searchText = ""
  var sortOrder: SortOrder = .memory
  var sortAscending = false
  var expandedGroupIDs: Set<String> = []
  var lastRefreshError: String?

  func start()
  func stop()
  func refresh() async
}
```

`MonitorModel`은 하나의 취소 가능한 `Task`로 갱신한다. 이전 갱신이 끝나기 전에 새 갱신을 겹쳐 실행하지 않는다. 설정이 바뀌면 현재 raw sample로 화면 snapshot을 즉시 다시 만들고 다음 주기부터 새 설정을 사용한다.

### Views

- `MonitorView`: 전체 36/64 분할, 검색, 목록 정렬
- `MemoryPieChart`: `ChartSlice`만 받아 표시
- `ProcessGroupRow`: 그룹과 subprocess 확장 표시
- `SettingsView`: `UserDefaults`, `SMAppService` 설정

View는 시스템 호출과 집계 계산을 수행하지 않는다.

## 플랫폼과 권한

- Swift 6 strict concurrency
- SwiftUI, Charts, Observation, AppKit, ServiceManagement, Darwin/libproc
- 외부 패키지 없음
- App Sandbox 비활성화: 다른 프로세스의 libproc 정보 열람에 필요
- Hardened Runtime 활성화
- 관리자 권한과 Accessibility 권한 요청 없음

## 구현 경계

| 영역 | RAM Monitor 처리 |
|---|---|
| 시스템 수집 | `ProcessSampler` 하나가 담당 |
| 그룹핑·회계 | `SnapshotBuilder` 순수 계산으로 분리 |
| 화면 상태 | `MonitorModel`이 갱신·검색·정렬을 담당 |
| 프로세스 표시 | 단일 목록과 subprocess 확장만 제공 |
| 설정 | RAM, 갱신, 단위, 정렬, 열, 로그인 실행만 제공 |

## 오류 원칙

- 프로세스는 수집 도중 종료될 수 있으므로 개별 실패는 정상적인 누락으로 취급한다.
- 경로를 읽었지만 metric 호출이 실패하면 행은 유지하고 metric을 `nil`로 둔다.
- 프로세스 목록 자체를 읽지 못하면 `SamplingError.processEnumerationFailed`를 던지고 마지막 성공 snapshot을 유지한다.
- 정수 합계는 overflow를 검사하고 초과 시 `UInt64.max`가 아니라 해당 집계를 `nil`로 만든다.
- unsafe pointer 범위는 각 Darwin 호출 wrapper 내부로 제한한다.
