# 구현 작업

이 문서가 구현 진행도의 기준이다. 세부 절차와 코드는 [`implementation.md`](implementation.md), 완료 판정은 [`quality.md`](quality.md)를 따른다.

## 현재 상태

- 구현: `8 / 9`
- 현재 작업: Task 9 — Universal DMG와 개인 Tap release
- 다음 작업: 공개 GitHub Release와 personal Tap 설치 검증
- 마지막 갱신: 2026-09-03

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
| [9. Universal DMG와 개인 Tap release](implementation.md#task-9-universal-dmg와-개인-tap-release) | Universal 2 DMG, SHA-256, release workflow와 cask | 8 | 진행 중 | 산출물·서명·DMG·Tap 설치 검증 통과 |

## 전체 완료 조건

- Task 1~9가 모두 `완료`
- [`implementation.md`](implementation.md)의 완료 조건 충족
- 최종 `make verify` 통과
- 실제 DMG와 Homebrew 설치 흐름 확인
