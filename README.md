# SignSpeak — On-Device ASL Learning & Real-Time Communicator

An accessible, privacy-first iOS application that bridges the communication gap between Deaf/hard-of-hearing individuals and hearing people, while providing an engaging, curriculum-aligned American Sign Language (ASL) learning path.

Built entirely with **SwiftUI** and powered by **100% on-device machine learning** (Apple Vision, Core ML, Speech, and SoundAnalysis), SignSpeak requires **zero cloud AI or remote inference**—ensuring absolute privacy for camera frames, hand landmarks, voice audio, and biometric data.

---

### Coursework Information
- **Coursework:** NIBM iOS Application Development Final Coursework
- **Candidate:** Mileesha Fernando
- **Target OS:** iOS 17.0+ & iPadOS 17.0+ (Universal iPhone & iPad)
- **Bundle Identifier:** `com.mileesha.SignSpeak`
- **Development Tool:** Xcode 16.0+ (Swift 5.9 / 6.0)
- **Architecture:** MVVM with Protocol-Based Dependency Injection (`AppDependencies`)
- **Unit Testing Framework:** Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`)

---

## Table of Contents
1. [Core Idea & Mission](#core-idea--mission)
2. [Key Features](#key-features)
   - [Learn Hub & Practice Mirror](#1-learn-hub--practice-mirror)
   - [Two-Way Communicator Mode](#2-two-way-communicator-mode)
   - [Sound Alerts (Assistive Ambient Listener)](#3-sound-alerts-assistive-ambient-listener)
   - [ASL Reference Directory](#4-asl-reference-directory)
   - [Community & Social Learning](#5-community--social-learning)
   - [Widgets & App Intents](#6-widgets--app-intents)
   - [Security & Biometric App Lock](#7-security--biometric-app-lock)
   - [Universal Accessibility](#8-universal-accessibility)
   - [Offline-First Resilience](#9-offline-first-resilience)
3. [System Architecture](#system-architecture)
   - [Text Architecture Diagram](#text-architecture-diagram)
   - [Service Protocol Layer & Dependency Injection](#service-protocol-layer--dependency-injection)
   - [On-Device ML Recognition Pipeline](#on-device-ml-recognition-pipeline)
   - [Two-Way Audio & Speech Pipeline](#two-way-audio--speech-pipeline)
4. [On-Device Privacy & Zero-Cloud Guarantee](#on-device-privacy--zero-cloud-guarantee)
5. [Project Structure](#project-structure)
6. [Tech Stack](#tech-stack)
7. [System Requirements](#system-requirements)
8. [Getting Started & Setup Guide](#getting-started--setup-guide)
9. [Testing Strategy](#testing-strategy)
10. [AI-Use Declaration Placeholder](#ai-use-declaration-placeholder)
11. [Viva Examination Guide](#viva-examination-guide)

---

## Core Idea & Mission

Communication between hearing and Deaf or hard-of-hearing people often faces severe barriers due to the scarcity of human interpreters, high latency of cloud-dependent translation services, and deep privacy concerns surrounding streaming camera and microphone data to remote servers.

SignSpeak solves these challenges by combining:
1. **Interactive ASL Education:** Gamified alphabet, numbers, and common phrase lessons paired with a real-time **Practice Mirror** providing instant skeletal landmark feedback and posture coaching.
2. **Two-Way Communicator Mode:** 
   - **Deaf → Hearing:** Continuous hand sign recognition converted into clear speech via `AVSpeechSynthesizer`.
   - **Hearing → Deaf:** Real-time on-device speech-to-text (`SFSpeechRecognizer`) rendered as high-contrast, scalable live captions.
3. **Assistive Ambient Sound Alerts:** Environmental sound recognition (`SoundAnalysis`) for alarms, sirens, door knocks, and crying, delivered via distinct haptic vibrations (`CoreHaptics`) and full-screen visual flash cues.

All sensor inputs (video frames, hand landmarks, microphone audio) are processed strictly in RAM and discarded immediately. No video, audio, or biometric data ever leaves the device.

---

## Key Features

### 1. Learn Hub & Practice Mirror
- **Curriculum Paths:**
  - **Fingerspelling Path:** All 26 letters of the ASL alphabet (A–Z) and numbers (1–9) with letter mastery tracking.
  - **Thematic Packs:** Common words and expressions (Greetings, Everyday Needs, Family, Emergency).
- **Practice Mirror:**
  - Real-time 21-joint 2D hand landmark detection using Apple's Vision framework (`VNDetectHumanHandPoseRequest`).
  - Turquoise skeleton overlay rendering joint nodes and bone connections at 30 fps.
  - **Real-Time Coaching Hints:** Dynamic guidance detecting low lighting, excessive distance, off-center positioning, or obscured fingers.
  - **Stability Filter:** Exponential moving average and rolling consensus buffer that prevents flickering classifications and false positives.
- **Spaced Repetition System (`SpacedRepetitionScheduler`):**
  - Adapts review schedules based on sign recall accuracy, ensuring weak signs are practiced more frequently.
- **Interactive Quizzes (`QuizEngine`):**
  - Multiple formats: sign-to-letter flashcards, multiple-choice quizzes, and live camera-based practical sign demonstrations.

### 2. Two-Way Communicator Mode
- **Deaf-to-Hearing Translation:**
  - Real-time sign classification pipeline (`SignRecognitionService`) detects static hand shapes and dynamic gestures.
  - Recognized words are aggregated in a live sentence builder buffer with auto-spacing.
  - Synthesizes speech aloud using `AVSpeechSynthesizer` with customizable speech rate and pitch.
- **Hearing-to-Deaf Subtitles:**
  - Live speech recognition using Apple's `Speech` framework with `requiresOnDeviceRecognition = true`.
  - Continuous streaming transcription with instant word updates and high-contrast, large-format typography.
- **Quick Phrases Drawer:**
  - Pre-configured emergency and everyday phrases (e.g., *"I am Deaf, please read my screen"*, *"Call an emergency contact"*, *"Thank you"*).
  - Customizable user phrases with one-tap text-to-speech triggers.
- **Conversation History:**
  - Local session transcripts saved for user reference and exportable as plain text.

### 3. Sound Alerts (Assistive Ambient Listener)
- **Environmental Sound Detection:**
  - Utilizes Apple's `SoundAnalysis` framework with `SNClassifySoundRequest` on an audio stream background queue.
  - Pre-trained classifiers recognize smoke/fire alarms, sirens, door knocks, doorbells, and crying.
- **Multi-Sensory Feedback:**
  - Custom `CoreHaptics` vibration patterns designed specifically for urgency levels (repetitive bursts for alarms, gentle pulses for knocks).
  - High-visibility full-screen color strobing / flash banners for immediate visual alerting.
- **Sound Alert History:**
  - Timestamped log of detected environmental sounds with sound type and confidence metrics.

### 4. ASL Reference Directory
- **Catalogue of 100+ Signs:**
  - Alphabet, numbers, emergency signs, common phrases, and conversational vocabulary.
- **Sign Detail Cards:**
  - Embedded high-definition video demonstrations with slow-motion toggle and frame scrubbing.
  - Detailed textual descriptions, movement trajectories, memory mnemonics, and difficulty ratings.
- **Search & Filters:**
  - Instant search by title or keyword.
  - Filtering by category (Basics, People, Food, Emergency, Numbers) and mastery status.
  - Personal bookmarking system (`FavouritesRepository`).

### 5. Community & Social Learning
- **Milestone Feed:**
  - Share learning streaks, quiz scores, and newly mastered signs with other learners.
  - Community reactions and encouraging comments.
- **User Profiles & Custom Avatars:**
  - Personalized profile with avatar selection and badge showcase.
  - Streak tracking with daily streak freezes and longest streak records.
- **Safe Cloud Sync:**
  - Syncs only user-generated social posts, reactions, and aggregate progress to Cloud Firestore.

### 6. Widgets & App Intents
- **WidgetKit Integration:**
  - **Streak Tracker Widget:** Displays current daily streak and next milestone on Home Screen and Lock Screen.
  - **Sign of the Day Widget:** Curated daily sign with preview imagery, definition, and quick-launch practice action.
  - **Quick Communicator Widget:** Instant one-tap shortcut to launch directly into live two-way Communicator mode.
- **App Intents:**
  - Interactive widget actions and deep-linking into specific practice modules.
  - App Group shared storage (`SharedStore`) for synchronizing widget data with the main application.

### 7. Security & Biometric App Lock
- **Biometric App Lock (`BiometricAuthServicing`):**
  - Uses `LocalAuthentication` (`LAContext`) to gate app access via Face ID or Touch ID.
  - Re-authenticates upon initial launch and immediately when resuming from background or device lock.
  - Graceful fallback to device passcode when biometrics are unavailable or declined.
- **Secure Keychain Storage (`CredentialVault`):**
  - Stores sensitive user tokens and biometric lock preferences in the hardware-backed iOS Keychain.

### 8. Universal Accessibility
- **VoiceOver First-Class Citizen:**
  - Every interactive element, custom card, camera viewfinder, and toolbar button features descriptive accessibility labels, hints, traits, and custom rotor actions.
  - Card elements combine content into single readable elements to avoid repetitive swipe navigation.
- **Dynamic Type Support:**
  - All views support Dynamic Type up to Accessibility XXL sizes with adaptive wrapping (`ViewThatFits`) to prevent text truncation.
- **Accessibility Preferences:**
  - Respects system `accessibilityReduceMotion` (disables spring animations in favor of subtle opacity fades).
  - Respects `colorSchemeContrast` (adds high-contrast borders and elevated stroke weights).
- **Official Deaf Flag Palette:**
  - Color palette based on the World Federation of the Deaf (WFD) official flag:
    - Turquoise (`#0FA3B1`) — Primary accent & active states
    - Navy (`#0B2A4A`) — Backgrounds, headings, high-contrast text
    - Yellow (`#FFC72C`) — Streaks, achievements, milestones
    - Off-White (`#F7FAFB`) — Primary surface in light mode
    - Pale Turquoise (`#E6F6F8`) — Card surfaces and subtle badges
    - Success Green (`#2BB673`) — Correct sign verification
    - Error Red (`#E5484D`) — Validation alerts and offline warnings
