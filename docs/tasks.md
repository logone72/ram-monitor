# 구현 작업

이 문서가 구현 진행도의 기준이다. 세부 절차와 코드는 [`implementation.md`](implementation.md), 완료 판정은 [`quality.md`](quality.md)를 따른다.

## 현재 상태

- 구현: `8 / 9`
- 현재 작업: Task 9 — Universal DMG와 개인 Tap release
- 다음 작업: CI SDK 환경 수정본의 원격 재검증 → 0.1.0 DMG 설치본 사용자 최종 확인 → 별도 승인 후 공개 Release·Tap 배포
- 마지막 갱신: 2026-09-16

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

- [x] 사용자가 로컬 앱을 직접 실행하고 주요 동작을 확인한다.
- [x] 확인된 피드백을 반영한다.
- [x] 변경 후 `make verify`와 로컬 DMG 검증을 다시 통과한다.
- [ ] 생성된 DMG 설치본을 사용자가 최종 확인한다.
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
- [x] 사용자 재확인 및 후속 피드백 반영 — 선택 해제·테두리·스크롤·초기 창 높이 개선

이번 개선은 Task 9의 배포 전 피드백 반영에 해당한다. 로컬 DMG 검증은 아래 2026-09-16 기록을 참고하며, 공개 Release·Tap 배포는 아직 완료하지 않았다.

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
- [x] 전체 `make verify`: 2026-09-16 호버 검사 동기화 보완 후 통과. 아래 재검증 기록 참고.

당시 단위 28개와 테두리 픽셀·방향키 검사는 통과했다. 전체 UI 검사에서 클릭 위치 탐색·호버 실패가 발생했고, 빈 목록 클릭은 재실행에서 통과했다. 기존 호버 검사의 `Google Chrome`/`ChatGPT` 불일치는 포커스 테두리 수정 전 코드에서도 재현됐으며, 아래 재검증에서 검사 방식과 실행 환경을 확인했다.

변경 파일: `RAMMonitor/Views/MonitorView.swift`, `RAMMonitorUITests/RAMMonitorUITests.swift`, `docs/interface.md`, `docs/tasks.md`.

### 왼쪽 오버레이와 초기 창 높이

- [x] 왼쪽만 오버레이·자동 숨김 적용, 오른쪽의 시스템 스크롤바 설정 유지
- [x] 전체 범례 9개와 설명의 실제 높이 642pt 측정 → 툴바 포함 기본 높이 694pt 적용
- [x] 이전의 작은 창 크기가 복원되면 처음에만 높이 보정, 이후 수동 축소·스크롤 허용
- [x] 실제 기본 창에서 스크롤해도 콘텐츠 위치가 변하지 않음, 작은 창에서는 하단 요약까지 스크롤 가능
- [x] 단위 30개·관련 UI 6개, 포맷·lint·빌드·Analyze 통과. 전체 UI 재검증은 아니며 기존 호버 검사 실패는 앞 항목에 별도 기록되어 있다.

변경 파일: `RAMMonitor/RAMMonitorApp.swift`, `RAMMonitor/Views/MonitorView.swift`, `RAMMonitor/Views/SummaryScrollConfiguration.swift`, `RAMMonitorTests/MemoryLayoutTests.swift`, `RAMMonitorUITests/RAMMonitorUITests.swift`, `docs/interface.md`, `docs/tasks.md`.

## 2026-09-16 UI 검사 안정화 및 전체 재검증

- [x] 호버 직후 즉시 label을 비교하던 네 곳을 최대 3초의 조건부 대기로 변경. 입력 재시도·검사 생략 없이 기대 항목명을 검증한다.
- [x] 실패 녹화에서 뒤늦게 정상 강조가 표시되는 사례 확인. 별도 실행에서는 시스템 권한 팝업과 다른 앱 창의 입력 방해 기록을 확인했다.
- [x] 최종 `make verify` 통과 — 단위 30개·UI 15개, 포맷·lint·build·Analyze 성공 (Xcode 27.0).
- [x] 임시 진단 코드 제거. 앱 동작 코드는 변경하지 않음.

중간 반복 검사 15회 중 1회는 외부 창 개입과 함께 실패했으므로 반복 검사를 전부 통과한 것으로 기록하지 않는다. 이후 최종 전체 검증은 실패 없이 완료됐다. 모든 과거 실패가 동일 원인이었다고 단정하지 않으며, 재발 시 입력 방해와 실제 앱 회귀를 구분한다.

변경 파일: `RAMMonitorUITests/RAMMonitorUITests.swift`, `docs/quality.md`, `docs/index.md`, `docs/tasks.md`. 이후 로컬 DMG 검증 결과는 아래에 기록하며, 공개 배포는 Task 9의 남은 작업이다.

### 이전 차트 회계·헤더 검증 기록

