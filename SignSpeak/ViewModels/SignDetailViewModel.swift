import SwiftUI
import Observation

/// Available practice modes when practicing an individual sign.
public enum SignDetailPracticeMode: String, Identifiable, Sendable, CaseIterable {
    case cameraRecognition = "Camera Practice"
    case watchAndChoose = "Watch & Choose"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .cameraRecognition: return "camera.viewfinder"
        case .watchAndChoose: return "checkmark.circle.badge.questionmark"
        }
    }
}

/// Observable ViewModel coordinating state, learning progress, favourites persistence,
/// and practice mode routing for `SignDetailView`.
/// Matches designs `45-sign-detail-hello` and `33-sign-detail-letter-m`.
@Observable
@MainActor
public final class SignDetailViewModel {
    public private(set) var sign: Sign?
    public let signId: String

    public var isFavourite: Bool = false
    public var isBookmarked: Bool = false
    public var isLoading: Bool = false
    public var isTogglingFavourite: Bool = false
    public var errorMessage: String? = nil

    public var signProgress: SignProgress? = nil

    public var activePracticeMode: SignDetailPracticeMode? = nil
    public var isPresentingPractice: Bool = false

    private let favouritesRepository: any FavouritesRepository
    private let progressRepository: any ProgressRepository
    private let signCatalogService: any SignCatalogServicing
    private let userId: String

    // MARK: - Initializers

    public init(
        sign: Sign,
        favouritesRepository: any FavouritesRepository,
        progressRepository: any ProgressRepository,
        signCatalogService: any SignCatalogServicing,
        userId: String = "default"
    ) {
        self.sign = sign
        self.signId = sign.id
        self.favouritesRepository = favouritesRepository
        self.progressRepository = progressRepository
        self.signCatalogService = signCatalogService
        self.userId = userId
    }

    public init(
        signId: String,
        favouritesRepository: any FavouritesRepository,
        progressRepository: any ProgressRepository,
        signCatalogService: any SignCatalogServicing,
        userId: String = "default"
    ) {
        self.signId = signId
        self.sign = signCatalogService.sign(byId: signId)
        self.favouritesRepository = favouritesRepository
        self.progressRepository = progressRepository
        self.signCatalogService = signCatalogService
        self.userId = userId
    }

    // MARK: - Asynchronous Lifecycle

    public func load() async {
        isLoading = true
        defer { isLoading = false }

        // If sign was initialized with signId and wasn't loaded immediately, retry from catalog
        if sign == nil {
            sign = signCatalogService.sign(byId: signId)
        }

        // 1. Fetch Favourite / Bookmark state
        do {
            let fav = try await favouritesRepository.isFavourite(userId: userId, signId: signId)
            self.isFavourite = fav
            self.isBookmarked = fav
        } catch {
            // Keep local state if query fails
        }

        // 2. Fetch User Learning Progress
        if let progressList = try? await progressRepository.fetchProgress(userId: userId) {
            self.signProgress = progressList.first(where: { $0.signId == signId })
        }
    }

    // MARK: - Favourites Management

    public func toggleFavourite() async {
        guard !isTogglingFavourite else { return }
        isTogglingFavourite = true
        defer { isTogglingFavourite = false }

        let previous = isFavourite
        let next = !previous
        isFavourite = next
        isBookmarked = next

        do {
            if next {
                try await favouritesRepository.addFavourite(userId: userId, signId: signId)
            } else {
                try await favouritesRepository.removeFavourite(userId: userId, signId: signId)
            }
        } catch {
            // Roll back on failure
            isFavourite = previous
            isBookmarked = previous
            errorMessage = "Failed to update favourite: \(error.localizedDescription)"
        }
    }

    // MARK: - Computed Properties

    public var isRecognizable: Bool {
        sign?.isRecognizable ?? false
    }

    public var recommendedPracticeMode: SignDetailPracticeMode {
        isRecognizable ? .cameraRecognition : .watchAndChoose
    }