- **Touch Targets:** Minimum 44 × 44 pt tap targets across all interactive controls.

### 9. Offline-First Resilience
- **Network Reachability Monitoring (`NetworkMonitorService`):**
  - Tracks network connectivity in real time using `NWPathMonitor`.
  - Non-intrusive, global offline banner alerts the user when offline.
- **Complete Local Functionality:**
  - Camera, hand landmark detection, Core ML sign classification, speech synthesis, and local practice operate 100% offline.
  - Firestore data (profile, progress, feed) uses local disk cache fallback.

---

## System Architecture

SignSpeak follows the **Model-View-ViewModel (MVVM)** architectural pattern combined with **Protocol-Based Dependency Injection**. Views are thin, declarative SwiftUI views. All presentation logic and state reside in `@Observable @MainActor` ViewModels.

Hardware, machine learning, speech, and network resources are hidden behind strict Swift protocols in `SignSpeak/Services/`, allowing the entire application to be tested in isolation using lightweight mock services in `SignSpeakTests/Mocks/`.

### Text Architecture Diagram

```
+---------------------------------------------------------------------------------+
|                                 USER INTERFACE                                  |
|   SwiftUI Views: Home, Learn, Talk (Communicator), Signs, Community, Settings  |
|   Design System: Deaf Flag Colors, Dynamic Type, VoiceOver, Haptics             |
+---------------------------------------------------------------------------------+
                                       |
                                       | Observes state / Dispatches user actions
                                       v
+---------------------------------------------------------------------------------+
|                               VIEWMODEL LAYER                                   |
|   @Observable @MainActor Classes: CommunicatorViewModel, LearnHubViewModel,     |
|   SignRecognitionViewModel, SignsDirectoryViewModel, AuthViewModel, etc.        |
+---------------------------------------------------------------------------------+
                                       |
                                       | Injected via AppDependencies container
                                       v
+---------------------------------------------------------------------------------+
|                       SERVICE LAYER (Protocol Abstractions)                    |
|   CameraServicing             SignClassifying          SpeechRecognitionServicing|
|   SpeechSynthesisServicing    SoundAlertServicing      AuthServicing             |
|   ProgressRepository          FavouritesRepository     NotificationServicing     |
|   BiometricAuthServicing      NetworkMonitorServicing  ConversationRepository    |
+---------------------------------------------------------------------------------+
          |                        |                                   |
          v                        v                                   v
+--------------------+   +--------------------+              +--------------------+
|  SENSOR / ML PIPELINE|   |   AUDIO PIPELINE   |              |  PERSISTENCE / SYNC|
|  AVFoundation      |   |  AVAudioEngine     |              |  iOS Keychain      |
|  Vision Hand Pose  |   |  SFSpeechRecognizer|              |  (CredentialVault) |
|  Core ML (ANE/GPU) |   |  (On-Device Only)  |              |  App Group Storage |
|  Stability Filter  |   |  AVSpeechSynth     |              |  (SharedStore)     |
|  (Zero Network)    |   |  SoundAnalysis     |              |  Cloud Firestore   |
|                    |   |  CoreHaptics       |              |  (User state only) |
+--------------------+   +--------------------+              +--------------------+
```

