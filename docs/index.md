# RAM Monitor

macOS의 여러 subprocess를 작업 단위로 묶어 **실제 RAM 점유를 한눈에 보여주는 모니터**.

## 핵심

- V1 release 전 공개 전환 · `logone72/ram-monitor` · 표시 이름 `RAM Monitor` · macOS 14+
- 기본 RAM: Physical Footprint / 전체 물리 RAM 기준 파이 차트
- 선택 RAM: Resident Size / 측정 프로세스 합계 기준 파이 차트
- 화면: 큰 파이 차트 + 하나로 통합한 작업 목록 + subprocess 확장
- 기능: RAM, CPU, 검색, 정렬, 열 설정, 새로고침, 로그인 시 실행
- 품질: 단일 검증 명령 + 로컬 Git 검사 + CI

## 진행도

- 계획: 완료
- 구현: `8 / 9`
- 현재 작업: [Task 9 — Universal DMG와 개인 Tap release](tasks.md#작업-목록)
- 다음 작업: 사용자 직접 테스트 → 피드백 반영 → 재검증
- 이후 작업: 공개 GitHub Release와 personal Tap 설치 검증
- 상세 진행도: [`tasks.md`](tasks.md)

## 세부 문서

[제품](product.md) · [RAM 측정](memory.md) · [시스템 API](system-api.md) · [그룹핑](grouping.md) · [화면](interface.md) · [구조](architecture.md) · [하네스](harness.md) · [작업](tasks.md) · [구현](implementation.md) · [검증](quality.md) · [배포](release.md)
