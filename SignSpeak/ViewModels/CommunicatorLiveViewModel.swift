import SwiftUI
import AVFoundation
import CoreMedia

/// View model driving the two-way live Communicator session (design `39a-communicator-live`).
/// Coordinates real-time speech-to-text with audio waveform, camera gesture recognition with skeleton overlay,
/// immediate text-to-speech for recognized words, fingerspelling buffer manipulation, and conversation persistence.
@Observable
@MainActor
public final class CommunicatorLiveViewModel {
    // MARK: - Dependencies

    public let cameraService: any CameraServicing
    public let handPoseDetector: any HandPoseDetecting
    public let signClassifier: any SignClassifying
    public let signRecognitionService: any SignRecognitionServicing
    public let speechRecognitionService: any SpeechRecognitionServicing
    public let speechSynthesisService: any SpeechSynthesisServicing
    public let conversationRepository: any ConversationRepository
    public let userId: String

    // MARK: - Configuration

    public var mode: ConversationMode
    public var dominantHand: DominantHand
    public var isPartnerRotated180: Bool = true
    public var cameraPosition: AVCaptureDevice.Position = .front

    // MARK: - Conversation Transcript & Messages

    public var messages: [ConversationMessage] = []
    public var activePartnerTranscript: String = ""
    public var isPartnerSpeaking: Bool = false
    public var partnerAudioLevel: Float = 0.0

    // MARK: - Sign Recognition & Camera State

    public var isCameraRunning: Bool = false
    public var detectedPose: HandPose? = nil
    public var recognitionState: RecognitionState = .noHand
    public var lastRecognizedLabel: String? = nil

    // MARK: - Immediate Word Speech & Fingerspelling Buffer

    public var spokenAloudWord: String? = nil
    public var showSpokenAloudChip: Bool = false
    public var fingerspellingBuffer: String = ""

    // MARK: - Controls & Status

    public var isPaused: Bool = false
    public var isEnding: Bool = false
    public var activeSoundAlert: String? = nil
    public var errorMessage: String? = nil

    // MARK: - Private Tasks & Deduplication

    private var speechTask: Task<Void, Never>?
    private var audioLevelTask: Task<Void, Never>?
    private var cameraTask: Task<Void, Never>?
    private var spokenChipDismissTask: Task<Void, Never>?
    private var lastSpokenSignTimestamp: Date = .distantPast
    private let sessionStartTime: Date = Date()

    // MARK: - Initialization

    public init(
        cameraService: any CameraServicing,
        handPoseDetector: any HandPoseDetecting,
        signClassifier: any SignClassifying,
        signRecognitionService: any SignRecognitionServicing,
        speechRecognitionService: any SpeechRecognitionServicing,
        speechSynthesisService: any SpeechSynthesisServicing,
        conversationRepository: any ConversationRepository,
        userId: String = "guest",
        mode: ConversationMode = .faceToFaceSplit,
        dominantHand: DominantHand = .right
    ) {
        self.cameraService = cameraService
        self.handPoseDetector = handPoseDetector
        self.signClassifier = signClassifier
        self.signRecognitionService = signRecognitionService
        self.speechRecognitionService = speechRecognitionService
        self.speechSynthesisService = speechSynthesisService
        self.conversationRepository = conversationRepository
        self.userId = userId
        self.mode = mode
        self.dominantHand = dominantHand
        self.cameraPosition = cameraService.currentPosition
    }

    // MARK: - Session Lifecycle

    public func startSession() async {
        isPaused = false
        await startCameraRecognition()
        setupAudioSession()
        await startSpeechRecognition()
    }

    public func stopSession() async {
        speechTask?.cancel()
        speechTask = nil
        audioLevelTask?.cancel()
        audioLevelTask = nil
        cameraTask?.cancel()
        cameraTask = nil
        spokenChipDismissTask?.cancel()
        spokenChipDismissTask = nil

        await speechRecognitionService.stopTranscription()
        speechSynthesisService.stopSpeaking()
        await cameraService.stopSession()
        await signRecognitionService.stopRecognition()

        isCameraRunning = false
        detectedPose = nil
        partnerAudioLevel = 0.0
    }

    // MARK: - Audio Session (playAndRecord + voiceChat Echo Cancellation)

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session configuration failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Speech Recognition Stream

    public func startSpeechRecognition() async {
        speechTask?.cancel()
        audioLevelTask?.cancel()

        // 1. Request Speech & Microphone Permissions
        let granted = await speechRecognitionService.requestPermissions()
        guard granted else {
            errorMessage = "Microphone and Speech Recognition access are required. Please enable them in Settings."
            return
        }

        // 2. Observe Speech Transcripts
        speechTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = try await self.speechRecognitionService.startTranscription()
                for await result in stream {
                    if Task.isCancelled { break }
                    if let err = result.error {
                        self.errorMessage = "Speech error: \(err)"
                        continue
                    }
                    self.activePartnerTranscript = result.text
                    self.isPartnerSpeaking = !result.text.isEmpty

                    if result.isFinal && !result.text.isEmpty {
                        self.appendMessage(speaker: "Partner", text: result.text, source: "speech")
                        self.activePartnerTranscript = ""
                        self.isPartnerSpeaking = false
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                }
            }
        }

