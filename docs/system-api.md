# macOS 시스템 수집 계약

## 목적

이 문서는 `ProcessSampler`의 저수준 계약이다. 제품 동작의 기준은 이 저장소의 문서이고, 시스템 호출의 기준은 빌드에 사용되는 macOS SDK 헤더다.

V1은 `Darwin`과 `Foundation`만 사용한다. 별도 C bridging header, 외부 패키지, 관리자 권한, helper process는 만들지 않는다.

## 기준 API

| 수집값 | API | 성공 조건 | 실패 처리 |
|---|---|---|---|
| PID 목록 | `proc_listallpids` | 반환 개수 `> 0`, 버퍼보다 작음 | snapshot 전체 실패 |
| 실행 경로 | `proc_pidpath` | 반환 길이 `> 0` | 해당 PID 제외 |
| PPID·시작 시각 | `proc_pidinfo` + `PROC_PIDTBSDINFO` | 반환 바이트가 구조체 크기와 같음 | 해당 PID 제외 |
| Resident·CPU·thread | `proc_pidinfo` + `PROC_PIDTASKINFO` | 반환 바이트가 구조체 크기와 같음 | 각 값 `nil` |
| Physical Footprint | `proc_pid_rusage` + `RUSAGE_INFO_V4` | 반환값 `0` | 값 `nil` |
| Architecture | `proc_pidinfo` + `PROC_PIDARCHINFO` | 반환 바이트가 구조체 크기와 같음 | 값 `nil` |
| 전체 물리 RAM | `ProcessInfo.processInfo.physicalMemory` | 값 `> 0` | snapshot 전체 실패 |

`proc_pidinfo`는 실패 시 `0`을 반환할 수 있으므로 `-1`만 검사하면 안 된다. 항상 요청한 구조체의 바이트 크기와 정확히 비교한다.

## Swift import 계약

`import Darwin`에서 다음 C 구조체와 상수는 직접 사용한다.

```swift
proc_taskinfo
proc_archinfo
proc_bsdinfo
rusage_info_v4

PROC_PIDTASKINFO
PROC_PIDARCHINFO
PROC_PIDTBSDINFO
RUSAGE_INFO_V4
CPU_TYPE_ARM64
CPU_TYPE_X86_64
MAXPATHLEN
```

경로 버퍼 크기는 SDK의 `MAXPATHLEN`으로 계산한다.

```swift
let processPathCapacity = Int(MAXPATHLEN) * 4
```

- `PROC_PIDPATHINFO_MAXSIZE`를 숫자 `4096`으로 다시 선언하지 않는다.
- `PROC_PIDARCHINFO_FLAVOR` 같은 별도 상수를 만들지 않고 SDK의 `PROC_PIDARCHINFO`를 쓴다.
- `proc_taskinfo`, `proc_archinfo`, `proc_bsdinfo`를 Swift 구조체로 복제하지 않는다. 현재 SDK가 세 구조체를 직접 import한다.

문서 작성 시 사용한 Xcode SDK의 arm64 import 결과는 `proc_taskinfo` 96바이트, `proc_archinfo` 8바이트, `proc_bsdinfo` 136바이트, `rusage_info_v4` 296바이트였다. 이 숫자는 진단 참고값일 뿐 구현 상수로 쓰지 않는다.

## 공개 표면과 내부 상태

```swift
actor ProcessSampler {
  func sample() throws -> RawMonitorSample
}

enum SamplingError: Error, Sendable {
  case processEnumerationFailed(errno: Int32)
  case invalidPIDBufferSize
  case invalidSystemMemoryValue
}
```

actor가 소유하는 가변 상태는 세 개다.

```swift
private var previousCPU: [ProcessSample.Identity: CPUTimeSnapshot] = [:]
private var bundleCache: [String: BundleIdentity] = [:]
private var processInfoCache: [ProcessSample.Identity: StableProcessInfo] = [:]
```

- `previousCPU`: CPU delta 계산용이며 매 성공 주기마다 사라진 identity를 제거한다.
- `bundleCache`: 성공한 Bundle 해석만 실행 경로로 캐시한다. 실패를 캐시하기 위한 별도 enum은 만들지 않는다.
- `processInfoCache`: 같은 `(pid, startTime)`의 경로·이름·architecture를 재사용하며 매 성공 주기에 사라진 identity를 제거한다.
- 수집 결과만 `Sendable` 값 타입으로 actor 밖에 보낸다. C 구조체와 unsafe pointer는 wrapper 밖으로 노출하지 않는다.