### Service Protocol Layer & Dependency Injection

All services are registered inside a single, decoupled dependency container:
```swift
@MainActor
public final class AppDependencies: Observable {
    public let authService: any AuthServicing
    public let biometricService: any BiometricAuthServicing
    public let cameraService: any CameraServicing
    public let handPoseDetector: any HandPoseDetecting
    public let signClassifier: any SignClassifying
    public let recognitionService: any SignRecognitionServicing
    public let speechRecognizer: any SpeechRecognitionServicing
    public let speechSynthesizer: any SpeechSynthesisServicing
    public let soundAlertService: any SoundAlertServicing
    public let networkMonitor: any NetworkMonitorServicing
    public let progressRepository: any ProgressRepository
    public let favouritesRepository: any FavouritesRepository
    // ...
}
```
During runtime, real services are instantiated and passed via the SwiftUI `.environment(appDependencies)`. During automated testing, mock services conforming to these identical protocols are passed into ViewModels, completely eliminating hardware and network flakiness.

### On-Device ML Recognition Pipeline

```
[AVCaptureSession] (30 fps camera feed on background serial queue)
       │
       ▼
[Vision Framework] (`VNDetectHumanHandPoseRequest`)
  Extracts 21 2D joint landmarks normalized to [0.0, 1.0]
       │
       ├──► [Practice Mirror View] (Renders real-time turquoise skeleton overlay)
       │
       ▼
[Feature Extraction] (Normalizes coordinates relative to wrist joint node)
       │
       ├──► [StaticSignClassifier.mlmodel] (Classifies static poses A–Y, ILoveYou)
       │
       └──► [MotionSignClassifier.mlmodel] (Temporal window buffer of 45 frames for J, Z, phrases)
       │
       ▼
[StabilityFilter] (Consensus buffer + threshold confidence gating >= 0.70)
       │
       ▼
[MainActor UI / Speech Synthesis] (Displays subtitle card & triggers AVSpeechSynthesizer)
```

