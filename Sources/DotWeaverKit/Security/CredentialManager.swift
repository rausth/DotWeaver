import Foundation
import Security

public actor CredentialManager {
    public static let shared = CredentialManager()
    private init() {}
    
    private let serviceName = "com.rausth.DotWeaver"
    
    public func savePassword(for provider: SyncProvider, account: String, password: String) throws {
        let accountKey = "\(provider.rawValue).\(account)"
        let lookupQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountKey
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: password.data(using: .utf8) ?? Data(),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(lookupQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw NSError(domain: "CredentialManager", code: Int(updateStatus))
        }

        var addQuery = lookupQuery
        attributes.forEach { addQuery[$0.key] = $0.value }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw NSError(domain: "CredentialManager", code: Int(addStatus))
        }
    }
    
    public func getPassword(for provider: SyncProvider, account: String) async throws -> String? {
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
