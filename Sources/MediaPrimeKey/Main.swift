import AppKit

@main
enum MediaPrimeKeyApp {
    static func main() {
        if CommandLine.arguments.contains("--self-test") {
            SelfTest.run()
            return
        }

        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}

private enum SelfTest {
    static func run() {
        let cases: [(Int, MediaCommand?)] = [
            ((16 << 16) | (0x0A << 8), .playPause),
            ((17 << 16) | (0x0A << 8), .next),
            ((18 << 16) | (0x0A << 8), .previous),
            ((16 << 16) | (0x0B << 8), nil),
            ((16 << 16) | (0x0A << 8) | 1, nil),
            ((19 << 16) | (0x0A << 8), nil)
        ]

        for (data, expected) in cases {
            precondition(MediaKeyDecoder.command(fromData1: data) == expected)
        }

        precondition(MediaKeyDecoder.isManagedKey(data1: (16 << 16)))
        precondition(!MediaKeyDecoder.isManagedKey(data1: (0 << 16)))

        for player in MusicPlayer.allCases {
            precondition(!player.displayName.isEmpty)
            precondition(!player.bundleIdentifier.isEmpty)
            precondition(player.appleEvent(for: .playPause, startPlayback: true).eventID == 0x506C_6179)
            precondition(player.appleEvent(for: .next, startPlayback: false).eventID == 0x4E65_7874)
            precondition(player.appleEvent(for: .previous, startPlayback: false).eventID == 0x5072_6576)
        }

        var coldStartGate = ColdStartPlaybackGate()
        precondition(coldStartGate.begin(for: .spotify))
        precondition(coldStartGate.isPending(for: .spotify))
        precondition(!coldStartGate.begin(for: .spotify))
        precondition(coldStartGate.begin(for: .appleMusic))
        coldStartGate.end(for: .spotify)
        precondition(!coldStartGate.isPending(for: .spotify))
        precondition(coldStartGate.begin(for: .spotify))

        print("MediaPrimeKey self-test passed")
    }
}
