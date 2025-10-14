import SwiftUI

struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                switch viewModel.currentStep {
                case .welcome:
                    WelcomeScreen(viewModel: viewModel)
                case .benefits:
                    BenefitsScreen(viewModel: viewModel)
                case .auth:
                    AuthScreen(viewModel: viewModel)
                }
            }
        }
    }
}

struct WelcomeScreen: View {
    var viewModel: OnboardingViewModel

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [Color.brandBlue, Color.brandBlueLift],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                // App Icon
                Image(systemName: "airplane.departure")
                    .font(.system(size: 96))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 8)

                VStack(spacing: Spacing.md) {
                    Text("Welcome to FareLens")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Discover amazing flight deals\nand never miss a bargain")
                        .title3Style()
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                FLButton(title: "Get Started", style: .primary) {
                    viewModel.nextStep()
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.xl)
            }
        }
    }
}

struct BenefitsScreen: View {
    var viewModel: OnboardingViewModel

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                // Header
                Text("What You'll Get")
                    .title1Style()
                    .foregroundColor(.textPrimary)
                    .padding(.top, Spacing.xl * 2)

                // Benefits List
                VStack(spacing: Spacing.lg) {
                    BenefitRow(
                        icon: "bell.fill",
                        iconColor: .brandBlue,
                        title: "Smart Alerts",
                        description: "Get notified instantly when deals match your preferences"
                    )

                    BenefitRow(
                        icon: "bookmark.fill",
                        iconColor: .brandBlue,
                        title: "Watchlists",
                        description: "Track specific routes and get priority alerts"
                    )

                    BenefitRow(
                        icon: "star.fill",
                        iconColor: .warning,
                        title: "Deal Scores",
                        description: "See quality ratings on every deal (70-100)"
                    )

                    BenefitRow(
                        icon: "crown.fill",
                        iconColor: .warning,
                        title: "Pro Features",
                        description: "Upgrade for more alerts and unlimited watchlists"
                    )
                }
                .padding(.horizontal, Spacing.screenHorizontal)

                Spacer()

                // Actions
                VStack(spacing: Spacing.md) {
                    FLButton(title: "Continue", style: .primary) {
                        viewModel.nextStep()
                    }

                    Button(action: {
                        viewModel.previousStep()
                    }) {
                        Text("Back")
                            .headlineStyle()
                            .foregroundColor(.brandBlue)
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.xl)
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        FLCard {
            HStack(spacing: Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(iconColor)
                }

                // Content
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .headlineStyle()
                        .foregroundColor(.textPrimary)

                    Text(description)
                        .bodyStyle()
                        .foregroundColor(.textSecondary)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

struct AuthScreen: View {
    var viewModel: OnboardingViewModel
    @State private var isSignUp = false

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Header
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 72))
                            .foregroundColor(.brandBlue)

                        Text(isSignUp ? "Create Account" : "Sign In")
                            .title1Style()
                            .foregroundColor(.textPrimary)
                    }
                    .padding(.top, Spacing.xl * 2)

                    // Form
                    VStack(spacing: Spacing.md) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Email")
                                .bodyStyle()
                                .foregroundColor(.textSecondary)

                            TextField("email@example.com", text: $viewModel.email)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .padding(.vertical, Spacing.xs)
                        }

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Password")
                                .bodyStyle()
                                .foregroundColor(.textSecondary)

                            SecureField("••••••••", text: $viewModel.password)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(isSignUp ? .newPassword : .password)
                                .padding(.vertical, Spacing.xs)
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)

                    // Error Message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .footnoteStyle()
                            .foregroundColor(.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.screenHorizontal)
                    }

                    // Submit Button
                    Group {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.brandBlue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.buttonVertical)
                        } else {
                            FLButton(
                                title: isSignUp ? "Sign Up" : "Sign In",
                                style: viewModel.isFormValid ? .primary : .secondary
                            ) {
                                Task {
                                    if isSignUp {
                                        await viewModel.signUp()
                                    } else {
                                        await viewModel.signIn()
                                    }
                                }
                            }
                            .disabled(!viewModel.isFormValid)
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)

                    // Toggle Auth Mode
                    Button(action: {
                        isSignUp.toggle()
                    }) {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .bodyStyle()
                            .foregroundColor(.brandBlue)
                    }

                    Spacer()

                    // Back Button
                    Button(action: {
                        viewModel.previousStep()
                    }) {
                        Text("Back")
                            .headlineStyle()
                            .foregroundColor(.brandBlue)
                    }
                    .padding(.bottom, Spacing.xl)
                }
            }
        }
    }
}