        // 3. Observe Audio Power Level for Waveform
        audioLevelTask = Task { [weak self] in
            guard let self else { return }
            let levels = self.speechRecognitionService.audioLevelStream()
            for await level in levels {
                if Task.isCancelled { break }
                self.partnerAudioLevel = level
            }
        }
    }

    // MARK: - Camera & Sign Recognition Pipeline

    public func startCameraRecognition() async {
        cameraTask?.cancel()

        let granted = await cameraService.requestAuthorization()
        guard granted else {
            errorMessage = "Camera access denied. Please allow camera access in Settings."
            return
        }

        await cameraService.startSession()
        isCameraRunning = true

        cameraTask = Task { [weak self] in
            guard let self else { return }
            for await sampleBuffer in self.cameraService.frameStream {
                if Task.isCancelled { break }
                if self.isPaused { continue }

                do {
                    let pose = try await self.handPoseDetector.detectPose(in: sampleBuffer)
                    if Task.isCancelled { break }
                    self.detectedPose = pose

                    let state = self.signRecognitionService.processPose(pose)
                    self.recognitionState = state

                    if case .recognized(let label, _, _) = state {
                        await self.handleRecognizedSign(label)
                    }
                } catch {
                    // Frame dropped or detection error; continue pipeline
                }
            }
        }
    }

    // MARK: - Gesture Handling (Words vs Fingerspelling)

    public func handleRecognizedSign(_ label: String) async {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Prevent rapid re-firing of the same sign within 1.2 seconds
        let now = Date()
        guard now.timeIntervalSince(lastSpokenSignTimestamp) > 1.2 || trimmed != lastRecognizedLabel else { return }
        lastSpokenSignTimestamp = now
        lastRecognizedLabel = trimmed

        // Check if single letter (fingerspelling) or complete word/phrase
        if trimmed.count == 1 && trimmed.rangeOfCharacter(from: .letters) != nil {
            appendFingerspelling(trimmed.uppercased())
        } else {
            await speakWordImmediately(trimmed)
        }
    }

    public func speakWordImmediately(_ word: String) async {
        spokenAloudWord = word
        showSpokenAloudChip = true

        appendMessage(speaker: "You", text: word, source: "sign")

        try? await speechSynthesisService.speak(text: word, voiceLanguage: "en-US")

        // Auto-dismiss spoken chip after 2.5 seconds
        spokenChipDismissTask?.cancel()
        spokenChipDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            self?.showSpokenAloudChip = false
        }
    }

    // MARK: - Fingerspelling Buffer Operations

    public func appendFingerspelling(_ letter: String) {
        fingerspellingBuffer += letter
    }

    public func deleteLastFingerspellingLetter() {
        guard !fingerspellingBuffer.isEmpty else { return }
        fingerspellingBuffer.removeLast()
    }

    public func clearFingerspellingBuffer() {
        fingerspellingBuffer = ""
    }

    public func speakFingerspellingBuffer() async {
        let text = fingerspellingBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        clearFingerspellingBuffer()
        await speakWordImmediately(text)
    }

    /// External keyboard type-to-speak: speaks phrase aloud immediately via TTS and logs to transcript.
    public func typeAndSpeak(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        appendMessage(speaker: "You", text: trimmed, source: "typed")
        spokenAloudWord = trimmed
        showSpokenAloudChip = true

        try? await speechSynthesisService.speak(text: trimmed, voiceLanguage: "en-US")

        spokenChipDismissTask?.cancel()
        spokenChipDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            self?.showSpokenAloudChip = false
        }
    }

    // MARK: - Shortcuts & Interactions

    public func sendThumbsUp() async {
        let confirmation = "👍 Got it!"
        appendMessage(speaker: "You", text: confirmation, source: "typed")
        try? await speechSynthesisService.speak(text: "Got it!", voiceLanguage: "en-US")
    }

    public func replayLastMessage() async {
        guard let lastMsg = messages.last else { return }
        try? await speechSynthesisService.speak(text: lastMsg.text, voiceLanguage: "en-US")
    }

    public func toggleRotation() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isPartnerRotated180.toggle()
        }
    }

    public func togglePause() {
        isPaused.toggle()
        if isPaused {
            speechSynthesisService.stopSpeaking()
        }
    }

    public func switchCamera() async {
        await cameraService.switchCamera()
        cameraPosition = cameraService.currentPosition
    }

    // MARK: - End Conversation & Save Transcript

    public func endConversation() async -> SavedConversation {
        isEnding = true
        await stopSession()

        // Create saved transcript
        let title = messages.first?.text.prefix(30).appending("...") ?? "Conversation"
        let conversation = SavedConversation(
            title: String(title),
            startedAt: sessionStartTime,
            endedAt: Date(),
            messages: messages
        )

        try? await conversationRepository.saveConversation(userId: userId, conversation: conversation)
        return conversation
    }

    // MARK: - Message Helper

    public func appendMessage(speaker: String, text: String, source: String) {
        let msg = ConversationMessage(
            speaker: speaker,
            text: text,
            at: Date(),
            source: source
        )
        messages.append(msg)
    }
}
