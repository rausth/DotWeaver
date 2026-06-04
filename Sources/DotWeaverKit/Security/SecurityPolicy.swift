import Foundation

public enum SecurityPolicy {
    public static var requiresBiometricAuthentication: Bool {
        if isRunningTests {
            return false
        }

        if defaults.object(forKey: "biometricEnabled") == nil {
            return true
        }

        return defaults.bool(forKey: "biometricEnabled")
    }

    public static var hooksEnabled: Bool {
        defaults.bool(forKey: "hooksEnabled")
    }

    public static func setHooksEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: "hooksEnabled")
    }

    public static var allowsUnsafeLocalPaths: Bool {
        if isRunningTests {
            return true
        }

        #if DEBUG
        return ProcessInfo.processInfo.environment["DOTWEAVER_ALLOW_UNSAFE_LOCAL_PATHS"] == "1"
        #else
        return false
        #endif
    }

    public static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        ProcessInfo.processInfo.processName.contains("xctest") ||
        ProcessInfo.processInfo.processName.contains("PackageTests") ||
        ProcessInfo.processInfo.arguments.contains { $0.contains(".xctest") || $0.contains("DotWeaverPackageTests") } ||
        NSClassFromString("XCTestCase") != nil
    }

    private static var defaults: UserDefaults {
        if let suite = ProcessInfo.processInfo.environment["DOTWEAVER_USER_DEFAULTS_SUITE"],
           !suite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let defaults = UserDefaults(suiteName: suite) {
            return defaults
        }
        return .standard
    }
}
