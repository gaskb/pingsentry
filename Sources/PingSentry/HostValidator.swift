import Foundation

enum PingExecutable: Sendable {
    case ping4
    case ping6

    var executableURL: URL {
        switch self {
        case .ping4: return URL(fileURLWithPath: "/sbin/ping")
        case .ping6: return URL(fileURLWithPath: "/sbin/ping6")
        }
    }
}

struct HostValidationResult: Equatable, Sendable {
    let isValid: Bool
    let executable: PingExecutable
    let errorMessageKey: String?
}

enum HostValidator {
    static func validate(_ rawHost: String) -> HostValidationResult {
        let host = rawHost.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.isEmpty {
            return HostValidationResult(isValid: false, executable: .ping4, errorMessageKey: "settings.host_empty")
        }

        // Prevent passing flags as host
        if host.hasPrefix("-") {
            return HostValidationResult(isValid: false, executable: .ping4, errorMessageKey: "settings.host_invalid")
        }

        // Disallow dangerous shell characters or whitespace inside host
        let invalidChars = CharacterSet.whitespacesAndNewlines.union(
            CharacterSet(charactersIn: "\"'`;|&$><()\\{}[]!?*#")
        )
        if host.rangeOfCharacter(from: invalidChars) != nil {
            return HostValidationResult(isValid: false, executable: .ping4, errorMessageKey: "settings.host_invalid")
        }

        // IPv6 literal check
        if host.contains(":") {
            // Allows standard IPv6 hex, colons, dots (IPv4-mapped), and interface scope identifiers (e.g. %en0)
            let ipv6Allowed = CharacterSet(charactersIn: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ:._-%")
            if host.rangeOfCharacter(from: ipv6Allowed.inverted) != nil {
                return HostValidationResult(isValid: false, executable: .ping6, errorMessageKey: "settings.host_invalid")
            }
            return HostValidationResult(isValid: true, executable: .ping6, errorMessageKey: nil)
        }

        // Standard Hostname / IPv4 check
        let hostAllowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_")
        if host.rangeOfCharacter(from: hostAllowed.inverted) != nil {
            return HostValidationResult(isValid: false, executable: .ping4, errorMessageKey: "settings.host_invalid")
        }

        return HostValidationResult(isValid: true, executable: .ping4, errorMessageKey: nil)
    }
}
