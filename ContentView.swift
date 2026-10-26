//
//  ContentView.swift
//  VisionPal
//
//  Created by Zachary D'Souza on 9/26/26.
//

import SwiftUI
import Charts
import LocalAuthentication
import ServiceManagement

enum TelemetryTimeframe: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    var id: String { self.rawValue }
}

enum MetricType: String, CaseIterable, Identifiable {
    case count = "Triggers"
    case duration = "Time (Min)"
    var id: String { self.rawValue }
}

struct ContentView: View {
    @ObservedObject var tracker: ProximityTracker
    @StateObject private var telemetryStore = TelemetryStore.shared
    
    @State private var selectedTimeframe: TelemetryTimeframe = .week
    @State private var selectedMetric: MetricType = .count
    
    // Persistent Unlock State: Stays unlocked across closes/reboots until parent clicks Lock
    @AppStorage("visionPal_isThresholdUnlocked") private var isThresholdUnlocked: Bool = false
    
    // Persistent New PIN Prompt State: Stays active even if menu closes during Mac Admin auth
    @AppStorage("visionPal_isSettingNewPIN") private var isSettingNewPIN: Bool = false
    
    // UI State for Parental Gate Modals
    @State private var isShowingUnlockSection: Bool = false
    @State private var pendingAction: ActionType? = nil
    @State private var passwordInput: String = ""
    @State private var passwordError: Bool = false
    
    @State private var newPasswordInput: String = ""
    @State private var calibrationStatusMessage: String?

