import Foundation

/// Container matching the bundled `signs.json` root schema.
public struct SignCatalogPayload: Codable, Sendable, Equatable {
    public let categories: [SignCategory]
    public let units: [LearningUnit]
    public let lessons: [Lesson]
    public let signs: [Sign]

    public init(
        categories: [SignCategory] = [],
        units: [LearningUnit] = [],
        lessons: [Lesson] = [],
        signs: [Sign] = []
    ) {
        self.categories = categories
        self.units = units
        self.lessons = lessons
        self.signs = signs
    }
}

/// Service protocol providing high-performance lookup, search, and filtering over the sign curriculum catalog.
public protocol SignCatalogServicing: Sendable {
    /// Returns all registered signs in the catalog.
    func allSigns() -> [Sign]

    /// Returns all curriculum categories sorted by order.
    func allCategories() -> [SignCategory]

    /// Returns all curriculum units sorted by order.
    func allUnits() -> [LearningUnit]

    /// Returns all lessons across all units sorted by order.
    func allLessons() -> [Lesson]

    /// Looks up a sign by its unique identifier (e.g. "sign-letter-a").
    func sign(byId id: String) -> Sign?

    /// Looks up a sign by its display name (case-insensitive, e.g. "A" or "hello").
    func sign(named name: String) -> Sign?

    /// Looks up a category by its identifier.
    func category(byId id: String) -> SignCategory?

    /// Looks up a unit by its identifier.
    func unit(byId id: String) -> LearningUnit?

    /// Looks up a lesson by its identifier.
    func lesson(byId id: String) -> Lesson?

    /// Returns all signs belonging to a specific category.
    func signs(forCategory categoryId: String) -> [Sign]

    /// Returns all signs associated with a lesson in lesson order.
    func signs(forLesson lessonId: String) -> [Sign]

    /// Returns all lessons belonging to a specific unit.
    func lessons(forUnit unitId: String) -> [Lesson]

    /// Fast text search matching query against sign name, pronunciation, category, description, and mnemonic.
    func search(query: String) -> [Sign]

    /// Filters signs by optional criteria (category, level, recognition mode).
    func filter(
        category: String?,
        level: SignLevel?,
        recognition: SignRecognitionType?
    ) -> [Sign]
}

/// Production sign catalog service with pre-indexed in-memory caching.
public final class SignCatalogService: SignCatalogServicing, @unchecked Sendable {
    private let payload: SignCatalogPayload

    // In-memory lookup tables for O(1) query performance
    private let signsById: [String: Sign]
    private let signsByNameLower: [String: Sign]
    private let categoriesById: [String: SignCategory]
    private let unitsById: [String: LearningUnit]
    private let lessonsById: [String: Lesson]
    private let signsByCategory: [String: [Sign]]
    private let signsByLesson: [String: [Sign]]
    private let lessonsByUnit: [String: [Lesson]]

    public init(payload: SignCatalogPayload) {
        self.payload = payload

        var idMap: [String: Sign] = [:]
        var nameMap: [String: Sign] = [:]
        var catMap: [String: [Sign]] = [:]

        for sign in payload.signs {
            idMap[sign.id] = sign
            nameMap[sign.name.lowercased()] = sign
            catMap[sign.category, default: []].append(sign)
        }

        self.signsById = idMap
        self.signsByNameLower = nameMap
        self.signsByCategory = catMap

        var categoriesMap: [String: SignCategory] = [:]
        for cat in payload.categories {
            categoriesMap[cat.id] = cat
        }
        self.categoriesById = categoriesMap

        var unitsMap: [String: LearningUnit] = [:]
        for unit in payload.units {
            unitsMap[unit.id] = unit
        }
        self.unitsById = unitsMap

        var lessonsMap: [String: Lesson] = [:]
        var lessonSignsMap: [String: [Sign]] = [:]
        var unitLessonsMap: [String: [Lesson]] = [:]

        for lesson in payload.lessons {
            lessonsMap[lesson.id] = lesson
            unitLessonsMap[lesson.unitId, default: []].append(lesson)

            // Resolve ordered signs for this lesson
            let lessonSigns = lesson.signIds.compactMap { idMap[$0] }
            lessonSignsMap[lesson.id] = lessonSigns
        }

        self.lessonsById = lessonsMap
        self.signsByLesson = lessonSignsMap
        self.lessonsByUnit = unitLessonsMap
    }

    /// Convenience initializer loading from a specific bundle URL or bundled `signs.json`.
    public convenience init(bundleURL: URL? = nil) {
        let url = bundleURL ?? Bundle.main.url(forResource: "signs", withExtension: "json")
        if let url, let data = try? Data(contentsOf: url) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode(SignCatalogPayload.self, from: data) {
                self.init(payload: decoded)
                return
            }
        }