### Two-Way Audio & Speech Pipeline

```
[Hearing Partner Speaks]
       │
       ▼
[AVAudioEngine Input Node] (16kHz audio buffer)
       │
       ▼
[SFSpeechAudioBufferRecognitionRequest]
  • requiresOnDeviceRecognition = true
  • shouldReportPartialResults = true
       │
       ▼
[High-Contrast Live Captions] (Rendered on Communicator screen with dynamic text sizing)

────────────────────────────────────────────────────────────────────────────

[Deaf Partner Signs]
       │
       ▼
[SignRecognitionService] (Identifies gesture from hand landmarks)
       │
       ▼
[AVSpeechSynthesizer] (Speaks text aloud through speaker using AVSystem voice)
```

---

## On-Device Privacy & Zero-Cloud Guarantee

SignSpeak is engineered with a strict **Zero-Cloud AI Privacy Guarantee**:

| Data Type | Storage & Transmission Rule | Processing Engine |
| :--- | :--- | :--- |
| **Camera Frames** | **Never saved, never uploaded.** Processed in volatile RAM and immediately discarded. | Apple Vision Framework |
| **Hand Landmarks** | **100% on-device.** Normalized keypoint coordinates exist only during inference. | Apple Neural Engine & GPU |
| **Microphone Audio** | **Zero remote streaming.** Processed locally using on-device acoustic models. | `SFSpeechRecognizer` (On-Device) |
| **Face ID / Biometrics** | **Never leaves the Secure Enclave.** App evaluates boolean authentication tokens only. | `LocalAuthentication` |
| **User Account & Progress** | Securely synced to Cloud Firestore under strict authentication rules. | Firebase Auth & Firestore |

### What Firebase Does (and Does NOT) Touch
- **Allowed:** User email/UID, display name, avatar ID, completed lesson identifiers, practice streaks, bookmarks, and user-published community feed messages.
- **Forbidden:** No images, no audio files, no video clips, no hand landmark coordinates, no biometric data, and no third-party tracking/analytics packages.

