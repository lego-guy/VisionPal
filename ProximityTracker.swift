//
//  ProximityTracker.swift
//  VisionPal
//
//  Created by Zachary D'Souza on 9/26/26.

//
//  ProximityTracker.swift
//  VisionPal
//

import Foundation
import AVFoundation
import Vision
import Combine

class ProximityTracker: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var estimatedDistanceInches: Double = 24.0
    
    // Persists distance threshold across reboots
    @Published var thresholdInches: Double = {
        let saved = UserDefaults.standard.double(forKey: "VisionPal_SavedThreshold")
        return saved >= 10.0 ? saved : 20.0
    }() {
        didSet {
            UserDefaults.standard.set(thresholdInches, forKey: "VisionPal_SavedThreshold")
        }
    }
    
    @Published var isTooClose: Bool = false
    @Published var isCameraCovered: Bool = false
    @Published var isPaused: Bool = false
    @Published var dailyTooCloseEvents: Int = 0
    @Published var dailyTooCloseDuration: TimeInterval = 0
    
    private var captureSession: AVCaptureSession?
    private let videoDataOutputQueue = DispatchQueue(label: "com.visionpal.videoQueue", qos: .userInteractive)
    private var sequenceHandler = VNSequenceRequestHandler()
    
    // Performance: Throttle frame rate to reduce CPU and thermals (~7.5 FPS)
    private var frameCounter: Int = 0
    private let throttleRatio: Int = 4
    
    // Violation timing & debouncing
    private var violationStartTime: Date?
    private var missingFaceFrameCount: Int = 0
    private let missingFaceThreshold: Int = 10 // ~2.0 seconds of occlusion
    private var faceFoundFrameCount: Int = 0
    private let faceFoundThreshold: Int = 2
    private var tooCloseFrameCount: Int = 0
    private let tooCloseThreshold: Int = 3 // ~400 ms debounce

    override init() {
        super.init()
        loadTodayMetrics()
        checkCameraPermissionsAndSetup()
    }

    private func loadTodayMetrics() {
        let (events, duration) = TelemetryStore.shared.getTodayTotals()
        self.dailyTooCloseEvents = events
        self.dailyTooCloseDuration = duration
    }

    private func checkCameraPermissionsAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async { self?.setupCamera() }
                }
            }
        default:
            print("Camera access not granted.")
        }
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .medium
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if session.canAddInput(input) { session.addInput(input) }
        
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        
        if session.canAddOutput(output) { session.addOutput(output) }
        self.captureSession = session
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func calibrateCurrentDistance() {
        self.thresholdInches = self.estimatedDistanceInches
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isPaused else { return }
        
        frameCounter += 1
        if frameCounter % throttleRatio != 0 { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let detectFaceRequest = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let results = request.results as? [VNFaceObservation], !results.isEmpty {
                // 1. Filter out background faces smaller than 8% screen width (>4.5 ft away)
                let candidateFaces = results.filter { $0.boundingBox.width >= 0.08 }
                
                // 2. Select the closest foreground face (largest width projection)
                guard let face = (candidateFaces.isEmpty ? results : candidateFaces).max(by: {
                    $0.boundingBox.width < $1.boundingBox.width
                }) else { return }
                
                self.missingFaceFrameCount = 0
                self.faceFoundFrameCount += 1
                
                let faceWidth = face.boundingBox.width
                let rawDistance = 4.5 / Double(faceWidth)
                let calculatedDistance = max(8.0, min(36.0, rawDistance))
                
                DispatchQueue.main.async {
                    if self.faceFoundFrameCount >= self.faceFoundThreshold {
                        self.isCameraCovered = false
                    }
                    self.estimatedDistanceInches = calculatedDistance
                    
                    let currentlyTooClose = calculatedDistance < self.thresholdInches
                    if currentlyTooClose {
                        self.tooCloseFrameCount += 1
                        if self.tooCloseFrameCount >= self.tooCloseThreshold {
                            if !self.isTooClose {
                                self.isTooClose = true
                                self.violationStartTime = Date()
                                self.dailyTooCloseEvents += 1
                                TelemetryStore.shared.logTrigger()
                            }
                        }
                    } else {
                        self.tooCloseFrameCount = 0
                        if self.isTooClose {
                            self.isTooClose = false
                            if let start = self.violationStartTime {
                                let duration = Date().timeIntervalSince(start)
                                self.dailyTooCloseDuration += duration
                                TelemetryStore.shared.logDuration(seconds: duration)
                                self.violationStartTime = nil
                            }
                        }
                    }
                }
            } else {
                // No faces detected in frame (Anti-Tamper Occlusion logic)
                self.faceFoundFrameCount = 0
                DispatchQueue.main.async {
                    self.missingFaceFrameCount += 1
                    if self.missingFaceFrameCount >= self.missingFaceThreshold {
                        self.isCameraCovered = true
                        self.isTooClose = true
                    }
                }
            }
        }
        
        try? sequenceHandler.perform([detectFaceRequest], on: pixelBuffer, orientation: .up)
    }
}
