import Foundation
import Testing
@testable import SignSpeak

@Suite("Signs Directory & Search Tests (Step 6.1)")
struct SignsDirectoryTests {

    private func makeDependencies() -> (
        StubSignCatalogService,
        StubProgressRepository,
        StubFavouritesRepository,
        StubSignRequestRepository,
        StubAuthService
    ) {
        let sampleSigns = [
            Sign(
                id: "sign-letter-a",
                name: "A",
                pronunciationHint: "AY",
                category: "alphabet",
                level: .beginner,
                recognition: .staticSign,
                description: "Fist with thumb up along index.",
                howToSteps: ["Make a fist", "Rest thumb along index finger"]
            ),
            Sign(
                id: "sign-word-hello",
                name: "Hello",
                pronunciationHint: "heh-LOH",
                category: "greetings",
                level: .beginner,
                recognition: .none,
                description: "Open flat hand touching temple and moving outward.",
                howToSteps: ["Touch forehead with flat hand", "Move hand forward and away"]
            ),
            Sign(
                id: "sign-word-thankyou",
                name: "Thank You",
                pronunciationHint: "THANGK-yoo",
                category: "courtesy",
                level: .beginner,
                recognition: .none,
                description: "Fingertips touch chin then extend forward.",
                howToSteps: ["Touch fingertips to lips/chin", "Move hand forward toward person"]
            ),
            Sign(
                id: "sign-word-help",
                name: "Help",
                pronunciationHint: "HELP",
                category: "emergency",
                level: .intermediate,
                recognition: .staticSign,
                description: "Closed fist thumbs up rested on open palm lifting up.",
                howToSteps: ["Place thumbs-up fist on flat non-dominant palm", "Lift both upward"]
            ),
            Sign(
                id: "sign-word-fire",
                name: "Fire",
                pronunciationHint: "FY-er",
                category: "emergency",
                level: .intermediate,
                recognition: .motionSign,
                description: "Both hands wiggling fingers rising upward like flames.",
                howToSteps: ["Wiggle open claw hands", "Move hands upward like flames"]
            )
        ]

        let sampleCategories = [
            SignCategory(id: "alphabet", name: "Alphabet", iconName: "character.bubble", description: "A-Z", order: 1),
            SignCategory(id: "greetings", name: "Greetings", iconName: "hand.wave", description: "Hello", order: 2),
            SignCategory(id: "courtesy", name: "Courtesy", iconName: "heart", description: "Thank You", order: 3),
            SignCategory(id: "emergency", name: "Emergency", iconName: "cross.case", description: "Help, Fire", order: 4)
        ]

        let payload = SignCatalogPayload(
            categories: sampleCategories,
            units: [],
            lessons: [],
            signs: sampleSigns
        )

        let catalog = StubSignCatalogService(payload: payload)

        let progressRepo = StubProgressRepository(initialStore: [
            "test-user": [
                "sign-letter-a": SignProgress(signId: "sign-letter-a", attempts: 5, correct: 5, isMastered: true),
                "sign-word-hello": SignProgress(signId: "sign-word-hello", attempts: 3, correct: 2, isMastered: false)
            ]
        ])

        let favRepo = StubFavouritesRepository(initialStore: [
            "test-user": [
                "sign-word-hello": FavouriteRecord(signId: "sign-word-hello")
            ]
        ])

        let requestRepo = StubSignRequestRepository()
        let authService = StubAuthService(initialUserId: "test-user")

        return (catalog, progressRepo, favRepo, requestRepo, authService)
    }

    // MARK: - 1. Loading & Metrics

    @Test("SignsDirectoryViewModel loads all signs, categories, user progress, and bookmarks")
    @MainActor
    func viewModelLoading() async {
        let (catalog, progress, favs, requests, auth) = makeDependencies()
        let vm = SignsDirectoryViewModel(
            signCatalogService: catalog,
            progressRepository: progress,
            favouritesRepository: favs,
            signRequestRepository: requests,
            authService: auth
        )

        await vm.load()

        #expect(vm.totalCount == 5)
        #expect(vm.masteredCount == 1) // Letter A
        #expect(vm.learningCount == 1) // Hello
        #expect(vm.newCount == 3)      // Thank You, Help, Fire
        #expect(vm.favouriteIds.contains("sign-word-hello"))
    }

