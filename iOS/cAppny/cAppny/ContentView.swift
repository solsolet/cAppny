//
//  ContentView.swift
//  cAppny
//
//  Created by Máster Móviles on 10/4/26.
//

import SwiftUI

struct ContentView: View {

    // @StateObject: SwiftUI owns and keeps this alive for the view's lifetime.
    // When cameraManager.edgeImage changes, this view redraws.
    @StateObject private var cameraManager = CameraManager()

    // Local UI state — these live in the view
    @State private var isProcessing = false
    @State private var blurValue: Float    = 2
    @State private var edgeValue: Float    = 50
    @State private var gradientValue: Float = 0

    var body: some View {
        ZStack(alignment: .bottom) {  // ZStack layers views on top of each other

            // Layer 1 — Camera preview (bottom)
            CameraPreviewView(session: cameraManager.captureSession)
                .ignoresSafeArea()  // fill the entire screen including notch area

            // Layer 2 — Edge detection overlay
            if let edgeImage = cameraManager.edgeImage {
                GeometryReader { geo in
                    Image(uiImage: edgeImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                .ignoresSafeArea()
            }

            // Layer 3 — Control panel (top, anchored to bottom)
            controlPanel
        }
        .onAppear {
            cameraManager.requestPermissionAndSetup()
        }
        .onDisappear {
            cameraManager.stop()
        }
    }

    // MARK: - Control panel extracted as a computed property for readability
    // In SwiftUI, breaking large bodies into smaller pieces like this
    // is the standard pattern (equivalent to separate XML layouts in Android)

    private var controlPanel: some View {
        VStack(spacing: 8) {

            // Start / Stop button
            Button(action: toggleProcessing) {
                Text(isProcessing ? "Stop" : "Start")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isProcessing ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            // Blur slider
            SliderRow(
                label: "Blur",
                value: $blurValue,       // $ = two-way binding: slider writes back to @State
                range: 0...6
            ) { newValue in
                cameraManager.blurProgress = newValue
            }

            // Edge slider
            SliderRow(
                label: "Edge",
                value: $edgeValue,
                range: 0...100
            ) { newValue in
                cameraManager.edgeProgress = newValue
            }

            // Gradient angle slider
            SliderRow(
                label: "Gradient Angle",
                value: $gradientValue,
                range: 0...2
            ) { newValue in
                cameraManager.gradientProgress = newValue
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)  // SafeArea handles the navigation bar gap automatically in SwiftUI
        .background(.black.opacity(0.75))
    }

    // MARK: - Actions

    private func toggleProcessing() {
        isProcessing.toggle()
        cameraManager.isProcessing = isProcessing
        if !isProcessing {
            cameraManager.edgeImage = nil
        }
    }
}

// MARK: - Reusable slider row component
// In SwiftUI, small reusable views like this replace XML view components

struct SliderRow: View {
    let label: String
    @Binding var value: Float          // @Binding receives the binding passed from the parent
    let range: ClosedRange<Float>
    let onChange: (Float) -> Void      // callback to notify CameraManager of changes

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .foregroundColor(.white)
                .font(.caption)
            Slider(value: $value, in: range, step: 1) { _ in
                onChange(value)
            }
        }
    }
}

#Preview {
    ContentView()
}
