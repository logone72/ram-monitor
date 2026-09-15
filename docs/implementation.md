# RAM Monitor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 새 독립 macOS 프로젝트에서 작업 그룹별 RAM을 중심으로 보여주는 RAM Monitor V1을 완성하고 DMG와 개인 Homebrew Tap으로 배포한다.

**Architecture:** `ProcessSampler → SnapshotBuilder → MonitorModel → SwiftUI`의 단방향 흐름으로 새로 구현하며, 시스템 호출과 순수 계산을 분리한다.

**Tech Stack:** Swift 6, SwiftUI, Charts, Observation, AppKit, ServiceManagement, Darwin/libproc, Swift Testing, XCTest UI Testing, swift-format, SwiftLint, Make, Git hooks, GitHub Actions.

**Spec:** [`product.md`](product.md), [`memory.md`](memory.md), [`system-api.md`](system-api.md), [`grouping.md`](grouping.md), [`interface.md`](interface.md), [`architecture.md`](architecture.md), [`harness.md`](harness.md), [`quality.md`](quality.md), [`release.md`](release.md)

**Progress:** Task 상태와 현재·다음 작업은 [`tasks.md`](tasks.md)를 기준으로 관리한다.

## Global Constraints

- 모든 경로와 명령은 이 저장소 루트를 기준으로 한다.
- 제품명은 `RAM Monitor`, 프로젝트·스킴·모듈명은 `RAMMonitor`, Bundle ID는 `com.roegankim.RAMMonitor`다.
- GitHub 저장소와 release URL은 `logone72/ram-monitor`, 개인 Tap은 `logone72/homebrew-tap`을 사용한다.
- macOS 14 Sonoma 이상, Universal 2 `arm64 + x86_64`를 지원한다.
- 공개 MIT 프로젝트이며 라이선스 표기는 `Copyright (c) 2026 Roegan Kim (logone72)`이다.
- 구현의 source of truth는 `docs/`와 활성 macOS SDK다.
- App Sandbox는 비활성화하고 Hardened Runtime은 활성화한다.
- Apple 시스템 프레임워크만 사용하고 외부 dependency를 추가하지 않는다.
- 수집 범위는 제품 사양에 정의된 RAM과 CPU다.
- 각 task는 관련 부분 검사와 `make verify`를 통과하고 독립적으로 검토 가능한 상태로 끝낸다.
- Git staging, commit, push, tag, release는 현재 요청에서 명시적으로 승인된 경우에만 수행한다.

---

### Task 1: 독립 프로젝트 기반과 개발 하네스

**Files:**

- Create: `RAMMonitor.xcodeproj`
- Create: `RAMMonitor/RAMMonitorApp.swift`
- Create: `RAMMonitor/Views/MonitorView.swift`
- Create: `RAMMonitorTests/`
- Create: `RAMMonitorUITests/`
- Create: `LICENSE`
- Create: `AGENTS.md`
- Create: `CLAUDE.md` (symlink to `AGENTS.md`)
- Create: `.gitignore`
- Create: `.swift-format`
- Create: `.swiftlint.yml`
- Create: `Brewfile`
- Create: `Makefile`
- Create: `.githooks/pre-commit`
- Create: `.githooks/commit-msg`
- Create: `.github/workflows/ci.yml`

**Interfaces:**

- Produces: 빌드 가능한 앱과 test target, 공통 개발 명령, 로컬 Git 검사, CI `verify` job
- Consumes: 없음

- [x] **Step 1: Xcode에서 새 macOS App 프로젝트 생성**

이 저장소 루트에 다음 값으로 만든다.

```text
Product Name: RAMMonitor
Team: None
Organization Identifier: com.roegankim
Interface: SwiftUI
Language: Swift
Testing System: Swift Testing with UI Tests
```

`RAMMonitor` scheme은 shared로 저장해 로컬과 CI가 같은 scheme을 사용하게 한다.

- [x] **Step 2: target 설정 고정**

앱과 테스트 target의 deployment target을 macOS 14.0으로 맞추고 앱 target에 아래 값을 설정한다.

```text
PRODUCT_NAME = RAM Monitor
PRODUCT_BUNDLE_IDENTIFIER = com.roegankim.RAMMonitor
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY = -
DEVELOPMENT_TEAM = ""
ENABLE_APP_SANDBOX = NO
ENABLE_HARDENED_RUNTIME = YES
SWIFT_VERSION = 6.0
SWIFT_STRICT_CONCURRENCY = complete
SWIFT_TREAT_WARNINGS_AS_ERRORS = YES
GCC_TREAT_WARNINGS_AS_ERRORS = YES
ARCHS = arm64 x86_64
ONLY_ACTIVE_ARCH[Release] = NO
```

- [x] **Step 3: 최소 앱 shell 작성**

```swift
import SwiftUI

@main
struct RAMMonitorApp: App {
  var body: some Scene {
    Window("RAM Monitor", id: "main") {
      MonitorView()
    }
    .defaultSize(width: 1000, height: 680)

    Settings {
      Text("Settings")
    }
  }
}
```

- [x] **Step 4: 저장소 규칙과 도구 설정 작성**

`AGENTS.md`는 다음 내용으로 시작하고 100줄 이내로 유지한다.

```markdown
# RAM Monitor

macOS 14+에서 subprocess를 작업 단위로 묶어 RAM과 CPU를 보여주는 SwiftUI 앱이다.

## Source of truth

- 제품과 기술 계약: `docs/`
- 구현 순서와 완료 조건: `docs/implementation.md`
- 시스템 호출 계약: `docs/system-api.md`

## Commands

- 환경 준비: `make bootstrap`
- 포맷 적용: `make format`
- 빠른 검사: `make check`
- 전체 검증: `make verify`

## Rules

- Swift 6 strict concurrency와 macOS 14 deployment target을 유지한다.
- 시스템 호출은 `ProcessSampler`, 순수 계산은 `SnapshotBuilder`, 화면 상태는 `MonitorModel`에 둔다.
- 앱 target에는 Apple 시스템 프레임워크만 연결한다.
- 동작 변경은 실패하는 최소 테스트를 먼저 추가하고 통과시킨다.
- 소스와 staging 상태를 hook에서 자동 변경하지 않는다.
- 변경 범위와 무관한 파일을 수정하지 않는다.
- 완료 보고에 변경 파일과 실행한 검증 결과를 적는다.
- Git staging, commit, push, release는 현재 요청에서 명시적으로 승인된 경우에만 수행한다.
```

