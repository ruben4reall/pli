import SwiftUI

/// Asked once, at the first launch of 1.1, to an install that never said whether Pli opens at login: Pli 1.0 only
/// registered when the welcome window closed on Done, so a Mac that restarted lost the fold until Pli was opened by
/// hand. Closing the window, either way, means the question is never asked again.
public struct OpenAtLoginWindow: View {
    let interface: InterfaceModel
    @Environment(\.dismissWindow) private var dismissWindow

    public init(interface: InterfaceModel) {
        self.interface = interface
    }

    public var body: some View {
        let problem = interface.loginProblem
        let needsApproval = interface.loginItem == .needsApproval
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: "power")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Noir.glacier)
                    .accessibilityHidden(true)
                    .padding(.bottom, 4)
                Text(Strings.keepTheFoldTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Noir.text)
                Text(Strings.keepTheFoldWhy)
                    .font(.system(size: 13))
                    .foregroundStyle(Noir.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Footnote(problem ?? (needsApproval ? Strings.loginNeedsApproval : Strings.keepTheFoldLater))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            .padding(.top, 36)
            Spacer(minLength: 16)
            HStack(spacing: 12) {
                Spacer()
                Button(Strings.notNow) { close() }
                    .buttonStyle(NoirButtonStyle())
                    .keyboardShortcut(.cancelAction)
                if needsApproval {
                    Button(Strings.openLoginItems) {
                        interface.openLoginItemsSettings()
                        close()
                    }
                    .buttonStyle(NoirButtonStyle(primary: true))
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button(Strings.openAtLogin) {
                        interface.loginPromptAccept()
                        if interface.loginItem == .enabled { close() }
                    }
                    .buttonStyle(NoirButtonStyle(primary: true))
                    .keyboardShortcut(.defaultAction)
                    .disabled(problem != nil)
                }
            }
            .padding(20)
        }
        .frame(width: Theme.Layout.openAtLoginSize.width, height: Theme.Layout.openAtLoginSize.height)
        .background(Noir.window)
        .background(StageBackground())
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .tint(Noir.glacier)
        .onAppear { interface.loginPromptDidOpen() }
        .onDisappear { interface.loginPromptDidClose() }
    }

    private func close() {
        dismissWindow(id: PliWindow.openAtLogin.id)
    }
}
