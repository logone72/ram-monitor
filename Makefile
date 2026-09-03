PROJECT := RAMMonitor.xcodeproj
SCHEME := RAMMonitor
DESTINATION := platform=macOS
DERIVED_DATA := .build/DerivedData
SWIFT_PATHS := RAMMonitor RAMMonitorTests RAMMonitorUITests
DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
export DEVELOPER_DIR

.PHONY: bootstrap doctor format format-check lint release-check build test analyze check verify

bootstrap:
	brew bundle --file=Brewfile
	git config core.hooksPath .githooks
	chmod +x .githooks/pre-commit .githooks/commit-msg

doctor:
	@test -x '$(DEVELOPER_DIR)/usr/bin/xcodebuild'
	@command -v xcrun >/dev/null
	@command -v swiftlint >/dev/null
	xcodebuild -version
	xcrun swift --version
	xcrun swift-format --version
	swiftlint version

format:
	xcrun swift-format format --configuration .swift-format --recursive --parallel --in-place $(SWIFT_PATHS)

format-check:
	xcrun swift-format lint --configuration .swift-format --recursive --parallel --strict $(SWIFT_PATHS)

lint:
	swiftlint lint --strict --config .swiftlint.yml

release-check:
	bash -n scripts/build-release.sh

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) build

test:
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) -enableCodeCoverage YES

analyze:
	xcodebuild analyze -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA)

check: format-check lint release-check
	git diff --check
	git diff --cached --check

verify: doctor check build test analyze