    enum ActionType {
        case quit
        case uninstall
        case pauseToggle
        case unlockThreshold
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            
            // 1. Header with Title & Operational Dot
            HStack {
                Text("VisionPal Proximity")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                if tracker.isPaused {
                    Text("PAUSED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
                Circle()
                    .fill(tracker.isPaused ? Color.orange : (tracker.isTooClose ? Color.red : Color.green))
                    .frame(width: 10, height: 10)
            }
            
            Divider()
            
            // 2. Real-Time Distance & Persistent Lock Toggle
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Current: \(Int(tracker.estimatedDistanceInches))\"")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("Limit: \(Int(tracker.thresholdInches))\"")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Persistent Lock/Unlock Toggle Button
                    Button(action: {
                        if isThresholdUnlocked {
                            isThresholdUnlocked = false
                        } else {
                            requestProtectedAction(.unlockThreshold)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isThresholdUnlocked ? "lock.open.fill" : "lock.fill")
                            Text(isThresholdUnlocked ? "Lock" : "Unlock")
                        }
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(isThresholdUnlocked ? Color.green.opacity(0.18) : Color.blue.opacity(0.18))
                        .foregroundColor(isThresholdUnlocked ? .green : .accentColor)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                
                // Slider (Active while unlocked; dimmed and unmovable when locked)
                Slider(value: $tracker.thresholdInches, in: 10...35, step: 1)
                    .accentColor(.blue)
                    .disabled(!isThresholdUnlocked)
                    .opacity(isThresholdUnlocked ? 1.0 : 0.4)
                
                HStack {
                    Button("Optometrist (20\")") {
                        tracker.thresholdInches = 20.0
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .buttonStyle(.plain)
                    .disabled(!isThresholdUnlocked)
                    .opacity(isThresholdUnlocked ? 1.0 : 0.4)
                    
                    Spacer()
                    
                    Button("📏 Lock Current Posture") {
                        tracker.calibrateCurrentDistance()
                        calibrationStatusMessage = "Posture locked to \(Int(tracker.thresholdInches))\"!"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            calibrationStatusMessage = nil
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .buttonStyle(.plain)
                    .disabled(!isThresholdUnlocked)
                    .opacity(isThresholdUnlocked ? 1.0 : 0.4)
                }
                
                if !isThresholdUnlocked {
                    Text("🔒 Distance locked. Tap Unlock to make changes.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let status = calibrationStatusMessage {
                    Text(status)
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            Divider()
            
            // 3. Telemetry Visualizer (Trigger Frequency & Duration)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Posture Analytics")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Spacer()
                    Picker("", selection: $selectedTimeframe) {
                        ForEach(TelemetryTimeframe.allCases) { timeframe in
                            Text(timeframe.rawValue).tag(timeframe)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 135)
                }
                
                HStack {
                    Picker("Metric", selection: $selectedMetric) {
                        ForEach(MetricType.allCases) { metric in
                            Text(metric.rawValue).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Spacer()
                    
                    Text("Today: \(tracker.dailyTooCloseEvents)x (\(Int(tracker.dailyTooCloseDuration / 60))m)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Chart {
                    ForEach(chartData) { item in
                        BarMark(
                            x: .value("Period", item.label),
                            y: .value("Value", item.value)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .cornerRadius(3)
                    }
                }
                .frame(height: 85)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let text = value.as(String.self) {
                                Text(text)
                                    .font(.system(size: selectedTimeframe == .year ? 8.5 : 10, weight: .medium))
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // 4. Action Controls, PIN Entry & Forgot PIN Recovery
            if isSettingNewPIN {
                // Screen A: Set New Parental PIN (Triggered by Mac Admin Password)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Set New Parental PIN:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    SecureField("Enter new 4-digit PIN", text: $newPasswordInput)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Button("Cancel") {
                            isSettingNewPIN = false
                            newPasswordInput = ""
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Save PIN") {
                            if !newPasswordInput.isEmpty {
                                _ = SecureParentalVault.savePasscode(newPasswordInput)
                                isSettingNewPIN = false
                                newPasswordInput = ""
                                calibrationStatusMessage = "New PIN saved successfully!"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                    calibrationStatusMessage = nil
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                    }
                }
            } else if isShowingUnlockSection {
                // Screen B: Standard Authorization Modal
                VStack(alignment: .leading, spacing: 8) {
                    Text(unlockPromptTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    SecureField("App PIN", text: $passwordInput)
                        .textFieldStyle(.roundedBorder)
                    
                    if passwordError {
                        Text("Incorrect PIN. Try again or tap Forgot PIN.")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                    
                    HStack {
                        Button("Cancel") {
                            resetAuthInputs()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Authorize") {
                            verifyPasscodeAndExecute()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                    }
                    
                    HStack {
                        // Prompts for Mac Admin password to set a new PIN
                        Button("Forgot PIN?") {
                            authenticateWithMacAdminForPINReset()
                        }
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        // Prompts for Mac Admin password to authorize current action directly
                        Button("Use Mac Password") {
                            authenticateWithMacAdmin()
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .buttonStyle(.plain)
                    }
                }
            } else {
                // Screen C: Default State Buttons
                HStack {
                    Button(tracker.isPaused ? "▶️ Resume Alerts" : "⏸️ Pause Alerts") {
                        requestProtectedAction(.pauseToggle)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    
                    Spacer()
                    
                    Button("Quit") {
                        requestProtectedAction(.quit)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.red)
                    
                    Text("•").foregroundColor(.secondary)
                    
                    Button("Uninstall") {
                        requestProtectedAction(.uninstall)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(width: 320)
        .onDisappear {
            // Clears textfield inputs without resetting the persistent unlocked state
            resetAuthInputs()
        }
    }

    private var unlockPromptTitle: String {
        switch pendingAction {
        case .unlockThreshold:
            return "Enter PIN to Unlock Distance:"
        case .quit:
            return "Enter PIN to Quit:"
        case .pauseToggle:
            return "Enter PIN to Pause Alerts:"
        case .uninstall:
            return "Enter PIN to Uninstall:"
        case .none:
            return "Enter Parental PIN:"
        }
    }

    private var chartData: [TelemetryChartItem] {
        let isDuration = selectedMetric == .duration
        switch selectedTimeframe {
        case .week:
            return telemetryStore.getWeeklyData(metric: isDuration ? .duration : .count)
        case .month:
            return telemetryStore.getMonthlyData(metric: isDuration ? .duration : .count)
        case .year:
            return telemetryStore.getYearlyData(metric: isDuration ? .duration : .count)
        }
    }

    private func requestProtectedAction(_ action: ActionType) {
        pendingAction = action
        isShowingUnlockSection = true
        passwordInput = ""
        passwordError = false
    }

    private func verifyPasscodeAndExecute() {
        if SecureParentalVault.verifyPasscode(passwordInput) {
            guard let action = pendingAction else { return }
            executeAction(action)
            resetAuthInputs()
        } else {
            passwordError = true
            passwordInput = ""
        }
    }

    // Authenticates via Mac Admin Password to directly configure a new PIN
    private func authenticateWithMacAdminForPINReset() {
        let context = LAContext()
        var error: NSError?
        let reason = "Authenticate with your Mac password to change your VisionPal PIN."
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        // Saved persistently so the prompt appears even if MenuBarExtra lost focus
                        self.isSettingNewPIN = true
                        self.isShowingUnlockSection = false
                        self.passwordInput = ""
                        self.passwordError = false
                    }
                }
            }
        }
    }

    // Authenticates via Mac Admin Password to execute the pending action (Unlock, Quit, Pause)
    private func authenticateWithMacAdmin() {
        let context = LAContext()
        var error: NSError?
        let reason = "Authenticate with your Mac password to authorize VisionPal."
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        if self.pendingAction == .unlockThreshold {
                            self.isThresholdUnlocked = true
                        } else if let action = self.pendingAction {
                            self.executeAction(action)
                        }
                        self.resetAuthInputs()
                    }
                }
            }
        }
    }

    private func executeAction(_ action: ActionType) {
        switch action {
        case .unlockThreshold:
            isThresholdUnlocked = true
            
        case .quit:
            AppState.shared.isAuthorizedToQuit = true
            NSApplication.shared.terminate(nil)
            
        case .pauseToggle:
            tracker.isPaused.toggle()
            
        case .uninstall:
            if #available(macOS 13.0, *) {
                try? SMAppService.mainApp.unregister()
            }
            telemetryStore.clearAllHistory()
            AppState.shared.isAuthorizedToQuit = true
            NSApplication.shared.terminate(nil)
        }
    }

    private func resetAuthInputs() {
        isShowingUnlockSection = false
        pendingAction = nil
        passwordInput = ""
        passwordError = false
    }
}
