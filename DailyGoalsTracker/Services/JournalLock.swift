import CryptoKit
import Foundation
import LocalAuthentication

enum JournalLockScope: String, Codable, CaseIterable, Identifiable {
    case all
    case selected
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .all: return "All days"
        case .selected: return "Selected days"
        }
    }
}

enum JournalLockError: LocalizedError {
    case passwordTooShort
    case passwordMismatch
    case wrongPassword
    case passwordRequired
    case locked
    case biometryUnavailable
    case biometryFailed
    case biometryCancelled
    case biometryLockout
    case needsJournalPassword
    case touchIDSetupFailed
    case notConfigured
    
    var errorDescription: String? {
        switch self {
        case .passwordTooShort: return "Use at least 4 characters."
        case .passwordMismatch: return "Those passwords do not match."
        case .wrongPassword: return "That password is incorrect."
        case .passwordRequired: return "Set a journal password in Settings first."
        case .locked: return "Unlock the journal first."
        case .biometryUnavailable: return "Touch ID is not available on this Mac."
        case .biometryFailed: return "Touch ID could not unlock the journal."
        case .biometryCancelled: return "Touch ID was canceled."
        case .biometryLockout: return "Touch ID is locked. Use the journal password."
        case .needsJournalPassword: return "Enter the journal password."
        case .touchIDSetupFailed: return "Touch ID could not be turned on. Try the switch again and rest your finger on the sensor."
        case .notConfigured: return "No journal password is set."
        }
    }
}

struct JournalVaultRecord: Codable, Equatable {
    var salt: Data
    var wrappedKey: Data
    var iterations: Int
    var touchIDEnabled: Bool
}

struct JournalDocument: Codable {
    var vault: JournalVaultRecord?
    var scope: JournalLockScope
    var entries: [JournalEntry]
}

private struct JournalSealedBody: Codable {
    var text: String
    var rtfData: Data?
}

/// One password wraps a random key. That key encrypts each secured day.
@Observable
final class JournalLock {
    private(set) var record: JournalVaultRecord?
    var scope: JournalLockScope = .selected
    private(set) var isUnlocked = false
    private var contentKey: SymmetricKey?
    
    var hasPassword: Bool { record != nil }
    var touchIDEnabled: Bool { record?.touchIDEnabled ?? false }
    
    var biometryAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    func adopt(record: JournalVaultRecord?, scope: JournalLockScope) {
        self.record = record
        self.scope = scope
    }
    
    func shouldSeal(markedSecure: Bool) -> Bool {
        guard hasPassword else { return false }
        return scope == .all || markedSecure
    }
    
    func dayShouldSeal(_ entry: JournalEntry) -> Bool {
        shouldSeal(markedSecure: entry.markedSecure)
    }
    
    func setPassword(_ password: String, confirmation: String) throws {
        guard password.count >= 4 else { throw JournalLockError.passwordTooShort }
        guard password == confirmation else { throw JournalLockError.passwordMismatch }
        let key = SymmetricKey(size: .bits256)
        record = try wrap(key, password: password, touchID: false)
        contentKey = key
        isUnlocked = true
    }
    
    func changePassword(from old: String, to new: String, confirmation: String) throws {
        guard let existing = record else { throw JournalLockError.notConfigured }
        guard new.count >= 4 else { throw JournalLockError.passwordTooShort }
        guard new == confirmation else { throw JournalLockError.passwordMismatch }
        let key = try unwrap(existing, password: old)
        record = try wrap(key, password: new, touchID: existing.touchIDEnabled)
        contentKey = key
        isUnlocked = true
        if existing.touchIDEnabled {
            record?.touchIDEnabled = false
            clearKeychain()
        }
    }
    
    func removePassword(_ password: String) throws {
        guard let existing = record else { return }
        _ = try unwrap(existing, password: password)
        clearKeychain()
        record = nil
        contentKey = nil
        isUnlocked = false
        scope = .selected
    }
    
    func unlock(password: String) throws {
        guard let existing = record else { throw JournalLockError.notConfigured }
        contentKey = try unwrap(existing, password: password)
        isUnlocked = true
    }
    
    func endSession() {
        contentKey = nil
        isUnlocked = false
    }
    
