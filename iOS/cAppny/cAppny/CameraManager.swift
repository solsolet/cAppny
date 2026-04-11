//
//  CameraManager.swift
//  cAppny
//
//  Created by Máster Móviles on 10/4/26.
//

import AVFoundation
import UIKit
import Combine

// ObservableObject lets SwiftUI views subscribe to changes in this class.
// When we publish a new processed image, the view automatically re-renders.
class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // @Published: any SwiftUI view observing this object will redraw
    // when this value changes — this is how we push the result to the UI
    @Published var edgeImage: UIImage? = nil

    // These are set by the SwiftUI sliders and read on the video thread
    // They don't need to be @Published because we don't need the UI
    // to react to them — we just read them when processing each frame
    var blurProgress: Float = 2
    var edgeProgress: Float = 50
    var gradientProgress: Float = 0
    var isProcessing: Bool = false

    let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override init() {
        super.init()
    }

    // MARK: - Setup

    func requestPermissionAndSetup() {
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
            print("Camera access denied")
        }
    }

    private func setupCamera() {
        captureSession.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back
        ) else {
            print("No back camera found — are you on a simulator?")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            print("Camera input error: \(error)")
            return
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(
            self,
            queue: DispatchQueue(label: "videoQueue")
        )
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        // Fix orientation to portrait
        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
        }

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    func stop() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.stopRunning()
        }
    }

    // MARK: - Frame processing

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        guard isProcessing else { return }

        // Convert slider floats → OpenCV parameters
        // Same formulas as Android:
        // Blur:     v * 2 + 1  → always odd (1, 3, 5 ...)
        // Edge:     low = v,  high = v * 3
        // Gradient: v * 2 + 3 → 3, 5, or 7
        let blurSize     = Int32(blurProgress) * 2 + 1
        let lowThreshold = Double(edgeProgress)
        let highThreshold = lowThreshold * 3.0
        let apertureSize = Int32(gradientProgress) * 2 + 3

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)

        // Call OpenCV — identical to the Storyboard version
        let result = OpenCVWrapper.processImage(
            uiImage,
            withBlurSize: blurSize,
            lowThreshold: lowThreshold,
            highThreshold: highThreshold,
            apertureSize: apertureSize
        )

        // Publish result → SwiftUI view redraws automatically
        DispatchQueue.main.async { [weak self] in
            self?.edgeImage = result
        }
    }
}
