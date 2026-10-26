
//  SecureParentalVault.swift
//  VisionPal
//
//  Created by Zachary D'Souza on 9/26/26.
//
import Foundation
import CryptoKit

class SecureParentalVault {
    private static let salt = "VisionPal_Ergonomic_Parental_Salt_2026"
    private static let hashStorageKey = "VisionPal_ParentalPIN_Hash"

    /// Saves a new parental passcode as a salted SHA-256 hash.
    static func savePasscode(_ passcode: String) -> Bool {
        let salted = passcode + salt
        let digest = SHA256.hash(data: Data(salted.utf8))
        let hashString = digest.compactMap { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hashString, forKey: hashStorageKey)
        return true
    }

    /// Verifies the entered passcode against the stored hash (or factory default "1234").
    static func verifyPasscode(_ input: String) -> Bool {
        guard let savedHash = UserDefaults.standard.string(forKey: hashStorageKey) else {
            return input == "1234"
        }
        
        let salted = input + salt
        let digest = SHA256.hash(data: Data(salted.utf8))
        let computedHash = digest.compactMap { String(format: "%02x", $0) }.joined()
        return computedHash == savedHash
    }

    /// Resets the passcode back to factory default ("1234").
    static func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: hashStorageKey)
    }
}
