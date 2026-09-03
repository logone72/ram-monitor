# RAM Monitor

[English](README.md) | [한국어](README.ko.md)

RAM Monitor는 서로 연관된 하위 프로세스를 하나의 작업 단위로 묶어, 실제로 어떤 작업이 메모리를 사용하고 있는지 보여주는 네이티브 macOS 유틸리티입니다. RAM 사용량을 중심으로 실시간 CPU 사용량, 검색, 정렬, 표시 열 설정과 하위 프로세스 확인 기능을 제공합니다.

![RAM Monitor 대시보드](docs/screenshot.png)

## 요구 사항

- macOS 14 Sonoma 이상
- Apple Silicon 또는 Intel Mac
- 개발 시 Xcode 16 이상
- 개발 도구 설치 또는 Tap 설치 시에만 Homebrew 필요

## 메모리 측정 방식

- **Physical Footprint**가 기본값입니다. 전체 물리 RAM을 파이 차트의 기준으로 사용하며, 사용 가능 메모리와 시스템 또는 분류되지 않은 메모리도 함께 표시합니다.
- **Resident Size**는 수집된 프로세스의 상주 메모리를 표시합니다. 파이 차트의 기준은 전체 물리 RAM이 아니라 측정된 프로세스 메모리의 합계입니다.

메인 목록도 파이 차트에서 선택한 것과 동일한 측정 방식을 사용합니다. 프로세스는 번들 식별자가 있으면 번들 식별자로, 없으면 정확한 실행 파일 경로로 묶습니다.

## 빌드 및 실행

로컬 개발에는 유료 Apple Developer 계정이나 서명 인증서가 필요하지 않습니다.

```bash
brew bundle
make bootstrap
make verify
open RAMMonitor.xcodeproj
```

Xcode에서 `RAMMonitor` 스킴을 선택해 실행하거나, 명령줄에서 빌드한 앱을 직접 열 수 있습니다.

```bash
make build
open '.build/DerivedData/Build/Products/Debug/RAM Monitor.app'
```

## 설치

GitHub Releases에서 `RAM-Monitor-X.Y.Z.dmg`를 내려받아 열고 **RAM Monitor**를 응용 프로그램 폴더로 드래그합니다.

릴리스 빌드는 임시 서명되어 있으며 공증되지 않았습니다. 처음 실행할 때 앱을 마우스 오른쪽 버튼으로 클릭해 **열기**를 선택한 다음 다시 **열기**를 확인하세요. **시스템 설정 → 개인정보 보호 및 보안 → 확인 없이 열기**에서도 실행을 허용할 수 있습니다.

개인 Tap을 통한 릴리스가 제공되면 다음 명령으로 설치할 수 있습니다.

```bash
brew tap logone72/tap
brew install --cask ram-monitor
```

## 릴리스 빌드

품질 검사를 먼저 실행한 다음 임시 서명된 Universal 2 릴리스를 빌드합니다.

```bash
make verify
./scripts/build-release.sh 0.1.0
./scripts/build-release.sh --verify-only release/RAM-Monitor-0.1.0.dmg
```

스크립트는 앱, DMG, `SHA256SUMS`, 체크섬이 포함된 `ram-monitor.rb` Cask 파일을 `release/`에 생성합니다. `vX.Y.Z` 태그를 푸시하면 동일한 검증을 거쳐 릴리스 파일을 게시합니다. 생성된 Cask 파일을 `logone72/homebrew-tap/Casks/ram-monitor.rb`에 복사하면 개인 Tap에서 설치할 수 있습니다.

## 개인정보 및 권한

RAM Monitor는 RAM과 CPU 사용량을 계산하는 데 필요한 로컬 프로세스 목록과 Mach 프로세스 정보를 읽습니다. 샌드박스 환경에서는 시스템 전체 프로세스를 확인할 수 없기 때문에 App Sandbox는 비활성화되어 있습니다. 프로세스 정보는 디스크에 저장하거나 네트워크로 전송하지 않으며, 화면 설정만 `UserDefaults`에 저장합니다.

이 앱은 프로세스를 종료하거나 벤치마크를 실행하지 않으며 분석 데이터를 수집하지 않습니다.

## 개발

`make verify`는 전체 품질 검사 명령입니다. swift-format, SwiftLint, 공백 검사, 빌드, 코드 커버리지를 포함한 단위 및 UI 테스트, Xcode Analyze를 실행합니다. Git hook은 커밋 전에 포맷과 린트 검사를 실행하며 Conventional Commits 접두사를 검사합니다.

## 라이선스

MIT 라이선스를 따릅니다. 자세한 내용은 [LICENSE](LICENSE)를 확인하세요.