    public var masteryStatusTitle: String {
        guard let progress = signProgress else { return "New Sign" }
        if progress.isMastered { return "Mastered" }
        if progress.attempts > 0 { return "Learning" }
        return "New Sign"
    }

    public var masteryStatusColor: Color {
        guard let progress = signProgress else { return Color.brandTurquoise }
        if progress.isMastered { return Color.green }
        if progress.attempts > 0 { return Color.brandYellow }
        return Color.brandTurquoise
    }

    public var accuracyPercentageText: String? {
        guard let progress = signProgress, progress.attempts > 0 else { return nil }
        let pct = Int(round(Double(progress.correct) / Double(progress.attempts) * 100))
        return "\(pct)% accuracy (\(progress.correct)/\(progress.attempts))"
    }

    public var attemptsCountText: String? {
        guard let progress = signProgress, progress.attempts > 0 else { return nil }
        return "\(progress.attempts) practice \(progress.attempts == 1 ? "attempt" : "attempts")"
    }

    public var subtitleText: String {
        guard let sign else { return "ASL Sign" }
        if sign.category.lowercased().contains("alphabet") {
            return "Manual Alphabet Finger-spelling"
        } else if sign.category.lowercased().contains("number") {
            return "American Sign Language Number"
        } else if sign.category.lowercased().contains("greeting") {
            return "Formal & Informal ASL Greeting"
        } else if sign.category.lowercased().contains("courtesy") {
            return "Everyday ASL Courtesy Sign"
        } else {
            return "\(sign.category.capitalized) ASL Sign"
        }
    }

    public var subtitleIconName: String {
        guard let sign else { return "hand.raised" }
        if sign.category.lowercased().contains("alphabet") {
            return "character.textbox"
        } else if sign.category.lowercased().contains("number") {
            return "number"
        } else {
            return "hand.wave"
        }
    }

    public var shareText: String {
        guard let sign else { return "Learn American Sign Language on SignSpeak!" }
        var parts: [String] = []
        parts.append("Learn how to sign '\(sign.name)' in American Sign Language with SignSpeak!")
        if let hint = sign.pronunciationHint {
            parts.append("Pronunciation: \(hint)")
        }
        parts.append("Category: \(sign.category.capitalized)")
        parts.append("\n\(sign.description)")
        if let mistake = sign.commonMistake, !mistake.isEmpty {
            parts.append("\nTip: \(mistake)")
        }
        parts.append("\nPractice on SignSpeak: signspeak://sign?id=\(sign.id)")
        return parts.joined(separator: "\n")
    }

    // MARK: - Practice Routing

    public func startPractice(mode: SignDetailPracticeMode? = nil) {
        let chosenMode = mode ?? recommendedPracticeMode
        self.activePracticeMode = chosenMode
        self.isPresentingPractice = true
    }

    /// Generates a single targeted Watch & Choose quiz question for this sign.
    public func makeWatchAndChooseQuestion() -> QuizQuestion? {
        guard let sign else { return nil }
        let allCatalog = signCatalogService.allSigns()
        let options = QuizEngine.generateOptions(for: sign, allSigns: allCatalog)

        return QuizQuestion(
            id: "quiz-detail-\(sign.id)",
            targetSign: sign,
            mode: .watchAndChoose,
            options: options,
            correctAnswer: sign.name,
            timeLimitSeconds: 10.0
        )
    }

    /// Records practice attempt outcome to update progress immediately.
    public func recordPracticeOutcome(isCorrect: Bool) async {
        guard let sign else { return }
        try? await progressRepository.recordAttempt(
            userId: userId,
            signId: sign.id,
            isCorrect: isCorrect,
            detectedAs: isCorrect ? sign.name : nil
        )

        // Reload local progress
        if let progressList = try? await progressRepository.fetchProgress(userId: userId) {
            self.signProgress = progressList.first(where: { $0.signId == signId })
        }
    }
}
