# 배포 계획

## V1: 유료 Apple Developer 가입 없이 배포

배포 산출물은 Universal 2 `RAM Monitor.app`을 담은 DMG 하나다.

```text
Git tag vX.Y.Z
  → make verify
  → Release archive (arm64 + x86_64)
  → ad-hoc codesign
  → RAM-Monitor-X.Y.Z.dmg
  → SHA-256
  → GitHub Release
  → 개인 homebrew-tap의 ram-monitor cask 갱신
```

Apple은 서명하지 않은 macOS 앱을 직접 복사해 배포하는 방식도 제공하지만, Developer ID와 notarization이 없으면 Gatekeeper의 신뢰 확인을 받을 수 없다. V1은 이 제한을 README와 DMG 설치 안내에 명확히 적는다.

### 산출물

- `RAM-Monitor-X.Y.Z.dmg`
- `SHA256SUMS`
- GitHub Release notes
- `logone72/homebrew-tap`의 `Casks/ram-monitor.rb`

### 빌드 스크립트

`make verify`가 통과한 commit에서만 `scripts/build-release.sh X.Y.Z`를 실행한다. 스크립트가 아래 작업을 한 번에 수행한다.

1. Release configuration을 `arm64 x86_64`로 archive
2. archive에서 `RAM Monitor.app` 복사
3. `codesign --force --options runtime --sign -`로 ad-hoc 서명
4. 앱과 `/Applications` 바로가기를 staging 폴더에 배치
5. `hdiutil create`로 DMG 생성
6. `lipo`, `codesign`, `hdiutil verify` 검사
7. SHA-256 출력

DMG 배경 이미지와 별도 installer는 만들지 않는다.

### 개인 Homebrew Tap

```ruby
cask "ram-monitor" do
  version "X.Y.Z"
  sha256 "RELEASE_SHA256"

  url "https://github.com/logone72/ram-monitor/releases/download/v#{version}/RAM-Monitor-#{version}.dmg"
  name "RAM Monitor"
  desc "RAM-focused macOS process monitor with grouped subprocesses"
  homepage "https://github.com/logone72/ram-monitor"

  app "RAM Monitor.app"

  caveats <<~EOS
    This build is not notarized. On first launch, right-click RAM Monitor,
    choose Open, and confirm Open. You can also use Privacy & Security > Open Anyway.
  EOS
end
```

사용자 설치 명령:

```bash
brew tap logone72/tap
brew install --cask ram-monitor
```

`logone72/homebrew-tap`은 V1 release 작업에서 생성한다. release를 만들기 전에 `logone72/ram-monitor`를 공개로 전환하고 cask URL이 인증 없이 다운로드되는지 확인한다.

## V2: Developer ID 가입 후

유료 Apple Developer Program에 가입하면 다음 단계로 전환한다.

1. `Developer ID Application` 인증서로 앱 서명
2. Hardened Runtime과 secure timestamp 확인
3. DMG를 Apple notary service에 제출
4. notarization ticket을 DMG에 staple
5. `spctl --assess`와 깨끗한 Mac에서 최초 실행 검증
6. 개인 Tap에서 Gatekeeper caveat 제거

Apple은 Mac App Store 밖 배포에 Developer ID 서명과 notarization을 권장하며, Developer ID 인증서는 Apple Developer Program 또는 Enterprise Program 구성원에게 발급한다.

## 공식 `homebrew/cask` 전환 조건

공식 Homebrew cask는 V1 목표가 아니다. 2026-09-03 기준으로 다음 조건을 모두 충족한 뒤 진행한다.

- Gatekeeper 검사를 우회하지 않고 통과하는 notarized DMG
- 최신 macOS와 선언한 모든 아키텍처에서 동작
- 공개 홈페이지와 지속적으로 관리되는 upstream
- 일반 제출: 30 forks 또는 30 watchers 또는 75 stars
- 저장소 소유자의 self-submission: 90 forks 또는 90 watchers 또는 225 stars
- 생성 후 30일 이상 지난 저장소

수치 조건을 만족해도 공식 저장소 채택이 보장되지는 않는다. 그전에는 개인 Tap을 정식 설치 경로로 유지한다.

## 공식 근거

- [Apple Developer ID](https://developer.apple.com/support/developer-id/)
- [Apple: Packaging Mac software for distribution](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)
- [Homebrew: Acceptable Casks](https://docs.brew.sh/Acceptable-Casks)
- [Homebrew: Package Acceptance Policy](https://docs.brew.sh/Package-Acceptance-Policy)