`CLAUDE.md`는 별도 내용을 복제하지 않고 링크로 만든다.

```bash
ln -s AGENTS.md CLAUDE.md
```

`.gitignore`:

```gitignore
.DS_Store
.build/
DerivedData/
*.xcuserstate
xcuserdata/
release/
```

`.swift-format`:

```json
{
  "version": 1,
  "lineLength": 100,
  "indentation": { "spaces": 2 },
  "multiElementCollectionTrailingCommas": true
}
```

`.swiftlint.yml`:

```yaml
included:
  - RAMMonitor
  - RAMMonitorTests
  - RAMMonitorUITests

excluded:
  - .build

disabled_rules:
  - line_length
  - trailing_comma

opt_in_rules:
  - force_unwrapping

function_body_length:
  warning: 60
  error: 120

type_body_length:
  warning: 350
  error: 700

file_length:
  warning: 600
  error: 1000
```

`Brewfile`:

```ruby
brew "swiftlint"
```

- [x] **Step 5: 공통 명령 표면 작성**

`Makefile`:

```makefile
PROJECT := RAMMonitor.xcodeproj
SCHEME := RAMMonitor
DESTINATION := platform=macOS
DERIVED_DATA := .build/DerivedData
SWIFT_PATHS := RAMMonitor RAMMonitorTests RAMMonitorUITests
DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
export DEVELOPER_DIR

.PHONY: bootstrap doctor format format-check lint release-check build test analyze check verify

bootstrap:
	brew bundle --file=Brewfile
	git config core.hooksPath .githooks
	chmod +x .githooks/pre-commit .githooks/commit-msg

doctor:
	@test -x '$(DEVELOPER_DIR)/usr/bin/xcodebuild'
	@command -v xcrun >/dev/null
	@command -v swiftlint >/dev/null
	xcodebuild -version
	xcrun swift --version
	xcrun swift-format --version
	swiftlint version

format:
	xcrun swift-format format --configuration .swift-format --recursive --parallel --in-place $(SWIFT_PATHS)

format-check:
	xcrun swift-format lint --configuration .swift-format --recursive --parallel --strict $(SWIFT_PATHS)

lint:
	swiftlint lint --strict --config .swiftlint.yml

release-check:
	bash -n scripts/build-release.sh

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) build

test:
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) -enableCodeCoverage YES

analyze:
	xcodebuild analyze -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA)

check: format-check lint release-check
	git diff --check
	git diff --cached --check

verify: doctor check build test analyze
```

- [x] **Step 6: 로컬 Git 검사 작성**

`.githooks/pre-commit`:

```sh
#!/bin/sh
set -eu

make check
```

`.githooks/commit-msg`:

```sh
#!/bin/sh
set -eu

subject=$(sed -n '1p' "$1")

case "$subject" in
  Merge\ *|Revert\ *) exit 0 ;;
esac

if ! printf '%s\n' "$subject" | grep -Eq '^(feat|fix|refactor|chore|test|docs|build|ci)(\([a-z0-9._/-]+\))?!?: .+'; then
  printf '%s\n' 'Commit subject must follow Conventional Commits.' >&2
  exit 1
fi
```

두 hook은 검사만 실행하고 파일이나 staging 상태를 변경하지 않는다.

- [x] **Step 7: CI 작성**

`.github/workflows/ci.yml`:

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  verify:
    runs-on: macos-15
    timeout-minutes: 30
    env:
      DEVELOPER_DIR: /Applications/Xcode.app/Contents/Developer
    steps:
      - uses: actions/checkout@v4
      - run: brew bundle --file=Brewfile
      - run: make verify
```

- [x] **Step 8: 하네스 자체 검사**

```bash
make bootstrap
make doctor
make check

valid_message=$(mktemp)
invalid_message=$(mktemp)
trap 'rm -f "$valid_message" "$invalid_message"' EXIT
printf '%s\n' 'chore: initialize project harness' > "$valid_message"
printf '%s\n' 'initialize project harness' > "$invalid_message"
.githooks/commit-msg "$valid_message"
if .githooks/commit-msg "$invalid_message"; then exit 1; fi
```

Expected: 환경과 `make check`가 성공하고, 올바른 commit 제목은 통과하며 잘못된 제목은 실패한다.

- [x] **Step 9: 빌드와 빈 테스트 target 확인**

```bash
make verify
```

Expected: `BUILD SUCCEEDED`와 `TEST SUCCEEDED`.

- [x] **Step 10: 명시적으로 승인된 경우 첫 commit 생성**

```bash
git add AGENTS.md CLAUDE.md .gitignore .swift-format .swiftlint.yml Brewfile Makefile .githooks .github/workflows/ci.yml docs RAMMonitor.xcodeproj RAMMonitor RAMMonitorTests RAMMonitorUITests LICENSE
git commit -m "chore: initialize RAM Monitor"
```

---

### Task 2: 모델과 RAM 차트 회계

**Files:**

- Create: `RAMMonitor/Models/MonitorModels.swift`
- Create: `RAMMonitor/Services/SnapshotBuilder.swift`
- Create: `RAMMonitorTests/SnapshotBuilderTests.swift`

**Interfaces:**

- Produces: `MemoryMetric`, `BundleIdentity`, `ProcessSample`, `ProcessGroup`, `SystemMemorySample`, `RawMonitorSample`, `ChartSlice`, `MonitorSnapshot`, `SnapshotBuilder.build(raw:metric:topSliceCount:)`
- Consumes: 없음

- [x] **Step 1: Physical Footprint 차트 불변 조건 테스트 작성**

```swift
import Testing
@testable import RAMMonitor

