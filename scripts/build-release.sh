#!/bin/bash

set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

readonly app_name="RAM Monitor"
readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly project_root="$(cd "$script_dir/.." && pwd)"
readonly release_dir="$project_root/release"
readonly project_path="$project_root/RAMMonitor.xcodeproj"
readonly scheme="RAMMonitor"

staging_dir=""
verification_mount_dir=""

cleanup() {
  if [[ -n "$verification_mount_dir" && -d "$verification_mount_dir" ]]; then
    hdiutil detach "$verification_mount_dir" >/dev/null 2>&1 || true
    rmdir "$verification_mount_dir" >/dev/null 2>&1 || true
  fi

  if [[ -n "$staging_dir" && -d "$staging_dir" ]]; then
    rm -rf "$staging_dir"
  fi
}

die() {
  echo "error: $*" >&2
  exit 1
}

verify_app() {
  local app_path="$1"
  local binary_path="$app_path/Contents/MacOS/$app_name"
  local architectures

  [[ -d "$app_path" ]] || die "app not found: $app_path"
  [[ -f "$binary_path" ]] || die "app binary not found: $binary_path"

  architectures="$(lipo -archs "$binary_path")"
  [[ " $architectures " == *" arm64 "* ]] || die "arm64 architecture is missing"
  [[ " $architectures " == *" x86_64 "* ]] || die "x86_64 architecture is missing"
  codesign --verify --deep --strict --verbose=2 "$app_path"
}

verify_dmg() {
  local candidate_dmg="$1"

  [[ -f "$candidate_dmg" ]] || die "DMG not found: $candidate_dmg"
  hdiutil verify "$candidate_dmg"

  verification_mount_dir="$(mktemp -d "${TMPDIR:-/tmp}/ram-monitor-verify.XXXXXX")"
  hdiutil attach -nobrowse -readonly -mountpoint "$verification_mount_dir" "$candidate_dmg" >/dev/null
  verify_app "$verification_mount_dir/$app_name.app"
  hdiutil detach "$verification_mount_dir" >/dev/null
  rmdir "$verification_mount_dir"
  verification_mount_dir=""
}

usage() {
  echo "Usage: $0 X.Y.Z"
  echo "       $0 --verify-only path/to/RAM-Monitor-X.Y.Z.dmg"
}

trap cleanup EXIT

[[ -d "$project_path" ]] || die "Xcode project not found: $project_path"

if [[ "${1:-}" == "--verify-only" ]]; then
  [[ $# -eq 2 ]] || {
    usage >&2
    exit 64
  }
  verify_dmg "$2"
  echo "Verified: $2"
  exit 0
fi

[[ $# -eq 1 ]] || {
  usage >&2
  exit 64
}

readonly version="$1"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must use X.Y.Z"

readonly archive_path="$release_dir/RAMMonitor.xcarchive"
readonly archived_app="$archive_path/Products/Applications/$app_name.app"
readonly output_app="$release_dir/$app_name.app"
readonly dmg_path="$release_dir/RAM-Monitor-$version.dmg"
readonly checksum_path="$release_dir/SHA256SUMS"
readonly cask_path="$release_dir/ram-monitor.rb"

mkdir -p "$release_dir"
rm -rf "$archive_path" "$output_app"
rm -f "$dmg_path" "$checksum_path" "$cask_path"

cd "$project_root"
xcodebuild archive \
  -project "$project_path" \
  -scheme "$scheme" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$archive_path" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  SKIP_INSTALL=NO \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  MARKETING_VERSION="$version"

[[ -d "$archived_app" ]] || die "archive did not contain $app_name.app"
ditto "$archived_app" "$output_app"
codesign --force --deep --options runtime --sign - --timestamp=none "$output_app"
verify_app "$output_app"

staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/ram-monitor-release.XXXXXX")"
ditto "$output_app" "$staging_dir/$app_name.app"
ln -s /Applications "$staging_dir/Applications"
hdiutil create \
  -volname "$app_name" \
  -srcfolder "$staging_dir" \
  -format UDZO \
  -ov \
  "$dmg_path"

verify_dmg "$dmg_path"

readonly dmg_filename="$(basename "$dmg_path")"
readonly checksum="$(shasum -a 256 "$dmg_path" | awk '{print $1}')"
printf '%s  %s\n' "$checksum" "$dmg_filename" > "$checksum_path"

cat > "$cask_path" <<EOF
cask "ram-monitor" do
  version "$version"
  sha256 "$checksum"

  url "https://github.com/logone72/ram-monitor/releases/download/v#{version}/RAM-Monitor-#{version}.dmg"
  name "RAM Monitor"
  desc "RAM-focused process monitor with grouped subprocesses"
  homepage "https://github.com/logone72/ram-monitor"

  depends_on macos: :sonoma

  app "RAM Monitor.app"

  caveats <<~EOS
    This build is not notarized. On first launch, right-click RAM Monitor,
    choose Open, and confirm Open. You can also use Privacy & Security > Open Anyway.
  EOS
end
EOF

echo "Created: $dmg_path"
echo "SHA-256: $checksum"
echo "Cask: $cask_path"
