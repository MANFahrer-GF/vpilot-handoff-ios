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
    case noLocalNetwork
    case sendFailed

    var errorDescription: String? {
        switch self {
        case .socketCreationFailed: return "Could not create a network socket."
        case .noLocalNetwork:
            return "No Wi-Fi network found — join the same network as the PC, or enter the IP manually."
        case .sendFailed: return "Could not send the discovery request."
        }
    }
}

/// UDP discovery per protocol.md: send ASCII "HANDOFF_DISCOVER" to port 48766, the
/// plugin unicasts back {"port":..., "fingerprint":...}.
///
/// protocol.md describes a broadcast to 255.255.255.255. On a real iPad that is
/// unreliable: since iOS 14 the system drops broadcast and multicast sends unless
/// the app carries the Multicast Networking entitlement, which Apple grants on
/// request only, and the Simulator hides the problem because it shares the Mac's
/// network stack. So the broadcast is still attempted, but the discovery that
/// actually finds the PC is a unicast sweep: the same message to every address in
/// the iPad's own subnet. Unicast is never gated, the plugin's UDP socket answers
/// it exactly like a broadcast, and a home /24 is 254 tiny packets.
///
/// Still best-effort (client isolation, a /16 corporate network, the PC's firewall),
/// so callers must always offer manual IP entry alongside this.
final class DiscoveryService: @unchecked Sendable {
    private static let discoveryPort: UInt16 = 48766
    private static let discoveryMessage = "HANDOFF_DISCOVER"
    /// Larger subnets are swept only up to this many hosts, counted outward from
    /// the iPad's own address -- the PC is almost always a neighbour.
    static let sweepLimit = 1024

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

    // MARK: - Subnet enumeration

    /// An IPv4 interface the iPad is on, in host byte order.
    struct Subnet: Equatable {
        let address: UInt32
        let netmask: UInt32
    }

    /// Every other host address in the subnet, nearest to `address` first, at most
    /// `limit` of them. Network and broadcast addresses are skipped; so is the
    /// iPad itself. Pure, so the ordering and the cap are testable.
    static func sweepTargets(for subnet: Subnet, limit: Int = sweepLimit) -> [UInt32] {
        let network = subnet.address & subnet.netmask
        let broadcast = network | ~subnet.netmask
        guard broadcast > network + 1 else { return [] }   // /31, /32: nothing to sweep
        let first = network + 1
        let last = broadcast - 1

        var targets: [UInt32] = []
        targets.reserveCapacity(min(limit, Int(last - first)))
        var below = subnet.address
        var above = subnet.address
        while targets.count < limit {
            var advanced = false
            if above < last {
                above += 1
                targets.append(above)
                advanced = true
            }
            if targets.count < limit, below > first {
                below -= 1
                targets.append(below)
                advanced = true
            }
            if !advanced { break }
        }
        return targets
    }

    /// The IPv4 subnets of the interfaces that are up and not loopback. Wi-Fi (en0)
    /// first, since that is where the PC will be; cellular is skipped because a
    /// carrier subnet is never the home LAN.
    static func localSubnets() -> [Subnet] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }

        var named: [(name: String, subnet: Subnet)] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            let flags = entry.pointee.ifa_flags
            guard flags & UInt32(IFF_UP) != 0, flags & UInt32(IFF_LOOPBACK) == 0,
                  let addr = entry.pointee.ifa_addr, addr.pointee.sa_family == sa_family_t(AF_INET),
                  let mask = entry.pointee.ifa_netmask else { continue }
            let name = String(cString: entry.pointee.ifa_name)
            guard !name.hasPrefix("pdp_ip") else { continue }   // cellular
            let address = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt32(bigEndian: $0.pointee.sin_addr.s_addr) }
            let netmask = mask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt32(bigEndian: $0.pointee.sin_addr.s_addr) }
            guard netmask != 0 else { continue }
            named.append((name, Subnet(address: address, netmask: netmask)))
        }
        named.sort { a, b in
            // en0 (Wi-Fi) before everything else; otherwise keep enumeration order.
            (a.name == "en0" ? 0 : 1) < (b.name == "en0" ? 0 : 1)
        }
        var seen = Set<UInt32>()
        return named.compactMap { seen.insert($0.subnet.address & $0.subnet.netmask).inserted ? $0.subnet : nil }
    }

    // MARK: - Wire

    private static func performDiscovery(timeout: TimeInterval) throws -> [DiscoveryResult] {
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { throw DiscoveryError.socketCreationFailed }
        defer { close(sock) }

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

        let messageBytes = Array(discoveryMessage.utf8)
        func send(to hostOrderAddress: UInt32) -> Bool {
            var dest = sockaddr_in()
            dest.sin_family = sa_family_t(AF_INET)
            dest.sin_port = discoveryPort.bigEndian
            dest.sin_addr.s_addr = hostOrderAddress.bigEndian
            let sent = withUnsafePointer(to: &dest) { ptr -> Int in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(sock, messageBytes, messageBytes.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            return sent > 0
        }

        // The broadcast from protocol.md, kept because it costs nothing and reaches
        // a PC on a second subnet that a router happens to forward to. Its failure
        // is expected on a device without the multicast entitlement, so it is not
        // an error.
        var broadcastEnable: Int32 = 1
        var delivered = 0
        if setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, socklen_t(MemoryLayout<Int32>.size)) == 0,
           send(to: 0xFFFF_FFFF) {
            delivered += 1
        }

        let subnets = localSubnets()
        for subnet in subnets {
            for target in sweepTargets(for: subnet) where send(to: target) {
                delivered += 1
            }
        }
        if subnets.isEmpty && delivered == 0 { throw DiscoveryError.noLocalNetwork }
        guard delivered > 0 else { throw DiscoveryError.sendFailed }

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
