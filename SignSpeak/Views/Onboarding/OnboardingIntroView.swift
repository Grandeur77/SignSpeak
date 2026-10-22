import SwiftUI

/// Host to the 3-slide carousel, role selection, daily goal pacing, permission primers
/// (camera, microphone, stay-on-track notifications), and sound alerts setup.
public struct OnboardingIntroView: View {
    @Environment(\.dependencies) private var dependencies
    @Bindable var router: AppRouter
    @State private var viewModel: OnboardingViewModel?

    public init(router: AppRouter) {
        self.router = router
    }

    public var body: some View {
        ZStack {
            if let viewModel {
                Group {
                    switch viewModel.currentStep {
                    case .carousel1, .carousel2, .carousel3:
                        OnboardingCarouselView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .opacity,
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))

                    case .role:
                        OnboardingRoleView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))

                    case .dailyGoal:
                        OnboardingDailyGoalView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))

                    case .camera:
                        CameraPermissionView(
                            isDenied: viewModel.isCameraDenied,
                            onRequestAccess: {
                                Task {
                                    await viewModel.requestCameraAccess()
                                }
                            },
                            onSkip: {
                                withAnimation {
                                    viewModel.advance()
                                }
                            },
                            onBack: {
                                withAnimation {
                                    viewModel.goBack()
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                    case .microphone:
                        OnboardingMicrophonePrimerView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))

                    case .notifications:
                        OnboardingNotificationsView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))

                    case .soundAlerts:
                        OnboardingSoundAlertsView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.currentStep)
            } else {
                SplashView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = OnboardingViewModel(
                    authService: dependencies.authService,
                    userProfileRepository: dependencies.userProfileRepository,
                    publicProfileRepository: dependencies.publicProfileRepository,
                    cameraService: dependencies.cameraService,
                    notificationService: dependencies.notificationService,
                    router: router
                )
            }
        }
    }
}
