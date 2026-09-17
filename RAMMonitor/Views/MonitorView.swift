import SwiftUI

struct MonitorView: View {
  @Bindable var model: MonitorModel
  @State private var listFocusRequest = 0
  @State private var pendingScrollGroupID: String?
  @FocusState private var isListFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      if let error = model.lastRefreshError {
        errorBanner(error)
      }

      GeometryReader { geometry in
        HStack(spacing: 0) {
          ScrollView {
            MemoryPieChart(
              chart: model.snapshot?.chart ?? emptyChart,
              metric: model.settings.memoryMetric,
              totalPhysicalBytes: model.snapshot?.totalPhysicalBytes,
              useBinaryUnits: model.settings.useBinaryUnits,
              selectedGroupID: model.selectedGroupID,
              selectedSliceID: model.selectedChartSliceID,
              onSelectSlice: { id in
                if model.selectChartSlice(id) { listFocusRequest += 1 }
              }
            )
            .background { SummaryScrollConfiguration().allowsHitTesting(false) }
          }
          .accessibilityIdentifier("memory-summary-scroll")
          .frame(width: max(300, geometry.size.width * 0.36))

          Divider()

          workUnitList
        }
      }
    }
    .contentShape(Rectangle())
    .onTapGesture { model.selectedGroupID = nil }
    .onChange(of: model.selectedGroupID) {
      if model.selectedGroupID == nil { pendingScrollGroupID = nil }
    }
    .navigationTitle("RAM Monitor")
    .searchable(text: $model.searchText, prompt: "Search work units")
    .onAppear { model.start() }
    .onDisappear { model.stop() }
  }

  private var emptyChart: MemoryChart {
    MemoryChart(denominatorBytes: 0, slices: [])
  }

  private var workUnitList: some View {
    let visibleGroups = model.visibleGroups
    return ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
          Section {
            ForEach(visibleGroups) { group in
              ProcessGroupRow(
                group: group,
                metric: model.settings.memoryMetric,
                settings: model.settings,
                isExpanded: model.expandedGroupIDs.contains(group.id),
                isSelected: model.selectedGroupID == group.id,
                onToggle: { toggle(group.id) },
                onSelect: {
                  model.toggleGroupSelection(group.id)
                  isListFocused = true
                }
              )
              .task(id: pendingScrollGroupID) {
                guard pendingScrollGroupID == group.id, model.selectedGroupID == group.id else {
                  return
                }
                proxy.scrollTo("row:\(group.id)", anchor: .center)
                pendingScrollGroupID = nil
              }
            }
          } header: {
            VStack(spacing: 0) {
              columnHeaders
              Divider()
            }
            .background(.background)
          }
        }
      }
      .overlay {
        Group {
          if model.snapshot == nil {
            ContentUnavailableView("Loading processes", systemImage: "memorychip")
          } else if visibleGroups.isEmpty {
            ContentUnavailableView("No matching work units", systemImage: "magnifyingglass")
              .accessibilityLabel("No matching work units")
              .accessibilityIdentifier("no-matching-work-units")
          }
        }
        .padding(.top, 36)
        .allowsHitTesting(false)
      }
      .focusable()
      .focusEffectDisabled()
      .focused($isListFocused)
      .onKeyPress(.downArrow) { moveSelection(by: 1) }
      .onKeyPress(.upArrow) { moveSelection(by: -1) }
      .onKeyPress(.leftArrow) { collapseSelection() }
      .onKeyPress(.rightArrow) { expandSelection() }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("work-unit-list")
      .onChange(of: listFocusRequest) {
        guard let id = model.selectedGroupID else { return }
        // Realize the lazy group first; its task then reveals the parent row below the pinned header.
        proxy.scrollTo(id, anchor: .top)
        pendingScrollGroupID = id
        isListFocused = true
      }
    }
  }

  private var columnHeaders: some View {
    HStack(spacing: WorkListLayout.spacing) {
      sortButton("Work unit", order: .name)
        .frame(maxWidth: .infinity, alignment: .leading)
      sortButton("RAM", order: .memory)
        .frame(width: WorkListLayout.memoryWidth, alignment: .trailing)
      sortButton("CPU", order: .cpu)
        .frame(width: WorkListLayout.cpuWidth, alignment: .trailing)
      if model.settings.showThreadsColumn {
        Text("Threads").frame(width: WorkListLayout.threadsWidth, alignment: .trailing)
      }
      if model.settings.showPIDColumn {
        Text("PID").frame(width: WorkListLayout.pidWidth, alignment: .trailing)
      }
      if model.settings.showProcessCountColumn {
        sortButton("Processes", order: .processCount)
          .frame(width: WorkListLayout.processCountWidth, alignment: .trailing)
      }
      if model.settings.showArchitectureColumn {
        Text("Architecture").frame(width: WorkListLayout.architectureWidth, alignment: .trailing)
      }
    }
    .font(.caption.weight(.semibold))
    .foregroundStyle(.secondary)
    .padding(.horizontal, WorkListLayout.horizontalPadding)
    .frame(height: 36)
  }

  private func sortButton(_ title: String, order: SortOrder) -> some View {
    Button {
      model.selectedGroupID = nil
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
    model.selectedGroupID = nil
    if model.expandedGroupIDs.contains(id) {
      model.expandedGroupIDs.remove(id)
    } else {
      model.expandedGroupIDs.insert(id)
    }
  }

  private func moveSelection(by offset: Int) -> KeyPress.Result {
    let groups = model.visibleGroups
    guard !groups.isEmpty else { return .ignored }
    let current = groups.firstIndex { $0.id == model.selectedGroupID }
    let next = min(max((current ?? (offset > 0 ? -1 : groups.count)) + offset, 0), groups.count - 1)
    model.selectedGroupID = groups[next].id
    listFocusRequest += 1
    return .handled
  }

  private func collapseSelection() -> KeyPress.Result {
    guard let selectedGroupID = model.selectedGroupID else { return .ignored }
    model.expandedGroupIDs.remove(selectedGroupID)
    return .handled
  }

  private func expandSelection() -> KeyPress.Result {
    guard let selectedGroupID = model.selectedGroupID else { return .ignored }
    model.expandedGroupIDs.insert(selectedGroupID)
    return .handled
  }
}
