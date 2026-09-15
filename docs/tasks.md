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

검증에서 기존 헤더와 RAM 행의 오른쪽 끝이 16pt 어긋나는 것을 재현했고 수정 후 1pt 이내로 일치했다. 물리 RAM보다 큰 Footprint 합계, 일부 측정 불가·0·overflow, 모드 전환, 스크롤바 설정과 선택 열 표시·숨김, 스크롤 중 헤더 고정, 작은 창의 요약 접근을 검사했다. 실제 앱 화면에서도 원본 바이트 일치와 독립 스크롤을 확인했다.

변경 파일:

- 앱: `RAMMonitor/Models/MonitorModels.swift`, `RAMMonitor/Services/SnapshotBuilder.swift`, `RAMMonitor/Views/MemoryPieChart.swift`, `RAMMonitor/Views/MonitorView.swift`, `RAMMonitor/Views/ProcessGroupRow.swift`
- 테스트: `RAMMonitorTests/SnapshotBuilderTests.swift`, `RAMMonitorTests/MonitorModelTests.swift`, `RAMMonitorUITests/RAMMonitorUITests.swift`
- 공개 문서: `README.md`, `README.ko.md` — 기존 변경을 보존하고 측정 방식 설명 갱신
- 계획·진행 문서: `docs/index.md`, `docs/tasks.md`, `docs/product.md`, `docs/memory.md`, `docs/interface.md`, `docs/system-api.md`, `docs/quality.md`, `docs/implementation.md`