    /// One system prompt. Touch ID succeeds into the Keychain read on this same context.
    /// "Use Journal Password" is the system fallback button.
    func unlockWithTouchID(fresh: Bool = false) async throws {
        guard touchIDEnabled else { throw JournalLockError.needsJournalPassword }
        guard biometryAvailable else { throw JournalLockError.needsJournalPassword }
        let context = LAContext()
        context.localizedFallbackTitle = "Use Journal Password"
        context.localizedCancelTitle = "Cancel"
        context.touchIDAuthenticationAllowableReuseDuration = fresh ? 0 : 10
        do {
            try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock your journal"
            )
        } catch let error as LAError {
            switch error.code {
            case .userFallback, .biometryLockout:
                throw JournalLockError.needsJournalPassword
            case .userCancel, .appCancel, .systemCancel:
                throw JournalLockError.biometryCancelled
            default:
                throw JournalLockError.biometryFailed
            }
        } catch {
            throw JournalLockError.biometryFailed
        }
        guard let keyData = copyKeychainKey(context: context) ?? copyKeychainKey(context: nil) else {
            throw JournalLockError.needsJournalPassword
        }
        contentKey = SymmetricKey(data: keyData)
        isUnlocked = true
    }
    
    func setTouchIDEnabled(_ enabled: Bool) async throws {
        guard isUnlocked, let contentKey, var record else { throw JournalLockError.locked }
        if enabled {
            guard biometryAvailable else { throw JournalLockError.biometryUnavailable }
            let context = LAContext()
            context.localizedCancelTitle = "Cancel"
            context.touchIDAuthenticationAllowableReuseDuration = 10
            do {
                try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: "Turn on Touch ID for your journal"
                )
            } catch {
                throw JournalLockError.touchIDSetupFailed
            }
            try storeTouchIDKey(contentKey)
        } else {
            clearKeychain()
        }
        record.touchIDEnabled = enabled
        self.record = record
    }
    
    /// Ciphertext for disk. Plain days pass through. Sealed days stay sealed when the key is not in memory.
    func prepareForDisk(_ entry: JournalEntry) -> JournalEntry {
        guard dayShouldSeal(entry) else {
            var open = entry
            open.sealedPayload = nil
            return open
        }
        if entry.isSealed, entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return entry
        }
        guard let contentKey else { return entry }
        return seal(entry, using: contentKey)
    }
    
    func reveal(_ entry: JournalEntry) -> JournalEntry? {
        guard let contentKey, entry.isSealed, let payload = entry.sealedPayload else { return nil }
        guard let box = try? AES.GCM.SealedBox(combined: payload),
              let data = try? AES.GCM.open(box, using: contentKey),
              let body = try? JSONDecoder().decode(JournalSealedBody.self, from: data) else {
            return nil
        }
        var opened = entry
        opened.text = body.text
        opened.rtfData = body.rtfData
        opened.sealedPayload = nil
        return opened
    }
    
    private func seal(_ entry: JournalEntry, using key: SymmetricKey) -> JournalEntry {
        let body = JournalSealedBody(text: entry.text, rtfData: entry.rtfData)
        guard let data = try? JSONEncoder().encode(body),
              let sealed = try? AES.GCM.seal(data, using: key),
              let combined = sealed.combined else {
            return entry
        }
        var sealedEntry = entry
        sealedEntry.text = ""
        sealedEntry.rtfData = nil
        sealedEntry.sealedPayload = combined
        if scope == .selected {
            sealedEntry.markedSecure = true
        }
        return sealedEntry
    }
    
    private func wrap(_ key: SymmetricKey, password: String, touchID: Bool) throws -> JournalVaultRecord {
        let salt = Data(AES.GCM.Nonce().withUnsafeBytes { Data($0) })
        let kek = deriveKey(password: password, salt: salt, iterations: Self.iterations)
        let keyData = key.withUnsafeBytes { Data($0) }
        let sealed = try AES.GCM.seal(keyData, using: kek)
        guard let combined = sealed.combined else { throw JournalLockError.wrongPassword }
        return JournalVaultRecord(
            salt: salt,
            wrappedKey: combined,
            iterations: Self.iterations,
            touchIDEnabled: touchID
        )
    }
    
    private func unwrap(_ record: JournalVaultRecord, password: String) throws -> SymmetricKey {
        let kek = deriveKey(password: password, salt: record.salt, iterations: record.iterations)
        guard let box = try? AES.GCM.SealedBox(combined: record.wrappedKey),
              let keyData = try? AES.GCM.open(box, using: kek) else {
            throw JournalLockError.wrongPassword
        }
        return SymmetricKey(data: keyData)
    }
    
    private static let iterations = 120_000
    private static let keychainService = "DailyGoalsTracker.journal"
    private static let keychainAccount = "content-key"
    
    private func deriveKey(password: String, salt: Data, iterations: Int) -> SymmetricKey {
        let passwordData = Data(password.utf8)
        var block = Data()
        var index = UInt32(1).bigEndian
        var indexBytes = Data()
        withUnsafeBytes(of: &index) { indexBytes.append(contentsOf: $0) }
        var u = hmacSHA256(key: passwordData, message: salt + indexBytes)
        var t = u
        if iterations > 1 {
            for _ in 1..<iterations {
                u = hmacSHA256(key: passwordData, message: Data(u))
                t = zip(t, u).map { $0 ^ $1 }
            }
        }
        block.append(contentsOf: t)
        return SymmetricKey(data: block)
    }
    
    private func hmacSHA256(key: Data, message: Data) -> [UInt8] {
        let code = HMAC<SHA256>.authenticationCode(for: message, using: SymmetricKey(data: key))
        return Array(code)
    }
    
    /// Login-keychain copy of the content key. Touch ID is checked before this is read or written.
    /// A biometry-only keychain item needs a development certificate this app does not have.
    private func storeTouchIDKey(_ key: SymmetricKey) throws {
        clearKeychain()
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw JournalLockError.touchIDSetupFailed }
    }
    
    private func copyKeychainKey(context: LAContext?) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let context {
            query[kSecUseAuthenticationContext as String] = context
        }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }
    
    private func clearKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
