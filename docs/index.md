# RAM Monitor

macOS의 여러 subprocess를 작업 단위로 묶어 **실제 RAM 점유를 한눈에 보여주는 모니터**.

## 핵심

- 공개 저장소 · `logone72/ram-monitor` · 표시 이름 `RAM Monitor` · macOS 14+
- RAM 모드: Physical Footprint(기본) / Resident Size
- 파이 차트: 선택 모드의 측정 프로세스 합계 기준 · 물리 RAM 용량은 별도 표시
- 화면: 큰 파이 차트 + 하나로 통합한 작업 목록 + subprocess 확장
- 기능: RAM, CPU, 검색, 정렬, 열 설정, 새로고침, 로그인 시 실행
- 품질: 단일 검증 명령 + 로컬 Git 검사 + CI

## 진행도

- 계획: 완료
- 구현: `8 / 9`
- 현재 작업: Task 9 — GitHub Release 완료, 개인 Tap 후속 준비
- 검증: `cce61a0` [원격 CI 통과](https://github.com/logone72/ram-monitor/actions/runs/36378499871) · 0.1.0 Universal DMG 재생성·무결성·서명 검사 통과 (2026-09-28)
- 공개 배포: [v0.1.0](https://github.com/logone72/ram-monitor/releases/tag/v0.1.0) · 비인증 다운로드·체크섬·서명 검증 통과
- 다음 작업: personal Tap 배포와 설치 검증 (별도 승인 후)
- 상세 진행도: [`tasks.md`](tasks.md)

## 세부 문서

[제품](product.md) · [RAM 측정](memory.md) · [시스템 API](system-api.md) · [그룹핑](grouping.md) · [화면](interface.md) · [구조](architecture.md) · [하네스](harness.md) · [작업](tasks.md) · [구현](implementation.md) · [검증](quality.md) · [배포](release.md)
