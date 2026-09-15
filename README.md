# RAM Monitor

[English](README.md) | [한국어](README.ko.md)

RAM Monitor is a native macOS utility that groups related subprocesses into one work unit so you can see what is actually using your memory. It keeps RAM at the center while retaining live CPU usage, search, sorting, configurable columns, and subprocess inspection.

![RAM Monitor dashboard](docs/screenshot.png)

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel Mac
- Full Xcode app at `/Applications/Xcode.app` for development (verified with Xcode 26.6)
- Homebrew for development tools

## Memory modes

- **Physical Footprint** is the default. It includes memory charged to a process, including compressed or swapped memory accounted for at its original size.
- **Resident Size** shows resident bytes reported for sampled processes. Shared memory can be counted in more than one process.

The main list uses the same selected metric as the chart. Processes are grouped by bundle identifier when one is available and by exact executable path otherwise.

Choose the metric in Settings (`⌘,`). In both modes, the pie uses the measured group total: the top eight work units and `Other` retain the same byte values as the list, without scaling. Percentages show each work unit's share of measured process memory, not physical RAM usage. Installed physical RAM is shown separately.

Search filters the list, not the chart. Compare totals with search cleared, counting each parent group once rather than adding its expanded subprocess rows again. Unavailable readings appear as `—` and are excluded from totals; CPU usage can exceed 100% across multiple cores.

## Build and run

No paid Apple Developer account or signing certificate is required for local development.

```bash
make build
open RAMMonitor.xcodeproj
```

Run these commands from the repository root. Select the `RAMMonitor` scheme and `My Mac` in Xcode, then press `⌘R`, or open the built app directly:

```bash
open '.build/DerivedData/Build/Products/Debug/RAM Monitor.app'
```

## Release status

The first public release is pending local testing and feedback improvements. DMG downloads and personal Homebrew Tap installation are planned. See [progress](docs/tasks.md).

Release builds are ad-hoc signed and are not notarized. macOS may require approval in **System Settings → Privacy & Security** before launch.

See [release instructions](docs/release.md) for Universal 2 DMG builds and publishing.

## Privacy and permissions

RAM Monitor reads the local process list and Mach process accounting values needed to calculate RAM and CPU usage. The App Sandbox is disabled because a sandboxed process cannot inspect system-wide processes. No process snapshots are written to disk or sent over the network; only UI preferences are stored in `UserDefaults`.

The app does not kill processes, run benchmarks, or collect analytics.

## Development

With Homebrew installed, prepare SwiftLint and Git hooks, then run the full checks:

```bash
make bootstrap
make verify
```

`make verify` is the single quality gate. It runs swift-format, SwiftLint, whitespace checks, build, unit and UI tests with coverage, and Xcode Analyze. Git hooks run formatting and lint checks before each commit and enforce conventional commit prefixes.

Use `make format` to apply formatting; hooks do not rewrite files. See [docs/index.md](docs/index.md) for specifications, architecture, and the development plan.

## License

MIT. See [LICENSE](LICENSE).
