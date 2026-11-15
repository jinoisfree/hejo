import Foundation

/// AT-HF-58/59 app side: find the airport without typing (local owner file first, then the owner's Tailscale Macs).
@MainActor func airportTests() async throws {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); defer { try? FileManager.default.removeItem(at: home) }
    try FileManager.default.createDirectory(at: home.appendingPathComponent("hejo"), withIntermediateDirectories: true)
    let file = home.appendingPathComponent("hejo/local-pair.json")
    try check(AirportFinder.localPair(home: home) == nil, "AT58 no local file")
    try Data(#"{"v":1,"port":47999,"code":"Ab-_cdEFgh12"}"#.utf8).write(to: file)
    try check(AirportFinder.localPair(home: home) == .init(port: 47999, code: "Ab-_cdEFgh12"), "AT58 local file parsed")
    try Data(#"{"v":1,"port":70000,"code":"short"}"#.utf8).write(to: file)
    try check(AirportFinder.localPair(home: home) == nil, "AT58 malformed local file ignored")
    let status = Data(#"{"Self":{"UserID":1},"Peer":{"a":{"Online":true,"OS":"iOS","HostName":"phone","TailscaleIPs":["100.64.0.3","fd7a::3"]},"b":{"Online":false,"OS":"macOS","HostName":"old","TailscaleIPs":["100.64.0.4"]},"c":{"Online":true,"OS":"macOS","HostName":"airport","TailscaleIPs":["fd7a::2","100.64.0.2"]}}}"#.utf8)
    try check(AirportFinder.peers(statusJSON: status) == ["100.64.0.2", "100.64.0.3"], "AT59 online peers, Macs first, IPv4 only")

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); defer { try? FileManager.default.removeItem(at: directory) }
    let client = GateClient(store: try LocalStore(directory: directory), credentials: MemoryCredentials())
    try Data(#"{"v":1,"port":47999,"code":"Ab-_cdEFgh12"}"#.utf8).write(to: file)
    var probed: [String] = []
    let local = await AirportFinder.connect(client, home: home, status: { probed.append("status"); return status }, reach: { probed.append($0); return true })
    try check(local, "AT58 local file connects")
    try check(client.store.settings.address == "127.0.0.1:47999" && probed.isEmpty, "AT58 local file wins without Tailscale probing")
    client.stop(); try FileManager.default.removeItem(at: file)
    let tail = await AirportFinder.connect(client, home: home, status: { status }, reach: { probed.append($0); return $0 == "100.64.0.3" })
    try check(tail, "AT59 reachable Tailscale peer connects")
    try check(probed == ["100.64.0.2", "100.64.0.3"] && client.store.settings.address == "100.64.0.3:47820", "AT59 probes in order and picks the gate")
    client.stop()
    let none = await AirportFinder.connect(client, home: home, status: { nil }, reach: { _ in true })
    try check(!none, "AT59 no Tailscale means not found")
    print("AT-HF-58 APP PASS"); print("AT-HF-59 APP PASS")
}
