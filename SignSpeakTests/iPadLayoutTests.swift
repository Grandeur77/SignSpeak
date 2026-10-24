import Testing
import Foundation
import AVFoundation
@testable import SignSpeak

@Suite("iPad Layout & Interaction Tests")
@MainActor
struct iPadLayoutTests {

    @Test("iPad sidebar destinations have all 9 cases, valid titles, and icons")
    func iPadSidebarDestinations() {
        let all = iPadSidebarDestination.allCases
        #expect(all.count == 9)

        #expect(iPadSidebarDestination.home.title == "Home")
        #expect(iPadSidebarDestination.talk.title == "Communicator")
        #expect(iPadSidebarDestination.learn.title == "Learn")
        #expect(iPadSidebarDestination.signs.title == "Signs Directory")
        #expect(iPadSidebarDestination.community.title == "Community")
        #expect(iPadSidebarDestination.soundAlerts.title == "Sound Alerts")
        #expect(iPadSidebarDestination.inbox.title == "Notifications")
        #expect(iPadSidebarDestination.settings.title == "Settings")
        #expect(iPadSidebarDestination.profile.title == "My Profile")

        #expect(!iPadSidebarDestination.home.iconName.isEmpty)
        #expect(!iPadSidebarDestination.learn.iconName.isEmpty)
        #expect(!iPadSidebarDestination.talk.iconName.isEmpty)
    }

    @Test("External keyboard type and speak delivers synthesized audio and appends message")
    func externalKeyboardTypeAndSpeak() async {
        let conversationRepo = StubConversationRepository()
        let speechService = StubSpeechSynthesisService()
        let mockCamera = MockCameraService()
        let signRecognition = StubSignRecognitionService()
        let speechRecognition = StubSpeechRecognitionService()

        let vm = CommunicatorLiveViewModel(
            cameraService: mockCamera,
            handPoseDetector: StubHandPoseDetector(),
            signClassifier: StubSignClassifier(),
            signRecognitionService: signRecognition,
            speechRecognitionService: speechRecognition,
            speechSynthesisService: speechService,
            conversationRepository: conversationRepo,
            userId: "test-user-ipad"
        )

        let phrase = "Hello from external keyboard on iPad"
        await vm.typeAndSpeak(phrase)

        #expect(speechService.spokenUtterances.contains(phrase))
        #expect(vm.messages.contains(where: { $0.text == phrase && $0.speaker == "You" }))
    }

    @Test("Camera service sets and remembers iPad orientations")
    func cameraOrientationSupport() async {
        let cameraService = StubCameraService()
        await cameraService.setOrientation(.landscapeRight)
        #expect(cameraService.currentOrientation == .landscapeRight)

        await cameraService.setOrientation(.portrait)
        #expect(cameraService.currentOrientation == .portrait)

        await cameraService.setOrientation(.landscapeLeft)
        #expect(cameraService.currentOrientation == .landscapeLeft)

        await cameraService.setOrientation(.portraitUpsideDown)
        #expect(cameraService.currentOrientation == .portraitUpsideDown)
    }

    @Test("Lesson 1 A-E signs resolves all 5 letter signs in catalog")
    func lesson1SignsResolution() {
        let catalog = SignCatalogService()
        let lesson1 = catalog.allLessons().first(where: { $0.id == "lesson-alphabet-1" })
        #expect(lesson1 != nil)

        let signs = catalog.signs(forLesson: "lesson-alphabet-1")
        #expect(signs.count == 5)

        let names = signs.map(\.name)
        #expect(names == ["A", "B", "C", "D", "E"])

        for letter in ["A", "B", "C", "D", "E"] {
            let sign = catalog.sign(byId: "sign-letter-\(letter.lowercased())")
            #expect(sign != nil)
            #expect(sign?.name == letter)
            #expect(sign?.category == "alphabet")
        }
    }
}
