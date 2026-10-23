#if DEBUG
import Foundation
import Testing
@testable import SignSpeak

@Suite("Lesson Paths & Intro Tests (Step 5.2)")
struct LessonPathTests {

    private func makeCatalogService() -> SignCatalogService {
        SignCatalogService()
    }

    // MARK: - Fingerspelling Path & Letters

    @Test("Fingerspelling unit contains 5 sequential alphabet lessons")
    func fingerspellingLessonsIntegrity() {
        let catalog = makeCatalogService()
        let alphabetLessons = catalog.lessons(forUnit: "unit-alphabet")

        #expect(alphabetLessons.count == 5)
        #expect(alphabetLessons[0].id == "lesson-alphabet-1")
        #expect(alphabetLessons[1].id == "lesson-alphabet-2")
        #expect(alphabetLessons[2].id == "lesson-alphabet-3")
        #expect(alphabetLessons[3].id == "lesson-alphabet-4")
        #expect(alphabetLessons[4].id == "lesson-alphabet-5")

        // Lesson 1 is A-E
        let lesson1Signs = catalog.signs(forLesson: "lesson-alphabet-1")
        #expect(lesson1Signs.map(\.name) == ["A", "B", "C", "D", "E"])

        // Lesson 2 is F-J
        let lesson2Signs = catalog.signs(forLesson: "lesson-alphabet-2")
        #expect(lesson2Signs.map(\.name) == ["F", "G", "H", "I", "J"])
    }

    @Test("Alphabet category contains all 26 uppercase fingerspelling letters")
    func alphabetCategorySignsCount() {
        let catalog = makeCatalogService()
        let alphabetSigns = catalog.signs(forCategory: "alphabet")

        #expect(alphabetSigns.count == 26)

        let names = Set(alphabetSigns.map(\.name))
        for char in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" {
            #expect(names.contains(String(char)))
        }
    }

    // MARK: - Words & Phrases Categories

    @Test("Words & phrases categories exist with descriptions and order")
    func wordsPhrasesCategories() {
        let catalog = makeCatalogService()
        let categories = catalog.allCategories()

        let nonAlphabet = categories.filter { $0.id != "alphabet" && $0.id != "numbers" }
        #expect(nonAlphabet.count >= 6)

        let categoryIds = nonAlphabet.map(\.id)
        #expect(categoryIds.contains("greetings"))
        #expect(categoryIds.contains("everyday"))
        #expect(categoryIds.contains("family"))
        #expect(categoryIds.contains("emergency"))
    }

    @Test("Category signs resolution provides core signs for Greetings and Courtesy")
    func greetingsCategoryCoreSigns() {
        let catalog = makeCatalogService()
        let greetingSigns = catalog.signs(forCategory: "greetings")

        #expect(greetingSigns.count >= 4)

        let greetingNames = greetingSigns.map(\.name)
        #expect(greetingNames.contains("Hello"))
        #expect(greetingNames.contains("Good Morning"))
        #expect(greetingNames.contains("Good Night"))

        let courtesySigns = catalog.signs(forCategory: "courtesy")
        let courtesyNames = courtesySigns.map(\.name)
        #expect(courtesyNames.contains("Thank You"))
        #expect(courtesyNames.contains("Please"))
    }

    // MARK: - Lesson Intro Details

    @Test("Lesson 2 intro resolves all 5 target signs and pro tip")
    func lessonIntroResolution() {
        let catalog = makeCatalogService()
        guard let lesson2 = catalog.lesson(byId: "lesson-alphabet-2") else {
            Issue.record("Missing lesson-alphabet-2 in catalog")
            return
        }

        #expect(lesson2.title.contains("Lesson 2"))
        #expect(lesson2.category == "alphabet")
        #expect(lesson2.signIds.count == 5)

        let signs = catalog.signs(forLesson: lesson2.id)
        #expect(signs.count == 5)
        #expect(signs.map(\.name) == ["F", "G", "H", "I", "J"])

        // Every sign in lesson has a valid image and how-to steps
        for sign in signs {
            #expect(sign.imageName != nil)
            #expect(sign.howToSteps.isEmpty == false)
        }
    }
}
#endif
