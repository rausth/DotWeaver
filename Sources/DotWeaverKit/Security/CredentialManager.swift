import Foundation
import Security

actor CredentialManager {
    static let shared = CredentialManager()
    private init() {}
    
    private let serviceName = "com.rausth.DotWeaver"
    
    func savePassword(for provider: SyncProvider, account: String, password: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "\(provider.rawValue).\(account)",
            kSecValueData as String: password.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "CredentialManager", code: Int(status))
        }
    }
    
    func getPassword(for provider: SyncProvider, account: String) async throws -> String? {
        if SecurityPolicy.requiresBiometricAuthentication {
            _ = try await BiometricAuthenticator.shared.authenticate(reason: "Authenticate to access \(provider.title) credentials")
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "\(provider.rawValue).\(account)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