검증에서 기존 헤더와 RAM 행의 오른쪽 끝이 16pt 어긋나는 것을 재현했고 수정 후 1pt 이내로 일치했다. 물리 RAM보다 큰 Footprint 합계, 일부 측정 불가·0·overflow, 모드 전환, 스크롤바 설정과 선택 열 표시·숨김, 스크롤 중 헤더 고정, 작은 창의 요약 접근을 검사했다. 실제 앱 화면에서도 원본 바이트 일치와 독립 스크롤을 확인했다.

변경 파일:

- 앱: `RAMMonitor/Models/MonitorModels.swift`, `RAMMonitor/Services/SnapshotBuilder.swift`, `RAMMonitor/Views/MemoryPieChart.swift`, `RAMMonitor/Views/MonitorView.swift`, `RAMMonitor/Views/ProcessGroupRow.swift`
- 테스트: `RAMMonitorTests/SnapshotBuilderTests.swift`, `RAMMonitorTests/MonitorModelTests.swift`, `RAMMonitorUITests/RAMMonitorUITests.swift`
- 공개 문서: `README.md`, `README.ko.md` — 기존 변경을 보존하고 측정 방식 설명 갱신
- 계획·진행 문서: `docs/index.md`, `docs/tasks.md`, `docs/product.md`, `docs/memory.md`, `docs/interface.md`, `docs/system-api.md`, `docs/quality.md`, `docs/implementation.md`

## 2026-09-16 로컬 0.1.0 DMG 검증

아래는 최초 DMG 검증 기록이다. 최신 산출물과 checksum은 다음 아이콘 교체 기록을 따른다.

- 소스: `2e7a542d120508925ed276962dcfc8d5aaca697d` — 위 `make verify` 통과본. 앱 코드·빌드 스크립트 변경 없이 기존 `scripts/build-release.sh 0.1.0` 사용.
- 환경: Apple Silicon, macOS 26.6.2, Xcode 27.0. 시스템 `xcode-select`는 CLT 유지.
- 산출물: `release/RAM-Monitor-0.1.0.dmg`(3,773,437 bytes), `release/SHA256SUMS`, `release/ram-monitor.rb`. `release/`는 Git 추적 제외.
- DMG SHA-256: `1da504de21e333f1b7e14e5ab49f08636002d732901fc6ca2e7e53f0b51796fd`.
- [x] Release archive 성공, 앱 버전 0.1.0 / build 1 / macOS 14+ 확인
- [x] Universal 2(`arm64`, `x86_64`)와 ad-hoc 서명 무결성, `hdiutil verify`, SHA-256 대조 통과
- [x] DMG 내부 앱과 `/Applications` 바로가기 확인, cask checksum 일치 및 Ruby 구문 검사 통과
- [x] 기존 설치본이 없는 `/Applications/RAM Monitor.app`에 DMG의 앱을 복사하고 DMG 분리 후 실행
- [x] 실행 프로세스가 `/Applications` 설치본이며 빌드 산출물과 실행 파일 checksum이 같음을 확인
- [x] 실제 RAM·CPU 갱신, 차트·목록 표시, 검색, 차트 클릭에 따른 검색 해제·목록 선택, 재클릭 선택 해제, 두 RAM 모드 전환 확인
- [x] RAM 모드는 기존 Physical Footprint로 복원. 로그인 시 실행 설정은 변경하지 않음.

이번 검증은 로컬 빌드 설치·실행 검증이다. Intel Mac 실제 실행, macOS 14 실제 실행, 인터넷에서 내려받은 앱의 Gatekeeper 최초 실행, Homebrew 설치는 미검증이다. ad-hoc 서명 무결성 통과는 Developer ID·notarization 또는 Gatekeeper 신뢰 통과를 의미하지 않는다.

Git 태그·공개 Release·Tap 게시는 수행하지 않았다. cask URL은 향후 공개 Release를 가리키므로 아직 설치용으로 배포하지 않는다. Task 9는 설치본 사용자 최종 확인과 공개 배포 검증이 남아 `진행 중`을 유지한다.

이번 변경 파일: `docs/index.md`, `docs/tasks.md`.

### 앱 아이콘 교체

