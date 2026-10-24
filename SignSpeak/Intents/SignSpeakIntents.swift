import Foundation
import AppIntents
import AVFoundation
import SwiftUI

// MARK: - App Entities

/// AppEntity representing an ASL Curriculum Sign for Siri and Shortcuts.
public struct SignEntity: AppEntity, Identifiable, Sendable {
    public static var defaultQuery = SignEntityQuery()
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Sign"

    public let id: String

    @Property(title: "Sign Name")
    public var name: String

    @Property(title: "Category")
    public var category: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(category)")
    }

    public init(id: String, name: String, category: String) {
        self.id = id
        self.name = name
        self.category = category
    }
}

/// Query provider for Siri / Shortcuts parameter resolution for Signs.
public struct SignEntityQuery: EntityStringQuery, Sendable {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [SignEntity] {
        let catalog = SignCatalogService()
        return identifiers.compactMap { id in
            guard let sign = catalog.sign(byId: id) else { return nil }
            return SignEntity(id: sign.id, name: sign.name, category: sign.category.capitalized)
        }
    }

    public func suggestedEntities() async throws -> [SignEntity] {
        let catalog = SignCatalogService()
        return catalog.allSigns().prefix(10).map { sign in
            SignEntity(id: sign.id, name: sign.name, category: sign.category.capitalized)
        }
    }

    public func entities(matching string: String) async throws -> [SignEntity] {
        let catalog = SignCatalogService()
        return catalog.allSigns().filter {
            $0.name.localizedCaseInsensitiveContains(string) ||
            $0.category.localizedCaseInsensitiveContains(string)
        }.map { sign in
            SignEntity(id: sign.id, name: sign.name, category: sign.category.capitalized)
        }
    }
}

/// AppEntity representing a quick communicator phrase for Siri and Shortcuts.
public struct PhraseEntity: AppEntity, Identifiable, Sendable {
    public static var defaultQuery = PhraseEntityQuery()
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Quick Phrase"

    public let id: String

    @Property(title: "Phrase Text")
    public var text: String

    @Property(title: "Category")
    public var category: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(text)", subtitle: "\(category)")
    }

    public init(id: String, text: String, category: String) {
        self.id = id
        self.text = text
        self.category = category
    }
}

/// Query provider for Siri / Shortcuts phrase parameter resolution.
public struct PhraseEntityQuery: EntityStringQuery, Sendable {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [PhraseEntity] {
        let snapshot = SharedStore.shared.fetchSnapshot()
        return snapshot.quickPhrases.filter { identifiers.contains($0.id) }.map {
            PhraseEntity(id: $0.id, text: $0.text, category: $0.category)
        }
    }

    public func suggestedEntities() async throws -> [PhraseEntity] {
        let snapshot = SharedStore.shared.fetchSnapshot()
        return snapshot.quickPhrases.map {
            PhraseEntity(id: $0.id, text: $0.text, category: $0.category)
        }
    }

    public func entities(matching string: String) async throws -> [PhraseEntity] {
        let snapshot = SharedStore.shared.fetchSnapshot()
        return snapshot.quickPhrases.filter {
            $0.text.localizedCaseInsensitiveContains(string)
        }.map {
            PhraseEntity(id: $0.id, text: $0.text, category: $0.category)
        }
    }
}

// MARK: - App Intents

/// Intent opening the live Communicator conversation tool (`signspeak://communicator`).
public struct OpenCommunicatorIntent: AppIntent {
    public static var title: LocalizedStringResource = "Open Communicator"
    public static var description = IntentDescription("Opens live two-way Communicator in SignSpeak.")
    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        if let url = URL(string: "signspeak://communicator") {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

/// Intent launching live recognition practice for a specific sign or Sign of the Day.
public struct PracticeSignIntent: AppIntent {
    public static var title: LocalizedStringResource = "Practise Sign"
    public static var description = IntentDescription("Practise today's sign or a chosen sign with real-time feedback.")
    public static var openAppWhenRun: Bool = true

    @Parameter(title: "Sign", description: "Name of the sign to practice (defaults to Sign of the Day)")
    public var signName: String?

    public init() {}

    public init(signName: String?) {
        self.signName = signName
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        let snapshot = SharedStore.shared.fetchSnapshot()
        let targetId = signName ?? snapshot.signOfTheDay.id
        let urlString = "signspeak://practice?sign=\(targetId)"
        if let url = URL(string: urlString) {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

/// Intent synthesizing speech for a quick communicator phrase or custom text.
public struct SpeakPhraseIntent: AppIntent {
    public static var title: LocalizedStringResource = "Speak Phrase"
    public static var description = IntentDescription("Speaks a communicator phrase aloud.")
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Phrase", description: "The phrase to speak aloud")
    public var phrase: String

    public init() {
        self.phrase = ""
    }

    public init(phrase: String) {
        self.phrase = phrase
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "No phrase was provided to speak.")
        }

        // On-device speech synthesis
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)

        return .result(dialog: "Speaking: \(trimmed)")
    }
}

/// Intent activating Sound Alerts detector (`signspeak://alerts`).
public struct StartSoundAlertsIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start Sound Alerts"
    public static var description = IntentDescription("Starts listening for environmental sound alerts in SignSpeak.")
    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        if let url = URL(string: "signspeak://alerts") {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

/// Intent querying the user's current practice streak from SharedStore.
public struct GetStreakIntent: AppIntent {
    public static var title: LocalizedStringResource = "Get Streak"
    public static var description = IntentDescription("Checks your current practice streak in SignSpeak.")

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let snapshot = SharedStore.shared.fetchSnapshot()
        let streak = snapshot.currentStreak
        let xp = snapshot.xp
        let dialog: IntentDialog = streak > 0
            ? "You have a \(streak)-day streak with \(xp) XP in SignSpeak! Keep up the great work!"
            : "You don't have an active streak yet today in SignSpeak. Complete a lesson to start your streak!"
        return .result(dialog: dialog)
    }
}

// MARK: - App Shortcuts Provider

/// System AppShortcuts provider exposing Siri voice commands for SignSpeak (Step 13.5).
public struct SignSpeakShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenCommunicatorIntent(),
            phrases: [
                "Open Communicator in \(.applicationName)",
                "Open \(.applicationName) Communicator",
                "Start Communicator in \(.applicationName)"
            ],
            shortTitle: "Open Communicator",
            systemImageName: "bubble.left.and.bubble.right.fill"
        )

        AppShortcut(
            intent: PracticeSignIntent(),
            phrases: [
                "Practise today's sign with \(.applicationName)",
                "Practise sign in \(.applicationName)",
                "Practise with \(.applicationName)"
            ],
            shortTitle: "Practise Sign",
            systemImageName: "hand.raised.fill"
        )

        AppShortcut(
            intent: SpeakPhraseIntent(),
            phrases: [
                "Speak a phrase with \(.applicationName)",
                "Say something in \(.applicationName)"
            ],
            shortTitle: "Speak Phrase",
            systemImageName: "speaker.wave.2.fill"
        )

        AppShortcut(
            intent: StartSoundAlertsIntent(),
            phrases: [
                "Start Sound Alerts in \(.applicationName)",
                "Listen for sounds with \(.applicationName)"
            ],
            shortTitle: "Start Sound Alerts",
            systemImageName: "ear.badge.waveform"
        )

        AppShortcut(
            intent: GetStreakIntent(),
            phrases: [
                "What's my \(.applicationName) streak?",
                "Check my streak in \(.applicationName)",
                "How is my streak in \(.applicationName)?"
            ],
            shortTitle: "Check Streak",
            systemImageName: "flame.fill"
        )
    }
}