---

## Project Structure

```
SignSpeak/
├── Config/                             # Configuration files and compiler settings
├── docs/                               # Documentation, build plans, and dataset specs
│   ├── BUILD_PLAN.md                   # Complete implementation phase roadmap
│   ├── CLAUDE.md                       # Project rules, constraints, and guidelines
│   ├── DATASET.md                      # ASL dataset methodology & Create ML guide
│   └── SignSpeak-Prompts.md            # Step-by-step prompt documentation
├── SignSpeak/                          # Main Application Target
│   ├── App/                            # Entry point, AppDependencies DI container, Router
│   │   ├── SignSpeakApp.swift
│   │   ├── AppDependencies.swift
│   │   └── AppRouter.swift
│   ├── Models/                         # Domain structs (Codable, Identifiable, Hashable)
│   │   ├── SignItem.swift, Lesson.swift, UserProfile.swift, CommunityPost.swift, ...
│   ├── ViewModels/                     # Observable ViewModels (one per screen/flow)
│   │   ├── CommunicatorViewModel.swift, LearnHubViewModel.swift, SignsDirectoryViewModel.swift, ...
│   ├── Views/                          # SwiftUI Views grouped by feature
│   │   ├── Auth/                       # Login, Registration, Forgot Password
│   │   ├── Onboarding/                 # Multi-step welcome, role selection, permissions
│   │   ├── Home/                       # Dashboard, daily streak, quick resume, widgets
│   │   ├── Learn/                      # Fingerspelling path, Practice Mirror, Quizzes
│   │   ├── Talk/                       # Two-Way Communicator, live captions, quick phrases
│   │   ├── Signs/                      # ASL directory, search, filter, video detail player
│   │   ├── SoundAlerts/                # Ambient sound detector, haptic setup, alert log
│   │   ├── Community/                  # Social feed, milestone posts, public profiles
│   │   ├── Settings/                   # Face ID lock toggle, preferences, developer tools
│   │   └── Components/                 # Deaf Flag buttons, cards, skeletons, StateViews
│   ├── Services/                       # Protocol definitions and concrete implementations
│   │   ├── CameraService.swift & CameraServicing.swift
│   │   ├── HandPoseDetector.swift & HandPoseDetecting.swift
│   │   ├── SignClassifier.swift & MotionClassifier.swift
│   │   ├── SignRecognitionService.swift & StabilityFilter.swift
│   │   ├── SpeechRecognitionServicing.swift & SpeechSynthesisServicing.swift
│   │   ├── SoundAlertService.swift & HapticFeedbackService.swift
│   │   ├── BiometricAuthServicing.swift & CredentialVault.swift
│   │   ├── NetworkMonitorService.swift (NWPathMonitor)
│   │   └── FirebaseAuthService.swift & Firestore Repositories
│   └── Resources/                      # Assets, Core ML models, GoogleService-Info.plist
├── SignSpeakWidgets/                   # WidgetKit Extension & App Intents
│   ├── QuickCommunicatorWidget.swift   # Instant-launch lock screen & home screen widget
│   ├── SignOfTheDayWidget.swift        # Daily vocabulary flashcard widget
│   ├── StreakWidget.swift              # Streak tracking widget
│   └── WidgetSharedStore.swift         # Shared App Group storage
└── SignSpeakTests/                     # Comprehensive Unit & Integration Tests (Swift Testing)
    ├── Mocks/                          # Deterministic mock services for every protocol
    └── [45 Test Suites]                # 100% Swift Testing (@Suite, @Test, #expect)
```

---

## Tech Stack

- **Language:** Swift 5.9 / 6.0 (Concurrency: `async`/`await`, `AsyncStream`, `@Observable`, `@MainActor`)
- **UI Framework:** SwiftUI (iOS 17.0+ APIs, `NavigationStack`, `ViewThatFits`, `ContentUnavailableView`)
- **Vision:** `VNDetectHumanHandPoseRequest` (21 2D joint landmarks extraction)
- **Machine Learning:** Core ML / Create ML
  - `StaticSignClassifier.mlmodel` (26 static hand pose classes)
  - `MotionSignClassifier.mlmodel` (13 dynamic hand motion classes)
  - Neural Engine + GPU acceleration (`MLModelConfiguration.computeUnits = .all`)
