// ZipArchiveTests.swift
// luksMusicTests
//
// The ZIP reader behind compressed MusicXML (.mxl), against two small archives in Fixtures: duet.mxl (every file
// deflated, with META-INF/container.xml) and stored.mxl (every file stored, without a container).

import XCTest
@testable import luksMusic

final class ZipArchiveTests: XCTestCase {

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: ZipArchiveTests.self).url(forResource: name, withExtension: "mxl"), name)
        return try Data(contentsOf: url)
    }

    func testDeflatedFilesInflate() throws {
        let archive = try ZipArchive(data: try fixture("duet"))
        XCTAssertEqual(archive.entries.map(\.path), ["META-INF/container.xml", "decoy.xml", "score/duet.musicxml"])
        XCTAssertEqual(archive.entries.map(\.method), [8, 8, 8])
        let decoy = try XCTUnwrap(archive.entry(atPath: "decoy.xml"))
        XCTAssertEqual(String(decoding: try archive.contents(of: decoy), as: UTF8.self), "<notes>not the score</notes>\n")
    }

    func testStoredFilesReadAsIs() throws {
        let archive = try ZipArchive(data: try fixture("stored"))
        XCTAssertEqual(archive.entries.map(\.path), ["META-INF/manifest.xml", "readme.txt", "piece.musicxml"])
        XCTAssertEqual(archive.entries.map(\.method), [0, 0, 0])
        let readme = try XCTUnwrap(archive.entry(atPath: "readme.txt"))
        XCTAssertEqual(readme.uncompressedSize, 24)
        XCTAssertEqual(String(decoding: try archive.contents(of: readme), as: UTF8.self), "Stored, not compressed.\n")
    }

    /// The check value of CRC-32: the digits 1 to 9.
    func testCRC32() {
        XCTAssertEqual(ZipArchive.crc32(Array("123456789".utf8)), 0xCBF4_3926)
        XCTAssertEqual(ZipArchive.crc32([]), 0)
    }

    /// The score is the file container.xml names, not the first XML file of the archive; without a container it is
    /// the first .musicxml or .xml outside META-INF.
    func testScoreFileOfAnMXL() throws {
        let named = String(decoding: try MusicXMLParser.scoreFile(inMXL: try fixture("duet")), as: UTF8.self)
        XCTAssertTrue(named.hasPrefix("<?xml"))
        XCTAssertTrue(named.contains("<work-title>Duet</work-title>"))
        let found = String(decoding: try MusicXMLParser.scoreFile(inMXL: try fixture("stored")), as: UTF8.self)
        XCTAssertTrue(found.contains("<work-title>Stored</work-title>"))
    }

    func testDamagedArchivesThrow() throws {
        XCTAssertThrowsError(try ZipArchive(data: Data()))
        XCTAssertThrowsError(try ZipArchive(data: Data("not a zip archive at all".utf8)))
        XCTAssertThrowsError(try MusicXMLParser.parse(data: Data("PK\u{3}\u{4} but nothing after".utf8)))

        let stored = try fixture("stored")
        // Without its last 22 bytes the archive loses the end of central directory record
        XCTAssertThrowsError(try ZipArchive(data: stored.prefix(stored.count - 22)))

        // A central directory said to start past the end of the data (offset field at 16 in that record)
        var farDirectory = stored
        let directoryEnd = stored.count - 22
        farDirectory.replaceSubrange(directoryEnd + 16..<directoryEnd + 20, with: [UInt8](repeating: 0xFF, count: 4))
        XCTAssertThrowsError(try ZipArchive(data: farDirectory))

        // One letter of a stored file changed: the central directory still reads, the file fails its CRC-32
        var changedLetter = stored
        let title = try XCTUnwrap(stored.range(of: Data("<work-title>Stored".utf8)))
        changedLetter[title.upperBound - 1] = UInt8(ascii: "x")
        let archive = try ZipArchive(data: changedLetter)
        let piece = try XCTUnwrap(archive.entry(atPath: "piece.musicxml"))
        XCTAssertThrowsError(try archive.contents(of: piece))
        XCTAssertThrowsError(try MusicXMLParser.parse(data: changedLetter))

        // The first file's method (field at 10 of its central directory header) set to 12, bzip2
        var bzip2 = stored
        let firstHeader = try XCTUnwrap(stored.range(of: Data([0x50, 0x4B, 0x01, 0x02]))).lowerBound
        bzip2[firstHeader + 10] = 12
        let unsupported = try ZipArchive(data: bzip2)
        XCTAssertEqual(unsupported.entries[0].method, 12)
        XCTAssertThrowsError(try unsupported.contents(of: unsupported.entries[0]))
    }

    /// Eight bytes in the middle of the deflated score overwritten: it no longer inflates to the recorded size and CRC.
    func testDamagedDeflateStreamThrows() throws {
        var duet = try fixture("duet")
        let entry = try XCTUnwrap(try ZipArchive(data: duet).entry(atPath: "score/duet.musicxml"))
        // Python's zipfile wrote no extra field in the local header, so the data follows the 30 bytes and the name
        let middle = entry.localHeaderOffset + 30 + entry.path.utf8.count + entry.compressedSize / 2
        duet.replaceSubrange(middle..<middle + 8, with: [UInt8](repeating: 0xFF, count: 8))
        let archive = try ZipArchive(data: duet)
        XCTAssertThrowsError(try archive.contents(of: entry))
        XCTAssertThrowsError(try MusicXMLParser.parse(data: duet))
    }
}
