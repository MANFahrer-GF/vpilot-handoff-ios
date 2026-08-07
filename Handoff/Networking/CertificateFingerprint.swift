import Foundation
import Security
import CryptoKit

/// Computes our own SHA-256/public-key fingerprint of a presented certificate for
/// trust-on-first-use pinning. This is intentionally NOT compared against the
/// "fingerprint" string the plugin hands out during UDP discovery -- protocol.md
/// is explicit that the discovery value is only a same-round-trip convenience;
/// the real trust decision is self-consistency across our own connections to a
/// given host, computed the same way every time.
enum CertificateFingerprint {
    static func sha256PublicKeyFingerprint(of certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }
        let digest = SHA256.hash(data: publicKeyData)
        return digest.map { String(format: "%02X", $0) }.joined(separator: ":")
    }
}
