import SwiftUI

struct MonitorView: View {
  @Bindable var model: MonitorModel
  @State private var selectedGroupID: String?

  var body: some View {
    VStack(spacing: 0) {
      if let error = model.lastRefreshError {
        errorBanner(error)
      }

      GeometryReader { geometry in
        HStack(spacing: 0) {
          MemoryPieChart(
            chart: model.snapshot?.chart ?? emptyChart,
            metric: model.settings.memoryMetric,
            useBinaryUnits: model.settings.useBinaryUnits
          )
          .frame(width: max(300, geometry.size.width * 0.36))

          Divider()

          workUnitList
        }
      }
    }
    .navigationTitle("RAM Monitor")
    .searchable(text: $model.searchText, prompt: "Search work units")
    .onAppear { model.start() }
    .onDisappear { model.stop() }
  }

  private var emptyChart: MemoryChart {
    MemoryChart(denominatorBytes: 0, slices: [], wasNormalized: false)
  }

  private var workUnitList: some View {
    let visibleGroups = model.visibleGroups
    return VStack(spacing: 0) {
      columnHeaders
      Divider()

      if model.snapshot == nil {
        ContentUnavailableView("Loading processes", systemImage: "memorychip")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if visibleGroups.isEmpty {
        ContentUnavailableView("No matching work units", systemImage: "magnifyingglass")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .accessibilityLabel("No matching work units")
          .accessibilityIdentifier("no-matching-work-units")
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(visibleGroups) { group in
              ProcessGroupRow(
                group: group,
                metric: model.settings.memoryMetric,
                settings: model.settings,
                isExpanded: model.expandedGroupIDs.contains(group.id),
                isSelected: selectedGroupID == group.id,
                onToggle: { toggle(group.id) },
                onSelect: { selectedGroupID = group.id }
              )
            }
          }
        }
        .focusable()
        .onKeyPress(.downArrow) { moveSelection(by: 1) }
        .onKeyPress(.upArrow) { moveSelection(by: -1) }
        .onKeyPress(.leftArrow) { collapseSelection() }
        .onKeyPress(.rightArrow) { expandSelection() }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("work-unit-list")
  }

  private var columnHeaders: some View {
    HStack(spacing: 10) {
      sortButton("Work unit", order: .name)
        .frame(maxWidth: .infinity, alignment: .leading)
      sortButton("RAM", order: .memory)
        .frame(width: 90, alignment: .trailing)
      sortButton("CPU", order: .cpu)
        .frame(width: 64, alignment: .trailing)
      if model.settings.showThreadsColumn {
        Text("Threads").frame(width: 64, alignment: .trailing)
      }
      if model.settings.showPIDColumn {
        Text("PID").frame(width: 64, alignment: .trailing)
      }
      if model.settings.showProcessCountColumn {
        sortButton("Processes", order: .processCount)
          .frame(width: 76, alignment: .trailing)
      }
      if model.settings.showArchitectureColumn {
        Text("Architecture").frame(width: 88, alignment: .trailing)
      }
    }
    .font(.caption.weight(.semibold))
    .foregroundStyle(.secondary)
    .padding(.horizontal, 12)
    .frame(height: 36)
  }

  private func sortButton(_ title: String, order: SortOrder) -> some View {
    Button {
      model.selectSortOrder(order)
    } label: {
      HStack(spacing: 3) {
        Text(title)
        if model.sortOrder == order {
          Image(systemName: model.sortAscending ? "chevron.up" : "chevron.down")
            .font(.caption2)
        }
      }
      .frame(maxWidth: .infinity, alignment: title == "Work unit" ? .leading : .trailing)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Sort by \(title)")
  }

  private func errorBanner(_ error: String) -> some View {
    HStack {
      Image(systemName: "exclamationmark.triangle.fill")
      Text(error)
      Spacer()
      if model.isShowingStaleData, let date = model.lastSuccessfulRefresh {
        Text("Last updated \(date, format: .dateTime.hour().minute().second())")
          .foregroundStyle(.secondary)
      }
    }
    .font(.callout)
    .padding(.horizontal, 12)
    .frame(height: 36)
    .background(.orange.opacity(0.14))
  }

  private func toggle(_ id: String) {
    if model.expandedGroupIDs.contains(id) {
      model.expandedGroupIDs.remove(id)
    } else {
      model.expandedGroupIDs.insert(id)
    }
  }

  private func moveSelection(by offset: Int) -> KeyPress.Result {
    let groups = model.visibleGroups
    guard !groups.isEmpty else { return .ignored }
    let current = groups.firstIndex { $0.id == selectedGroupID }
    let next = min(max((current ?? (offset > 0 ? -1 : groups.count)) + offset, 0), groups.count - 1)
    selectedGroupID = groups[next].id
    return .handled
  }

  private func collapseSelection() -> KeyPress.Result {
    guard let selectedGroupID else { return .ignored }
    model.expandedGroupIDs.remove(selectedGroupID)
    return .handled
  }

  private func expandSelection() -> KeyPress.Result {
    guard let selectedGroupID else { return .ignored }
    model.expandedGroupIDs.insert(selectedGroupID)
    return .handled
  }
}
