import Foundation
import SwiftUI
import Speech
import AVFoundation

@MainActor
@Observable
final class SpeechRecognizer {
    var isRecording = false
    var transcribedText = ""
    var errorMessage: String?
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    
    func startRecording(onUpdate: @escaping (String) -> Void) {
        // Stop any active session first
        stopRecording()
        
        // Request authorization
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                switch status {
                case .authorized:
                    AVAudioApplication.requestRecordPermission { granted in
                        Task { @MainActor in
                            if granted {
                                await self.beginRecordingSession(onUpdate: onUpdate)
                            } else {
                                self.errorMessage = "Microphone access was denied. Please allow microphone access in Settings."
                            }
                        }
                    }
                case .denied:
                    self.errorMessage = "Speech recognition access was denied. Please allow speech recognition in Settings."
                case .restricted:
                    self.errorMessage = "Speech recognition is restricted on this device."
                case .notDetermined:
                    self.errorMessage = "Speech recognition authorization not determined."
                @unknown default:
                    self.errorMessage = "Speech recognition error."
                }
            }
        }
    }
    
    private func beginRecordingSession(onUpdate: @escaping (String) -> Void) async {
        stopRecording(deactivateSession: false)
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognizer is currently unavailable."
            return
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            if #available(iOS 27.0, *) {
                try await audioSession.activate()
            } else {
                try await Task.detached(priority: .userInitiated) {
                    try audioSession.setActive(true)
                }.value
            }
            
            let engine = AVAudioEngine()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            
            self.audioEngine = engine
            self.recognitionRequest = request
            
            let inputNode = engine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                request.append(buffer)
            }
            
            engine.prepare()
            try engine.start()
            
            self.isRecording = true
            self.errorMessage = nil
            
            self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.transcribedText = text
                    onUpdate(text)
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.stopRecording()
                }
            }
        } catch {
            self.errorMessage = "Could not start audio engine: \(error.localizedDescription)"
            stopRecording()
        }
    }
    
    func stopRecording() {
        stopRecording(deactivateSession: true)
    }
    
    private func stopRecording(deactivateSession: Bool) {
        if audioEngine?.isRunning ?? false {
            audioEngine?.stop()
            audioEngine?.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        
        if deactivateSession {
            Task {
                let audioSession = AVAudioSession.sharedInstance()
                if #available(iOS 27.0, *) {
                    _ = try? await audioSession.deactivate(options: .notifyOthersOnDeactivation)
                } else {
                    _ = try? await Task.detached(priority: .userInitiated) {
                        try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                    }.value
                }
            }
        }
    }
}

// MARK: - Reusable Dictation Button
struct DictationButton: View {
    @Binding var text: String
    var promptHint: String? = nil
    
    @State private var recognizer = SpeechRecognizer()
    @State private var textBeforeRecording = ""
    
    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if recognizer.isRecording {
                recognizer.stopRecording()
            } else {
                textBeforeRecording = text
                recognizer.startRecording { transcribed in
                    if textBeforeRecording.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        text = transcribed
                    } else {
                        text = "\(textBeforeRecording) \(transcribed)"
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: recognizer.isRecording ? "waveform.circle.fill" : "mic.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(recognizer.isRecording ? .red : .accentColor)
                    .symbolEffect(.pulse, isActive: recognizer.isRecording)
                
                if recognizer.isRecording {
                    Text("Listening...")
                        .font(.caption2.bold())
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, recognizer.isRecording ? 8 : 6)
            .padding(.vertical, 5)
            .background(recognizer.isRecording ? Color.red.opacity(0.15) : Color.primary.opacity(0.06))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recognizer.isRecording ? "Stop dictation" : "Start voice dictation")
    }
}
