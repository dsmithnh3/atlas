import Foundation
import CryptoKit

extension String {
    // First 16 bytes of the UTF-8 SHA256 hash, hex-encoded (32 chars).
    // Used for content-derived file names and cache keys where a full
    // 32-byte hash would be unwieldy and collisions in 16 bytes are
    // sufficiently unlikely for the size of the input space.
    var sha256HexPrefix16: String {
        let hash = SHA256.hash(data: Data(self.utf8))
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}
