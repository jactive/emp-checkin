import CryptoKit
import Foundation

enum CryptoService {
    enum CryptoError: Error, LocalizedError {
        case invalidData
        case decryptionFailed

        var errorDescription: String? {
            switch self {
            case .invalidData: return "Encrypted data is corrupted or missing"
            case .decryptionFailed: return "Wrong password"
            }
        }
    }

    private static func deriveKey(from password: String) -> SymmetricKey {
        let hash = SHA256.hash(data: Data(password.utf8))
        return SymmetricKey(data: hash)
    }

    static func decrypt(data: Data, password: String) throws -> Data {
        guard data.count > 12 else { throw CryptoError.invalidData }
        let nonce = data.prefix(12)
        let sealed = data.dropFirst(12)
        let key = deriveKey(from: password)
        do {
            let box = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: nonce),
                ciphertext: sealed.dropLast(16),
                tag: sealed.suffix(16)
            )
            return try AES.GCM.open(box, using: key)
        } catch {
            throw CryptoError.decryptionFailed
        }
    }

    static func decryptRoster<T: Decodable>(_ type: T.Type, from data: Data, password: String) throws -> T {
        let decrypted = try decrypt(data: data, password: password)
        return try JSONDecoder().decode(T.self, from: decrypted)
    }
}