@Suite("SnapshotBuilder")
struct SnapshotBuilderTests {
  @Test func physicalChartUsesMeasuredTotalAndKeepsPhysicalRAMSeparate() throws {
    let raw = Fixtures.raw(
      physicalRAM: 16_000,
      systemUsed: 12_000,
      processes: [
        .sample(id: 1, group: "browser", footprint: 5_000, resident: 7_000),
        .sample(id: 2, group: "editor", footprint: 3_000, resident: 4_000),
      ]
    )

    let result = SnapshotBuilder.build(raw: raw, metric: .physicalFootprint)

    #expect(result.chart.denominatorBytes == 8_000)
    #expect(result.chart.slices.reduce(0) { $0 + $1.bytes } == 8_000)
    #expect(result.totalPhysicalBytes == 16_000)
  }
}
```

- [x] **Step 2: Resident Size 분모와 top 8 테스트 작성**

```swift
extension SnapshotBuilderTests {
  @Test func residentChartUsesMeasuredProcessTotal() {
    let raw = Fixtures.rawWithTenGroups(residentBytesPerGroup: 100)
    let result = SnapshotBuilder.build(raw: raw, metric: .residentSize, topSliceCount: 8)

    #expect(result.chart.denominatorBytes == 1_000)
    #expect(result.chart.slices.filter { $0.kind == .group }.count == 8)
    #expect(result.chart.slices.first { $0.kind == .other }?.bytes == 200)
    #expect(result.chart.slices.count == 9)
  }
}
```

- [x] **Step 3: 테스트가 모델 부재로 실패하는지 확인**

```bash
xcodebuild test -project RAMMonitor.xcodeproj -scheme RAMMonitor \
  -destination 'platform=macOS' \
  -only-testing:RAMMonitorTests/SnapshotBuilderTests
```

Expected: `MemoryMetric` 또는 `SnapshotBuilder`를 찾지 못해 compile failure.

- [x] **Step 4: 모델과 builder 최소 구현**

다음 공개 표면을 정확히 구현한다.

```swift
enum MemoryMetric: String, CaseIterable, Sendable {
  case physicalFootprint
  case residentSize
}

enum SortOrder: String, CaseIterable, Sendable {
  case memory
  case cpu
  case name
  case processCount
}

struct BundleIdentity: Hashable, Sendable {
  let id: String
  let displayName: String
  let path: String
}

struct ProcessSample: Identifiable, Hashable, Sendable {
  struct Identity: Hashable, Sendable {
    let pid: pid_t
    let startTime: TimeInterval
  }

  let id: Identity
  let parentID: pid_t
  let name: String
  let path: String
  let bundle: BundleIdentity?
  let physicalFootprintBytes: UInt64?
  let residentSizeBytes: UInt64?
  let cpuPercent: Double?
  let threadCount: Int32?
  let architecture: String?
}

struct ProcessGroup: Identifiable, Sendable {
  let id: String
  let displayName: String
  let bundlePath: String?
  let processes: [ProcessSample]
  let totalPhysicalFootprintBytes: UInt64?
  let totalResidentSizeBytes: UInt64?
  let totalCPUPercent: Double?
  let totalThreads: Int32?
}

enum ChartSliceKind: Equatable, Sendable {
  case group
  case other
}

struct ChartSlice: Identifiable, Sendable {
  let id: String
  let label: String
  let bytes: UInt64
  let kind: ChartSliceKind
}

struct MemoryChart: Sendable {
  let denominatorBytes: UInt64
  let slices: [ChartSlice]
}

struct SystemMemorySample: Sendable {
  let totalPhysicalBytes: UInt64
  let activeBytes: UInt64
  let wiredBytes: UInt64
  let compressedBytes: UInt64
}

struct RawMonitorSample: Sendable {
  let processes: [ProcessSample]
  let systemMemory: SystemMemorySample
  let sampledAt: Date
}

struct MonitorSnapshot: Sendable {
  let metric: MemoryMetric
  let groups: [ProcessGroup]
  let chart: MemoryChart
  let totalPhysicalBytes: UInt64
  let sampledAt: Date
}

struct MonitorSettings: Sendable, Equatable {
  var memoryMetric: MemoryMetric = .physicalFootprint
  var refreshInterval: TimeInterval = 2
  var useBinaryUnits = false
  var defaultSortOrder: SortOrder = .memory
  var launchAtLogin = false
  var showThreadsColumn = true
  var showPIDColumn = false
  var showProcessCountColumn = false
  var showArchitectureColumn = false
}

extension ProcessGroup {
  func memoryBytes(for metric: MemoryMetric) -> UInt64? {
    switch metric {
    case .physicalFootprint: totalPhysicalFootprintBytes
    case .residentSize: totalResidentSizeBytes
    }
  }
}

enum SnapshotBuilder {
  static func build(
    raw: RawMonitorSample,
    metric: MemoryMetric,
    topSliceCount: Int = 8
  ) -> MonitorSnapshot
}

extension ProcessSample {
  func memoryBytes(for metric: MemoryMetric) -> UInt64? {
    switch metric {
    case .physicalFootprint: physicalFootprintBytes
    case .residentSize: residentSizeBytes
    }
  }
}
```

두 모드 모두 선택한 측정 그룹 합계를 분모로 사용한다. 상위 8개와 Other, 원본 바이트 보존, `nil`·0·overflow 처리를 [`memory.md`](memory.md)대로 구현한다. 물리 RAM 용량은 차트와 별도로 snapshot에 전달한다.

같은 테스트 파일에만 쓰는 fixture는 아래 표면으로 정의한다. `group`이 있으면 같은 문자열을 ID와 표시 이름으로 갖는 `BundleIdentity`를 만들고, `systemUsed`는 `activeBytes`에 넣으며 wired와 compressed는 0으로 둔다.

```swift
private enum Fixtures {
  static func raw(
    physicalRAM: UInt64 = 16_000,
    systemUsed: UInt64 = 12_000,
    processes: [ProcessSample]
  ) -> RawMonitorSample

