# 검증 계획

## 합격 기준

개발 환경과 자동화의 공통 계약은 [`harness.md`](harness.md)다. 구현 작업의 최종 합격 명령은 하나다.

```bash
make verify
```

이 명령이 포맷, lint, whitespace, build, unit test, UI test, code coverage 수집, Xcode Analyze를 실행한다. 부분 검사는 작업 중 피드백용이며 `make verify`를 대신하지 않는다.

## 자동 검증

| 영역 | 필수 검사 |
|---|---|
| 메모리 회계 | 두 모드 모두 조각 합 = 측정 그룹 합 = 분모, 같은 그룹의 차트·목록 값 일치, 물리 RAM 초과 시에도 원본 유지 |
| 모드 전환 | 목록·차트·백분율·RAM 정렬이 같은 metric 사용 |
| 그룹핑 | path, 부모 5단계, XPC, fallback, 다른 Bundle ID 분리 |
| 집계 | 일부 `nil`, 전부 `nil`, overflow 처리 |
| CPU | 첫 샘플 `nil`, PID 재사용 분리, stale sample 제거 |
| SDK 경계 | Swift import, 구조체 크기 기반 buffer, 반환 바이트 판정 |
| PID 열거 | 바이트 단위 buffer, 가득 찬 buffer 재시도, 0 PID 제거 |
| 오류 격리 | 개별 PID 실패는 누락·`nil`, 전역 실패는 마지막 snapshot 유지 |
| 시스템 자원 | 반복 수집 후 Mach host port send-right reference가 증가하지 않음 |
| 필터·정렬 | 그룹명·자식명 검색, RAM·CPU·이름·process count 정렬 |
| 설정 | 기본값과 `UserDefaults` 왕복 |
| 실제 수집 | 테스트 프로세스 자신을 발견하고 두 RAM 값 중 허용된 값을 수집 |
| UI smoke | 실행, 차트와 물리 RAM 별도 요약, 그룹 확장, 설정 열기, 빈 검색 결과 |
| 열 정렬 | 항상 표시/자동 숨김 스크롤바에서 헤더·RAM 행 오른쪽 끝 일치, 스크롤 후에도 헤더 고정 |
| 차트 상호작용 | 목록 선택과 조각 강조 연동, 호버 종료 시 선택 복귀, 차트 클릭의 검색 해제·부모 행 스크롤·키보드 포커스, 재클릭·비선택 영역 클릭 시 강조 해제와 호버 재진입, Other 처리, 갱신·모드 전환 시 선택 유지 및 사라진 그룹 해제 |

전체 테스트만 다시 실행할 때:

```bash
make test
```

UI 검사는 잠금 해제된 화면에서 다른 마우스·키보드 입력 없이 실행한다. 시스템 권한 팝업이 개입하면 해당 실행은 앱 회귀 판정에 사용하지 않고, 사용자가 팝업을 처리한 뒤 다시 검증한다. 호버 뒤에는 접근성 label이 기대값으로 반영될 때까지 최대 3초 기다린다. 입력 재시도나 실패 무시는 하지 않는다.

`ProcessSampler` 구현 전에는 [`system-api.md`](system-api.md)의 SDK import probe를 실행한다. `PROC_PIDPATHINFO_MAXSIZE`와 `HOST_VM_INFO64_COUNT`는 Swift에 import되지 않는다는 전제를 실제 활성 Xcode SDK에서 확인하고, 숫자를 하드코딩하지 않는다.

## 수동 비교

Activity Monitor와 RAM Monitor를 동시에 열고 2초 갱신으로 3회 이상 안정화한 뒤 확인한다.

1. Chrome 또는 Electron 앱 하나를 펼쳐 subprocess 구성이 합리적인지 확인한다.
2. Physical Footprint 모드의 상위 그룹 RAM이 Activity Monitor의 Memory 값과 같은 방향으로 움직이는지 확인한다.
3. 두 모드에서 차트 중앙이 선택 모드의 측정 프로세스 합계인지 확인한다. 물리 RAM 요약은 모드를 바꿔도 유지되어야 한다.
4. 모드를 전환할 때 RAM 정렬 순서와 각 행 값이 같은 주기에 바뀌는지 확인한다.
5. 보호된 프로세스가 있어도 목록 전체가 사라지지 않는지 확인한다.
6. Apple Silicon에서 CPU를 쓰는 테스트 프로세스가 한 코어 기준 약 100% 방향으로 보이는지 확인한다. wall tick에만 timebase를 적용해 과소 계산되지 않아야 한다.
7. 검색을 해제하고 상위 그룹 행의 합계를 차트와 비교한다. 같은 작업의 범례·hover·행 바이트 값이 같아야 한다. 펼친 자식 행은 중복 합산하지 않는다.
8. 스크롤바 항상 표시/자동 숨김, 창 크기 변경, 선택 열 표시·숨김에서 헤더와 행 열 정렬 및 스크롤 중 헤더 고정을 확인한다.
9. 조각·범례 호버와 목록 선택의 강조를 확인한다. 조각 클릭 후 선택된 부모 행이 보이고 방향키로 이동할 수 있어야 한다. 같은 항목 재클릭 및 중앙·빈 영역·정렬 버튼 클릭으로 선택과 강조가 해제되어야 하며, 포인터가 남아 있어도 즉시 다시 강조되지 않아야 한다. 펼친 그룹·Other·동작 줄이기 설정에서도 확인한다.

Activity Monitor와 그룹 경계가 같은 안정된 앱은 Physical Footprint 차이를 15% 이내로 목표로 한다. 차이가 크면 값 자체를 보정하지 않고 그룹 경계와 샘플 시점을 먼저 조사한다.

## 성능 기준

- 기본 2초 간격에서 60초 동안 RAM Monitor 자체 평균 CPU 2% 미만
- 새로고침 중 스크롤과 그룹 펼치기가 눈에 띄게 멈추지 않음
- bundle·process info cache와 CPU 이전 샘플에서 사라진 process identity가 계속 증가하지 않음
- 갱신 `Task`는 창 종료 시 취소됨

2026-09-03 로컬 Release 측정: 기본 2초 갱신으로 60초 동안 CPU time 1.05초, 평균 1.750%. 같은 장비에서 측정 전 2.283%였고 `KERN_PROC_PID`의 PID별 `sysctl`을 `PROC_PIDTBSDINFO`로 교체한 뒤 합격했다.

## 배포 검증

릴리스 생성 전 `make verify`가 먼저 통과해야 한다. 이후 산출물에 다음 검사를 적용한다.

```bash
lipo -archs 'release/RAM Monitor.app/Contents/MacOS/RAM Monitor'
codesign --verify --deep --strict --verbose=2 'release/RAM Monitor.app'
hdiutil verify 'release/RAM-Monitor.dmg'
shasum -a 256 'release/RAM-Monitor.dmg'
```

필수 결과:

- `lipo`: `arm64 x86_64`
- `codesign`: ad-hoc 서명 무결성 통과
- `hdiutil`: DMG 검증 통과
- SHA-256 값이 GitHub Release와 개인 Tap cask에 동일하게 반영

## 개인정보 확인

- 프로세스 snapshot은 현재 화면 구성에만 사용
- UserDefaults에는 UI 설정만 저장
- 앱이 요구하는 권한과 Sandbox 비활성화 이유를 README에 공개
