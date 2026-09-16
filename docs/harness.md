# 개발 하네스

## 목적

사람과 에이전트가 같은 명령과 같은 판정 기준으로 작업한다. 로컬 검사는 빠르게 실패 원인을 보여주고, 최종 합격 여부는 `make verify`와 CI가 결정한다.

## 기준 도구

| 영역 | 도구 | 기준 명령 |
|---|---|---|
| 포맷 | Xcode toolchain의 `swift-format` | `make format-check` |
| 정적 검사 | SwiftLint | `make lint` |
| 빌드 | `xcodebuild` | `make build` |
| 테스트·커버리지 | Swift Testing, XCTest UI Testing | `make test` |
| 정적 분석 | Xcode Analyze | `make analyze` |
| 전체 검증 | Make | `make verify` |
| 로컬 Git 검사 | 저장소에 포함한 hook | `pre-commit`, `commit-msg` |
| 원격 검증 | GitHub Actions | `verify` job |

앱 실행 파일에는 외부 패키지를 연결하지 않는다. SwiftLint는 개발 도구로만 설치한다.

저장소의 Xcode 명령은 시스템 `xcode-select` 상태에 의존하지 않는다. `Makefile`이 기본 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`를 export하고, 다른 Xcode를 사용할 때만 호출자가 이 값을 덮어쓴다. `doctor`와 CI 로그에 실제 Xcode 버전을 남긴다.

CI와 Release는 `macos-26` 러너의 `/Applications/Xcode_26.6.app/Contents/Developer`를 명시해 같은 toolchain을 사용한다. 러너 기본 Xcode 경로에 의존하지 않는다. Xcode 16.4 SDK에는 수집에 사용하는 `proc_archinfo`·`PROC_PIDARCHINFO`가 없으므로 `doctor`가 SDK 버전을 출력하고 두 선언의 Swift import를 빌드 전에 검사한다. 빌드 환경과 앱 실행 최소 버전은 별개이며 deployment target은 macOS 14를 유지한다.

러너의 Xcode·SDK 조합은 [GitHub 공식 이미지 목록](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md#xcode)에서 확인한다. 고정 버전을 변경할 때는 CI와 Release를 함께 갱신하고 `doctor`와 전체 검증을 다시 실행한다.

## 관리 파일

```text
AGENTS.md
CLAUDE.md -> AGENTS.md
.gitignore
.swift-format
.swiftlint.yml
Brewfile
Makefile
.githooks/
├── pre-commit
└── commit-msg
.github/workflows/
└── ci.yml
```

- `AGENTS.md`: 저장소 목적, 구조, 검증 명령, 변경 규칙을 100줄 이내로 유지한다.
- `CLAUDE.md`: `AGENTS.md`를 가리키는 심볼릭 링크로 두어 규칙 정의를 한 파일로 유지한다.
- `Brewfile`: 로컬 검증에 필요한 SwiftLint 버전을 Homebrew로 설치한다.
- `Makefile`: 사람, hook, CI가 공유하는 단일 명령 표면이다.
- Git hook: 검사만 실행하며 소스와 staging 상태를 자동으로 바꾸지 않는다.
- CI: 새 checkout에서 도구를 설치하고 `make verify`를 실행한다.

## 표준 작업 흐름

Homebrew와 Xcode가 설치된 Mac에서 처음 한 번:

```bash
make bootstrap
make doctor
```

평소 개발:

```bash
make format
make check
```

작업 완료 전:

```bash
make verify
```

명령의 책임은 다음과 같다.

- `bootstrap`: `Brewfile` 설치, `core.hooksPath=.githooks` 설정, hook 실행 권한 설정
- `doctor`: Xcode, Swift, swift-format, SwiftLint 사용 가능 여부·버전 출력과 필수 SDK 선언 import 검사
- `format`: Swift 소스 포맷 적용
- `format-check`: 포맷 차이 검사
- `lint`: SwiftLint 경고를 실패로 처리
- `release-check`: 배포 스크립트 Bash 문법 검사
- `build`: macOS 앱 빌드
- `test`: unit·UI test 실행 및 code coverage 수집
- `analyze`: Xcode 정적 분석
- `check`: whitespace, 포맷, lint, 배포 스크립트 검사
- `verify`: doctor, check, build, test, analyze 전체 실행

## 로컬 Git 검사

`pre-commit`은 `make check`를 실행한다. 실패하면 원인을 출력하고 commit을 중단한다.

`commit-msg`는 아래 형식을 검사한다.

```text
<type>(optional-scope): short description
```

허용 type은 `feat`, `fix`, `refactor`, `chore`, `test`, `docs`, `build`, `ci`다. merge와 revert commit은 Git 기본 제목을 허용한다.

## CI 합격 조건

`.github/workflows/ci.yml`은 `pull_request`와 `main` push에서 실행한다.

1. 저장소 checkout
2. `macos-26`에서 `DEVELOPER_DIR=/Applications/Xcode_26.6.app/Contents/Developer` 설정
3. `brew bundle --file=Brewfile`
4. `make verify`

job 이름은 `verify`로 고정한다. 저장소 설정에서는 `main` 변경 전에 이 job 성공을 요구한다. 동일 branch의 이전 실행은 취소해 불필요한 대기 시간을 줄인다.

## 에이전트 작업 규칙

- 구현 전 관련 `docs/`와 호출 경로를 읽는다.
- 동작 변경은 먼저 실패하는 최소 테스트로 경계를 고정한다.
- 새 계층과 dependency보다 Swift 표준 라이브러리와 Apple 프레임워크를 우선한다.
- 수정 범위와 무관한 파일은 건드리지 않는다.
- 완료 보고에는 변경 파일과 실행한 검증 결과를 적는다.
- Git staging, commit, push, release는 현재 요청에서 명시적으로 승인된 경우에만 수행한다.

## 운영 기준

- `make check`는 로컬 반복에 맞게 빠르게 유지한다.
- `make verify`는 완료 판정에 필요한 전체 검사를 포함한다.
- 규칙 변경은 설정 파일과 이 문서를 함께 수정한다.
- 경고 예외는 파일 전체 비활성화보다 필요한 줄에 가장 좁게 적용하고 이유를 남긴다.
- 테스트 커버리지는 CI에서 수집하되 초기에는 수치 기준을 두지 않는다. 안정된 기준선이 생기면 감소 방지 기준을 추가한다.
