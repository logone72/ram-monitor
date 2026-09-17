#if DEBUG
  import Foundation

  enum UITestSample {
    static let raw = RawMonitorSample(
      processes: (1...32).flatMap { index in
        let name = String(format: "Work unit %02d", index)
        let bundle = BundleIdentity(
          id: "ui.work-unit.\(index)", displayName: name,
          path: "/Applications/UITest\(index).app")
        return (0..<2).map { child in
          ProcessSample(
            id: .init(pid: pid_t(index * 10 + child), startTime: 1),
            parentID: child == 0 ? 0 : pid_t(index * 10),
            name: child == 0 ? name : "\(name) helper",
            path: "\(bundle.path)/Contents/MacOS/process-\(child)",
            bundle: bundle,
            physicalFootprintBytes: UInt64(33 - (index + 8) % 32) * 32 * 1_024 * 1_024,
            residentSizeBytes: UInt64(index % 32 + 1) * 48 * 1_024 * 1_024,
            cpuPercent: Double(index), threadCount: 4, architecture: "Apple")
        }
      },
      systemMemory: .init(totalPhysicalBytes: 16 * 1_024 * 1_024 * 1_024),
      sampledAt: Date(timeIntervalSince1970: 1))
  }
#endif