- **Audio & Speech:**
  - `Speech` (`SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`)
  - `AVFoundation` (`AVSpeechSynthesizer`, `AVCaptureSession`)
  - `SoundAnalysis` (`SNClassifySoundRequest` for environmental sound classification)
  - `CoreHaptics` (custom multi-sensory vibration waveforms)
- **Security:** `LocalAuthentication` (Face ID / Touch ID), iOS Keychain Services
- **System Integration:** `WidgetKit`, `AppIntents`, `UserNotifications` (Local Notifications), `Network` (`NWPathMonitor`)
- **Analytics & Data Visualisation:** `Swift Charts` (interactive weekly and monthly mastery graphs)
- **Backend Services:** `FirebaseAuth`, `FirebaseFirestore`, `GoogleSignIn` (via Swift Package Manager)
- **Testing:** `Swift Testing` framework (modern `@Suite`, `@Test`, `#expect`, `#require`)

---

## System Requirements

- **Development Workstation:** Mac running macOS Sonoma 14.0 or macOS Sequoia 15.0+
- **Integrated Development Environment:** Xcode 16.0 or later
- **Deployment Target:** iOS 17.0+ or iPadOS 17.0+
- **Hardware Recommendations:**
  - **Physical iPhone or iPad (Recommended):** Required for live camera capture, Vision hand landmark tracking, and real-time Speech recognition (simulators do not provide camera video feeds).
  - **Simulator:** Supported for UI testing, navigation, learning paths, quizzes, and mock sign recognition.

---

## Getting Started & Setup Guide

### 1. Clone the Repository
```bash
git clone https://github.com/mileeshafernando/SignSpeak.git
cd SignSpeak
```

### 2. Open the Xcode Project
```bash
open SignSpeak.xcodeproj
```
Wait for Xcode to resolve the Swift Package Manager (SPM) dependencies:
- `firebase-ios-sdk` (FirebaseAuth & FirebaseFirestore)
- `GoogleSignIn-iOS`

### 3. Firebase Configuration
The project is pre-configured with `GoogleService-Info.plist` located in `SignSpeak/Resources/`. It connects to the coursework evaluation Firebase project with authenticated Firestore rules. No manual configuration or credentials are required.

### 4. Select Scheme & Target
1. Select the **SignSpeak** scheme in the Xcode toolbar.
2. Select an **iOS 17.0+ Simulator** (e.g., *iPhone 17* or *iPad Air 11-inch (M4)*) or your connected physical device.
3. Press **Run** (`⌘R`) or click the Play button.

### 5. Runtime Permissions
Upon first launch, the app prompts for the following permissions with user-friendly usage descriptions:
- **Camera (`NSCameraUsageDescription`):** Required for the Practice Mirror and live sign recognition.
- **Microphone (`NSMicrophoneUsageDescription`):** Required for the Communicator's live transcription and Sound Alerts.
- **Speech Recognition (`NSSpeechRecognitionUsageDescription`):** Required for on-device speech-to-text.
- **Face ID (`NSFaceIDUsageDescription`):** Required for the optional biometric app-lock gate.
- **Notifications:** Required for daily study reminders and streak recovery alerts.

> **Simulator Tip (Face ID):** Enable Face ID in the simulator by selecting **Features → Face ID → Enrolled**, then simulate matching via **Features → Face ID → Matching Face**.

---

## Testing Strategy

All unit and integration tests are written exclusively using Apple's modern **Swift Testing** framework (`import Testing`, `@Suite`, `@Test`, `#expect`). **XCTest is not used.**

### Running Tests in Xcode
- Open `SignSpeak.xcodeproj` and press **Product → Test** (`⌘U`).