## 한 주기의 순서

1. `Date()`와 `mach_absolute_time()`을 각각 한 번 읽는다.
2. PID 목록을 확보한다.
3. 각 PID의 경로, PPID, 시작 시각을 읽어 `[pid_t: BasicProcessInfo]`를 만든다.
4. 기본 정보가 있는 PID만 RAM, CPU, thread, architecture를 읽는다.
5. 완성된 기본 정보 사전으로 Bundle을 해석한다.
6. 전체 물리 RAM 용량을 읽는다.
7. 이번 주기에 남은 process identity로 다음 CPU 상태를 만든다.
8. 전 단계가 성공하면 CPU 상태와 두 cache를 교체하고 `RawMonitorSample` 하나를 반환한다.

커널 상태는 호출 사이에도 바뀌므로 완전한 원자적 snapshot은 아니다. 다만 `sampledAt`, CPU timestamp, 프로세스 배열, 시스템 메모리는 같은 `RawMonitorSample`에만 묶는다. 중간 결과는 화면에 게시하지 않는다. 시스템 메모리 실패나 취소가 발생하면 actor의 CPU 기준 상태도 교체하지 않는다.

## 1. PID 열거

`proc_listallpids(nil, 0)`의 반환값은 PID 개수 추정치다. 프로세스 수는 두 호출 사이에 늘 수 있으므로 한 번의 고정 버퍼에 의존하지 않는다.

구현: [`ProcessSampler.listAllPIDs`](../RAMMonitor/Services/ProcessSampler.swift).

규칙:

- `buffersize`에는 PID 개수가 아니라 **바이트 수**를 전달한다.
- 반환 개수가 capacity와 같으면 잘렸을 가능성이 있으므로 두 배 버퍼로 재시도한다.
- 최대 3회 뒤에도 가득 차면 불완전한 목록을 게시하지 않고 마지막 성공 snapshot을 유지한다.
- PID `0`과 빈 슬롯은 제외하고 중복 PID를 제거한다. 목록 순서는 제품 의미가 없다.

## 2. 경로와 process identity

### 실행 경로

구현: [`ProcessSampler.processPath`](../RAMMonitor/Services/ProcessSampler.swift).

- 반환 길이는 NUL 문자를 제외한 길이다.
- 미리 0으로 채운 배열과 반환 길이를 함께 사용해 버퍼 밖을 읽지 않는다.
- 경로가 없으면 이름과 Bundle도 신뢰할 수 없으므로 해당 PID를 제외한다.
- 표시 이름의 1차 fallback은 `(path as NSString).lastPathComponent`다.

### PPID와 시작 시각

```swift
private struct BasicProcessInfo {
  let pid: pid_t
  let parentID: pid_t
  let startTime: TimeInterval
  let name: String
  let path: String
}
```

`PROC_PIDTBSDINFO`로 `proc_bsdinfo`를 읽고 다음 필드만 사용한다.

```swift
let parentID = pid_t(info.pbi_ppid)
let seconds = info.pbi_start_tvsec
let microseconds = info.pbi_start_tvusec
let startTime = TimeInterval(seconds) + TimeInterval(microseconds) / 1_000_000
```

성공 조건은 `proc_pidinfo` 반환 바이트가 `MemoryLayout<proc_bsdinfo>.size`와 같은 경우다. 실패한 PID에 `parentID = 0`, `startTime = 0` 같은 가짜 identity를 부여하지 않고 제외한다. UID와 사용자명은 제품에 표시하거나 그룹 키로 쓰지 않으므로 수집하지 않는다.

## 3. Resident Size, CPU 누적값, thread 수

구현: [`ProcessSampler.taskInfo`](../RAMMonitor/Services/ProcessSampler.swift).

사용 필드:

- `pti_resident_size` → `residentSizeBytes`
- `pti_total_user`와 `pti_total_system` → CPU delta
- `pti_threadnum` → `threadCount`

호출이 실패해도 경로와 identity가 유효한 행은 유지한다. Resident Size, CPU, thread만 `nil`로 둔다. `pti_virtual_size`, page fault, context switch 등 V1에 쓰지 않는 필드는 모델에 추가하지 않는다.

## 4. Physical Footprint

`rusage_info_t`가 `void *` typedef라 Swift에서 한 번의 pointer rebound가 필요하다.

구현: [`ProcessSampler.physicalFootprint`](../RAMMonitor/Services/ProcessSampler.swift).

