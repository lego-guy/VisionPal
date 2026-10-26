//
//  VisionPalApp.swift
//  VisionPal
//
//  Created by Zachary D'Souza on 10/12/26.
//
import SwiftUI
import Combine
import AppKit
import ServiceManagement

// 1. Application State for Managing Authentication & Overlays
class AppState: ObservableObject {
    static let shared = AppState()
    @Published var isAuthenticated: Bool = false
    var isAuthorizedToQuit: Bool = false
}

// 2. AppDelegate to Intercept System Quit Requests & Manage Startup
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if #available(macOS 13.0, *) {
            try? SMAppService.mainApp.register()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if AppState.shared.isAuthorizedToQuit {
            return .terminateNow
        } else {
            return .terminateCancel
        }
    }
}

// 3. Main App Entry Point
@main
struct VisionPalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var tracker = ProximityTracker()

    var body: some Scene {
        MenuBarExtra("VisionPal", systemImage: tracker.isPaused ? "pause.circle.fill" : (tracker.isTooClose ? "eye.trianglebadge.exclamationmark" : "eye.fill")) {
            ContentView(tracker: tracker)
        }
        .menuBarExtraStyle(.window)
        
        // Trigger blur when user gets too close or camera is covered (macOS 14+ two-parameter closure)
        .onChange(of: tracker.isTooClose) { _, _ in
            updateOverlay()
        }
        .onChange(of: tracker.isCameraCovered) { _, _ in
            updateOverlay()
        }
        .onChange(of: tracker.isPaused) { _, isPaused in
            if isPaused {
                BlurOverlayManager.shared.hideBlur()
            } else {
                updateOverlay()
            }
        }
    }

    private func updateOverlay() {
        guard !tracker.isPaused else {
            BlurOverlayManager.shared.hideBlur()
            return
        }

        if tracker.isTooClose {
            let reason: BlurReason = tracker.isCameraCovered ? .cameraCovered : .tooClose
            BlurOverlayManager.shared.showBlur(reason: reason, threshold: tracker.thresholdInches)
        } else {
            BlurOverlayManager.shared.hideBlur()
        }
    }
}

// 4. Manager to handle showing/hiding full-screen blur windows across all attached displays
@MainActor
class BlurOverlayManager {
    static let shared = BlurOverlayManager()
    private var windows: [NSWindow] = []

    func showBlur(reason: BlurReason, threshold: Double) {
        guard windows.isEmpty else {
            for window in windows {
                window.contentView = NSHostingView(rootView: BlurOverlayWindow(reason: reason, threshold: threshold))
            }
            return
        }
        
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            window.contentView = NSHostingView(
                rootView: BlurOverlayWindow(reason: reason, threshold: threshold)
            )
            
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            windows.append(window)
        }
    }

    func hideBlur() {
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }
}
