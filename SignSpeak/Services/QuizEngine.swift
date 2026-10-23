import Foundation

/// Supported interactive quiz modes matching designs `32-quiz-sign-it` and `36-quiz-watch-and-choose`.
public enum QuizQuestionMode: String, Codable, Sendable, CaseIterable {
    case watchAndChoose = "watch_and_choose"
    case signIt = "sign_it"

    public var title: String {
        switch self {
        case .watchAndChoose: return "Watch & Choose"
        case .signIt: return "Sign It Yourself"
        }
    }
}

/// An individual question within a quiz session.
public struct QuizQuestion: Identifiable, Sendable, Equatable {
    public let id: String
    public let targetSign: Sign
    public let mode: QuizQuestionMode
    public let options: [String] // 4 unique options for watchAndChoose; empty for signIt
    public let correctAnswer: String
    public let timeLimitSeconds: TimeInterval

    public init(
        id: String = UUID().uuidString,
        targetSign: Sign,
        mode: QuizQuestionMode,
        options: [String] = [],
        correctAnswer: String,
        timeLimitSeconds: TimeInterval = 6.0
    ) {
        self.id = id
        self.targetSign = targetSign
        self.mode = mode
        self.options = options
        self.correctAnswer = correctAnswer
        self.timeLimitSeconds = timeLimitSeconds
    }
}

/// Feedback outcome of an evaluated quiz question.
public struct QuizAnswerResult: Sendable, Equatable {
    public let isCorrect: Bool
    public let correctAnswer: String
    public let selectedAnswer: String?
    public let xpEarned: Int
    public let livesRemaining: Int
    public let streak: Int
    public let isGameOver: Bool
}

/// Pure testable quiz engine managing question generation, option randomization,
/// lives, streaks, scoring, and per-question evaluations.
public struct QuizEngine: Sendable {
    public private(set) var questions: [QuizQuestion]
    public private(set) var currentIndex: Int
    public private(set) var lives: Int
    public let maxLives: Int
    public private(set) var currentStreak: Int
    public private(set) var bestStreak: Int
    public private(set) var score: Int
    public private(set) var totalXP: Int
    public private(set) var mistakes: [SignPracticeMistake]
    public private(set) var isGameOver: Bool
    public private(set) var isComplete: Bool
    public let isSpeedRun: Bool
    public let startTime: Date

    public var currentQuestion: QuizQuestion? {
        guard currentIndex >= 0, currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    public var progressFraction: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(questions.count)
    }

    public var progressText: String {
        guard !questions.isEmpty else { return "0 / 0" }
        return "\(currentIndex + 1) / \(questions.count)"
    }

    public var accuracyPercentage: Int {
        guard !questions.isEmpty else { return 100 }
        let totalAnswered = score + mistakes.count
        guard totalAnswered > 0 else { return 100 }
        return Int((Double(score) / Double(totalAnswered)) * 100)
    }

    public init(
        questions: [QuizQuestion] = [],
        initialLives: Int = 3,
        isSpeedRun: Bool = false,
        startTime: Date = Date()
    ) {
        self.questions = questions
        self.currentIndex = 0
        self.lives = initialLives
        self.maxLives = initialLives
        self.currentStreak = 0
        self.bestStreak = 0
        self.score = 0
        self.totalXP = 0
        self.mistakes = []
        self.isGameOver = false
        self.isComplete = questions.isEmpty
        self.isSpeedRun = isSpeedRun
        self.startTime = startTime
    }

    // MARK: - Question Generation

    /// Generates randomized quiz questions without duplicate target signs,
    /// drawing distractors from the same category when possible.
    public static func generateQuestions(
        from signs: [Sign],
        allCatalogSigns: [Sign],
        count: Int = 5,
        preferredMode: QuizQuestionMode? = nil,
        isSpeedRun: Bool = false
    ) -> [QuizQuestion] {
        guard !signs.isEmpty else { return [] }

        // Deduplicate input signs by ID
        var uniqueSigns: [Sign] = []
        var seenIds = Set<String>()
        for sign in signs.shuffled() {
            if !seenIds.contains(sign.id) {
                seenIds.insert(sign.id)
                uniqueSigns.append(sign)
            }
        }

        let targetCount = min(count, uniqueSigns.count)
        let selectedSigns = Array(uniqueSigns.prefix(targetCount))

        return selectedSigns.enumerated().map { index, sign in
            let questionMode: QuizQuestionMode
            if let preferredMode {
                // If sign is not recognizable, force watchAndChoose
                if preferredMode == .signIt && !sign.isRecognizable {
                    questionMode = .watchAndChoose
                } else {
                    questionMode = preferredMode
                }
            } else {
                // Alternating modes when recognizable
                if sign.isRecognizable {
                    questionMode = (index % 2 == 0) ? .watchAndChoose : .signIt
                } else {
                    questionMode = .watchAndChoose
                }
            }

            if questionMode == .watchAndChoose {
                let options = generateOptions(for: sign, allSigns: allCatalogSigns)
                return QuizQuestion(
                    id: "quiz-q-\(sign.id)-\(index)",
                    targetSign: sign,
                    mode: .watchAndChoose,
                    options: options,
                    correctAnswer: sign.name,
                    timeLimitSeconds: isSpeedRun ? 4.0 : 6.0
                )
            } else {
                return QuizQuestion(
                    id: "quiz-q-\(sign.id)-\(index)",
                    targetSign: sign,
                    mode: .signIt,
                    options: [],
                    correctAnswer: sign.name,
                    timeLimitSeconds: isSpeedRun ? 4.0 : 6.0
                )
            }
        }
    }