  static func rawWithTenGroups(residentBytesPerGroup: UInt64) -> RawMonitorSample
}

private extension ProcessSample {
  static func sample(
    id: pid_t,
    group: String? = nil,
    path: String? = nil,
    bundle: BundleIdentity? = nil,
    footprint: UInt64? = 100,
    resident: UInt64? = 100,
    cpu: Double? = 0
  ) -> ProcessSample
}
```

- [x] **Step 5: builder 테스트 통과 확인**

```bash
xcodebuild test -project RAMMonitor.xcodeproj -scheme RAMMonitor \
  -destination 'platform=macOS' \
  -only-testing:RAMMonitorTests/SnapshotBuilderTests
```

Expected: `TEST SUCCEEDED`.

- [x] **Step 6: 전체 검증 후 명시적으로 승인된 경우 commit**

```bash
make verify
git add RAMMonitor/Models RAMMonitor/Services/SnapshotBuilder.swift RAMMonitorTests/SnapshotBuilderTests.swift
git commit -m "feat: add RAM snapshot accounting"
```

---

### Task 3: 프로세스 수집과 Bundle 해석

**Files:**

- Create: `RAMMonitor/Services/ProcessSampler.swift`
- Create: `RAMMonitorTests/ProcessSamplerIntegrationTests.swift`

**Interfaces:**

- Produces: `actor ProcessSampler`, `func sample() throws -> RawMonitorSample`
- Consumes: Task 2의 `ProcessSample`, `BundleIdentity`, `SystemMemorySample`, `RawMonitorSample`

- [x] **Step 1: 활성 Xcode SDK import 계약 확인**

[`system-api.md`](system-api.md)의 SDK import probe를 그대로 실행한다.

Expected: `proc_taskinfo`, `proc_archinfo`, `rusage_info_v4`, `PROC_PIDTASKINFO`, `PROC_PIDARCHINFO`, `MAXPATHLEN`이 compile된다. `PROC_PIDPATHINFO_MAXSIZE`와 `HOST_VM_INFO64_COUNT`는 Swift에서 직접 쓰지 않는다.

- [x] **Step 2: 실제 현재 프로세스와 CPU 단위 테스트 작성**

```swift
import Testing
@testable import RAMMonitor

@Suite("ProcessSampler integration", .serialized)
struct ProcessSamplerIntegrationTests {
  @Test func sampleContainsCurrentProcessAndPhysicalRAM() async throws {
    let sampler = ProcessSampler()
    let raw = try await sampler.sample()
    let currentPID = ProcessInfo.processInfo.processIdentifier
    let current = try #require(raw.processes.first { $0.id.pid == currentPID })

    #expect(raw.systemMemory.totalPhysicalBytes > 0)
    #expect(current.physicalFootprintBytes != nil || current.residentSizeBytes != nil)
  }

  @Test func firstCPUReadingIsUnavailable() async throws {
    let sampler = ProcessSampler()
    let raw = try await sampler.sample()
    #expect(raw.processes.allSatisfy { $0.cpuPercent == nil })
  }

  @Test func cpuUsesTheSameMachTickUnit() {
    let previous = CPUTimeSnapshot(user: 100, system: 100, timestamp: 1_000)
    let current = CPUTimeSnapshot(user: 400, system: 300, timestamp: 1_500)

    #expect(ProcessSampler.cpuPercent(previous: previous, current: current) == 100)
  }

  @Test func cpuRejectsCounterAndClockRollback() {
    let baseline = CPUTimeSnapshot(user: 100, system: 100, timestamp: 1_000)

    #expect(ProcessSampler.cpuPercent(
      previous: baseline,
      current: .init(user: 99, system: 100, timestamp: 1_500)
    ) == nil)
    #expect(ProcessSampler.cpuPercent(
      previous: baseline,
      current: .init(user: 200, system: 200, timestamp: 999)
    ) == nil)
  }
}
```

- [x] **Step 3: 테스트 실패 확인**

```bash
xcodebuild test -project RAMMonitor.xcodeproj -scheme RAMMonitor \
  -destination 'platform=macOS' \
  -only-testing:RAMMonitorTests/ProcessSamplerIntegrationTests
