import Foundation

// ===================================================================
// NibNab Storage Test Harness
// Run with ./run-tests.sh — exercises the real StorageManager against a
// temp directory. No XCTest dependency; exit code 0 = all green.
// ===================================================================

@main
struct StorageTestsMain {
    static func main() async {
        let failures = await MainActor.run { StorageTests.runAll() }
        exit(failures == 0 ? 0 : 1)
    }
}

@MainActor
enum StorageTests {
    static var failures = 0
    static var checks = 0
    static let color = "Highlighter Yellow"

    static func expect(_ condition: Bool, _ label: String) {
        checks += 1
        if condition {
            print("  ✅ \(label)")
        } else {
            failures += 1
            print("  ❌ \(label)")
        }
    }

    static func utcDate(_ string: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.date(from: string)!
    }

    static func makeStorage() -> (StorageManager, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nibnab-tests-\(UUID().uuidString)", isDirectory: true)
        return (StorageManager(baseURLOverride: dir), dir)
    }

    static func clipFile(in dir: URL) -> URL {
        dir.appendingPathComponent(color.lowercased(), isDirectory: true)
            .appendingPathComponent("\(color.lowercased())_clips.md")
    }

    static func runAll() -> Int {
        print("🧪 NibNab storage tests")

        basicRoundTrip()
        dividerEscaping()
        orderingStability()
        legacyFormats()
        dateLikeAndMetadataLookalikeText()
        capAndDeletePersistence()
        urlRoundTrip()

        print(failures == 0
            ? "\n🎉 All \(checks) checks passed"
            : "\n💥 \(failures)/\(checks) checks FAILED")
        return failures
    }

    static func basicRoundTrip() {
        print("— basic round trip")
        let (storage, dir) = makeStorage()
        defer { try? FileManager.default.removeItem(at: dir) }

        let clips = [
            Clip(text: "plain text", timestamp: utcDate("2026-07-10 10:00:03"), url: nil, appName: "Safari"),
            Clip(text: "unicode 🎸 émojis\nsecond line\n\nblank line kept", timestamp: utcDate("2026-07-10 09:59:02"), url: nil, appName: "Notes"),
            Clip(text: "code: if x != y { return }", timestamp: utcDate("2026-07-10 09:58:01"), url: nil, appName: "Terminal")
        ]
        storage.rewriteClips(clips, for: color)
        let loaded = storage.loadClips(for: color)

        expect(loaded.count == 3, "count survives")
        expect(loaded.map(\.text) == clips.map(\.text), "text round-trips exactly (unicode, newlines, blanks)")
        expect(loaded.map(\.id) == clips.map(\.id), "ids survive")
        expect(loaded.map(\.appName) == clips.map(\.appName), "app names survive")
        expect(loaded.map(\.timestamp) == clips.map(\.timestamp), "second-precision timestamps survive")
    }

    static func dividerEscaping() {
        print("— divider escaping")
        let (storage, dir) = makeStorage()
        defer { try? FileManager.default.removeItem(at: dir) }

        let nasty = "intro\n---\nmiddle\n\\---\nalready escaped\n---\nend"
        let clips = [
            Clip(text: nasty, timestamp: utcDate("2026-07-10 10:00:00"), url: nil, appName: "Markdown"),
            Clip(text: "victim clip that must not shatter", timestamp: utcDate("2026-07-10 09:00:00"), url: nil, appName: "Notes")
        ]
        storage.rewriteClips(clips, for: color)

        // Two full cycles — rewrite what was loaded, load again.
        let cycle1 = storage.loadClips(for: color)
        storage.rewriteClips(cycle1, for: color)
        let cycle2 = storage.loadClips(for: color)

        expect(cycle1.count == 2 && cycle2.count == 2, "clip count stable across two cycles")
        expect(cycle1.first?.text == nasty, "--- lines round-trip (cycle 1)")
        expect(cycle2.first?.text == nasty, "--- lines round-trip (cycle 2, stacked escapes lossless)")
        expect(cycle2.last?.text == "victim clip that must not shatter", "neighboring clip untouched")
    }

    static func orderingStability() {
        print("— ordering")
        let (storage, dir) = makeStorage()
        defer { try? FileManager.default.removeItem(at: dir) }

        let sameSecond = utcDate("2026-07-10 12:00:00")
        let clips = (0..<5).map {
            Clip(text: "same-second \($0)", timestamp: sameSecond, url: nil, appName: "App")
        } + [Clip(text: "newest", timestamp: utcDate("2026-07-10 13:00:00"), url: nil, appName: "App")]
        // Written with "newest" last on purpose — the loader must sort it first.
        storage.rewriteClips(clips, for: color)

        let load1 = storage.loadClips(for: color)
        storage.rewriteClips(load1, for: color)
        let load2 = storage.loadClips(for: color)

        expect(load1.first?.text == "newest", "newest-first sort")
        expect(load1.map(\.text) == load2.map(\.text), "same-second clips keep stable order across launches")
    }