        // Fallback to empty catalog if resource is not found
        self.init(payload: SignCatalogPayload())
    }

    // MARK: - SignCatalogServicing

    public func allSigns() -> [Sign] {
        payload.signs
    }

    public func allCategories() -> [SignCategory] {
        payload.categories.sorted(by: { $0.order < $1.order })
    }

    public func allUnits() -> [LearningUnit] {
        payload.units.sorted(by: { $0.order < $1.order })
    }

    public func allLessons() -> [Lesson] {
        payload.lessons.sorted(by: { $0.order < $1.order })
    }

    public func sign(byId id: String) -> Sign? {
        signsById[id]
    }

    public func sign(named name: String) -> Sign? {
        signsByNameLower[name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
    }

    public func category(byId id: String) -> SignCategory? {
        categoriesById[id]
    }

    public func unit(byId id: String) -> LearningUnit? {
        unitsById[id]
    }

    public func lesson(byId id: String) -> Lesson? {
        lessonsById[id]
    }

    public func signs(forCategory categoryId: String) -> [Sign] {
        signsByCategory[categoryId] ?? []
    }

    public func signs(forLesson lessonId: String) -> [Sign] {
        signsByLesson[lessonId] ?? []
    }

    public func lessons(forUnit unitId: String) -> [Lesson] {
        (lessonsByUnit[unitId] ?? []).sorted(by: { $0.order < $1.order })
    }

    public func search(query: String) -> [Sign] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return allSigns() }

        return payload.signs.filter { sign in
            if sign.name.lowercased().contains(trimmed) { return true }
            if let pron = sign.pronunciationHint, pron.lowercased().contains(trimmed) { return true }
            if sign.category.lowercased().contains(trimmed) { return true }
            if sign.description.lowercased().contains(trimmed) { return true }
            if let mnemonic = sign.mnemonicTip, mnemonic.lowercased().contains(trimmed) { return true }
            return false
        }
    }

    public func filter(
        category: String?,
        level: SignLevel?,
        recognition: SignRecognitionType?
    ) -> [Sign] {
        payload.signs.filter { sign in
            if let category, !category.isEmpty, sign.category != category {
                return false
            }
            if let level, sign.level != level {
                return false
            }
            if let recognition, sign.recognition != recognition {
                return false
            }
            return true
        }
    }
}

/// Fallback or test spy mock catalog service.
public final class StubSignCatalogService: SignCatalogServicing, @unchecked Sendable {
    public var stubbedPayload: SignCatalogPayload
    public private(set) var searchCallCount = 0
    public private(set) var filterCallCount = 0

    public init(payload: SignCatalogPayload = SignCatalogPayload()) {
        self.stubbedPayload = payload
    }

    public func allSigns() -> [Sign] { stubbedPayload.signs }
    public func allCategories() -> [SignCategory] { stubbedPayload.categories }
    public func allUnits() -> [LearningUnit] { stubbedPayload.units }
    public func allLessons() -> [Lesson] { stubbedPayload.lessons }

    public func sign(byId id: String) -> Sign? {
        stubbedPayload.signs.first { $0.id == id }
    }

    public func sign(named name: String) -> Sign? {
        stubbedPayload.signs.first { $0.name.lowercased() == name.lowercased() }
    }

    public func category(byId id: String) -> SignCategory? {
        stubbedPayload.categories.first { $0.id == id }
    }

    public func unit(byId id: String) -> LearningUnit? {
        stubbedPayload.units.first { $0.id == id }
    }

    public func lesson(byId id: String) -> Lesson? {
        stubbedPayload.lessons.first { $0.id == id }
    }

    public func signs(forCategory categoryId: String) -> [Sign] {
        stubbedPayload.signs.filter { $0.category == categoryId }
    }

    public func signs(forLesson lessonId: String) -> [Sign] {
        guard let lesson = stubbedPayload.lessons.first(where: { $0.id == lessonId }) else { return [] }
        return lesson.signIds.compactMap { id in stubbedPayload.signs.first { $0.id == id } }
    }

    public func lessons(forUnit unitId: String) -> [Lesson] {
        stubbedPayload.lessons.filter { $0.unitId == unitId }
    }

    public func search(query: String) -> [Sign] {
        searchCallCount += 1
        let q = query.lowercased()
        guard !q.isEmpty else { return stubbedPayload.signs }
        return stubbedPayload.signs.filter { $0.name.lowercased().contains(q) }
    }

    public func filter(category: String?, level: SignLevel?, recognition: SignRecognitionType?) -> [Sign] {
        filterCallCount += 1
        return stubbedPayload.signs.filter { sign in
            if let category, sign.category != category { return false }
            if let level, sign.level != level { return false }
            if let recognition, sign.recognition != recognition { return false }
            return true
        }
    }
}