```

Expected: `ProcessSampler`를 찾지 못해 compile failure.

- [x] **Step 4: PID, 경로, identity 수집 구현**

[`system-api.md`](system-api.md)의 1·2절을 구현한다.

- PID 예상 개수를 읽고 2배 크기 버퍼를 만든다.
- 반환 개수가 버퍼와 같으면 최대 3회까지 두 배로 재시도한다.
- buffer size는 `pid_t` 개수가 아니라 checked byte count로 전달한다.
- 경로 버퍼는 `Int(MAXPATHLEN) * 4`로 계산한다.
- `proc_pidinfo(..., PROC_PIDTBSDINFO, ...)`가 구조체 크기를 반환한 경우에만 PPID와 시작 시각을 채운다.
- 경로 또는 identity가 없으면 PID를 제외한다. UID와 사용자명은 수집하지 않는다.

모든 기본 정보를 먼저 `[pid_t: BasicProcessInfo]`로 만든다. 그래야 부모 체인을 PID당 최대 5회의 dictionary lookup으로 해석할 수 있다.

- [x] **Step 5: RAM, CPU, thread, architecture 수집 구현**

한 수집 주기에서 아래 API를 호출한다.

```text
proc_listallpids
proc_pidpath
proc_pidinfo(PROC_PIDTBSDINFO)
proc_pidinfo(PROC_PIDTASKINFO)
proc_pidinfo(PROC_PIDARCHINFO)
proc_pid_rusage(RUSAGE_INFO_V4)
host_page_size
host_statistics64(HOST_VM_INFO64)
```

`proc_taskinfo`, `proc_archinfo`, `rusage_info_v4`는 SDK가 import한 타입을 사용한다. `proc_pidinfo` 결과는 요청 구조체의 `MemoryLayout.size`와 같아야 성공이고, `proc_pid_rusage`는 `0`이어야 성공이다.

- `pti_resident_size` → Resident Size
- `ri_phys_footprint` → Physical Footprint
- `pti_threadnum` → thread count
- `CPU_TYPE_ARM64` → `Apple`, `CPU_TYPE_X86_64` → `Intel`, 나머지 → `nil`

각 unsafe pointer는 해당 private wrapper 안에서만 유효하게 둔다. 개별 metric 실패는 행을 없애지 않고 해당 값만 `nil`로 둔다.

- [x] **Step 6: CPU delta와 Bundle 해석 구현**

이전 CPU 값은 `(pid, startTime)`으로 저장하고 수집이 끝날 때 사라진 identity를 제거한다. CPU 누적 delta와 `mach_absolute_time()` delta는 같은 raw Mach tick 단위로 나눠 100을 곱한다. wall delta에만 `mach_timebase_info`를 적용하지 않는다. 첫 샘플, overflow, counter 역전, clock 역전은 `nil`이다.

Bundle은 실행 경로의 가장 바깥쪽 `.app` → 부모 체인 5단계 → XPC 상위 `.app` 순서로 해석하고 성공 결과만 경로별로 캐시한다. 부모 cycle은 방문 PID set으로 중단한다.

```swift
private func resolveBundle(
  for process: BasicProcessInfo,
  allProcesses: [pid_t: BasicProcessInfo]
) -> BundleIdentity?
```

- [x] **Step 7: 시스템 메모리 구현**

- 전체 물리 RAM은 `ProcessInfo.processInfo.physicalMemory`로 읽는다.
- page size는 `host_page_size`로 읽는다.
- `HOST_VM_INFO64_COUNT` 대신 `MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size`로 count를 계산한다.
- active, wired, compressor page count에 page size를 checked multiply한다.
- 시스템 메모리 실패는 `SamplingError`를 throw해 마지막 성공 snapshot을 유지한다.
- `mach_host_self()` 직후 `defer { mach_port_deallocate(mach_task_self_, host) }`를 등록해 모든 반환 경로에서 send right를 해제한다.

정확한 pointer rebound와 오류 표는 [`system-api.md`](system-api.md)를 그대로 따른다.

- [x] **Step 8: sampler 테스트 통과 확인**

```bash
xcodebuild test -project RAMMonitor.xcodeproj -scheme RAMMonitor \
  -destination 'platform=macOS' \
  -only-testing:RAMMonitorTests/ProcessSamplerIntegrationTests
```

Expected: `TEST SUCCEEDED`.

- [x] **Step 9: 실제 값과 수동 비교**

2초 간격으로 세 번 측정한 뒤 현재 프로세스와 Chrome 계열 프로세스의 RAM 값이 비어 있지 않고 값의 증감 방향이 Activity Monitor와 일치하는지 확인한다. Apple Silicon에서는 한 코어를 지속 사용한 테스트 프로세스가 약 100% 방향인지 확인한다.

- [x] **Step 10: 전체 검증 후 명시적으로 승인된 경우 commit**

```bash
make verify
git add RAMMonitor/Services/ProcessSampler.swift RAMMonitorTests/ProcessSamplerIntegrationTests.swift
git commit -m "feat: sample process RAM and CPU"
```

---

### Task 4: 그룹핑·검색·정렬

**Files:**

- Modify: `RAMMonitor/Services/SnapshotBuilder.swift`
- Modify: `RAMMonitorTests/SnapshotBuilderTests.swift`

**Interfaces:**

- Produces: `ProcessGroup` 집계, `MonitorSnapshot.groups`, `MonitorSnapshot.filtered(searchText:sortOrder:ascending:)`
- Consumes: Task 3에서 부여한 `ProcessSample.bundle`

- [x] **Step 1: 그룹 키와 fallback 테스트 작성**

```swift
extension SnapshotBuilderTests {
  @Test func groupsByBundleIDAndFallsBackToPath() {
    let sharedBundle = BundleIdentity(id: "com.example.browser", displayName: "Browser", path: "/Applications/Browser.app")
    let raw = Fixtures.raw(processes: [
      .sample(id: 1, path: "/Applications/Browser.app/Contents/MacOS/Browser", bundle: sharedBundle),
      .sample(id: 2, path: "/Applications/Browser.app/Contents/Frameworks/Helper", bundle: sharedBundle),
      .sample(id: 3, path: "/usr/bin/task", bundle: nil),
    ])

    let result = SnapshotBuilder.build(raw: raw, metric: .physicalFootprint)

    #expect(result.groups.first { $0.id == "com.example.browser" }?.processes.count == 2)
    #expect(result.groups.contains { $0.id == "/usr/bin/task" })
  }
}
```

- [x] **Step 2: 이름이 같고 Bundle ID가 다른 그룹을 합치지 않는 테스트 작성**

두 sample의 `displayName`은 `Browser`로 같게, Bundle ID는 `com.a.browser`, `com.b.browser`로 만들고 결과 그룹이 2개인지 검사한다.

- [x] **Step 3: 검색·정렬 테스트 작성**

그룹명 검색, 자식 이름 검색, RAM 내림차순, CPU 내림차순, locale-aware 이름 오름차순, process count 정렬을 각각 합성 snapshot으로 검사한다.

```swift
extension MonitorSnapshot {
  func filtered(
    searchText: String,
    sortOrder: SortOrder,
    ascending: Bool
  ) -> [ProcessGroup]
}
```

- [x] **Step 4: 테스트 실패 확인**

```bash
xcodebuild test -project RAMMonitor.xcodeproj -scheme RAMMonitor \
  -destination 'platform=macOS' \
  -only-testing:RAMMonitorTests/SnapshotBuilderTests
