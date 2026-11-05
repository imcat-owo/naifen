//
//  MicButton.swift
//  Minis - chat page (AIChatView)
//
//  The composer's mic button: starts voice input on touch release (finger
//  lift) so a brushing touch does not activate it.
//
//  Map of the AIChatView files: AIChatView/AIChatView.swift.
//

import AVFoundation
import AVKit
import Combine
import GameController
import PhotosUI
import QuickLook
import QuickLook
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WebKit

// MARK: - Mic Button (touch-release activation)

/// Mic button that triggers on touch-release (finger lift) to avoid accidental activation.
/// Press highlight is provided via GestureState.
struct MicButton: View {
    @ObservedObject var speechManager: SpeechRecognitionManager
    @Binding var inputFocused: Bool
    /// Opens the voice-input (VAD) panel. The mic button no longer drives the
    /// in-bar SFSpeech live dictation directly — the panel (with the configured
    /// ASR provider, or the offline System fallback) is the single voice entry
    /// point. The SpeechRecognitionManager path stays in place but is no longer
    /// triggered from here.
    var onTap: () -> Void = {}
    /// True while inline voice mode is active — the button flips to a "T" glyph
    /// that switches back to text input.
    var isVoiceActive: Bool = false
    /// Press feedback for the custom-gesture button.
    @State private var micPressed = false
    /// [Phase 2 composer] Sensory-feedback trigger: toggled once per
    /// successful activation (not on press-down), so one tap fires one
    /// matching .selection feedback.
    @State private var micActivated = false
    /// Reduce Motion: the press scale is held at 1 (no motion); the
    /// feedback trigger still fires — feedback is not motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let diameter: CGFloat = 34
    /// [Phase 2 composer] The tappable circle: 44pt. The visible disc stays
    /// 34pt; the frame below widens the hit area around it.
    private static let hitDiameter: CGFloat = 44

    var body: some View {
        // NOT a Button: SwiftUI's Button has a generous system touch-slop / touch-
        // up tolerance that fires when the finger lifts slightly outside, or moves
        // a little during a scroll/drag — which made this toggle very easy to
        // mis-tap. We use a DragGesture(minimumDistance: 0) and only activate when
        // BOTH the press and release land inside the circle AND movement is tiny.
        // In voice mode: a keyboard glyph = switch back to text input. The keyboard
        // glyph is wider than the mic, so it renders smaller for parity
        // (bodyEmphasized 13pt against the mic's displaySmall 20pt).
        // [Phase 2 composer] Glyph sizes are the nearest Theme.Font roles
        // (mic 18pt -> 20pt, keyboard 15pt -> 13pt); the 34pt disc keeps its
        // visual size and the hit circle below is 44pt.
        Image(systemName: isVoiceActive ? "keyboard" : "mic")
            .font(isVoiceActive ? Theme.Font.bodyEmphasized() : Theme.Font.displaySmall())
            .foregroundStyle(Theme.Color.ink2)
            .frame(width: Self.diameter, height: Self.diameter)
            .background(Theme.Color.surface2)
            .clipShape(Circle())
            .overlay(Circle().stroke(Theme.Color.line, lineWidth: 0.5))
            .scaleEffect(micPressed && !reduceMotion ? DressUpMotion.pressedScale : 1.0)
            .animation(DressUpMotion.animation(for: .press, reduceMotion: reduceMotion), value: micPressed)
            // 44pt hit area around the 34pt disc; the gesture below reads
            // its coordinates in this 44pt frame (see isInside).
            .frame(minWidth: Self.hitDiameter, minHeight: Self.hitDiameter)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        micPressed = Self.isInside(value.location)
                    }
                    .onEnded { value in
                        let started = Self.isInside(value.startLocation)
                        let ended = Self.isInside(value.location)
                        let moved = hypot(value.translation.width, value.translation.height)
                        micPressed = false
                        guard started, ended, moved < 10 else { return }
                        micActivated.toggle()
                        inputFocused = false
                        onTap()
                    }
            )
            .dressUpHaptic(.selection, trigger: micActivated)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(isVoiceActive
                ? Text("Switch to text input", comment: "Mic button exits voice mode")
                : Text("Voice input", comment: "Mic button opens voice panel"))
    }

    /// Whether a point (in the button's local space) is within the visible circle.
    /// [Phase 2 composer] The local space is the 44pt hit frame, so the
    /// circle is the 44pt hit circle, not the 34pt disc.
    private static func isInside(_ p: CGPoint) -> Bool {
        let r = hitDiameter / 2
        let dx = p.x - r, dy = p.y - r
        return (dx * dx + dy * dy) <= r * r
    }
}
