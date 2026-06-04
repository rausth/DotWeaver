import CryptoKit
import Foundation
import Security

public enum VaultCrypto {
    private static let service = "com.rausth.DotWeaver.vault"
    private static let account = "master-key"
    private static let wrappedAccount = "master-key.secure-enclave-wrapped"
    private static let enclavePrivateKeyTag = "com.rausth.DotWeaver.vault.secure-enclave.private-key".data(using: .utf8)!

    public static func encrypt(_ data: Data, originalPath: String) throws -> Data {
        let key = try masterKey()
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw SyncError.encryptionFailed("Unable to create encrypted payload")
        }

        let envelope = VaultEnvelope(
            version: 1,
            algorithm: "AES.GCM",
            originalPath: originalPath,
            machineID: try MachineIdentity.current().id,
            encryptedAt: Date(),
            payload: combined.base64EncodedString()
        )

        return try JSONEncoder.pretty.encode(envelope)
    }

    public static func decryptIfNeeded(_ data: Data) throws -> Data {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let envelope = try? decoder.decode(VaultEnvelope.self, from: data) else {
            return data
        }

        guard envelope.algorithm == "AES.GCM",
              let combined = Data(base64Encoded: envelope.payload) else {
            throw SyncError.encryptionFailed("Invalid vault payload")
        }

        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: masterKey())
    }

    public static func isEncrypted(_ data: Data) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(VaultEnvelope.self, from: data)) != nil
    }

    private static func masterKey() throws -> SymmetricKey {
        if let data = try readSecureEnclaveWrappedKey() {
            return SymmetricKey(data: data)
        }

        if let data = try readKey() {
            _ = saveSecureEnclaveWrappedKey(data)
            return SymmetricKey(data: data)
        }

        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        if !saveSecureEnclaveWrappedKey(data) {
            try saveKey(data)
        }
        SyncAuditLog.record("Created vault master key")
        return key
    }

    public static func secureEnclaveWrappingAvailable() -> Bool {
        (try? secureEnclaveWrappingKey()) != nil
    }

    private static func readKey() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw SyncError.encryptionFailed("Unable to read vault master key")
        }
        return data
    }

    private static func saveKey(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SyncError.encryptionFailed("Unable to save vault master key: \(status)")
        }
    }

    private static func readSecureEnclaveWrappedKey() throws -> Data? {
        guard let encrypted = try readKey(account: wrappedAccount),
              let wrappingKey = try? secureEnclaveWrappingKey() else {
            return nil
        }

        let box = try AES.GCM.SealedBox(combined: encrypted)
        return try AES.GCM.open(box, using: wrappingKey)
    }

    @discardableResult
    private static func saveSecureEnclaveWrappedKey(_ data: Data) -> Bool {
        do {
            let wrappingKey = try secureEnclaveWrappingKey()
            guard let encrypted = try AES.GCM.seal(data, using: wrappingKey).combined else {
                return false
            }
            try saveKey(encrypted, account: wrappedAccount)
            SyncAuditLog.record("Stored vault master key with Secure Enclave wrapping")
            return true
        } catch {
            SyncAuditLog.record("Secure Enclave wrapping unavailable", metadata: ["error": error.localizedDescription])
            return false
        }
    }

    private static func readKey(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw SyncError.encryptionFailed("Unable to read vault key item")
        }
        return data
    }

    private static func saveKey(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SyncError.encryptionFailed("Unable to save vault key item: \(status)")
        }
    }

    private static func secureEnclaveWrappingKey() throws -> SymmetricKey {
        let privateKey = try secureEnclavePrivateKey()
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SyncError.encryptionFailed("Unable to read Secure Enclave public key")
        }

        var error: Unmanaged<CFError>?
        guard let shared = SecKeyCopyKeyExchangeResult(
            privateKey,
            .ecdhKeyExchangeStandardX963SHA256,
            publicKey,
            [:] as CFDictionary,
            &error
        ) as Data? else {
            throw error?.takeRetainedValue() as Error? ?? SyncError.encryptionFailed("Secure Enclave key exchange failed")
        }

        return SymmetricKey(data: SHA256.hash(data: shared))
    }

    private static func secureEnclavePrivateKey() throws -> SecKey {
        if let key = try loadSecureEnclavePrivateKey() {
            return key
        }

        var accessError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage],
            &accessError
        ) else {
            throw accessError?.takeRetainedValue() as Error? ?? SyncError.encryptionFailed("Unable to create Secure Enclave access control")
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: enclavePrivateKeyTag,
                kSecAttrAccessControl as String: access
            ]
        ]

        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error?.takeRetainedValue() as Error? ?? SyncError.encryptionFailed("Unable to create Secure Enclave key")
        }
        return key
    }

    private static func loadSecureEnclavePrivateKey() throws -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: enclavePrivateKeyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw SyncError.encryptionFailed("Unable to load Secure Enclave key: \(status)")
        }
        return (item as! SecKey)
    }
}

private struct VaultEnvelope: Codable {
    let version: Int
    let algorithm: String
    let originalPath: String
    let machineID: String
    let encryptedAt: Date
    let payload: String
}
