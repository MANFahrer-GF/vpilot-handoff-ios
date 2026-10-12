import Foundation

/// Read-only client for the undocumented api.viffsys.com A-CDM backend — the same reverse
/// engineered service behind the EuroScope `rpuig2001/CDM` plugin and vats.im/vdgs, and the one
/// the Android client reads (upstream issue #143).
///
/// Reads need no key and no account. The write side (`/ifps/dpi`) is properly key-gated and this
/// client never touches it: setting a TOBT goes through the real VDGS website in `VdgsWebSheet`,
/// with the pilot's own VATSIM login.
///
/// Nothing here guarantees the shape stays stable — it is not a published API. Every call returns
/// nil on any failure (offline, non-2xx, unexpected JSON) rather than throwing, so a backend that
/// changes or disappears costs the tile and nothing else.
struct CdmClient {
    private let baseUrl = URL(string: "https://api.viffsys.com")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Every airport the backend knows, used to gate polling to the ones actually CDM-covered.
    func fetchCadAirports() async -> [CadAirport]? {
        await get("/etfms/getCadAirports")
    }

    /// Every currently-tracked flight departing `icao`; the caller finds its own callsign's row.
    /// The narrower `/ifps/callsign` endpoint exists but its response shape was never confirmed
    /// against a live flight, so this sticks to the one the upstream issue verified.
    func fetchDepartureAirportFlights(icao: String) async -> [CdmFlight]? {
        guard let encoded = icao.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        return await get("/ifps/depAirport?airport=\(encoded)")
    }

    private func get<T: Decodable>(_ path: String) async -> T? {
        guard let url = URL(string: path, relativeTo: baseUrl) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Handoff-iOS", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            return try? JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }
}
