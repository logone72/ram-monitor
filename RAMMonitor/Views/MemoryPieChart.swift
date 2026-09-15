import Charts
import SwiftUI

struct MemoryPieChart: View {
  let chart: MemoryChart
  let metric: MemoryMetric
  let totalPhysicalBytes: UInt64?
  let useBinaryUnits: Bool

  @State private var hoveredSliceID: String?

  var body: some View {
    VStack(spacing: 18) {
      Text(metric == .physicalFootprint ? "Physical Footprint" : "Resident Size")
        .font(.headline)

      ZStack {
        Chart(Array(chart.slices.enumerated()), id: \.element.id) { index, slice in
          SectorMark(
            angle: .value("Bytes", slice.bytes),
            innerRadius: .ratio(0.58),
            angularInset: 1
          )
          .foregroundStyle(color(for: slice, at: index))
          .accessibilityLabel(slice.label)
          .accessibilityValue(accessibilityValue(for: slice))
        }
        .chartLegend(.hidden)
        .frame(width: 230, height: 230)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("memory-pie-chart")
        .overlay {
          GeometryReader { geometry in
            Color.clear
              .contentShape(Circle())
              .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                  hoveredSliceID = sliceID(at: location, in: geometry.size)
                case .ended:
                  hoveredSliceID = nil
                }
              }
          }
        }

        VStack(spacing: 3) {
          if let hoveredSlice {
            Text(hoveredSlice.label)
              .font(.caption)
              .lineLimit(1)
            Text(ByteText.string(hoveredSlice.bytes, binary: useBinaryUnits))
              .font(.headline.monospacedDigit())
            Text(percentage(hoveredSlice.bytes))
              .font(.caption)
              .foregroundStyle(.secondary)
          } else {
            Text("Measured process total")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(ByteText.string(chart.denominatorBytes, binary: useBinaryUnits))
              .font(.headline.monospacedDigit())
          }
        }
        .multilineTextAlignment(.center)
        .frame(width: 120)
        .allowsHitTesting(false)
      }

      VStack(alignment: .leading, spacing: 7) {
        ForEach(Array(chart.slices.enumerated()), id: \.element.id) { index, slice in
          HStack(spacing: 7) {
            Circle()
              .fill(color(for: slice, at: index))
              .frame(width: 8, height: 8)
            Text(slice.label)
              .lineLimit(1)
            Spacer(minLength: 4)
            Text(ByteText.string(slice.bytes, binary: useBinaryUnits))
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
          .font(.caption)
          .accessibilityElement(children: .combine)
        }
      }
      .frame(maxWidth: 240)

      VStack(spacing: 7) {
        Divider()
        LabeledContent(
          "Physical RAM", value: ByteText.string(totalPhysicalBytes, binary: useBinaryUnits)
        )
        .font(.caption)
        .accessibilityIdentifier("physical-ram-summary")
        Text(
          "Percentages show each work unit’s share of measured process memory, not physical RAM usage."
        )
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: 240)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  private var hoveredSlice: ChartSlice? {
    chart.slices.first { $0.id == hoveredSliceID }
  }

  private func sliceID(at location: CGPoint, in size: CGSize) -> String? {
    guard chart.denominatorBytes > 0 else { return nil }
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let horizontalOffset = location.x - center.x
    let verticalOffset = location.y - center.y
    let radius = hypot(horizontalOffset, verticalOffset)
    let outerRadius = min(size.width, size.height) / 2
    guard radius >= outerRadius * 0.58, radius <= outerRadius else { return nil }

    let angle =
      (atan2(horizontalOffset, -verticalOffset) + 2 * .pi)
      .truncatingRemainder(dividingBy: 2 * .pi)
    let bytePosition = Double(chart.denominatorBytes) * angle / (2 * .pi)
    var boundary = 0.0
    for slice in chart.slices {
      boundary += Double(slice.bytes)
      if bytePosition < boundary { return slice.id }
    }
    return chart.slices.last?.id
  }

  private func percentage(_ bytes: UInt64) -> String {
    guard chart.denominatorBytes > 0 else { return "0%" }
    return (Double(bytes) / Double(chart.denominatorBytes)).formatted(
      .percent.precision(.fractionLength(1)))
  }

  private func accessibilityValue(for slice: ChartSlice) -> String {
    "\(ByteText.string(slice.bytes, binary: useBinaryUnits)), \(percentage(slice.bytes))"
  }

  private func color(for slice: ChartSlice, at index: Int) -> Color {
    switch slice.kind {
    case .other: .secondary
    case .group: Self.groupColors[index % Self.groupColors.count]
    }
  }

  private static let groupColors: [Color] = [
    .blue, .orange, .green, .purple, .pink, .cyan, .indigo, .yellow,
  ]
}

enum ByteText {
  static func string(_ bytes: UInt64?, binary: Bool) -> String {
    guard let bytes else { return "—" }
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = .useAll
    formatter.countStyle = binary ? .binary : .decimal
    formatter.includesUnit = true
    formatter.isAdaptive = true
    return formatter.string(fromByteCount: Int64(clamping: bytes))
  }
}
