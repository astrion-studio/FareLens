// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Observation
import SwiftUI

struct OnboardingView: View {
    let appState: AppState
    @State private var viewModel: OnboardingViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = State(initialValue: OnboardingViewModel(appState: appState))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationView {
            ZStack {
                switch viewModel.currentStep {
                case .welcome:
                    WelcomeScreen(viewModel: viewModel)
                case .benefits:
                    BenefitsScreen(viewModel: viewModel)
                case .auth:
                    AuthScreen(viewModel: viewModel)
                case .airportSelection:
                    AirportSelectionScreen(viewModel: viewModel)
                }
            }
        }
    }
}

struct WelcomeScreen: View {
    @Bindable var viewModel: OnboardingViewModel

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
    @Bindable var viewModel: OnboardingViewModel

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
    @Bindable var viewModel: OnboardingViewModel
    @State private var isSignUp = false
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case email
        case password
    }

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

                    // Server error banner
                    if let error = viewModel.serverError {
                        ErrorBanner(
                            message: error.message,
                            actionTitle: error.actionTitle
                        ) {
                            handleErrorAction(error)
                        }
                        .animation(.spring(response: 0.3), value: viewModel.serverError)
                    }

                    // Form
                    VStack(spacing: Spacing.md) {
                        // Email field
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Email")
                                .bodyStyle()
                                .foregroundColor(.textSecondary)

                            TextField("email@example.com", text: $viewModel.email)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .submitLabel(.next)
                                .focused($focusedField, equals: .email)
                                .onSubmit {
                                    focusedField = .password
                                }
                                .onChange(of: focusedField) { oldValue, newValue in
                                    // Validate email format on blur
                                    if oldValue == .email, newValue != .email {
                                        viewModel.validateEmailFormat()
                                    }
                                }
                                .accessibilityLabel("Email")
                                .accessibilityHint("Enter your email address")

                            // Inline error
                            if let error = viewModel.emailError {
                                ErrorText(message: error.message)
                            }
                        }

                        // Password field
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Password")
                                .bodyStyle()
                                .foregroundColor(.textSecondary)

                            SecureField("••••••••", text: $viewModel.password)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(isSignUp ? .newPassword : .password)
                                .submitLabel(.go)
                                .focused($focusedField, equals: .password)
                                .onSubmit {
                                    Task {
                                        await viewModel.validateAndSubmit(isSignUp: isSignUp)
                                    }
                                }
                                .accessibilityLabel("Password")
                                .accessibilityHint("Enter your password")

                            // Password requirements (sign up only)
                            if isSignUp {
                                PasswordRequirements(password: viewModel.password)
                            }

                            // Inline error
                            if let error = viewModel.passwordError {
                                ErrorText(message: error.message)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)

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
                                style: .primary // Always primary, never disabled
                            ) {
                                Task {
                                    await viewModel.validateAndSubmit(isSignUp: isSignUp)
                                }
                            }
                            .accessibilityHint(viewModel
                                .isFormValid ? "Activate to \(isSignUp ? "sign up" : "sign in")" :
                                "Complete all fields to continue")
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)

                    // Toggle Auth Mode
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            isSignUp.toggle()
                            viewModel.clearErrors()
                        }
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
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                // Pre-warm keyboard by focusing email field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusedField = .email
                }
            }
        }
        .onTapGesture {
            focusedField = nil // Dismiss keyboard on tap outside
        }
        .accessibilityAction(.escape) {
            focusedField = nil // VoiceOver: two-finger double-tap dismisses keyboard
        }
    }

    private func handleErrorAction(_ error: ServerError) {
        switch error {
        case .emailNotConfirmed:
            // TODO: Implement resend confirmation
            break
        case .emailAlreadyExists:
            isSignUp = false // Switch to sign in
            viewModel.clearErrors()
        case .network:
            Task {
                await viewModel.validateAndSubmit(isSignUp: isSignUp)
            }
        case .weakPassword:
            focusedField = .password
            viewModel.passwordError = .tooShort
        default:
            break
        }
    }
}
