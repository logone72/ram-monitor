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
- 현재 작업: [CI Binding 컴파일러 크래시 대응](tasks.md#후속-ci-binding-컴파일러-크래시-대응)
- 검증: 수정본 로컬 빌드·단위/통합 37개·lint·정적 분석 통과 · 원격 CI 미확인 (2026-09-17)
- 다음 작업: 원격 CI 재검증 → 최종 DMG 재생성·설치본 사용자 확인
- 이후 작업: 공개 GitHub Release와 personal Tap 설치 검증
- 상세 진행도: [`tasks.md`](tasks.md)

## 세부 문서

[제품](product.md) · [RAM 측정](memory.md) · [시스템 API](system-api.md) · [그룹핑](grouping.md) · [화면](interface.md) · [구조](architecture.md) · [하네스](harness.md) · [작업](tasks.md) · [구현](implementation.md) · [검증](quality.md) · [배포](release.md)
