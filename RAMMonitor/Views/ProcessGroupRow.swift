import AppKit
import SwiftUI

struct ProcessGroupRow: View {
  let group: ProcessGroup
  let metric: MemoryMetric
  let settings: MonitorSettings
  let isExpanded: Bool
  let isSelected: Bool
  let onToggle: () -> Void
  let onSelect: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      row(
        Values(
          name: group.displayName,
          memoryBytes: group.memoryBytes(for: metric),
          cpuPercent: group.totalCPUPercent,
          threads: group.totalThreads,
          pid: group.processes.count == 1 ? group.processes.first?.id.pid : nil,
          processCount: group.processes.count,
          architecture: groupArchitecture
        ),
        isChild: false
      )
      .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
      .contentShape(Rectangle())
      .onTapGesture(perform: onSelect)

      if isExpanded {
        ForEach(group.processes) { process in
          row(
            Values(
              name: process.name,
              memoryBytes: process.memoryBytes(for: metric),
              cpuPercent: process.cpuPercent,
              threads: process.threadCount,
              pid: process.id.pid,
              processCount: 1,
              architecture: process.architecture
            ),
            isChild: true
          )
          .background(Color.secondary.opacity(0.04))
        }
      }

      Divider()
    }
  }

  private var groupArchitecture: String? {
    let values = Set(group.processes.compactMap(\.architecture))
    if values.count == 1 { return values.first }
    return values.isEmpty ? nil : "Mixed"
  }

  @ViewBuilder private var groupIcon: some View {
    if let path = group.bundlePath {
      Image(nsImage: NSWorkspace.shared.icon(forFile: path))
        .resizable()
        .scaledToFit()
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    } else {
      Image(systemName: "gearshape.2")
        .frame(width: 20, height: 20)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
  }

  private func row(_ values: Values, isChild: Bool) -> some View {
    HStack(spacing: 10) {
      HStack(spacing: 7) {
        if isChild {
          Color.clear.frame(width: 37)
        } else {
          Button(action: onToggle) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
              .frame(width: 10)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(
            isExpanded ? "Collapse \(values.name)" : "Expand \(values.name)")
          groupIcon
        }
        Text(values.name).lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Text(ByteText.string(values.memoryBytes, binary: settings.useBinaryUnits))
        .frame(width: 90, alignment: .trailing)
        .monospacedDigit()
      Text(percent(values.cpuPercent))
        .frame(width: 64, alignment: .trailing)
        .monospacedDigit()
      if settings.showThreadsColumn {
        Text(number(values.threads)).frame(width: 64, alignment: .trailing).monospacedDigit()
      }
      if settings.showPIDColumn {
        Text(number(values.pid)).frame(width: 64, alignment: .trailing).monospacedDigit()
      }
      if settings.showProcessCountColumn {
        Text(values.processCount.formatted()).frame(width: 76, alignment: .trailing)
          .monospacedDigit()
      }
      if settings.showArchitectureColumn {
        Text(values.architecture ?? "—").frame(width: 88, alignment: .trailing)
      }
    }
    .font(isChild ? .caption : .body)
    .padding(.horizontal, 12)
    .frame(height: isChild ? 32 : 38)
    .accessibilityElement(children: isChild ? .ignore : .contain)
    .accessibilityLabel(
      "\(values.name), RAM \(ByteText.string(values.memoryBytes, binary: settings.useBinaryUnits)), CPU \(percent(values.cpuPercent)), \(optionalAccessibility(threads: values.threads, pid: values.pid, count: values.processCount, architecture: values.architecture))"
    )
  }

  private func percent(_ value: Double?) -> String {
    value.map { "\($0.formatted(.number.precision(.fractionLength(1))))%" } ?? "—"
  }

  private func number<T: BinaryInteger>(_ value: T?) -> String {
    value?.formatted() ?? "—"
  }

  private func optionalAccessibility(
    threads: Int32?,
    pid: pid_t?,
    count: Int,
    architecture: String?
  ) -> String {
    var values: [String] = []
    if settings.showThreadsColumn { values.append("Threads \(number(threads))") }
    if settings.showPIDColumn { values.append("PID \(number(pid))") }
    if settings.showProcessCountColumn { values.append("Processes \(count)") }
    if settings.showArchitectureColumn {
      values.append("Architecture \(architecture ?? "unknown")")
    }
    return values.joined(separator: ", ")
  }

  private struct Values {
    let name: String
    let memoryBytes: UInt64?
    let cpuPercent: Double?
    let threads: Int32?
    let pid: pid_t?
    let processCount: Int
    let architecture: String?
  }
}
