//
//  SWFractalClouds.swift
//  Adapted from ShipSwift (MIT) — github.com/signerlabs/ShipSwift
//
//  Drifting fractal cumulus rendered through SwiftUI's colorEffect Metal pipeline.
//  Two-pass 5-octave FBM: the first pass perturbs the sample position for the second,
//  producing soft cumulus-like swirls.
//
//  Changed from the original: the live-tuning control sheet is dropped, and the
//  renderer honours Reduce Motion by freezing the drift instead of animating.
//

import SwiftUI

struct SWFractalClouds: View {
    var skyColor: Color
    var cloudColor: Color
    var warmTint: Color
    var warmth: Float = 0.5
    var speed: Float = 1.0
    var zoom: Float = 3.0
    var driftX: Float = 0.08
    var driftY: Float = 0.04
    var warp: Float = 2.0
    var coverage: Float = 0.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    /// Elapsed time is banked when the view goes away and resumed when it comes back.
    ///
    /// `start` was fixed at init, so time kept running while this screen was covered by
    /// another. Returning after a few seconds jumped the cloud field to a completely
    /// different position in a single frame — a whole-screen flicker on the way back
    /// from the detail view.
    @State private var accumulated: TimeInterval = 0

    var body: some View {
        content
            .onAppear { start = .now.addingTimeInterval(-accumulated) }
            .onDisappear { accumulated = Date.now.timeIntervalSince(start) }
    }

    @ViewBuilder
    private var content: some View {
        if reduceMotion {
            // A still frame, not a blank one: the sky is the signature, so it stays.
            canvas(elapsed: 0)
        } else {
            // 15 fps, not 60. The shader runs two five-octave FBM evaluations per
            // pixel, and clouds drift slowly enough that the extra 45 frames a second
            // are invisible work — this is a four-fold cut in GPU cost for no visible
            // difference, and it is what was making scrolling and navigation stutter.
            TimelineView(.periodic(from: start, by: 1.0 / 15.0)) { context in
                canvas(elapsed: Float(context.date.timeIntervalSince(start)))
            }
        }
    }

    private func canvas(elapsed: Float) -> some View {
        cloudColor
            .colorEffect(
                ShaderLibrary.swFractalClouds(
                    .boundingRect,
                    .float(elapsed),
                    .float(speed),
                    .float(zoom),
                    .float(driftX),
                    .float(driftY),
                    .float(warp),
                    .float(coverage),
                    .color(skyColor),
                    .color(cloudColor),
                    .color(warmTint),
                    .float(warmth)
                )
            )
    }
}