- V1은 `ri_phys_footprint`만 사용한다.
- 보호된 프로세스나 종료 중 프로세스의 실패는 정상적인 `nil`이다.

## 5. Architecture

구현: [`ProcessSampler.architecture`](../RAMMonitor/Services/ProcessSampler.swift).

CPU type 숫자를 직접 적지 않는다. Rosetta로 실행되는 프로세스는 `x86_64`이므로 `Intel`로 표시된다. 알 수 없는 값과 호출 실패는 `nil`이며 화면에서 `—`로 보인다.

## 6. CPU percent

`pti_total_user`, `pti_total_system`, `mach_absolute_time()`은 같은 Mach absolute-time 단위로 delta를 비교한다. 비율만 필요하므로 둘 다 나노초로 바꾸지 않는다.

구현: [`ProcessSampler.cpuPercent`](../RAMMonitor/Services/ProcessSampler.swift).

CPU 계산과 입력 타입은 모듈 내부에서만 보이게 두어 `@testable import`로 단위 검증한다. 앱의 공개 API로 노출하지 않는다.

중요:

- CPU 누적값은 그대로 두고 wall delta만 `mach_timebase_info`로 나노초 변환하면 안 된다. Apple Silicon에서 timebase 비율만큼 CPU가 과소 계산될 수 있다.
- 둘 다 raw Mach tick으로 나누거나 둘 다 같은 timebase로 변환해야 한다. V1은 더 짧고 오차가 적은 raw tick 비율을 쓴다.
- 첫 샘플, counter 역전, timestamp 역전, task info 실패는 `nil`이다.
- 계산 성공 여부와 관계없이 유효한 최신 task info는 다음 비교값으로 교체한다.
- 한 코어를 가득 쓰면 약 100%, 여러 코어를 쓰면 100%를 넘을 수 있다. 상한을 강제로 자르지 않는다.

## 7. 시스템 메모리

구현: [`ProcessSampler.systemMemory`](../RAMMonitor/Services/ProcessSampler.swift).

`SystemMemorySample`은 전체 물리 RAM 용량만 전달한다. 값이 0이면 수집을 실패 처리하고 마지막 성공 화면을 유지한다.

active/wired/compressed VM page 통계는 화면·집계에 사용하지 않으므로 수집하지 않는다. host port도 획득하지 않는다. 두 RAM 모드는 측정 그룹 합계를 차트 기준으로 쓰고, 물리 RAM 용량만 별도 요약으로 전달한다.

## 8. Bundle 해석

Bundle 해석은 시스템 수집 뒤 같은 actor에서 수행하되 규칙 자체는 [`grouping.md`](grouping.md)를 따른다.

구현 순서:

1. 실행 경로의 path component 중 `.app`으로 끝나는 것을 루트에서부터 찾아 가장 바깥쪽 경로를 선택한다.
2. 없으면 `[pid_t: BasicProcessInfo]`에서 부모를 최대 5번 따라가며 같은 검사를 한다.
3. 이미 방문한 PID는 `Set<pid_t>`로 감지해 cycle을 중단한다.
4. `.xpc` 안의 실행 파일도 상위 path component의 가장 바깥쪽 `.app`을 선택한다.
5. 찾은 `.app`만 `Bundle(path:)`로 열고 Bundle ID와 표시 이름을 읽는다.
6. 성공 결과만 원래 실행 경로를 key로 캐시한다.

부모 탐색은 매 단계 전체 프로세스 배열을 검색하지 않고 PID 사전을 사용한다. 최대 5단계라는 상한이 있으므로 별도 graph 타입은 만들지 않는다.

Bundle cache는 매 성공 주기 후 현재 실행 경로 집합에 없는 key를 제거한다. Process info cache는 현재 identity만 남긴다. Bundle ID가 없으면 Bundle로 취급하지 않고 경로 fallback을 사용한다.

## 9. 실패와 race 규칙

| 상황 | 결과 |
|---|---|
| PID 열거 실패·계속 가득 찬 버퍼 | `sample()` throw, 마지막 성공 화면 유지 |
| 경로 또는 identity 실패 | PID 제외 |
| 경로 수집 뒤 PID 소멸 | 이후 metric은 `nil`, 행 유지 가능 |
| task info 실패 | Resident, CPU, thread `nil` |
| rusage 실패 | Physical Footprint `nil` |
| architecture 실패 | Architecture `nil` |
| Bundle 해석 실패 | 실행 경로 그룹으로 fallback |
| 물리 RAM 용량이 0 | `sample()` throw, 마지막 성공 화면 유지 |
| 모든 개별 PID 제외 | 빈 프로세스 목록 + 유효한 시스템 메모리 snapshot |

