# SignSpeak

An iOS app that helps people learn sign language and communicate across the
hearing/deaf divide, using the iPhone camera and entirely on-device machine
learning.

**Status:** In development. This README reflects the current build state and
will be updated as each phase is completed — see the commit history for
progress.

## Core Idea

SignSpeak recognizes hand signs in real time using Apple's Vision framework
and a custom Core ML classifier, teaches sign language through structured
lessons and quizzes, and provides a two-way "Communicator" mode: a deaf or
non-verbal user's signs are recognized and spoken aloud, while a hearing
person's speech is transcribed to text on screen.

## Planned Features

**Basic**
- Authentication & Onboarding (Firebase Auth — email/password, Google, guest)
- Settings & Face ID / Touch ID Lock
- Push Notifications (daily reminders, streak alerts)
- Dashboard (streak, accuracy, practice time)
- Lesson & Quiz Flow (Alphabet + Words/Phrases)
- Sign Directory (searchable reference catalogue)
- Community Feed (milestones, reactions, comments)
- Progress Analytics (Swift Charts)

**Advanced**
- Hand-Sign Recognition — Vision + Core ML (on-device)
- Communicator Mode — Speech framework + AVSpeechSynthesizer (on-device)
- Home & Lock Screen Widgets — WidgetKit + App Intents
- Sound Alerts — SoundAnalysis + CoreHaptics (stretch goal)

## Planned Architecture

MVVM, with camera, recognition, speech, and data-access services wrapped
behind protocols so ViewModels can be unit-tested with mocks rather than
real hardware or network calls.

Camera frames, hand landmarks, audio and speech are processed on-device and
never uploaded. Firebase stores only account, progress and community data.

## Project Structure

```
SignSpeak/
├── App/          App entry point and app delegate (Firebase setup)
├── Models/       Data types (signs, lessons, progress, posts)
├── ViewModels/   Screen state and logic, one per feature
├── Views/        SwiftUI screens, grouped by feature
│   ├── Auth, Onboarding, Home, Learn, Talk
│   ├── Signs, Community, Settings
│   └── Components   Reusable buttons, cards and styles
├── Services/     Camera, recognition, speech, Firebase (protocol-based)
└── Resources/    GoogleService-Info.plist, ML model, sign assets
SignSpeakTests/   Unit tests (Swift Testing)
```

## Tech Stack

Swift · SwiftUI · Firebase Auth & Firestore (Swift Package Manager) ·
Vision · Core ML / Create ML · AVFoundation · Speech · AVSpeechSynthesizer ·
LocalAuthentication · UserNotifications · WidgetKit · App Intents ·
Swift Charts · Swift Testing

## Requirements

- Xcode 26 or later
- iOS 17.0 or later — iPhone and iPad
- A real device for camera-based features (the simulator has no camera)

## Getting Started

1. Clone the repository and open `SignSpeak.xcodeproj`.
2. Wait for Xcode to resolve the Firebase Swift packages.
3. Select the **SignSpeak** scheme and an iPhone or iPad simulator, then run (⌘R).

`GoogleService-Info.plist` is included in `SignSpeak/Resources/` so the
project runs as submitted. It identifies the Firebase project and is not a
secret; data access is protected by Firestore security rules and Firebase
Authentication.

## Testing

Unit tests use the **Swift Testing** framework (`import Testing`, `@Test`,
`#expect`). Run them with **Product → Test** (⌘U).

## AI Use

AI tools were used during development for planning, research and coding
assistance. This use is declared in the project report.
