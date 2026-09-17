# RAM Monitor

macOS의 여러 subprocess를 작업 단위로 묶어 **실제 RAM 점유를 한눈에 보여주는 모니터**.

## 핵심

- V1 release 전 공개 전환 · `logone72/ram-monitor` · 표시 이름 `RAM Monitor` · macOS 14+
- RAM 모드: Physical Footprint(기본) / Resident Size
- 파이 차트: 선택 모드의 측정 프로세스 합계 기준 · 물리 RAM 용량은 별도 표시
- 화면: 큰 파이 차트 + 하나로 통합한 작업 목록 + subprocess 확장
- 기능: RAM, CPU, 검색, 정렬, 열 설정, 새로고침, 로그인 시 실행
- 품질: 단일 검증 명령 + 로컬 Git 검사 + CI

## 진행도

- 계획: 완료
- 구현: `8 / 9`
- 현재 작업: [Task 9 — Universal DMG와 개인 Tap release](tasks.md#작업-목록)
- 검증: `make verify`(단위 30개 · UI 15개) 통과 · 단순화한 R 아이콘의 0.1.0 DMG 재생성·설치 확인 (2026-09-16)
- 다음 작업: CI 초기 창 높이 수정본의 원격 재검증 · 설치본 사용자 최종 확인
- 이후 작업: 공개 GitHub Release와 personal Tap 설치 검증
- 상세 진행도: [`tasks.md`](tasks.md)

## 세부 문서

[제품](product.md) · [RAM 측정](memory.md) · [시스템 API](system-api.md) · [그룹핑](grouping.md) · [화면](interface.md) · [구조](architecture.md) · [하네스](harness.md) · [작업](tasks.md) · [구현](implementation.md) · [검증](quality.md) · [배포](release.md)
