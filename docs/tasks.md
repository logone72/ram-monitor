# 구현 작업

이 문서가 구현 진행도의 기준이다. 세부 절차와 코드는 [`implementation.md`](implementation.md), 완료 판정은 [`quality.md`](quality.md)를 따른다.

## 현재 상태

- 구현: `8 / 9`
- 현재 작업: Task 9 — Universal DMG와 개인 Tap release
- 다음 작업: 개선된 로컬 앱 사용자 재확인 및 남은 피드백 수집
- 마지막 갱신: 2026-09-15

상태는 `대기`, `진행 중`, `차단`, `완료`만 사용한다. 한 번에 하나의 Task만 `진행 중`으로 두고, 해당 Task의 검사와 `make verify`가 모두 통과한 뒤 `완료`로 바꾼다. Task 상태가 바뀌면 이 문서와 [`index.md`](index.md)의 요약을 함께 갱신한다.

## 작업 목록

| Task | 결과물 | 선행 Task | 상태 | 완료 조건 |
|---|---|---|---|---|
| [1. 독립 프로젝트 기반과 개발 하네스](implementation.md#task-1-독립-프로젝트-기반과-개발-하네스) | 빌드 가능한 앱 shell, 테스트 target, 공통 하네스와 CI | 없음 | 완료 | 빈 앱 build·test와 하네스 자체 검사 통과 |
| [2. 모델과 RAM 차트 회계](implementation.md#task-2-모델과-ram-차트-회계) | 측정 모델과 두 RAM 모드의 차트 회계 | 1 | 완료 | SnapshotBuilder RAM 회계 테스트 통과 |
| [3. 프로세스 수집과 Bundle 해석](implementation.md#task-3-프로세스-수집과-bundle-해석) | 실제 프로세스 RAM·CPU·identity와 시스템 메모리 수집 | 2 | 완료 | SDK probe와 ProcessSampler 검사 통과 |
| [4. 그룹핑·검색·정렬](implementation.md#task-4-그룹핑검색정렬) | 작업 단위 그룹과 목록 변환 규칙 | 2, 3 | 완료 | 그룹핑·검색·정렬 테스트 통과 |
| [5. 갱신 모델과 설정 상태](implementation.md#task-5-갱신-모델과-설정-상태) | 주기적 snapshot과 영속 설정 상태 | 2, 4 | 완료 | 갱신·오류 유지·설정 왕복 테스트 통과 |
| [6. 파이 차트와 통합 작업 목록](implementation.md#task-6-파이-차트와-통합-작업-목록) | 단일 화면의 차트, 그룹 목록과 상호작용 | 5 | 완료 | 전체 unit test와 UI smoke test 통과 |
| [7. 설정과 로그인 시 실행](implementation.md#task-7-설정과-로그인-시-실행) | 설정 화면과 SMAppService 연결 | 5, 6 | 완료 | 설정·등록 실패 복구 검사 통과 |
| [8. 앱 식별 정보와 공개 문서](implementation.md#task-8-앱-식별-정보와-공개-문서) | 앱 아이콘, metadata, README와 라이선스 | 6, 7 | 완료 | 제품 식별 정보 확인과 `make verify` 통과 |
| [9. Universal DMG와 개인 Tap release](implementation.md#task-9-universal-dmg와-개인-tap-release) | 사용자 테스트와 개선을 거친 Universal 2 DMG, release workflow와 cask | 8 | 진행 중 | 직접 테스트·피드백 반영·재검증 후 DMG·Tap 설치 검증 통과 |

## Task 9 배포 전 게이트

- [ ] 사용자가 로컬 앱을 직접 실행하고 주요 동작을 확인한다.
- [ ] 확인된 피드백을 반영한다.
- [ ] 변경 후 `make verify`와 로컬 DMG 검증을 다시 통과한다.
- [ ] 위 단계가 끝난 뒤 공개 GitHub Release와 personal Tap 배포를 진행한다.

## 전체 완료 조건

- Task 1~9가 모두 `완료`
- [`implementation.md`](implementation.md)의 완료 조건 충족
- 최종 `make verify` 통과
- 사용자 직접 테스트와 피드백 반영 완료
- 실제 DMG와 Homebrew 설치 흐름 확인

## 2026-09-15 피드백 반영

- [x] 두 RAM 모드의 차트 분모를 측정 그룹 합계로 통일하고 차트 전용 비례 축소 제거
- [x] 물리 RAM 용량을 별도 표시하고 차트·목록의 동일 작업 바이트 값 일치
- [x] 헤더와 행을 같은 스크롤 영역에 배치하고 헤더 상단 고정
- [x] 작은 창에서도 큰 파이 크기를 유지하며 범례·물리 RAM 요약까지 스크롤 가능
- [x] 회귀 테스트와 `make verify` 통과 — 단위 26개·UI 8개, 포맷·lint·build·Analyze 통과
- [ ] 사용자 재확인 및 남은 피드백 수집

이번 개선은 Task 9의 배포 전 피드백 반영에 해당한다. 공개 Release·Tap 배포 및 로컬 DMG 재검증은 아직 완료하지 않았다.

### 차트·목록 선택 연동

- [x] 이전 차트 회계·헤더 개선을 `81e2bf2`로 커밋
- [x] 조각·범례 호버 강조와 짧은 애니메이션, 동작 줄이기 설정 대응
- [x] 목록 선택 → 그룹 조각 강조, 호버 종료 → 기존 선택 강조 복귀, 새 키보드 선택 시 이전 호버 해제
- [x] 조각·범례 클릭 → 부모 행 선택·스크롤·키보드 포커스, 숨겨진 대상의 검색 해제
- [x] 화면 밖 항목 및 펼친 그룹의 부모 행 이동, 고정 헤더에 가리지 않도록 위치 조정
- [x] 그룹 ID 기준 선택 유지, Other·측정 불가·0 처리, 사라진 그룹 선택 해제
- [x] 새 회귀 테스트와 전체 `make verify` 통과 — 단위 28개·UI 10개, 포맷·lint·build·Analyze 통과

2026-09-15 최초 검증: 화면 밖 그룹 이동, 펼친 그룹의 부모 행이 고정 헤더에 가리지 않음, 검색 해제 및 방향키 포커스, 호버 중 키보드 선택 변경(`Other` 내부 이동 포함)을 실제 앱 UI 테스트로 확인했다. 첫 화면 검사는 이전 테스트의 마우스 위치에 영향받지 않도록 호버를 명시적으로 해제한다. 재클릭 동작은 아래 추가 피드백에 따라 선택 해제로 변경했다.

신규 상호작용 변경 파일: `RAMMonitor/ViewModels/MonitorModel.swift`, `RAMMonitor/Views/MemoryPieChart.swift`, `RAMMonitor/Views/MonitorView.swift`, `RAMMonitor/Views/ProcessGroupRow.swift`, `RAMMonitorTests/MonitorModelTests.swift`, `RAMMonitorUITests/RAMMonitorUITests.swift`, `README.md`, `README.ko.md`, `docs/interface.md`, `docs/quality.md`, `docs/index.md`, `docs/tasks.md`.

### 선택 해제 피드백

- [x] 선택된 조각·범례·목록 행 재클릭 시 선택과 강조 해제
- [x] 차트 중앙·제목·빈 목록·정렬·펼치기 버튼·검색창·Other로 해제
- [x] 해제 직후 남아 있는 포인터로 다시 강조되지 않도록 처리하고, 호버 재진입 시 정상 복귀
- [x] 해제 시 대기 중인 목록 스크롤 취소, 재선택 시 부모 행 이동 유지
- [x] 최종 `make verify` 통과 — 단위 28개·UI 13개, 포맷·lint·build·Analyze 통과

재클릭 해제 전 UI 테스트에서 선택과 항목명이 남는 것을 재현했다. 검색창 클릭도 별도로 재현·수정했다. 호버 회귀 검사 중 Chrome 창의 개입 기록이 있는 실패가 한 번 있었고, 같은 검사를 두 번 연속 재실행해 통과했다.

최종 전체 검증에서는 기존 호버·키보드·스크롤 연동과 신규 선택 해제 검사가 모두 통과했다.

이번 수정 파일:

- 앱: `RAMMonitor/ViewModels/MonitorModel.swift`, `RAMMonitor/Views/MemoryPieChart.swift`, `RAMMonitor/Views/MonitorView.swift`
- 테스트: `RAMMonitorTests/MonitorModelTests.swift`, `RAMMonitorUITests/RAMMonitorUITests.swift`
- 문서: `README.md`, `README.ko.md`, `docs/interface.md`, `docs/quality.md`, `docs/index.md`, `docs/tasks.md`

### 차트·목록 사이 포커스 테두리

- [x] 목록에 포커스가 갈 때 나타나는 하늘색 시스템 테두리를 재현하고 경계 픽셀 검사 추가
- [x] 목록의 포커스 효과만 비활성화하고 중립색 구분선·행 선택 표시·방향키 이동 유지
- [x] 수정 전 픽셀 검사 실패 → 수정 후 통과, 실제 선택 화면에서도 테두리 제거 확인
- [x] 최종 수정본의 테두리·방향키 검사, 포맷·lint·빌드·Analyze 통과
- [ ] 전체 `make verify`: 기존 호버 UI 검사 실패로 미통과. 이번 수정 제외 후 비교 실행에서도 같은 실패를 확인했다.

단위 28개와 테두리 픽셀·방향키 검사는 통과했다. 전체 UI 검사에서 클릭 위치 탐색·호버 실패가 발생했고, 빈 목록 클릭은 재실행에서 통과했다. 기존 호버 검사의 `Google Chrome`/`ChatGPT` 불일치는 포커스 테두리 수정 전 코드에서도 재현되어 별도 확인이 필요하다.

변경 파일: `RAMMonitor/Views/MonitorView.swift`, `RAMMonitorUITests/RAMMonitorUITests.swift`, `docs/interface.md`, `docs/tasks.md`.

### 왼쪽 오버레이와 초기 창 높이

- [x] 왼쪽만 오버레이·자동 숨김 적용, 오른쪽의 시스템 스크롤바 설정 유지
- [x] 전체 범례 9개와 설명의 실제 높이 642pt 측정 → 툴바 포함 기본 높이 694pt 적용
- [x] 이전의 작은 창 크기가 복원되면 처음에만 높이 보정, 이후 수동 축소·스크롤 허용
- [x] 실제 기본 창에서 스크롤해도 콘텐츠 위치가 변하지 않음, 작은 창에서는 하단 요약까지 스크롤 가능
- [x] 단위 30개·관련 UI 6개, 포맷·lint·빌드·Analyze 통과. 전체 UI 재검증은 아니며 기존 호버 검사 실패는 앞 항목에 별도 기록되어 있다.

변경 파일: `RAMMonitor/RAMMonitorApp.swift`, `RAMMonitor/Views/MonitorView.swift`, `RAMMonitor/Views/SummaryScrollConfiguration.swift`, `RAMMonitorTests/MemoryLayoutTests.swift`, `RAMMonitorUITests/RAMMonitorUITests.swift`, `docs/interface.md`, `docs/tasks.md`.

### 이전 차트 회계·헤더 검증 기록

검증에서 기존 헤더와 RAM 행의 오른쪽 끝이 16pt 어긋나는 것을 재현했고 수정 후 1pt 이내로 일치했다. 물리 RAM보다 큰 Footprint 합계, 일부 측정 불가·0·overflow, 모드 전환, 스크롤바 설정과 선택 열 표시·숨김, 스크롤 중 헤더 고정, 작은 창의 요약 접근을 검사했다. 실제 앱 화면에서도 원본 바이트 일치와 독립 스크롤을 확인했다.

변경 파일:

- 앱: `RAMMonitor/Models/MonitorModels.swift`, `RAMMonitor/Services/SnapshotBuilder.swift`, `RAMMonitor/Views/MemoryPieChart.swift`, `RAMMonitor/Views/MonitorView.swift`, `RAMMonitor/Views/ProcessGroupRow.swift`
- 테스트: `RAMMonitorTests/SnapshotBuilderTests.swift`, `RAMMonitorTests/MonitorModelTests.swift`, `RAMMonitorUITests/RAMMonitorUITests.swift`
- 공개 문서: `README.md`, `README.ko.md` — 기존 변경을 보존하고 측정 방식 설명 갱신
- 계획·진행 문서: `docs/index.md`, `docs/tasks.md`, `docs/product.md`, `docs/memory.md`, `docs/interface.md`, `docs/system-api.md`, `docs/quality.md`, `docs/implementation.md`
