# RAM Monitor

macOS 14+에서 subprocess를 작업 단위로 묶어 RAM과 CPU를 보여주는 SwiftUI 앱이다.

## Source of truth

- 제품과 기술 계약: `docs/`
- 진행 상태: `docs/tasks.md`
- 초기 구현 순서·기록: `docs/implementation.md` (현행 구현은 연결된 소스, 완료 판정은 `docs/quality.md`)
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