```

Expected: 새 그룹핑 또는 필터 함수에 대한 test failure.

- [x] **Step 5: 현재 그룹 기준 그대로 구현**

```swift
let groupID = process.bundle?.id ?? process.path
let displayName = process.bundle?.displayName
  ?? URL(fileURLWithPath: process.path).lastPathComponent
```

이름을 그룹 키에 추가하지 않는다. 모든 그룹을 하나의 배열로 반환한다.

- [x] **Step 6: 테스트와 전체 검증 후 명시적으로 승인된 경우 commit**

```bash
xcodebuild test -project RAMMonitor.xcodeproj -scheme RAMMonitor \
  -destination 'platform=macOS' \
  -only-testing:RAMMonitorTests/SnapshotBuilderTests
make verify
git add RAMMonitor/Services/SnapshotBuilder.swift RAMMonitorTests/SnapshotBuilderTests.swift
git commit -m "feat: group and sort work units"
```

---

### Task 5: 갱신 모델과 설정 상태

**Files:**

- Create: `RAMMonitor/ViewModels/MonitorModel.swift`
- Create: `RAMMonitorTests/MonitorModelTests.swift`

**Interfaces:**

- Produces: `MonitorModel.start()`, `stop()`, `refresh()`, `visibleGroups`, `settings`
- Consumes: `ProcessSampler.sample()`, `SnapshotBuilder.build(...)`

- [x] **Step 1: 한 번의 refresh가 snapshot을 교체하는 테스트 작성**

```swift
@Suite("MonitorModel")
struct MonitorModelTests {
 @Test @MainActor func refreshPublishesOneCoherentSnapshot() async throws {
  let process = ProcessSample(
    id: .init(pid: 1, startTime: 1),
    parentID: 0,
    name: "editor",
    path: "/Applications/Editor.app/Contents/MacOS/Editor",
    bundle: .init(id: "com.example.editor", displayName: "Editor", path: "/Applications/Editor.app"),
    physicalFootprintBytes: 100,
    residentSizeBytes: 200,
    cpuPercent: 3,
    threadCount: 4,
    architecture: "arm64"
  )
  let raw = RawMonitorSample(
    processes: [process],
    systemMemory: .init(
      totalPhysicalBytes: 16_000,
      activeBytes: 8_000,
      wiredBytes: 2_000,
      compressedBytes: 1_000
    ),
    sampledAt: .now
  )
  let defaults = try #require(UserDefaults(suiteName: #function))
  let model = MonitorModel(defaults: defaults, sample: { raw })

  model.settings.memoryMetric = .residentSize
  await model.refresh()

  let snapshot = try #require(model.snapshot)
  #expect(snapshot.metric == .residentSize)
  #expect(snapshot.chart.denominatorBytes == 200)
  #expect(model.visibleGroups.first?.memoryBytes(for: .residentSize) == 200)
 }
}
```

- [x] **Step 2: 설정 기본값과 저장 왕복 테스트 작성**

격리된 `UserDefaults` suite에서 Physical Footprint, 2초, decimal, RAM 내림차순, Threads만 켜짐을 검사한다. 값을 바꾸고 새 `MonitorModel`을 만들어 같은 값이 복원되는지 검사한다.

- [x] **Step 3: 테스트 실패 확인**

```bash
xcodebuild test -project RAMMonitor.xcodeproj -scheme RAMMonitor \
  -destination 'platform=macOS' \
  -only-testing:RAMMonitorTests/MonitorModelTests
```

Expected: `MonitorModel`을 찾지 못해 compile failure.

- [x] **Step 4: model 구현**

```swift
typealias SampleProvider = @Sendable () async throws -> RawMonitorSample

@Observable
@MainActor
final class MonitorModel {
  init(defaults: UserDefaults = .standard)
  init(defaults: UserDefaults, sample: @escaping SampleProvider)

  func start()
  func stop()
  func refresh() async
}
```

기본 initializer는 하나의 `ProcessSampler` 인스턴스를 closure에 캡처한다. `start()`는 기존 task를 취소한 뒤 `refresh → sleep` 순서로 반복한다. 갱신 실패 시 마지막 snapshot을 유지한다.

- [x] **Step 5: metric 전환과 정렬 일관성 구현**

마지막 `RawMonitorSample`을 보관하고 `memoryMetric`이 바뀌면 새 시스템 호출 없이 `SnapshotBuilder.build`를 다시 실행한다. 그 결과에 검색과 정렬을 적용해 목록과 차트를 한 번에 교체한다.

- [x] **Step 6: model 테스트 통과 확인**

```bash
xcodebuild test -project RAMMonitor.xcodeproj -scheme RAMMonitor \
  -destination 'platform=macOS' \
  -only-testing:RAMMonitorTests/MonitorModelTests
