import AppKit
import ApplicationServices
import IOKit.hid
import SwiftUI

/// Callido brand colours, shared by the setup window.
enum Brand {
    static let violet = Color(red: 58 / 255, green: 30 / 255, blue: 140 / 255)
    static let plum = Color(red: 122 / 255, green: 52 / 255, blue: 150 / 255)
    static let coral = Color(red: 232 / 255, green: 98 / 255, blue: 104 / 255)
    static let amber = Color(red: 248 / 255, green: 160 / 255, blue: 72 / 255)
    static let gradient = LinearGradient(colors: [violet, plum, coral, amber],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// Live view of what Callido Touch needs: the two privacy permissions and a connected panel.
final class SetupModel: ObservableObject {
    @Published var inputMonitoring = false
    @Published var accessibility = false
    @Published var devices: [String] = []
    /// Input Monitoring only takes effect after a restart; true once it was granted while running.
    @Published var needsRestart = false

    private let launchedWithInputMonitoring: Bool
    private let deviceNames: () -> [String]
    private var timer: Timer?

    init(deviceNames: @escaping () -> [String]) {
        self.deviceNames = deviceNames
        launchedWithInputMonitoring = SetupModel.hasInputMonitoring
        refresh()
    }

    static var hasInputMonitoring: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    static var allGranted: Bool { hasInputMonitoring && AXIsProcessTrusted() }

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        inputMonitoring = SetupModel.hasInputMonitoring
        accessibility = AXIsProcessTrusted()
        devices = deviceNames()
        needsRestart = inputMonitoring && !launchedWithInputMonitoring
    }

    func openInputMonitoring() {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    func openAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    private func open(_ url: String) {
        if let url = URL(string: url) { NSWorkspace.shared.open(url) }
    }
}

struct SetupView: View {
    @ObservedObject var model: SetupModel
    var onRestart: () -> Void
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 14) {
                PermissionRow(
                    title: "Input Monitoring",
                    detail: "Lets Callido Touch read the touch screen and the pen.",
                    granted: model.inputMonitoring, action: model.openInputMonitoring)
                PermissionRow(
                    title: "Accessibility",
                    detail: "Lets Callido Touch click, scroll and type for you.",
                    granted: model.accessibility, action: model.openAccessibility)
                Divider()
                deviceRow
                if model.needsRestart {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.clockwise.circle.fill").foregroundStyle(Brand.coral)
                        Text("Input Monitoring takes effect after a restart.").font(.callout)
                        Spacer()
                        Button("Restart Now", action: onRestart)
                    }
                }
            }
            .padding(24)
            Divider()
            HStack {
                Text("Callido Touch \(Bundle.main.shortVersion)").font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Button(model.inputMonitoring && model.accessibility ? "Done" : "Later", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 500)
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Callido Touch").font(.system(size: 24, weight: .bold))
                Text("Touch screen and pen support for your Mac.")
                    .font(.callout).opacity(0.9)
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(24)
        .background(Brand.gradient)
    }

    private var deviceRow: some View {
        HStack(alignment: .top, spacing: 12) {
            StatusIcon(ok: !model.devices.isEmpty, pendingSymbol: "cable.connector")
            VStack(alignment: .leading, spacing: 2) {
                Text("Touch screen").font(.headline)
                if model.devices.isEmpty {
                    Text(model.inputMonitoring && !model.needsRestart
                         ? "No touch screen or pen found. Connect it with a USB cable that carries data."
                         : "Shown here once Input Monitoring is allowed.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(model.devices, id: \.self) { Text($0).font(.callout).foregroundStyle(.secondary) }
                }
            }
            Spacer()
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            StatusIcon(ok: granted, pendingSymbol: "lock.circle")
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Text("Allowed").font(.callout).foregroundStyle(.secondary)
            } else {
                Button("Open Settings…", action: action)
            }
        }
    }
}

private struct StatusIcon: View {
    let ok: Bool
    let pendingSymbol: String

    var body: some View {
        Image(systemName: ok ? "checkmark.circle.fill" : pendingSymbol)
            .font(.system(size: 20))
            .foregroundStyle(ok ? AnyShapeStyle(Color.green) : AnyShapeStyle(Brand.gradient))
            .frame(width: 24)
    }
}

/// Hosts SetupView in a normal window; the app is a menu bar app, so it activates itself while shown.
final class SetupWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let model: SetupModel

    init(deviceNames: @escaping () -> [String]) {
        model = SetupModel(deviceNames: deviceNames)
    }

    func show() {
        model.refresh()
        model.startPolling()
        if window == nil {
            let view = SetupView(model: model, onRestart: SetupWindowController.relaunch,
                                 onDone: { [weak self] in self?.window?.close() })
            let w = NSWindow(contentViewController: NSHostingController(rootView: view))
            w.title = "Callido Touch Setup"
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        model.stopPolling()
    }

    /// Starts a fresh copy of the app once this one has quit, so new permissions take effect.
    static func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "while kill -0 \(getpid()) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\"",
                          Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }
}

extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
