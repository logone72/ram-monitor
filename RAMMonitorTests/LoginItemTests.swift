import AppKit
import Foundation
import ServiceManagement
import SwiftUI
import Testing

@testable import RAMMonitor

@Suite("Login item")
struct LoginItemTests {
  @Test @MainActor func returningToAppRefreshesLoginItemStatus() throws {
    let defaults = try #require(UserDefaults(suiteName: #function))
    defer { defaults.removePersistentDomain(forName: #function) }
    let model = MonitorModel(defaults: defaults, sample: { throw CancellationError() })
    var reads = 0
    let view = NSHostingView(
      rootView: SettingsView(
        model: model,
        readLoginItemStatus: {
          reads += 1
          return .requiresApproval
        }))
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
      styleMask: [], backing: .buffered, defer: false)
    window.contentView = view
    defer { window.contentView = nil }
    view.layoutSubtreeIfNeeded()
    let beforeActivation = reads

    NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: NSApp)

    #expect(reads > beforeActivation)
  }

  @Test(arguments: [SMAppService.Status.enabled, .requiresApproval, .notRegistered, .notFound])
  @MainActor func changeReadsResultingOSStatus(status: SMAppService.Status) {
    var registered = false
    let result = SettingsView.applyLaunchAtLogin(
      true,
      registration: { registered = $0 },
      status: { registered ? status : .notRegistered })

    #expect(registered)
    #expect(result.status == status)
    #expect(result.error == nil)
  }

  @Test @MainActor func pendingApprovalDoesNotRegisterAgainAndCanBeCancelled() {
    var status = SMAppService.Status.requiresApproval
    var calls = 0
    let registration: (Bool) throws -> Void = { enabled in
      calls += 1
      status = enabled ? .requiresApproval : .notRegistered
    }
    let pending = SettingsView.applyLaunchAtLogin(
      true, registration: registration, status: { status })
    #expect(calls == 0)
    #expect(pending.status == .requiresApproval)

    let cancelled = SettingsView.applyLaunchAtLogin(
      false, registration: registration, status: { status })
    #expect(calls == 1)
    #expect(cancelled.status == .notRegistered)
  }

  @Test @MainActor func failureStillReadsOSStatus() {
    let result = SettingsView.applyLaunchAtLogin(
      false,
      registration: { _ in throw LoginError.failed },
      status: { .enabled })

    #expect(result.status == .enabled)
    #expect(result.error != nil)
  }
}

private enum LoginError: Error {
  case failed
}
