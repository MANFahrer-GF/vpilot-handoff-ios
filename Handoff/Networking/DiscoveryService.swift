import Foundation
#if canImport(Darwin)
import Darwin
#endif

struct DiscoveryResult: Equatable {
    let host: String
    let port: Int
    let fingerprint: String
}

enum DiscoveryError: LocalizedError {
    case socketCreationFailed
    case broadcastNotPermitted
    case sendFailed

    var errorDescription: String? {
        switch self {
        case .socketCreationFailed: return "Netzwerk-Socket konnte nicht erstellt werden."
        case .broadcastNotPermitted:
            // iOS gates broadcast/multicast sockets behind the Multicast Networking
            // entitlement on real devices (not in the Simulator, which shares the
            // Mac's own network stack). Manual IP entry is the documented fallback
            // in protocol.md for exactly this reason.
            return "Broadcast-Suche vom Gerät nicht erlaubt -- IP bitte manuell eingeben."
        case .sendFailed: return "Anfrage konnte nicht gesendet werden."
        }
    }
}

/// UDP broadcast discovery per protocol.md: send ASCII "HANDOFF_DISCOVER" to
/// 255.255.255.255:48766, plugin unicasts back {"port":..., "fingerprint":...}.
/// Best-effort only -- not guaranteed on every network (client isolation, broadcast
/// filtering), so callers must always offer manual IP entry alongside this.
final class DiscoveryService: @unchecked Sendable {
    private static let discoveryPort: UInt16 = 48766
    private static let discoveryMessage = "HANDOFF_DISCOVER"

    func discover(timeout: TimeInterval = 3.0) async throws -> [DiscoveryResult] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let results = try Self.performDiscovery(timeout: timeout)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func performDiscovery(timeout: TimeInterval) throws -> [DiscoveryResult] {
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { throw DiscoveryError.socketCreationFailed }
        defer { close(sock) }

        var broadcastEnable: Int32 = 1
        guard setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
            throw DiscoveryError.broadcastNotPermitted
        }

        var recvTimeout = timeval(tv_sec: 0, tv_usec: 300_000)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &recvTimeout, socklen_t(MemoryLayout<timeval>.size))

        var localAddr = sockaddr_in()
        localAddr.sin_family = sa_family_t(AF_INET)
        localAddr.sin_port = 0
        localAddr.sin_addr.s_addr = INADDR_ANY
        let bindResult = withUnsafePointer(to: &localAddr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(sock, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { throw DiscoveryError.socketCreationFailed }

        var destAddr = sockaddr_in()
        destAddr.sin_family = sa_family_t(AF_INET)
        destAddr.sin_port = discoveryPort.bigEndian
        destAddr.sin_addr.s_addr = INADDR_BROADCAST

        let messageBytes = Array(discoveryMessage.utf8)
        let sendResult = withUnsafePointer(to: &destAddr) { ptr -> Int in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                sendto(sock, messageBytes, messageBytes.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard sendResult > 0 else { throw DiscoveryError.sendFailed }

        var results: [DiscoveryResult] = []
        let deadline = Date().addingTimeInterval(timeout)
        var buffer = [UInt8](repeating: 0, count: 2048)

        while Date() < deadline {
            var fromAddr = sockaddr_in()
            var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let received = withUnsafeMutablePointer(to: &fromAddr) { ptr -> Int in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    recvfrom(sock, &buffer, buffer.count, 0, sa, &fromLen)
                }
            }
            guard received > 0 else { continue }

            let data = Data(buffer[0..<received])
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let port = json["port"] as? Int,
                  let fingerprint = json["fingerprint"] as? String else { continue }

            var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &fromAddr.sin_addr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
            let host = ipBuffer.withUnsafeBufferPointer { buffer in
                buffer.baseAddress.map { String(validatingCString: $0) ?? "" } ?? ""
            }
            guard !host.isEmpty else { continue }

            if !results.contains(where: { $0.host == host }) {
                results.append(DiscoveryResult(host: host, port: port, fingerprint: fingerprint))
            }
        }
        return results
    }
}