- 작은 크기의 시인성 피드백을 반영한 확정 R 로고로 `AppIcon.appiconset`의 PNG 7개(16~1024px)를 교체했다. 두꺼운 파란 R과 큰 초록·주황 조각 두 개로 단순화하고, 중앙 여백을 줄였으며 R 다리를 길게 뻗었다. 모서리는 과하게 둥글거나 날카롭지 않게 다듬고 흰 배경·평면적인 형태·그라데이션을 유지했다.
- 승인된 `exec-f708e4ee-47d6-43f4-bf20-80f1ebb2c26a.png`를 다시 생성하거나 보정하지 않고 macOS `sips`로 크기만 변환했다. 배경은 원본대로 불투명한 흰색이며, 최종 1024px 에셋은 `RAMMonitor/Assets.xcassets/AppIcon.appiconset/icon-1024.png`에 있다. 32px·64px 축소본도 확인했다.
- 소스는 위 commit에 아이콘 변경만 추가한 상태다. 앱 동작 코드는 변경하지 않았으며 전체 UI 테스트는 재실행하지 않았다.
- `make check`, 이미지 크기 확인, Universal 2 Release archive, 서명·DMG 무결성·SHA-256·cask Ruby 구문 검사 통과. 설치본의 `AppIcon.icns`와 실행 파일도 새 빌드와 동일함을 확인했고, 컴파일된 아이콘을 이미지로 추출해 확정 디자인과 대조했다.
- 새 DMG: `release/RAM-Monitor-0.1.0.dmg`(2,643,071 bytes), SHA-256 `8429afa9dac439ac0d003c2d1dbfc31257206142a3feee05fa18c35d511fbc1b`. checksum과 cask도 함께 재생성했다.
- DMG에서 `/Applications/RAM Monitor.app`을 갱신하고 분리 후 실행·차트와 목록 표시 확인. 직전 앱, 아이콘과 release 산출물은 `/private/tmp/ram-monitor-natural-icon.r8Qm2h/`에 임시 백업했다. 시스템 CLT 선택은 변경하지 않았다.
- 변경 파일: `RAMMonitor/Assets.xcassets/AppIcon.appiconset/icon-{16,32,64,128,256,512,1024}.png`, `docs/index.md`, `docs/tasks.md`. 공개 배포는 별도 승인 후 진행한다.

이미지 제작: built-in `image_gen`. 최종 편집 프롬프트 요약:

> Refine only the corners of the three-piece R logo. Lightly ease exposed corners and the blue bowl-to-leg junction; retain the long, thick diagonal leg with a mostly straight terminal. Keep the smooth circular arcs, small central opening, blue/indigo, green/teal and yellow/orange gradients, flat design and solid white background. Avoid razor-sharp tips, pill-shaped ends, extra details, text, outlines, 3D and shadows.

## 2026-09-16 CI SDK 환경 수정

- 원격 CI `35081134757`은 기본 Xcode 16.4 / macOS 15.5 SDK에서 `proc_archinfo`와 `PROC_PIDARCHINFO`를 찾지 못해 빌드 단계에서 실패했다. 앞서 기록한 로컬 검증 통과와 원격 CI 성공은 별개다.
- 구형 macOS 14.4 SDK에서도 같은 Swift import 오류를 재현했고, macOS 26.5 SDK에서는 arm64·x86_64 모두 통과했다. 캐시가 아닌 SDK 선언 차이로 확인했다.
- CI·Release를 `macos-26` + Xcode 26.6으로 고정했다. Release 트리거·게시 방식과 앱 소스·macOS 14 deployment target은 변경하지 않았다.
- `make doctor`에 SDK 버전 출력과 필수 선언의 Swift typecheck를 추가했다. 로컬 `make doctor check`, 두 workflow의 YAML·환경 일치 검사, 설치된 Xcode 27 SDK의 arm64·x86_64 앱 빌드가 통과했다.
- 로컬 Xcode 27에서 외부 CLT 26.5 SDK를 사용하는 전체 앱 빌드는 SDK 등록 조회 오류로 완료하지 못했다. 해당 SDK의 import 검사와 Xcode 26.6 자체에서의 전체 검증을 동일하게 취급하지 않는다.
- GitHub Actions의 새 환경 전체 검증은 push 후 확인해야 한다. 로컬 UI 테스트와 배포는 실행하지 않았다. 시스템 `xcode-select`는 CLT를 유지했다.
- 변경 파일: `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `Makefile`, `docs/harness.md`, `docs/index.md`, `docs/tasks.md`.

## 2026-09-17 CI 초기 창 높이 수정

- 원격 CI `35082563719`에서 SDK 오류는 해소됐다. 빌드와 단위 테스트 30개는 통과했으나 UI 테스트 15개 중 `testInitialSummaryFitsWithoutScrolling`이 20pt 위치 변화로 실패했다.
- 로컬에서 기존 UI 테스트는 통과했다. 실제 AppKit unified 툴바를 붙이는 회귀 테스트를 추가하자 창 전체 높이 694pt에서 콘텐츠 영역이 628pt로 부족해 실패했다. 기존 보정은 창 전체 높이만 비교했고, 콘텐츠 검사에서는 툴바를 52pt로 가정했다.
- 초기 보정에 `window.contentLayoutRect`로 측정한 실제 제목 표시줄·툴바 높이를 사용해 콘텐츠 642pt를 확보한다. 화면의 가용 높이 제한과 이후 수동 축소는 유지한다. 기존 UI assertion은 완화하지 않았다.
- 수정 후 로컬 단위 테스트 31개, 초기 높이·작은 창 UI 테스트 2개, `make check`, `make analyze` 통과. 전체 UI 테스트와 원격 CI 재실행은 수행하지 않았다. 커밋·push·배포 및 설치된 앱·DMG 교체도 하지 않았다.
- 변경 파일: `RAMMonitor/RAMMonitorApp.swift`, `RAMMonitor/Views/SummaryScrollConfiguration.swift`, `RAMMonitorTests/MemoryLayoutTests.swift`, `docs/interface.md`, `docs/index.md`, `docs/tasks.md`.
