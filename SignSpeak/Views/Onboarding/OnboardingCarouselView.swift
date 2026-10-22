import SwiftUI

/// 3-slide interactive onboarding carousel introducing Core ML vision, two-way speech-sign bridge,
public struct OnboardingCarouselView: View {
    @Bindable var viewModel: OnboardingViewModel

    public init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Bar: Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    viewModel.skip()
                }
                .font(.appBody)
                .foregroundStyle(Color.textSecondary)
                .frame(minHeight: Theme.minTapTarget)
                .padding(.horizontal, Theme.Spacing.m)
                .accessibilityLabel("Skip onboarding")
            }

            Spacer()

            // Visual Slide Content
            TabView(selection: Binding(
                get: { viewModel.currentStep.rawValue },
                set: { newRaw in
                    if let newStep = OnboardingStep(rawValue: newRaw), newStep <= .carousel3 {
                        viewModel.currentStep = newStep
                    }
                }
            )) {
                learnSlide
                    .tag(OnboardingStep.carousel1.rawValue)

                talkSlide
                    .tag(OnboardingStep.carousel2.rawValue)

                communitySlide
                    .tag(OnboardingStep.carousel3.rawValue)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: 520)

            Spacer()

            // Custom Page Indicator Dots
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Capsule()
                        .fill(viewModel.currentStep.rawValue == index ? Color.brandTurquoise : Color.brandTurquoise.opacity(0.2))
                        .frame(width: viewModel.currentStep.rawValue == index ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.currentStep)
                }
            }
            .padding(.bottom, Theme.Spacing.l)

            // Primary Navigation Button
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    viewModel.advance()
                }
            } label: {
                HStack(spacing: Theme.Spacing.s) {
                    Text(viewModel.currentStep == .carousel3 ? "Get started" : "Next")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.onPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.primaryFill, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xl)
            .accessibilityLabel(viewModel.currentStep == .carousel3 ? "Get started with role personalization" : "Go to next slide")
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    // MARK: - Slide 1: Learn with camera (10-onboarding-1-learn)

    private var learnSlide: some View {
        VStack(spacing: Theme.Spacing.l) {
            // Card Preview
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.brandTurquoise.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)

                VStack(spacing: Theme.Spacing.m) {
                    // Header badges
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.brandTurquoise)
                                .frame(width: 6, height: 6)
                            Text("VISION ENGINE 2.4")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.brandTurquoise)
                                .tracking(0.8)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.brandTurquoise.opacity(0.12), in: Capsule())

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                            Text("On-Device AI")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.top, Theme.Spacing.m)

                    Spacer()

                    // Stylized Skeleton Hand
                    ZStack {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(Color.brandTurquoise.opacity(0.25))

                        Image(systemName: "waveform.path.badge.plus")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.brandTurquoise)
                    }

                    // Recognition Pill
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.brandYellow)

                        Text("ASL Letter 'B' • 98%")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.brandNavy, in: Capsule())

                    // Footer stats
                    HStack {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("60 FPS Real-time")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer()

                        Text("Tracking 21 Points")
                            .font(.caption2)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.bottom, Theme.Spacing.m)
                }
            }
            .frame(height: 250)
            .padding(.horizontal, Theme.Spacing.l)

            // Titles & Copy
            VStack(spacing: Theme.Spacing.s) {
                Text("• STEP 1 OF 3 • SMART LEARNING")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
                    .tracking(1.0)

                Text("Learn with your camera")
                    .font(.appLargeTitle)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Master sign language with instant, private AI feedback on your hand shape and motion.")
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.m)
            }
        }
    }

    // MARK: - Slide 2: Two-way talk (12-onboarding-2-talk)

    private var talkSlide: some View {
        VStack(spacing: Theme.Spacing.l) {
            // Card Preview
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.brandTurquoise.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)

                VStack(spacing: Theme.Spacing.m) {
                    // Header
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.brandTurquoise)
                                .frame(width: 6, height: 6)
                            Text("TWO-WAY BRIDGE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.brandTurquoise)
                                .tracking(0.8)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.brandTurquoise.opacity(0.12), in: Capsule())

                        Spacer()

                        Image(systemName: "waveform")
                            .foregroundStyle(Color.brandTurquoise)
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.top, Theme.Spacing.m)

                    Spacer()

                    // Speech bubble (Hearing side)
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.brandTurquoise)
                            Text("\"Good morning! How are you?\"")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 14))
                        Spacer()
                    }
                    .padding(.horizontal, Theme.Spacing.m)

                    // Directional Indicator
                    HStack {
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.brandTurquoise)
                    }

                    // Sign bubble (Deaf / Signing side)
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Text("✋ \"Great to see you today!\"")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.brandNavy)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.brandYellow, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, Theme.Spacing.m)

                    Spacer()
                }
            }
            .frame(height: 250)
            .padding(.horizontal, Theme.Spacing.l)

            // Titles & Copy
            VStack(spacing: Theme.Spacing.s) {
                Text("• STEP 2 OF 3 • TWO-WAY BRIDGE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
                    .tracking(1.0)

                Text("Talk in both directions")
                    .font(.appLargeTitle)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Seamless real-time translation between sign language and spoken speech, right on your device.")
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.m)
            }
        }
    }

    // MARK: - Slide 3: Community (15-onboarding-3-community)

    private var communitySlide: some View {
        VStack(spacing: Theme.Spacing.l) {
            // Card Preview
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.brandTurquoise.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)

                VStack(spacing: Theme.Spacing.m) {
                    // Header
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("14K SIGNING NOW")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.brandTurquoise)
                                .tracking(0.8)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.brandTurquoise.opacity(0.12), in: Capsule())

                        Spacer()

                        Image(systemName: "person.3.fill")
                            .foregroundStyle(Color.brandTurquoise)
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.top, Theme.Spacing.m)

                    Spacer()

                    // Community Snippets
                    VStack(spacing: 10) {
                        HStack {
                            Circle()
                                .fill(Color.brandTurquoise)
                                .frame(width: 28, height: 28)
                                .overlay(Text("A").font(.caption.bold()).foregroundStyle(.white))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Aisha • Mastered 'Thank You'")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.textPrimary)
                                Text("Streak Keeper • 7 Days")
                                    .font(.caption2)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            Spacer()
                            Text("🔥 7")
                                .font(.caption.bold())
                                .foregroundStyle(Color.brandTurquoise)
                        }
                        .padding(10)
                        .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 12))

                        HStack {
                            Circle()
                                .fill(Color.brandNavy)
                                .frame(width: 28, height: 28)
                                .overlay(Text("L").font(.caption.bold()).foregroundStyle(.white))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Liam • Completed Unit 1")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.textPrimary)
                                Text("Daily Goal Met • 15 min")
                                    .font(.caption2)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            Spacer()
                            Text("+25 XP")
                                .font(.caption.bold())
                                .foregroundStyle(Color.brandTurquoise)
                        }
                        .padding(10)
                        .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, Theme.Spacing.m)

                    Spacer()
                }
            }
            .frame(height: 250)
            .padding(.horizontal, Theme.Spacing.l)

            // Titles & Copy
            VStack(spacing: Theme.Spacing.s) {
                Text("• STEP 3 OF 3 • COMMUNITY")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
                    .tracking(1.0)

                Text("Grow together")
                    .font(.appLargeTitle)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Join a vibrant community of signers and learners sharing progress, real-time feedback, and daily encouragement.")
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.m)
            }
        }
    }
}
