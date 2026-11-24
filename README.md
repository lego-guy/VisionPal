[visionpal_readme (1).md](https://github.com/user-attachments/files/35375234/visionpal_readme.1.md)
# VisionPal

**VisionPal** is a lightweight macOS menu bar app built with Swift and SwiftUI that helps protect your eyesight and encourage healthy viewing habits by monitoring how close you sit to your screen in real time.

## Features

### Real-Time Proximity Monitoring & Screen Blur

* **Live Distance Tracking:** Uses your Mac's camera (`ProximityTracker`) to continuously estimate how far you are from the display in inches.

* **Automatic Screen Blur:** When you lean closer than your set threshold, VisionPal smoothly blurs all connected displays until you sit back at a comfortable distance. Built-in debouncing keeps the blur from flickering during minor movements.

* **Optometrist Preset & Custom Thresholds:** Adjust the distance threshold ($10\text{–}35\text{ inches}$) using a password-locked slider, or apply the recommended setting in one click with **Set Optometrist Rec (20 in)**.

### Proximity History & Dynamic Charts

* **Daily Trigger Counts:** Tracks how many times the proximity threshold is crossed each day and resets automatically at midnight.

* **Interactive Charts:** Displays your proximity history across **Week**, **Month**, and **Year** views using SwiftCharts (`TelemetryStore`).

* **Adaptive Y-Axis Scaling:** Charts start with a ceiling of **20** triggers and automatically step up by **10** ($20 \rightarrow 30 \rightarrow 40 \dots$) if daily counts go higher, resetting back to 20 the next day.

### Guardian Reports & Email Management

* **Multiple Recipients:** Send daily posture summaries to one or more comma-separated guardian email addresses.

* **Address Validation:** Checks email formatting before saving or updating recipients (`Not valid email! Please enter again.`).

* **Password-Protected Changes:** Adding, switching, or removing email addresses requires the guardian password. Leaving the replacement field blank when switching cleanly removes the selected address.

* **Native Mail Integration:** Sends morning reports ($6\text{–}8\text{ AM}$) and manual summaries (**Send Now**) directly through the macOS **Mail** app with an on-screen confirmation (`Report sent!`).

### Guardian Controls & Security

* **Touch ID & Mac Password Support:** Guardians can reset or update their VisionPal password anytime using **Touch ID** or their Mac login password (`LocalAuthentication`).

* **Protected Settings & Exit:** Keeps the distance slider, recipient list, **Quit VisionPal**, and **Uninstall** actions locked behind the guardian password.

## How It's Organized

| Component | Purpose | 
| ----- | ----- | 
| **`VisionPalApp` / `AppDelegate`** | Manages the menu bar interface (`MenuBarExtra`), multi-display blur overlays, and quit protection. | 
| **`AppState`** | Coordinates shared state across the app, including active blur overlays and quit authorization. | 
| **`ProximityTracker`** | Handles camera input, distance estimation, debouncing, and daily trigger counts. | 
| **`TelemetryStore`** | Saves date-stamped (`yyyy-MM-dd`) event history and prepares data for the Week, Month, and Year charts. | 
| **`ContentView`** | Powers the menu bar popover UI, including live distance readouts, locked controls, charts, email settings, and Touch ID prompts. | 

## Getting Started

### Requirements

* **macOS 13.0 (Ventura)** or later

* **Xcode 15.0** or later

* A built-in or external webcam

* At least one active email account signed into the macOS **Mail** app (for sending guardian reports)

### Building in Xcode

1. Open the **VisionPal** project in Xcode.

2. Select the **VisionPal** target and open **Signing & Capabilities**:

   * Choose your development **Team**.

   * If **App Sandbox** is active, either remove it or enable the **Camera** (`com.apple.security.device.camera`) and **Apple Events** (`com.apple.security.automation.apple-events`) entitlements.

3. Check the target's **Info** tab (`Info.plist`) to make sure both privacy descriptions are included:

   * **`Privacy - Camera Usage Description`** (`NSCameraUsageDescription`) — needed to estimate viewing distance.

   * **`Privacy - AppleEvents Sending Usage Description`** (`NSAppleEventsUsageDescription`) — needed to send summary reports through Apple Mail.

4. Press **Cmd + R** to build and run.

### Opening an Exported Build

If macOS Gatekeeper blocks an exported copy of the app on first launch, clear the quarantine flag in Terminal:

```bash
xattr -d com.apple.quarantine /Applications/VisionPal.app
```

## First-Time Setup

1. **Allow Permissions:** When prompted on first launch, grant **Camera** access for distance tracking and **Automation (Mail)** access for report delivery.

2. **Update Your Guardian Password:**

   * The default password is `1234`.

   * Click **Change Password (via Touch ID or Mac Password)** in the popover menu to set your own password right away.

3. **Add Guardian Emails:**

   * Enter a recipient email address and click **Save**.

   * Use **Add Email** or **Switch / Remove Email** (password required) whenever you need to update the list.

4. **Set Your Distance Threshold:**

   * Click **Unlock Slider**, enter the guardian password, and choose your preferred distance (or click **Set Optometrist Rec (20 in)**). Click **Lock Slider** once you're done.

Hopefully you benefit from this app!
