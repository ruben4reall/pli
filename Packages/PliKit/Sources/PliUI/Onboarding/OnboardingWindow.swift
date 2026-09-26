import SwiftUI

/// The first launch in three steps (spec 8.5): Welcome, Screen Recording, Try It. Closing the window counts as seen.
public struct OnboardingWindow: View {
    let interface: InterfaceModel
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(interface: InterfaceModel) {
        self.interface = interface
    }

    public var body: some View {
        let step = interface.onboarding.step
        VStack(spacing: 0) {
            ZStack {
                switch step {
                case .welcome: WelcomeStep()
                case .permission: PermissionStep(interface: interface)
                case .tryIt: TryItStep(interface: interface)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 48)
            .padding(.top, 40)
            .id(step)
            .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            HStack(spacing: 12) {
                StepDots(step: step)
                Spacer()
                buttons(for: step)
            }
            .padding(20)
        }
        .frame(width: Theme.Layout.onboardingSize.width, height: Theme.Layout.onboardingSize.height)
        .background(Noir.window)
        .background(StageBackground())
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .tint(Noir.glacier)
        .animation(Theme.Motion.unlessReduced(Theme.Motion.fold(0.45), reduceMotion), value: step)
        .onAppear { interface.onboardingDidOpen() }
        .onDisappear { interface.onboardingDidClose() }
    }

    @ViewBuilder
    private func buttons(for step: OnboardingModel.Step) -> some View {
        switch step {
        case .welcome:
            Button(Strings.getStarted) { interface.onboardingGetStarted() }
                .buttonStyle(NoirButtonStyle(primary: true))
                .keyboardShortcut(.defaultAction)
        case .permission:
            Button(Strings.later) { interface.onboardingLater() }
                .buttonStyle(NoirButtonStyle())
            Button(Strings.allow) { interface.onboardingAllow() }
                .buttonStyle(NoirButtonStyle(primary: true))
                .keyboardShortcut(.defaultAction)
                .disabled(interface.onboarding.waitingForPermission)
        case .tryIt:
            Toggle(Strings.openPliAtLogin, isOn: Binding(get: { interface.onboarding.openAtLogin },
                                                        set: { interface.onboarding.openAtLogin = $0 }))
                .toggleStyle(.checkbox)
            Button(Strings.done) {
                interface.onboardingFinish()
                dismissWindow(id: PliWindow.onboarding.id)
            }
            .buttonStyle(NoirButtonStyle(primary: true))
            .keyboardShortcut(.defaultAction)
        }
    }
}

/// Step 1: the wordmark unfolds; one sentence.
private struct WelcomeStep: View {
    @State private var unfolded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Wordmark(height: 104, unfolded: unfolded)
            Text(Strings.welcomeSentence)
                .font(.system(size: 19))
                .foregroundStyle(Noir.secondary)
                .multilineTextAlignment(.center)
                .opacity(unfolded ? 1 : 0)
            Spacer()
        }
        .onAppear {
            withAnimation(Theme.Motion.unlessReduced(Theme.Motion.reveal(0.9), reduceMotion)) { unfolded = true }
        }
    }
}

/// Step 2: why the permission, the promise, the monthly confirmation; Allow or Later; Relaunch if macOS needs it.
private struct PermissionStep: View {
    let interface: InterfaceModel

    var body: some View {
        let live = interface.live
        VStack(spacing: 14) {
            Image(systemName: "rectangle.dashed.badge.record")
                .font(.system(size: 50))
                .foregroundStyle(Noir.glacier)
                .accessibilityHidden(true)
            Text(Strings.permissionTitle)
                .font(.system(size: 22, weight: .semibold))
            Text(Strings.permissionWhy)
                .foregroundStyle(Noir.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Label {
                Text(Strings.permissionPromise).fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "lock.shield").foregroundStyle(Noir.glacier)
            }
            Footnote(Strings.permissionMonthly)
                .multilineTextAlignment(.center)
            if live.screenCaptureAllowed {
                Label {
                    Text(Strings.permissionGranted)
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            } else if interface.onboarding.waitingForPermission {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(Strings.waitingForPermission)
                }
                HStack(spacing: 10) {
                    Footnote(Strings.relaunchNote)
                    Button(Strings.relaunchPli) { interface.relaunch() }
                        .buttonStyle(NoirButtonStyle(small: true))
                }
            } else {
                Footnote(Strings.permissionLaterNote)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

/// Step 3: close the lid halfway and watch the protractor and the real effect; a Demo button without a sensor.
private struct TryItStep: View {
    let interface: InterfaceModel

    var body: some View {
        let live = interface.live
        VStack(spacing: 16) {
            Text(Strings.tryItTitle)
                .font(.system(size: 22, weight: .semibold))
            if live.sensorAvailable {
                Text(Strings.tryItInstruction)
                    .font(.system(size: 16))
                    .foregroundStyle(Noir.secondary)
                    .multilineTextAlignment(.center)
                MacBookSide(angle: live.lidAngle ?? interface.protractorMarks.rest)
                    .frame(width: 300)
                    .padding(.top, 6)
                Text(live.lidAngle.map { Strings.degrees("\(Int($0.rounded()))") } ?? Strings.lidUnknown)
                    .font(.system(size: 44, weight: .thin))
                    .monospacedDigit()
                    .foregroundStyle(Noir.text)
            } else {
                Text(Strings.tryItNoSensor)
                    .font(.system(size: 16))
                    .foregroundStyle(Noir.secondary)
                    .multilineTextAlignment(.center)
                Button(Strings.playDemo) { interface.playDemo() }
                    .buttonStyle(NoirButtonStyle(primary: true))
            }
        }
    }
}

/// Where the person is among the three steps.
private struct StepDots: View {
    let step: OnboardingModel.Step

    var body: some View {
        HStack(spacing: 7) {
            ForEach(OnboardingModel.Step.allCases, id: \.self) { dot in
                Circle()
                    .fill(dot == step ? Noir.text : Noir.tertiary)
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Strings.stepOf(step.rawValue + 1, OnboardingModel.Step.allCases.count)))
    }
}