    // MARK: - 2. Search Filtering

    @Test("Search query filters across name, category, description, and pronunciation hint")
    @MainActor
    func searchFiltering() async {
        let (catalog, progress, favs, requests, auth) = makeDependencies()
        let vm = SignsDirectoryViewModel(
            signCatalogService: catalog,
            progressRepository: progress,
            favouritesRepository: favs,
            signRequestRepository: requests,
            authService: auth
        )
        await vm.load()

        // 1. By Name: "fire"
        vm.searchQuery = "fire"
        #expect(vm.filteredSigns.count == 1)
        #expect(vm.filteredSigns.first?.name == "Fire")

        // 2. By Category: "courtesy"
        vm.searchQuery = "courtesy"
        #expect(vm.filteredSigns.count == 1)
        #expect(vm.filteredSigns.first?.name == "Thank You")

        // 3. By Description: "flames"
        vm.searchQuery = "flames"
        #expect(vm.filteredSigns.count == 1)
        #expect(vm.filteredSigns.first?.name == "Fire")

        // 4. By Pronunciation Hint: "heh-LOH"
        vm.searchQuery = "heh-loh"
        #expect(vm.filteredSigns.count == 1)
        #expect(vm.filteredSigns.first?.name == "Hello")

        // 5. Unmatched query yields empty results
        vm.searchQuery = "elephant"
        #expect(vm.filteredSigns.isEmpty == true)
    }

    // MARK: - 3. Tabs (All, ASL Dictionary, Phrases)

    @Test("Tabs filter between single words and phrases accurately")
    @MainActor
    func tabsFiltering() async {
        let (catalog, progress, favs, requests, auth) = makeDependencies()
        let vm = SignsDirectoryViewModel(
            signCatalogService: catalog,
            progressRepository: progress,
            favouritesRepository: favs,
            signRequestRepository: requests,
            authService: auth
        )
        await vm.load()

        // All Tab
        vm.selectedTab = .all
        #expect(vm.filteredSigns.count == 5)

        // Dictionary Tab (single words + alphabet letters)
        vm.selectedTab = .dictionary
        let dictSigns = vm.filteredSigns
        #expect(dictSigns.map(\.name).contains("A"))
        #expect(dictSigns.map(\.name).contains("Hello"))
        #expect(dictSigns.map(\.name).contains("Help"))
        #expect(dictSigns.map(\.name).contains("Fire"))

        // Phrases Tab (multi-word phrases like "Thank You")
        vm.selectedTab = .phrases
        let phraseSigns = vm.filteredSigns
        #expect(phraseSigns.map(\.name).contains("Thank You"))
    }

    // MARK: - 4. Multi-Criteria Filters

    @Test("Filter sheet parameters (level, recognition, status, bookmark) combine properly")
    @MainActor
    func multiCriteriaFilters() async {
        let (catalog, progress, favs, requests, auth) = makeDependencies()
        let vm = SignsDirectoryViewModel(
            signCatalogService: catalog,
            progressRepository: progress,
            favouritesRepository: favs,
            signRequestRepository: requests,
            authService: auth
        )
        await vm.load()

        // Level Filter: Intermediate
        vm.selectedLevel = .intermediate
        #expect(vm.filteredSigns.count == 2) // Help, Fire

        // Recognition Filter: Motion only
        vm.selectedRecognition = .motionSign
        #expect(vm.filteredSigns.count == 1)
        #expect(vm.filteredSigns.first?.name == "Fire")

        // Status Filter: Mastered
        vm.resetFilters()
        vm.selectedStatus = .mastered
        #expect(vm.filteredSigns.count == 1)
        #expect(vm.filteredSigns.first?.name == "A")

        // Bookmarked only
        vm.resetFilters()
        vm.onlyBookmarked = true
        #expect(vm.filteredSigns.count == 1)
        #expect(vm.filteredSigns.first?.name == "Hello")
    }

