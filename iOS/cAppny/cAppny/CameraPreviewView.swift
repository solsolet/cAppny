//
//  CameraPreviewView.swift
//  cAppny
//
//  Created by Máster Móviles on 10/4/26.
//

import SwiftUI
import AVFoundation

// UIViewRepresentable wraps a UIKit view so SwiftUI can use it.
// Think of it as an adapter between the two worlds.
struct CameraPreviewView: UIViewRepresentable {

    // We receive the session from CameraManager so the preview
    // and the frame processing use the exact same session
    let session: AVCaptureSession

    // makeUIView: called once to create the underlying UIKit view
    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.setupPreview(session: session)
        return view
    }

    // updateUIView: called when SwiftUI state changes
    // We don't need to do anything here — the session manages itself
    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}

// The actual UIView subclass that hosts the preview layer
class PreviewUIView: UIView {

    private var previewLayer: AVCaptureVideoPreviewLayer?

    func setupPreview(session: AVCaptureSession) {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
    }

    // layoutSubviews is called whenever the view resizes
    // (rotation, first layout, etc.) — we keep the layer in sync
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
