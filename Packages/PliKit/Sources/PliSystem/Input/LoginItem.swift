import ServiceManagement

public enum LoginItemStatus: Sendable, Equatable {
    case enabled
    case disabled
    /// Registered, waiting for the person to allow it in System Settings, Login Items.
    case needsApproval
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

    public init(service: SMAppService = .mainApp) {
        self.service = service
    }

    public var status: LoginItemStatus { Self.status(from: service.status) }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }

    static func status(from status: SMAppService.Status) -> LoginItemStatus {
        switch status {
        case .enabled: .enabled
        case .notRegistered: .disabled
        case .requiresApproval: .needsApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }
}
