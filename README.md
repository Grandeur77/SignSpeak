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
- Authentication & Onboarding (Firebase Auth — Apple, Google, email)
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
