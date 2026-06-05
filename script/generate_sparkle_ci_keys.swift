#!/usr/bin/env swift

import CryptoKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: generate_sparkle_ci_keys.swift <private-key-output-file>\n".utf8))
    exit(1)
}

let outputURL = URL(fileURLWithPath: arguments[1])
let fileManager = FileManager.default

if fileManager.fileExists(atPath: outputURL.path) {
    FileHandle.standardError.write(Data("Private key output file already exists: \(outputURL.path)\n".utf8))
    exit(1)
}

let parentURL = outputURL.deletingLastPathComponent()
try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)

let privateKey = Curve25519.Signing.PrivateKey()
let privateSeed = privateKey.rawRepresentation.base64EncodedString()
let publicKey = privateKey.publicKey.rawRepresentation.base64EncodedString()

try privateSeed.write(to: outputURL, atomically: true, encoding: .utf8)
try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: outputURL.path)

print("Sparkle public key for SPARKLE_PUBLIC_ED_KEY:")
print(publicKey)
print("Sparkle private key written to: \(outputURL.path)")
print("Store the private key file contents as GitHub secret SPARKLE_PRIVATE_KEY.")