`EPERM`, `ESRCH` 같은 per-process 오류는 로그를 반복 출력하지 않는다. 사용자에게는 일부 값이 `—`로 보이는 것으로 충분하다. 전체 snapshot 실패만 `MonitorModel.lastRefreshError`에 짧게 표시한다.

## 10. 성능과 동시성

- `ProcessSampler` 호출은 한 번에 하나만 실행한다.
- 한 PID의 서로 독립적인 libproc 호출을 `TaskGroup`으로 쪼개지 않는다. 수백 개의 작은 task와 actor hop이 이득보다 크다.
- 한 주기에서 `mach_absolute_time()`은 CPU 기준점으로 한 번만 읽는다.
- `proc_pidpath`, `PROC_PIDARCHINFO`, `Bundle(path:)`은 같은 process identity의 성공 cache가 없을 때만 사용한다.
- 메인 actor에서는 시스템 호출을 실행하지 않는다.
- CPU 다음 상태와 두 cache 변경은 지역 변수에 모은 뒤 성공 시 한 번에 actor 상태에 반영한다.
- 취소는 PID 사이에서 `Task.isCancelled`를 확인하고 `CancellationError`를 던진다. 포인터 호출 도중의 강제 취소는 시도하지 않으며, 취소는 사용자 오류로 표시하지 않는다.

## 11. 구현 게이트

### SDK import 확인

Xcode의 활성 toolchain으로 다음 식별자가 compile되는지 먼저 확인한다.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift -module-cache-path /tmp/ram-monitor-swift-module-cache -e '
import Darwin
print(
  MemoryLayout<proc_taskinfo>.size,
  MemoryLayout<proc_archinfo>.size,
  MemoryLayout<proc_bsdinfo>.size,
  MemoryLayout<rusage_info_v4>.size,
  PROC_PIDTASKINFO,
  PROC_PIDARCHINFO,
  PROC_PIDTBSDINFO,
  MAXPATHLEN
)
'
```

Expected: compile 성공, 모든 크기와 상수가 0보다 큼. 시스템의 `xcode-select`가 Command Line Tools를 가리켜 SDK/compiler mismatch가 나면 Xcode의 `DEVELOPER_DIR`로 실행한다.

### 최소 자동 검사

1. 현재 테스트 프로세스가 PID 목록에 있다.
2. 현재 프로세스의 경로와 시작 시각이 유효하다.
3. 현재 프로세스에서 Physical Footprint 또는 Resident Size 중 하나 이상이 수집된다.
4. 전체 물리 RAM 용량이 `ProcessInfo.processInfo.physicalMemory`와 같고 0보다 크다.
5. CPU 순수 함수는 동일한 CPU tick delta와 wall tick delta에 `100`을 반환한다.
6. CPU counter 또는 timestamp가 역전되면 `nil`이다.
7. 두 번째 실제 샘플의 현재 프로세스 CPU가 유한하고 음수가 아니다.
8. architecture가 있으면 `Apple` 또는 `Intel` 중 하나다.
9. sampler가 세 번 연속 실행되어도 stale CPU·Bundle·process info cache가 계속 늘지 않는다.

통합 테스트는 실행 중인 다른 앱의 특정 PID나 정확한 RAM 바이트를 고정하지 않는다. 커널 상태와 보호 정책은 실행마다 달라진다.

## 근거

- 설치된 SDK: `usr/include/libproc.h`, `usr/include/sys/proc_info.h`, `usr/include/sys/resource.h`
- [Apple XNU `proc_info.h`](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/sys/proc_info.h)
- [Apple XNU process observability](https://github.com/apple-oss-distributions/xnu/blob/main/doc/observability/recount.md)
- [Apple `rusage_info_v4`](https://developer.apple.com/documentation/kernel/rusage_info_v4)
- [Apple `ProcessInfo.physicalMemory`](https://developer.apple.com/documentation/foundation/processinfo/physicalmemory)

SDK가 바뀌면 이 문서의 숫자를 수정하기 전에 실제 target을 build한다. 구현은 숫자가 아니라 import된 타입과 `MemoryLayout`을 사용하므로 대부분의 SDK 변화는 재작성 없이 검증으로 끝나야 한다.