    // MARK: - 5. Sorting

    @Test("Sorting orders signs alphabetically, by level, or by learning status")
    @MainActor
    func sortingOptions() async {
        let (catalog, progress, favs, requests, auth) = makeDependencies()
        let vm = SignsDirectoryViewModel(
            signCatalogService: catalog,
            progressRepository: progress,
            favouritesRepository: favs,
            signRequestRepository: requests,
            authService: auth
        )
        await vm.load()

        // A to Z
        vm.selectedSort = .alphabeticalAsc
        #expect(vm.filteredSigns.first?.name == "A")
        #expect(vm.filteredSigns.last?.name == "Thank You")

        // Z to A
        vm.selectedSort = .alphabeticalDesc
        #expect(vm.filteredSigns.first?.name == "Thank You")
        #expect(vm.filteredSigns.last?.name == "A")

        // Status (Mastered -> Learning -> New)
        vm.selectedSort = .status
        #expect(vm.filteredSigns[0].name == "A")       // Mastered
        #expect(vm.filteredSigns[1].name == "Hello")   // Learning
    }

    // MARK: - 6. Bookmarks / Favourites Toggling

    @Test("Bookmark toggle updates local state and persists in FavouritesRepository")
    @MainActor
    func bookmarkToggling() async throws {
        let (catalog, progress, favs, requests, auth) = makeDependencies()
        let vm = SignsDirectoryViewModel(
            signCatalogService: catalog,
            progressRepository: progress,
            favouritesRepository: favs,
            signRequestRepository: requests,
            authService: auth
        )
        await vm.load()

        let signA = catalog.sign(byId: "sign-letter-a")!
        #expect(vm.isBookmarked(sign: signA) == false)

        // Toggle ON
        await vm.toggleBookmark(sign: signA)
        #expect(vm.isBookmarked(sign: signA) == true)
        let isSaved = try await favs.isFavourite(userId: "test-user", signId: signA.id)
        #expect(isSaved == true)

        // Toggle OFF
        await vm.toggleBookmark(sign: signA)
        #expect(vm.isBookmarked(sign: signA) == false)
        let isRemoved = try await favs.isFavourite(userId: "test-user", signId: signA.id)
        #expect(isRemoved == false)
    }

    // MARK: - 7. Sign Request Submission

    @Test("Sign request submission writes to SignRequestRepository with pending status")
    @MainActor
    func signRequestSubmission() async throws {
        let (catalog, progress, favs, requests, auth) = makeDependencies()
        let vm = SignsDirectoryViewModel(
            signCatalogService: catalog,
            progressRepository: progress,
            favouritesRepository: favs,
            signRequestRepository: requests,
            authService: auth
        )
        await vm.load()

        try await vm.submitSignRequest(
            term: "Congratulations",
            category: "Celebrations",
            notes: "Common celebration gesture."
        )

        #expect(vm.requestSuccessBanner != nil)
        #expect(vm.requestSuccessBanner?.contains("Congratulations") == true)

        let userRequests = try await requests.fetchMyRequests(userId: "test-user")
        #expect(userRequests.count == 1)
        #expect(userRequests.first?.term == "Congratulations")
        #expect(userRequests.first?.category == "Celebrations")
        #expect(userRequests.first?.status == "pending")
    }

    // MARK: - 8. Browse Alphabet & Reset Filters