    static func legacyFormats() {
        print("— legacy formats")
        let (storage, dir) = makeStorage()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Minute-precision keyed timestamp (previous format) + bare-timestamp
        // Bangkok-era section (oldest format), hand-written like real old files.
        let legacy = """
        ### OldApp
        id: 11111111-2222-3333-4444-555555555555
        timestamp: 2024-01-01 11:11

        keyed minute-precision clip

        ---
        ### AncientApp
        2023-06-15 09:30 Bangkok

        bare-timestamp clip body
        """
        try! legacy.data(using: .utf8)!.write(to: clipFile(in: dir))

        let loaded = storage.loadClips(for: color)
        expect(loaded.count == 2, "both legacy sections parse")
        let keyed = loaded.first { $0.appName == "OldApp" }
        let bare = loaded.first { $0.appName == "AncientApp" }
        expect(keyed?.text == "keyed minute-precision clip", "keyed legacy text intact")
        expect(keyed?.timestamp == utcDate("2024-01-01 11:11:00"), "minute-precision timestamp parses")
        expect(keyed?.id == UUID(uuidString: "11111111-2222-3333-4444-555555555555"), "persisted id honored")
        expect(bare?.text == "bare-timestamp clip body", "bare-timestamp legacy text intact")
        expect(bare?.timestamp == utcDate("2023-06-15 09:30:00"), "Bangkok-suffix timestamp parses")

        // Re-save and reload: legacy content upgrades to current format losslessly.
        storage.rewriteClips(loaded, for: color)
        let upgraded = storage.loadClips(for: color)
        expect(upgraded.map(\.text).sorted() == loaded.map(\.text).sorted(), "legacy → current upgrade lossless")
    }

    static func dateLikeAndMetadataLookalikeText() {
        print("— hostile clip text")
        let (storage, dir) = makeStorage()
        defer { try? FileManager.default.removeItem(at: dir) }

        let dateLike = "2024-01-01 11:11\nrest of the clip"
        let metaLike = "id: not-a-real-id\ntimestamp: 9999-99-99 99:99\nactual content"
        let clips = [
            Clip(text: dateLike, timestamp: utcDate("2026-07-10 10:00:00"), url: nil, appName: "A"),
            Clip(text: metaLike, timestamp: utcDate("2026-07-10 09:00:00"), url: nil, appName: "B")
        ]
        storage.rewriteClips(clips, for: color)
        let loaded = storage.loadClips(for: color)

        expect(loaded.first?.text == dateLike, "date-like first line not swallowed as timestamp")
        expect(loaded.first?.timestamp == utcDate("2026-07-10 10:00:00"), "real timestamp wins over date-like text")
        expect(loaded.last?.text == metaLike, "id:/timestamp:-looking text lines preserved")
    }

    static func capAndDeletePersistence() {
        print("— cap + delete persistence")
        let (storage, dir) = makeStorage()
        defer { try? FileManager.default.removeItem(at: dir) }

        let many = (0..<120).map {
            Clip(text: "clip \($0)", timestamp: utcDate("2026-07-10 10:00:00").addingTimeInterval(Double($0)), url: nil, appName: "App")
        }.reversed()
        storage.rewriteClips(Array(many), for: color)
        let capped = storage.loadClips(for: color)
        expect(capped.count == 100, "100-clip cap enforced on disk")
        expect(capped.first?.text == "clip 119", "cap keeps the newest clips")

        // Delete = rewrite without the clip; must persist across reload.
        let afterDelete = capped.filter { $0.text != "clip 119" }
        storage.rewriteClips(afterDelete, for: color)
        let reloaded = storage.loadClips(for: color)
        expect(!reloaded.contains { $0.text == "clip 119" }, "deleted clip stays deleted after reload")

        storage.rewriteClips([], for: color)
        expect(!FileManager.default.fileExists(atPath: clipFile(in: dir).path), "empty rewrite removes the file")
        expect(storage.loadClips(for: color).isEmpty, "empty color loads as empty")
    }

    static func urlRoundTrip() {
        print("— url metadata")
        let (storage, dir) = makeStorage()
        defer { try? FileManager.default.removeItem(at: dir) }

        let clip = Clip(text: "linked clip", timestamp: utcDate("2026-07-10 10:00:00"), url: "https://nibnab.app/x?y=1", appName: "Safari")
        storage.rewriteClips([clip], for: color)
        let loaded = storage.loadClips(for: color)
        expect(loaded.first?.url == clip.url, "url survives round trip")
        expect(loaded.first?.appName == "Safari", "app name intact next to url")
    }
}
