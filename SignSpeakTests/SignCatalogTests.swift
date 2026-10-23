#if DEBUG
import Foundation
import Testing
@testable import SignSpeak

@Suite("Sign Catalog & Seed Data Tests (Step 4.1)")
struct SignCatalogTests {
    private func loadRealCatalogService() -> SignCatalogService {
        // Find signs.json from the repository bundle or direct path
        let candidates = [
            Bundle.main.url(forResource: "signs", withExtension: "json"),
            Bundle(for: MockSignRecognitionService.self).url(forResource: "signs", withExtension: "json"),
            URL(fileURLWithPath: "/Users/mileeshafernando/IOS/SignSpeak/SignSpeak/Resources/Data/signs.json")
        ]

        for url in candidates {
            if let url, FileManager.default.fileExists(atPath: url.path) {
                return SignCatalogService(bundleURL: url)
            }
        }

        return SignCatalogService()
    }

    @Test("Catalog loads all 26 alphabet letters and 10 numbers")
    func catalogLoadsAlphabetAndNumbers() {
        let catalog = loadRealCatalogService()
        let signs = catalog.allSigns()

        #expect(signs.count >= 36)

        // Verify all 26 alphabet letters exist
        let alphabetLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        for char in alphabetLetters {
            let letterStr = String(char)
            let sign = catalog.sign(named: letterStr)
            #expect(sign != nil, "Missing letter \(letterStr)")
            #expect(sign?.category == "alphabet")
            #expect(sign?.howToSteps.isEmpty == false)
        }

        // Verify numbers 1 to 10
        for num in 1...10 {
            let numStr = String(num)
            let sign = catalog.sign(named: numStr)
            #expect(sign != nil, "Missing number \(numStr)")
            #expect(sign?.category == "numbers")
        }
    }

    @Test("Alphabet lessons are partitioned strictly per plan (A-E, F-J, K-O, P-T, U-Z)")
    func alphabetLessonsPartitioning() {
        let catalog = loadRealCatalogService()

        let lesson1 = catalog.signs(forLesson: "lesson-alphabet-1")
        #expect(lesson1.map(\.name) == ["A", "B", "C", "D", "E"])

        let lesson2 = catalog.signs(forLesson: "lesson-alphabet-2")
        #expect(lesson2.map(\.name) == ["F", "G", "H", "I", "J"])

        let lesson3 = catalog.signs(forLesson: "lesson-alphabet-3")
        #expect(lesson3.map(\.name) == ["K", "L", "M", "N", "O"])

        let lesson4 = catalog.signs(forLesson: "lesson-alphabet-4")
        #expect(lesson4.map(\.name) == ["P", "Q", "R", "S", "T"])

        let lesson5 = catalog.signs(forLesson: "lesson-alphabet-5")
        #expect(lesson5.map(\.name) == ["U", "V", "W", "X", "Y", "Z"])
    }

    @Test("Recognition types are designated accurately for static vs dynamic signs")
    func recognitionTypeDesignation() {
        let catalog = loadRealCatalogService()

        // Static alphabet letters
        let letterA = catalog.sign(named: "A")
        #expect(letterA?.recognition == .staticSign)

        let letterB = catalog.sign(named: "B")
        #expect(letterB?.recognition == .staticSign)

        // Motion alphabet letters
        let letterJ = catalog.sign(named: "J")
        #expect(letterJ?.recognition == .motionSign)

        let letterZ = catalog.sign(named: "Z")
        #expect(letterZ?.recognition == .motionSign)

        // Motion vocabulary words
        let hello = catalog.sign(named: "Hello")
        #expect(hello?.recognition == .motionSign)

        let thankyou = catalog.sign(named: "Thank You")
        #expect(thankyou?.recognition == .motionSign)

        let please = catalog.sign(named: "Please")
        #expect(please?.recognition == .motionSign)

        let water = catalog.sign(named: "Water")
        #expect(water?.recognition == .motionSign)
    }

    @Test("Curriculum categories and units are organized in order")
    func categoriesAndUnitsIntegrity() {
        let catalog = loadRealCatalogService()

        let categories = catalog.allCategories()
        #expect(categories.count >= 10)

        // Verify order is strictly ascending
        for i in 0..<(categories.count - 1) {
            #expect(categories[i].order < categories[i + 1].order)
        }

        let units = catalog.allUnits()
        #expect(units.count == 3)
        #expect(units.map(\.id) == ["unit-alphabet", "unit-numbers", "unit-words-phrases"])
    }

    @Test("Full-text search queries match sign name, category, and mnemonic")
    func fullTextSearch() {
        let catalog = loadRealCatalogService()

        // Name match
        let waterMatches = catalog.search(query: "water")
        #expect(waterMatches.contains { $0.name == "Water" })

        // Case-insensitive query
        let helloMatches = catalog.search(query: "hElLo")
        #expect(helloMatches.contains { $0.name == "Hello" })

        // Mnemonic / description match
        let pirateMatches = catalog.search(query: "pirate")
        #expect(pirateMatches.contains { $0.name == "X" }) // Mnemonic: pirate's hook

        // Empty query returns all signs
        let allSigns = catalog.search(query: "")
        #expect(allSigns.count == catalog.allSigns().count)
    }

    @Test("Filter combines category, level, and recognition constraints")
    func filterQueryIntegrity() {
        let catalog = loadRealCatalogService()

        // Filter only motion signs in Greetings
        let motionGreetings = catalog.filter(
            category: "greetings",
            level: nil,
            recognition: .motionSign
        )
        #expect(motionGreetings.isEmpty == false)
        #expect(motionGreetings.allSatisfy { $0.category == "greetings" && $0.recognition == .motionSign })

        // Filter only static signs in Alphabet
        let staticAlphabet = catalog.filter(
            category: "alphabet",
            level: nil,
            recognition: .staticSign
        )
        #expect(staticAlphabet.count == 24) // 26 minus J and Z
    }

    @Test("StubSignCatalogService supports custom payloads and spies call counts")
    func stubCatalogBehavior() {
        let sampleSign = Sign(
            id: "test-sign",
            name: "Test",
            category: "test-cat",
            level: .beginner,
            handedness: .oneHanded,
            recognition: .staticSign,
            description: "Test description",
            howToSteps: ["Step 1", "Step 2"]
        )
        let samplePayload = SignCatalogPayload(
            categories: [SignCategory(id: "test-cat", name: "Test Category", iconName: "star", description: "Desc", order: 1)],
            units: [LearningUnit(id: "test-unit", title: "Unit 1", description: "Desc", lessonIds: ["test-lesson"], order: 1)],
            lessons: [Lesson(id: "test-lesson", unitId: "test-unit", title: "Lesson 1", subtitle: "Sub", category: "test-cat", signIds: ["test-sign"], order: 1)],
            signs: [sampleSign]
        )

        let stub = StubSignCatalogService(payload: samplePayload)

        #expect(stub.sign(byId: "test-sign") == sampleSign)
        #expect(stub.signs(forCategory: "test-cat") == [sampleSign])
        #expect(stub.signs(forLesson: "test-lesson") == [sampleSign])

        _ = stub.search(query: "Test")
        #expect(stub.searchCallCount == 1)

        _ = stub.filter(category: "test-cat", level: .beginner, recognition: nil)
        #expect(stub.filterCallCount == 1)
    }
}
#endif