```

Expected: `TEST SUCCEEDED`.

- [x] **Step 7: 전체 검증 후 명시적으로 승인된 경우 commit**

```bash
make verify
git add RAMMonitor/ViewModels/MonitorModel.swift RAMMonitorTests/MonitorModelTests.swift
git commit -m "feat: add monitor refresh state"
```

---

### Task 6: 파이 차트와 통합 작업 목록

**Files:**

- Modify: `RAMMonitor/RAMMonitorApp.swift`
- Modify: `RAMMonitor/Views/MonitorView.swift`
- Create: `RAMMonitor/Views/MemoryPieChart.swift`
- Create: `RAMMonitor/Views/ProcessGroupRow.swift`
- Modify: `RAMMonitorUITests/RAMMonitorUITests.swift`

**Interfaces:**

- Produces: `MonitorView(model:)`, `MemoryPieChart(chart:)`, `ProcessGroupRow(...)`
- Consumes: `MonitorModel.snapshot`, `visibleGroups`, `expandedGroupIDs`, `searchText`, `sortOrder`

- [x] **Step 1: UI smoke test 작성**

```swift
func testMainWindowHasChartListAndSearch() throws {
  let app = XCUIApplication()
  app.launch()

  XCTAssertTrue(app.otherElements["memory-pie-chart"].waitForExistence(timeout: 3))
  XCTAssertTrue(app.otherElements["work-unit-list"].waitForExistence(timeout: 5))
  XCTAssertTrue(app.searchFields["Search work units"].exists)
}
```

- [x] **Step 2: UI test 실패 확인**

```bash
xcodebuild test -project RAMMonitor.xcodeproj -scheme RAMMonitor \
  -destination 'platform=macOS' \
  -only-testing:RAMMonitorUITests/RAMMonitorUITests
```

Expected: accessibility identifier를 찾지 못해 test failure.

- [x] **Step 3: 36/64 메인 레이아웃 구현**

`GeometryReader` 안의 `HStack`으로 왼쪽 폭을 전체의 36%, 최소 300pt로 계산한다. `MemoryPieChart`의 chart frame은 `230 × 230pt`로 둔다. 오른쪽에는 하나의 통합 그룹 목록을 표시한다.

- [x] **Step 4: `SectorMark`와 범례 구현**

```swift
Chart(chart.slices) { slice in
  SectorMark(
    angle: .value("Bytes", slice.bytes),
    innerRadius: .ratio(0.58),
    angularInset: 1
  )
  .foregroundStyle(by: .value("Work unit", slice.label))
}
.accessibilityIdentifier("memory-pie-chart")
```

중앙 측정 합계, top 8 범례, Other, 별도 물리 RAM 용량과 hover 정보를 [`interface.md`](interface.md)대로 표시한다.

- [x] **Step 5: 그룹과 subprocess 행 구현**

CPU와 RAM을 항상 표시한다. Threads, PID, Processes, Architecture는 설정에 따라 표시한다.

헤더와 행은 같은 스크롤 영역을 사용하고 Section 헤더를 상단에 고정한다. 항상 표시/자동 숨김 스크롤바에서 열 정렬과 헤더 고정을 검증한다.

- [x] **Step 6: 검색·열 정렬·키보드 동작 연결**

`⌘F`, 열 머리글 정렬, 위·아래 선택, 왼쪽·오른쪽 접기·펼치기를 연결하고 필수 접근성 identifier와 label을 부여한다.

- [x] **Step 7: UI test와 unit test 통과 확인**

```bash
xcodebuild test -project RAMMonitor.xcodeproj -scheme RAMMonitor \
  -destination 'platform=macOS'
```

Expected: `TEST SUCCEEDED`.

- [x] **Step 8: 전체 검증 후 명시적으로 승인된 경우 commit**

```bash
make verify
git add RAMMonitor/RAMMonitorApp.swift RAMMonitor/Views RAMMonitorUITests
git commit -m "feat: add RAM monitor dashboard"
```

---

### Task 7: 설정과 로그인 시 실행

**Files:**

- Create: `RAMMonitor/Views/SettingsView.swift`
- Modify: `RAMMonitor/RAMMonitorApp.swift`
- Modify: `RAMMonitorTests/MonitorModelTests.swift`

**Interfaces:**

- Produces: General·Columns 설정 화면, `SMAppService.mainApp` 등록 처리
- Consumes: `MonitorModel.settings`, 설정 key와 기본값

- [x] **Step 1: 설정 key 테스트 보강**

각 key를 바꾼 뒤 새 model이 Physical Footprint/Resident Size, 새로고침 간격, 단위, 기본 정렬, 네 개 열 설정을 동일하게 복원하는지 검사한다.

- [x] **Step 2: 설정 화면 구현**

```swift
Settings {
  SettingsView(model: model)
}
```

General에는 RAM mode, 1/2/3/5/10초, decimal/binary, RAM/CPU/name 기본 정렬, Launch at Login을 둔다. Columns에는 Threads/PID/Processes/Architecture만 둔다.

- [x] **Step 3: 로그인 시 실행 실패 복구 구현**

```swift
do {
  if enabled {
    try SMAppService.mainApp.register()
  } else {
    try SMAppService.mainApp.unregister()
  }
  model.settings.launchAtLogin = enabled
} catch {
  launchAtLoginError = error.localizedDescription
}
```

실패하면 저장값을 바꾸지 않고 오류를 설정 화면에 표시한다.

- [x] **Step 4: 전체 테스트와 수동 재실행 확인**

```bash
xcodebuild test -project RAMMonitor.xcodeproj -scheme RAMMonitor \
  -destination 'platform=macOS'
