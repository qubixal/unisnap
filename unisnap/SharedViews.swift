//
//  SharedViews.swift
//  unisnap
//
//  Reusable view components shared across the app.
//

import SwiftUI

// MARK: - Glass Card

func glassCard<Content: View>(cornerRadius: CGFloat = 12, padding: CGFloat = 16, @ViewBuilder content: () -> Content) -> some View {
    content()
        .padding(padding)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
}

// MARK: - Hotkey Recorder Row

struct HotkeyRecorderRow: View {
    let displayString: String?
    let set: (HotkeyCombo) -> Void
    let clear: () -> Void

    @State private var isRecording = false
    private let recorder = HotkeyRecorder()

    var body: some View {
        HStack(spacing: 10) {
            Text("Shortcut:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)

            if isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 7, height: 7)
                        .transition(.scale)
                    Text("Press keys (ESC to quit)...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
                        }
                }
                .onTapGesture { cancelRecording() }
            } else if let displayString {
                Text(displayString)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.accentColor.opacity(0.25), lineWidth: 0.5)
                            }
                    }
                    .onTapGesture { startRecording() }

                Button(action: clearHotkey) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.quaternary)
                }
                .buttonStyle(.borderless)
            } else {
                Button(action: startRecording) {
                    Text("Click to set")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(.white.opacity(0.1), lineWidth: 0.5)
                                }
                        }
                }
                .buttonStyle(.borderless)
            }

            Spacer()
        }
    }

    private func startRecording() {
        isRecording = true
        recorder.startRecording { combo in
            DispatchQueue.main.async {
                self.isRecording = false
                if let combo = combo {
                    set(combo)
                }
            }
        }
    }

    private func cancelRecording() {
        recorder.stopRecording()
        isRecording = false
    }

    private func clearHotkey() {
        clear()
    }
}