    /// Generates 4 distinct options containing 1 correct answer and 3 distractors.
    /// Distractors prioritize the same category, falling back to other catalog signs.
    public static func generateOptions(for targetSign: Sign, allSigns: [Sign]) -> [String] {
        let correctAnswer = targetSign.name
        var distractors: [String] = []

        // 1. Same-category distractors
        let sameCategory = allSigns.filter {
            $0.category == targetSign.category &&
            $0.name.lowercased() != correctAnswer.lowercased()
        }.shuffled()

        for sign in sameCategory {
            if !distractors.contains(sign.name) {
                distractors.append(sign.name)
            }
            if distractors.count >= 3 { break }
        }

        // 2. Cross-category fallback if needed
        if distractors.count < 3 {
            let otherSigns = allSigns.filter {
                $0.name.lowercased() != correctAnswer.lowercased() &&
                !distractors.contains($0.name)
            }.shuffled()

            for sign in otherSigns {
                distractors.append(sign.name)
                if distractors.count >= 3 { break }
            }
        }

        // 3. Fallback filler if catalog is very small
        let emergencyFallbacks = ["A", "B", "C", "Hello", "Thank You", "Yes", "No"]
        var fallbackIndex = 0
        while distractors.count < 3 && fallbackIndex < emergencyFallbacks.count {
            let candidate = emergencyFallbacks[fallbackIndex]
            if candidate.lowercased() != correctAnswer.lowercased() && !distractors.contains(candidate) {
                distractors.append(candidate)
            }
            fallbackIndex += 1
        }

        var allOptions = Array(distractors.prefix(3))
        allOptions.append(correctAnswer)
        return allOptions.shuffled()
    }

    // MARK: - Evaluation Methods

    /// Evaluates a multiple-choice selection in Watch & Choose mode.
    public mutating func answerWatchAndChoose(selectedOption: String) -> QuizAnswerResult {
        guard let current = currentQuestion, !isGameOver, !isComplete else {
            return QuizAnswerResult(
                isCorrect: false,
                correctAnswer: currentQuestion?.correctAnswer ?? "",
                selectedAnswer: selectedOption,
                xpEarned: 0,
                livesRemaining: lives,
                streak: currentStreak,
                isGameOver: isGameOver
            )
        }

        let isCorrect = selectedOption.lowercased() == current.correctAnswer.lowercased()
        return processEvaluation(isCorrect: isCorrect, detectedOrSelected: selectedOption)
    }

    /// Evaluates camera sign recognition in Sign It Yourself mode.
    public mutating func answerSignIt(isCorrect: Bool, detectedLabel: String?) -> QuizAnswerResult {
        guard let current = currentQuestion, !isGameOver, !isComplete else {
            return QuizAnswerResult(
                isCorrect: false,
                correctAnswer: currentQuestion?.correctAnswer ?? "",
                selectedAnswer: detectedLabel,
                xpEarned: 0,
                livesRemaining: lives,
                streak: currentStreak,
                isGameOver: isGameOver
            )
        }

        return processEvaluation(isCorrect: isCorrect, detectedOrSelected: detectedLabel)
    }

    /// Advances to the next question in the session.
    public mutating func advance() {
        guard !isGameOver else { return }

        if currentIndex + 1 < questions.count {
            currentIndex += 1
        } else {
            isComplete = true
        }
    }

    // MARK: - Private State Mutation

    private mutating func processEvaluation(isCorrect: Bool, detectedOrSelected: String?) -> QuizAnswerResult {
        guard let current = currentQuestion else {
            return QuizAnswerResult(isCorrect: false, correctAnswer: "", selectedAnswer: nil, xpEarned: 0, livesRemaining: 0, streak: 0, isGameOver: true)
        }

        let earnedXP: Int

        if isCorrect {
            score += 1
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)

            let baseXP = isSpeedRun ? 15 : 10
            let streakBonus = currentStreak >= 3 ? 5 : 0
            earnedXP = baseXP + streakBonus
            totalXP += earnedXP
        } else {
            lives = max(0, lives - 1)
            currentStreak = 0
            earnedXP = 0

            let mistake = SignPracticeMistake(
                signId: current.targetSign.id,
                signName: current.targetSign.name,
                detectedAs: detectedOrSelected ?? "None",
                timestamp: Date()
            )
            mistakes.append(mistake)

            if lives == 0 {
                isGameOver = true
            }
        }

        return QuizAnswerResult(
            isCorrect: isCorrect,
            correctAnswer: current.correctAnswer,
            selectedAnswer: detectedOrSelected,
            xpEarned: earnedXP,
            livesRemaining: lives,
            streak: currentStreak,
            isGameOver: isGameOver
        )
    }
}
