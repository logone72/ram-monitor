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

기본 모드다. 목록과 그룹 합계는 Physical Footprint를 사용하며, 파이 차트 분모는 측정된 그룹의 Physical Footprint 합계다.

Physical Footprint에는 압축·스왑된 메모리의 압축 전 크기가 포함될 수 있다. 물리 RAM 용량을 넘더라도 원본 수치를 유지한다. 물리 RAM의 서로 겹치지 않는 구성 조각으로 해석하지 않는다. [Apple 메모리 설명](https://developer.apple.com/documentation/xcode/analyzing-the-memory-usage-of-your-metal-app)

## Resident Size 모드

목록과 그룹 합계는 Resident Size를 사용하며, 파이 차트 분모는 측정된 그룹의 Resident Size 합계다. 공유 메모리가 여러 프로세스에 중복 집계될 수 있으므로 실제 물리 RAM 전체의 구성으로 해석하지 않는다.

## 두 모드의 공통 차트 규칙

1. 선택한 측정값으로 그룹을 내림차순 정렬하고 상위 8개와 나머지 합계 `Other`를 표시한다.
2. 분모는 같은 snapshot의 측정 가능한 그룹 합계다. 조각의 바이트 값은 목록의 그룹 합계와 동일하며 비례 축소하지 않는다.
3. 백분율은 `조각 바이트 / 측정된 그룹 합계 × 100`이다. 이는 측정된 프로세스 메모리 안에서의 비중이며 물리 RAM 사용률이 아니다.
4. `Available`이나 `System / Unattributed` 조각을 만들지 않고 시스템 VM 통계와 프로세스 합계를 섞지 않는다.
5. 물리 RAM 용량은 snapshot의 별도 `totalPhysicalBytes`로 전달해 `Physical RAM` 요약에 표시한다. 차트 중앙은 두 모드 모두 `Measured process total`이다.
6. 측정 가능한 값이 없거나 합계가 0 또는 `UInt64` 범위를 넘으면 분모 `0`, 빈 차트로 처리한다. 일부 값이 `nil`이면 측정 가능한 값만 합산한다.
7. 검색은 목록만 필터링한다. 차트는 전체 측정 그룹을 유지하며, 비교할 때는 검색을 해제한 상위 그룹 행의 합계를 사용한다. 펼쳐진 subprocess 값을 상위 그룹과 중복해서 더하지 않는다.

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