```

앱을 재실행해 설정이 유지되고 metric 변경 시 파이 차트와 목록이 동시에 바뀌는지 확인한다.

- [x] **Step 5: 전체 검증 후 명시적으로 승인된 경우 commit**

```bash
make verify
git add RAMMonitor/RAMMonitorApp.swift RAMMonitor/Views/SettingsView.swift RAMMonitorTests/MonitorModelTests.swift
git commit -m "feat: add monitor settings"
```

---

### Task 8: 앱 식별 정보와 공개 문서

**Files:**

- Create: `RAMMonitor/Assets.xcassets/AppIcon.appiconset/`
- Create: `README.md`
- Verify: `LICENSE`
- Modify: `RAMMonitor.xcodeproj/project.pbxproj`

**Interfaces:**

- Produces: 제품 앱 아이콘, 제품 metadata, 설치·권한 설명
- Consumes: 제품과 배포 사양

- [x] **Step 1: 새 앱 아이콘 제작과 asset 등록**

RAM 사용량을 연상시키는 원형 분할 그래픽을 제작한다.

- [x] **Step 2: README 작성**

README에는 제품 목적, 스크린샷, macOS 14+, 두 RAM 모드 차이, Sandbox 비활성화 이유, 빌드 방법, DMG 설치, Gatekeeper 최초 실행, 개인 Tap 설치, 개인정보 방침, MIT 라이선스를 포함한다.

- [x] **Step 3: 전체 검증**

```bash
make verify
```

Expected: `BUILD SUCCEEDED`, `TEST SUCCEEDED`.

- [x] **Step 4: 명시적으로 승인된 경우 commit**

```bash
git add RAMMonitor/Assets.xcassets README.md LICENSE RAMMonitor.xcodeproj
git commit -m "docs: prepare RAM Monitor public project"
```

---

### Task 9: Universal DMG와 개인 Tap release

**Files:**

- Create: `scripts/build-release.sh`
- Create: `.github/workflows/release.yml`
- External repository after release: `logone72/homebrew-tap/Casks/ram-monitor.rb`

**Interfaces:**

- Produces: `RAM-Monitor-0.1.0.dmg`, SHA-256, GitHub Release, 설치 가능한 personal cask
- Consumes: Release configuration의 `RAM Monitor.app`

- [x] **Step 1: release script self-check 작성**

스크립트의 `--verify-only` 모드가 앱의 두 아키텍처, code signature, DMG 무결성을 검사하고 하나라도 실패하면 non-zero로 종료하게 한다.

```bash
./scripts/build-release.sh --verify-only release/RAM-Monitor-0.1.0.dmg
```

Expected before implementation: 실행 파일 부재로 실패.

- [x] **Step 2: build·ad-hoc sign·DMG 생성 구현**

[`release.md`](release.md)의 7단계를 `set -euo pipefail`인 shell script로 구현한다. 임시 staging 경로는 `mktemp -d`로 만들고 `trap`으로 정리한다.

- [x] **Step 3: release script 검증**

```bash
./scripts/build-release.sh 0.1.0
lipo -archs 'release/RAM Monitor.app/Contents/MacOS/RAM Monitor'
codesign --verify --deep --strict --verbose=2 'release/RAM Monitor.app'
hdiutil verify 'release/RAM-Monitor-0.1.0.dmg'
```

Expected: `arm64 x86_64`, codesign 성공, DMG verify 성공.

- [x] **Step 4: tag release workflow 작성**

`v*` tag에서 checkout → `make verify` → `build-release.sh` → GitHub Release asset 업로드 순서로 실행한다. workflow permission은 `contents: write`만 부여한다.

- [ ] **Step 5: 사용자 직접 테스트**

사용자가 로컬 앱을 직접 실행해 RAM 모드 전환, 차트, 그룹 목록, subprocess 확장, 검색, 정렬, 열 설정과 새로고침을 확인한다. 발견한 문제와 개선 의견을 기록한다.

- [ ] **Step 6: 피드백 반영과 재검증**

사용자 피드백을 반영하고 관련 테스트와 `make verify`를 실행한다. 새 DMG를 생성해 `--verify-only` 검증까지 다시 통과한 뒤에만 라이브 배포 단계로 넘어간다.

- [ ] **Step 7: 개인 Tap cask 생성**

GitHub Release의 실제 SHA-256을 사용해 `Casks/ram-monitor.rb`를 생성하고 다음 명령으로 검사한다.

```bash
brew audit --cask --tap logone72/tap ram-monitor
brew install --cask logone72/tap/ram-monitor
```

Expected: audit 통과, `/Applications/RAM Monitor.app` 설치.

로컬 산출물 `release/ram-monitor.rb`는 실제 DMG checksum으로 생성되며 임시 Tap에서 `brew style`과 `brew audit --cask --strict`를 통과했다. 공개 Release URL과 `logone72/homebrew-tap` 생성 후 온라인 audit·설치를 수행한다.

- [ ] **Step 8: 깨끗한 사용자 설치 흐름 확인**

GitHub DMG와 Homebrew 설치를 각각 수행하고 우클릭 Open 또는 Privacy & Security의 Open Anyway 안내로 최초 실행되는지 확인한다. 앱이 관리자 암호를 요구하지 않는지 확인한다.

로컬 Release 앱 실행 smoke test는 통과했다. 격리 속성이 붙는 실제 다운로드와 깨끗한 사용자 환경 검증은 공개 Release 발행 후 수행한다.

- [x] **Step 9: full verification**

```bash
make verify
```

Expected: 모든 테스트 통과.

- [x] **Step 10: 명시적으로 승인된 release commit**

```bash
git add scripts .github README.md
git commit -m "build: add unsigned DMG release pipeline"
```

- [ ] **Step 11: 명시적으로 승인된 tag와 원격 release**

```bash
git tag v0.1.0
```

원격 push와 GitHub Release 생성은 현재 요청에서 별도로 승인된 경우에만 수행한다. 첫 release 전에 `logone72/ram-monitor`를 공개로 전환하고 `logone72/homebrew-tap`을 준비한다.

---

## 완료 조건

- [x] [`product.md`](product.md)의 V1 범위가 모두 구현됨
- [x] Physical Footprint와 Resident Size 회계 테스트 통과
- [x] SDK import, PID buffer, RAM pointer, CPU Mach tick 계약 확인
- [x] 목록·차트·백분율·정렬의 metric 일관성 확인
- [x] 하나의 통합 그룹 목록과 subprocess 확장 동작 확인
- [x] macOS 14 deployment target과 Universal 2 binary 확인
- [x] `make check`와 `make verify` 통과
- [ ] 사용자 직접 테스트와 피드백 반영 후 재검증
- [ ] pull request와 `main` push에서 CI `verify` job 통과
- [ ] GitHub DMG와 개인 Tap 설치 흐름 확인
- [x] 유료 Developer ID 없이 배포된다는 한계를 사용자 문서에 명시
