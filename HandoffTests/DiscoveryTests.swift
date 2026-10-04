import Testing
@testable import Handoff

/// The unicast sweep replaced a broadcast that iOS drops on real devices. Its
/// enumeration is pure, so the properties that matter are pinned here: nothing
/// outside the subnet, never the iPad itself, neighbours first, and a hard cap so a
/// corporate /16 doesn't turn into 65,000 packets.
struct DiscoveryTests {
    private func ip(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ d: UInt32) -> UInt32 {
        (a << 24) | (b << 16) | (c << 8) | d
    }

    @Test func slash24SweepsEveryOtherHostExactlyOnce() {
        let subnet = DiscoveryService.Subnet(address: ip(192, 168, 1, 42), netmask: 0xFFFF_FF00)
        let targets = DiscoveryService.sweepTargets(for: subnet)
        #expect(targets.count == 253)
        #expect(Set(targets).count == 253)
        #expect(!targets.contains(ip(192, 168, 1, 42)))
        #expect(!targets.contains(ip(192, 168, 1, 0)))
        #expect(!targets.contains(ip(192, 168, 1, 255)))
        #expect(targets.allSatisfy { $0 & 0xFFFF_FF00 == ip(192, 168, 1, 0) })
    }

    @Test func neighboursComeFirst() {
        let subnet = DiscoveryService.Subnet(address: ip(10, 0, 0, 20), netmask: 0xFFFF_FF00)
        let targets = DiscoveryService.sweepTargets(for: subnet)
        #expect(Array(targets.prefix(4)) == [ip(10, 0, 0, 21), ip(10, 0, 0, 19), ip(10, 0, 0, 22), ip(10, 0, 0, 18)])
    }

    @Test func edgeOfSubnetStillCoversTheWholeRange() {
        let subnet = DiscoveryService.Subnet(address: ip(192, 168, 0, 1), netmask: 0xFFFF_FF00)
        let targets = DiscoveryService.sweepTargets(for: subnet)
        #expect(targets.count == 253)
        #expect(targets.first == ip(192, 168, 0, 2))
        #expect(targets.last == ip(192, 168, 0, 254))
    }

    @Test func largeSubnetIsCapped() {
        let subnet = DiscoveryService.Subnet(address: ip(10, 1, 7, 9), netmask: 0xFFFF_0000)
        let targets = DiscoveryService.sweepTargets(for: subnet)
        #expect(targets.count == DiscoveryService.sweepLimit)
        #expect(Set(targets).count == DiscoveryService.sweepLimit)
        #expect(!targets.contains(ip(10, 1, 7, 9)))
    }

    @Test func pointToPointSubnetsHaveNothingToSweep() {
        #expect(DiscoveryService.sweepTargets(for: .init(address: ip(10, 0, 0, 1), netmask: 0xFFFF_FFFF)).isEmpty)
        #expect(DiscoveryService.sweepTargets(for: .init(address: ip(10, 0, 0, 1), netmask: 0xFFFF_FFFE)).isEmpty)
        // A /30 has two usable hosts; the other one is the only target.
        #expect(DiscoveryService.sweepTargets(for: .init(address: ip(10, 0, 0, 1), netmask: 0xFFFF_FFFC)) == [ip(10, 0, 0, 2)])
    }
}