    @Test("Browse alphabet and reset filters actions restore expected view states")
    @MainActor
    func browseAlphabetAndResetFilters() async {
        let (catalog, progress, favs, requests, auth) = makeDependencies()
        let vm = SignsDirectoryViewModel(
            signCatalogService: catalog,
            progressRepository: progress,
            favouritesRepository: favs,
            signRequestRepository: requests,
            authService: auth
        )
        await vm.load()

        vm.searchQuery = "some query"
        vm.selectedLevel = .advanced
        vm.onlyBookmarked = true

        #expect(vm.activeFilterCount == 2)

        // Browse Alphabet sets category to alphabet and clears query
        vm.browseAlphabet()
        #expect(vm.searchQuery.isEmpty == true)
        #expect(vm.selectedCategory == "alphabet")
        #expect(vm.onlyBookmarked == false)

        // Reset Filters
        vm.resetFilters()
        #expect(vm.selectedCategory == nil)
        #expect(vm.activeFilterCount == 0)
    }

    // MARK: - 9. Search Ranking Tests (Step 6.4)

    @Test("Search ranking prioritizes exact matches over prefixes and description occurrences")
    @MainActor
    func searchRankingPrioritization() async {
        let exactSign = Sign(
            id: "s-help",
            name: "Help",
            category: "emergency",
            description: "A plea for assistance.",
            howToSteps: []
        )
        let prefixSign = Sign(
            id: "s-helper",
            name: "Helper",
            category: "people",
            description: "One who provides help.",
            howToSteps: []
        )
        let descriptionSign = Sign(
            id: "s-assist",
            name: "Assist",
            category: "actions",
            description: "To give help to someone in need.",
            howToSteps: []
        )

        let catalog = StubSignCatalogService(payload: SignCatalogPayload(signs: [descriptionSign, prefixSign, exactSign]))
        let (_, progress, favs, requests, auth) = makeDependencies()

        let vm = SignsDirectoryViewModel(
            signCatalogService: catalog,
            progressRepository: progress,
            favouritesRepository: favs,
            signRequestRepository: requests,
            authService: auth
        )
        await vm.load()

        vm.searchQuery = "help"
        let ranked = vm.filteredSigns

        #expect(ranked.count == 3)
        // Exact name match "Help" must be first
        #expect(ranked[0].id == "s-help")
        // Prefix match "Helper" must be second
        #expect(ranked[1].id == "s-helper")
        // Description match "Assist" must be third
        #expect(ranked[2].id == "s-assist")
    }

    // MARK: - 10. Status Mapping Tests (Step 6.4)

    @Test("Status mapping accurately distinguishes Mastered, Learning, and New signs per criteria")
    @MainActor
    func statusMappingCriteria() async {
        let (catalog, progress, favs, requests, auth) = makeDependencies()

        let signNew = Sign(id: "s-new", name: "New", category: "general", description: "", howToSteps: [])
        let signFewAttempts = Sign(id: "s-few", name: "Few", category: "general", description: "", howToSteps: [])
        let signLowAccuracy = Sign(id: "s-low", name: "Low", category: "general", description: "", howToSteps: [])
        let signMastered = Sign(id: "s-mast", name: "Mastered", category: "general", description: "", howToSteps: [])

        let customProgress = StubProgressRepository(initialStore: [
            "test-user": [
                // 4 attempts, 4 correct -> not yet mastered (requires >= 5 attempts)
                "s-few": SignProgress(signId: "s-few", attempts: 4, correct: 4, isMastered: false),
                // 7 attempts, 5 correct (71.4% < 75%) -> not mastered
                "s-low": SignProgress(signId: "s-low", attempts: 7, correct: 5, isMastered: false),
                // 6 attempts, 5 correct (83.3% >= 75%) -> mastered
                "s-mast": SignProgress(signId: "s-mast", attempts: 6, correct: 5, isMastered: true)
            ]
        ])

        let vm = SignsDirectoryViewModel(
            signCatalogService: catalog,
            progressRepository: customProgress,
            favouritesRepository: favs,
            signRequestRepository: requests,
            authService: auth
        )
        await vm.load()

        #expect(vm.status(for: signNew) == .newSign)
        #expect(vm.status(for: signFewAttempts) == .learning)
        #expect(vm.status(for: signLowAccuracy) == .learning)
        #expect(vm.status(for: signMastered) == .mastered)
    }
}

