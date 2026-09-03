# 작업 그룹핑 규칙

## 목적

모든 결과를 하나의 목록에 놓고, 사용자가 인식할 수 있는 앱 또는 실행 작업 단위로 묶는다.

## Bundle 탐색

각 프로세스는 아래 순서로 Bundle 정보를 찾는다.

1. **실행 경로**: 실행 파일 경로를 루트까지 올라가며 가장 바깥쪽 `.app`을 선택한다.
2. **부모 체인**: 직접 경로에서 찾지 못하면 부모 PID를 최대 5단계 올라가며 각 실행 경로의 가장 바깥쪽 `.app`을 찾는다.
3. **XPC 경로**: `.xpc` 내부 실행 파일이면 상위 경로의 가장 바깥쪽 `.app`을 찾는다.
4. **Fallback**: Bundle을 찾지 못하면 해당 프로세스의 실행 경로를 작업 단위로 사용한다.

Bundle 표시 이름의 우선순위는 `CFBundleDisplayName` → `CFBundleName` → `.app` 파일명이다.

## 그룹 키

```swift
let groupID = bundleInfo?.bundleIdentifier ?? process.path
```

- 이 문서에서 고정한 Bundle ID 우선 기준을 유지한다.
- 이름을 추가해 서로 다른 키를 강제로 합치지 않는다.
- 같은 프로그램이 여러 그룹으로 보이는 예외는 V1에서 별도 보정하지 않는다.
- Bundle 탐색 결과는 실행 경로별로 캐시한다.

## 집계

```swift
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
```

- 합계는 측정에 성공한 값만 더한다.
- 모든 하위 값이 `nil`이면 그룹 합계도 `nil`이다.
- subprocess는 현재 선택된 RAM 지표 내림차순으로 표시한다.
- 그룹을 접거나 펼쳐도 수집과 합계에는 영향을 주지 않는다.
- 검색은 그룹 표시 이름과 모든 subprocess 이름을 대소문자 구분 없이 검사한다.

## 필수 검증 사례

- 일반 `.app` 실행 파일이 Bundle ID로 묶인다.
- Electron의 중첩 helper `.app`은 가장 바깥쪽 앱으로 해석된다.
- 직접 경로에 `.app`이 없는 자식이 부모 앱에 묶인다.
- XPC 서비스가 상위 앱에 묶인다.
- Bundle이 없는 실행 파일은 경로별 독립 그룹이 된다.
- Bundle ID가 다른 두 그룹은 이름이 같아도 합쳐지지 않는다.
- PID가 재사용되어도 이전 CPU 샘플이 섞이지 않는다.
