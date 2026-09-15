# 제품 정의

## 목표

RAM Monitor는 macOS의 개별 프로세스를 그대로 나열하지 않고, 사용자가 인식할 수 있는 작업 단위로 묶어 RAM과 CPU 사용량을 보여준다. 핵심 질문은 “어떤 작업이 RAM을 얼마나 사용하고 있는가?”이다.

## 제품 식별자

| 항목 | 값 |
|---|---|
| 제품명 | RAM Monitor |
| 저장소명 | `ram-monitor` |
| GitHub 저장소 | `logone72/ram-monitor` |
| 문서·구현 기준 | 이 저장소 루트 |
| Xcode 프로젝트·스킴 | `RAMMonitor` |
| 앱 번들 | `RAM Monitor.app` |
| Bundle ID | `com.roegankim.RAMMonitor` |
| 지원 OS | macOS 14 Sonoma 이상 |
| 아키텍처 | Universal 2 (`arm64`, `x86_64`) |
| 공개 방식 | V1 release 전에 `logone72/ram-monitor`를 공개 전환 |
| 라이선스 | MIT, `Copyright (c) 2026 roegankim` |

GitHub 계정과 코드 식별자는 서로 다른 값으로 고정한다. 배포 URL과 Tap 소유자는 `logone72`, Bundle ID와 라이선스 저작권자는 `roegankim`을 사용한다.

## V1 범위

- 선택한 측정 모드의 프로세스 합계를 기준으로 한 작업별 RAM 파이 차트와 별도 물리 RAM 용량 요약
- Physical Footprint와 Resident Size 측정 모드
- 작업 그룹별 RAM과 CPU 합계
- 그룹을 펼쳐 subprocess별 RAM과 CPU 확인
- 이름과 subprocess 이름 검색
- RAM, CPU, 이름 정렬
- 새로고침 간격, 단위, 기본 정렬, 열 표시, 로그인 시 실행 설정
- 앱 아이콘과 시스템 프로세스 대체 아이콘

## 성공 조건

1. 사용자는 실행 직후 어느 작업이 RAM을 가장 많이 쓰는지 확인할 수 있다.
2. 파이 차트, 목록 값, 백분율, RAM 정렬은 항상 같은 측정 모드를 사용하며 같은 그룹의 차트·목록 바이트 값이 일치한다.
3. 동일 그룹에 속한 subprocess RAM과 CPU의 합이 상위 행에 반영된다.
4. 보호되거나 종료 중인 프로세스 때문에 전체 새로고침이 실패하지 않는다.
5. 수집 데이터는 현재 화면을 구성하는 데만 사용한다.

## 개발 기준

제품 동작은 아래처럼 이 저장소의 사양으로 고정한다.

- `actor`가 시스템 호출과 이전 CPU 샘플 상태를 소유하는 흐름
- `@Observable @MainActor` 모델이 새로고침과 화면 상태를 관리하는 흐름
- `.app` 경로, 부모 체인, XPC 순서의 그룹 탐색
- Bundle ID 우선, 실행 경로 fallback인 그룹 키
- 그룹 행을 펼쳐 subprocess를 표시하는 상호작용
- SwiftUI, Swift Testing, Apple 시스템 프레임워크만 사용하는 구성

구현의 source of truth는 `docs/`와 macOS SDK다. 코드와 자산은 이 저장소에서 관리한다.
