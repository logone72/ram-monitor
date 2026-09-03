# RAM·CPU 측정 규칙

## 공통 데이터

한 번의 수집 주기에서 각 프로세스에 다음 값을 기록한다.

```swift
enum MemoryMetric: String, CaseIterable, Sendable {
  case physicalFootprint
  case residentSize
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
```

- `physicalFootprintBytes`: `proc_pid_rusage(..., RUSAGE_INFO_V4, ...)`의 `ri_phys_footprint`
- `residentSizeBytes`: `proc_pidinfo(..., PROC_PIDTASKINFO, ...)`의 `pti_resident_size`
- 시스템 전체 물리 RAM: `ProcessInfo.processInfo.physicalMemory`
- 시스템 메모리 상태: `host_statistics64(..., HOST_VM_INFO64, ...)`
- 측정 실패 값은 `nil`이며 화면에는 `—`로 표시하고 합계에서는 제외한다.

## Physical Footprint 모드

기본 모드다. 목록과 그룹 합계는 Physical Footprint를 사용하고, 파이 차트 분모는 전체 물리 RAM이다.

파이 차트는 다음 순서로 만든다.

1. 그룹을 Physical Footprint 내림차순으로 정렬한다.
2. 상위 8개를 독립 조각으로 만든다.
3. 나머지 측정 그룹을 `Other`로 합친다.
4. `available = totalPhysical - min(active + wired + compressed, totalPhysical)`로 계산한다.
5. `System / Unattributed`는 전체 물리 RAM에서 프로세스 조각과 Available을 뺀 나머지다.
6. 서로 다른 커널 통계의 시점·회계 방식 때문에 합이 물리 RAM을 넘으면, **차트 조각만** 시스템 사용량 범위로 비례 축소한다. 목록의 수집 바이트 값은 유지한다.

```swift
let systemUsed = min(active + wired + compressed, totalPhysical)
let available = totalPhysical - systemUsed
let measured = groups.compactMap(\.totalPhysicalFootprintBytes).reduce(0, +)
let chartScale = measured > systemUsed && measured > 0
  ? Double(systemUsed) / Double(measured)
  : 1
let unattributed = systemUsed - min(systemUsed, measured)
```

차트 조각의 합은 항상 `totalPhysical`과 같아야 한다. 비례 축소가 발생한 경우 차트 하단에 `Process totals normalized for chart`를 작게 표시한다.

## Resident Size 모드

Resident Size는 실제 물리 RAM 전체의 구성으로 해석하지 않는다.

- 목록, 그룹 합계, 백분율, 정렬은 Resident Size를 사용한다.
- 파이 차트 분모는 `측정된 모든 프로세스 Resident Size의 합`이다.
- 조각은 상위 8개와 `Other`만 사용한다.
- `Available`과 `System / Unattributed`는 표시하지 않는다.
- 중앙 라벨은 `Measured process total`로 표시한다.

## 모드 전환 불변 조건

설정에서 모드를 바꾸면 다음 항목을 같은 화면 갱신에서 함께 교체한다.

- 그룹 RAM 값과 subprocess RAM 값
- 파이 차트 분모·조각·백분율
- RAM 기준 정렬 순서
- RAM 단위 표기

이전 모드의 값과 새 모드의 값을 한 화면에 섞지 않는다.

## CPU

CPU는 보조 지표로 유지한다.

```text
cpuDelta = (currentUser + currentSystem) - (previousUser + previousSystem)
wallDelta = currentMachTimestamp - previousMachTimestamp
cpuPercent = cpuDelta / wallDelta × 100
```

- CPU 누적값과 timestamp는 같은 Mach absolute-time 단위로 비교한다. 둘 다 변환하지 않거나 둘 다 같은 timebase로 변환해야 하며, V1은 raw tick 비율을 사용한다.
- CPU 누적값은 그대로 두고 wall delta만 나노초로 바꾸지 않는다. Apple Silicon에서는 잘못된 비율이 된다.
- 이전 값의 키는 PID 재사용을 막기 위해 `(pid, startTime)`을 사용한다.
- 첫 샘플과 시간 역전·호출 실패는 `nil`이다.
- 여러 코어를 사용하면 프로세스 또는 그룹 CPU가 100%를 넘을 수 있다.
- 사라진 프로세스의 이전 샘플은 매 주기 제거한다.

SDK 호출과 overflow 판정은 [`system-api.md`](system-api.md)의 CPU 계약을 따른다.

## 표시 단위

- 기본: decimal `GB`, `MB`
- 선택: binary `GiB`, `MiB`
- 1단위 이상은 소수점 한 자리, 그 미만은 정수 MB/MiB
- CPU는 100% 미만 소수점 한 자리, 100% 이상 정수
