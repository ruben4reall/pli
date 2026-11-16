import Foundation
import ServiceManagement

public enum LoginItemStatus: Sendable, Equatable {
    case enabled
    case disabled
    /// Registered, waiting for the person to allow it in System Settings, Login Items.
    case needsApproval
    /// This copy runs outside an Applications folder (a disk image, Downloads).
    case unavailable
}

@MainActor
public protocol LoginItemControlling: AnyObject {
    var status: LoginItemStatus { get }
    func setEnabled(_ enabled: Bool) throws
}

/// Open at Login (spec 8.1) through SMAppService: macOS lists Pli in Login Items, where it can also be removed.
@MainActor
public final class LoginItem: LoginItemControlling {
    private let service: SMAppService
    private let bundle: URL

    public init(service: SMAppService = .mainApp, bundle: URL = Bundle.main.bundleURL) {
        self.service = service
        self.bundle = bundle
    }

    public var status: LoginItemStatus { Self.status(from: service.status, bundle: bundle) }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }

    /// `.notFound` is also what macOS 27 answers for an app that was never registered, wherever it is, and registering
    /// it then works. So only a copy outside an Applications folder is told it cannot open at login.
    static func status(from status: SMAppService.Status, bundle: URL) -> LoginItemStatus {
        switch status {
        case .enabled: .enabled
        case .notRegistered: .disabled
        case .requiresApproval: .needsApproval
        case .notFound: isInApplicationsFolder(bundle) ? .disabled : .unavailable
        @unknown default: .unavailable
        }
    }

    /// /Applications, ~/Applications, or a folder inside either.
    static func isInApplicationsFolder(_ bundle: URL) -> Bool {
        let path = bundle.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        return ["/Applications/", home + "/Applications/"].contains { path.hasPrefix($0) }
    }
}
