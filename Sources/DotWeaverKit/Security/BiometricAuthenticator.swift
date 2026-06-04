import Foundation
import LocalAuthentication

public actor BiometricAuthenticator {
    public static let shared = BiometricAuthenticator()
    private init() {}
    
    public func authenticate(reason: String = "Authenticate to access credentials", allowFallback: Bool = true) async throws -> Bool {
        if SecurityPolicy.isRunningTests {
            throw BiometricError.notAvailable
        }

        let context = LAContext()
        let policy: LAPolicy = allowFallback ? .deviceOwnerAuthentication : .deviceOwnerAuthenticationWithBiometrics
        
        var error: NSError?
        guard context.canEvaluatePolicy(policy, error: &error) else {
            throw error ?? BiometricError.notAvailable
        }
        
        return try await context.evaluatePolicy(policy, localizedReason: reason)
    }
}

public enum BiometricError: LocalizedError {
    case notAvailable
    case authenticationFailed
    
    public var errorDescription: String? {
        switch self {
        case .notAvailable: return "Biometric authentication is not available on this device."
        case .authenticationFailed: return "Authentication was canceled or failed."
        }
    }
}