### Running Tests from the Command Line
```bash
xcodebuild test \
  -project SignSpeak.xcodeproj \
  -scheme SignSpeak \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Test Coverage Architecture
The test suite consists of **45+ test files** covering:
- **ViewModels:** `CommunicatorViewModelTests`, `AuthViewModelTests`, `LearnHubTests`, `SettingsTests`, etc.
- **Engines & Schedulers:** `LearningLogicTests`, `SpacedRepetitionTests`, `StreakEngineTests`, `QuizTests`, etc.
- **Pipelines & Filters:** `StabilityFilterTests`, `HandPoseDetectorTests`, `MotionClassifierTests`, `SignRecognitionServiceTests`.
- **System Integration:** `BiometricLockTests`, `NotificationTests`, `WidgetAndIntentTests`, `NetworkMonitorTests`.
- **Accessibility & Layout:** `iPadLayoutTests`, `Phase15AuditTests` (verifies VoiceOver labels, Dynamic Type scaling, and high-contrast adaptations).

All tests utilize isolated, deterministic mock services from `SignSpeakTests/Mocks/`, guaranteeing rapid test execution without network or hardware flakiness.

---

## AI-Use Declaration Placeholder

*As required by the NIBM Coursework Guidelines, use of artificial intelligence tools during research, planning, code design, and debugging must be transparently documented.*

### AI Tool Usage Summary

| Tool Name | Version / Model | Scope & Purpose | Student Verification & Modifications |
| :--- | :--- | :--- | :--- |
| **Claude / Antigravity** | Claude 3.5 Sonnet / Gemini | Initial architecture brainstorming, MVVM boilerplate drafting, Vision pipeline optimization research. | Verified all code adheres to Swift 6 concurrency, validated on-device ML constraints, wrote manual unit tests, and refined UI styling. |
| **Create ML** | macOS Sequoia Tool | Training static hand pose and motion hand gesture Core ML models. | Personally captured, filtered, labeled, and balanced the static and dynamic ASL dataset images and video clips. |

### Learning Outcomes (LO1 – LO4) Reflection Placeholder
*(To be completed in your own words for the final coursework report submission)*

- **LO1 — Practical Application of iOS Technologies:**  
  *[Insert student reflection on mastering Swift concurrency, SwiftUI, Vision framework, Core ML pipelines, and WidgetKit]*
- **LO2 — Software Architecture & Design Principles:**  
  *[Insert student reflection on implementing MVVM, protocol-driven dependency injection, and clean separation of concerns]*
- **LO3 — Accessibility & Inclusive Software Design:**  
  *[Insert student reflection on adhering to Apple HIG, VoiceOver semantic navigation, Dynamic Type scaling, and the WFD Deaf Flag design system]*
- **LO4 — Testing, Quality Assurance & Security:**  
  *[Insert student reflection on Swift Testing, isolated mock testing, zero-cloud privacy architecture, and Keychain biometric protection]*

---

## Viva Examination Guide

Key architectural points and design rationales for the viva defense:

1. **Why Protocol-Based Dependency Injection instead of Singletons?**
   - Singletons tightly couple view models to device hardware (e.g., `AVCaptureSession`) and external cloud networks, making automated unit testing virtually impossible. By abstracting services behind protocols (`CameraServicing`, `AuthServicing`, etc.) and passing them via an `AppDependencies` container, we achieve 100% deterministic testability with lightweight mocks in Swift Testing.

2. **Why On-Device Core ML instead of Cloud Vision APIs?**
   - Streaming video frames to a cloud server introduces unacceptable latency (300ms–1000ms), requires an active internet connection, and violates the fundamental privacy rights of Deaf users communicating in private settings. On-device inference with `VNDetectHumanHandPoseRequest` and Core ML runs in sub-15ms on the Apple Neural Engine and GPU without consuming external bandwidth.

3. **How does the Stability Filter work?**
   - Raw classifier output can oscillate due to rapid finger micro-movements. The `StabilityFilter` maintains a rolling temporal consensus window. A sign is only committed to the sentence buffer if the classifier returns the same high-confidence prediction across a consecutive sequence of frames, eliminating flicker and false activations.

4. **Why is Face ID / Touch ID implemented as an App-Wide Lock Gate?**
   - Given the personal nature of communication history, quick phrases, and community data, the biometric lock triggers on application launch and upon returning from `scenePhase == .background`. This ensures the app cannot be viewed in the iOS App Switcher without biometric re-authentication.

5. **How was Universal Accessibility implemented?**
   - Every view includes explicit `.accessibilityLabel()`, `.accessibilityHint()`, and `.accessibilityAction()` modifiers. Layouts adapt dynamically to Accessibility XXL sizes using `ViewThatFits` and responsive stacks. Spring animations automatically yield to opacity transitions when `accessibilityReduceMotion` is enabled.

---

### Author & Academic Details
- **Student Name:** Mileesha Fernando
- **Course:** NIBM iOS Application Development Final Coursework
- **Submission Date:** October 2026
- **License:** Educational Coursework Project — All Rights Reserved
