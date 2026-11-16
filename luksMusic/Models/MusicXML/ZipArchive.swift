// ZipArchive.swift
// luksMusic
//
// Reads the files of a ZIP archive held in memory, the container of compressed MusicXML (.mxl).

import Foundation
import Compression

/// Why a ZIP archive could not be read.
enum ZipArchiveError: LocalizedError {
    case corrupted
    case unsupported

    var errorDescription: String? {
        switch self {
        case .corrupted:
            return String(localized: "O arquivo compactado está danificado.")
        case .unsupported:
            return String(localized: "O arquivo compactado usa criptografia ou uma compressão que o app não lê.")
        }
    }
}

/// A ZIP archive: the central directory at its end lists the files, each stored as is or compressed with DEFLATE
/// (the two methods MusicXML allows). Every offset is checked against the data, so a damaged archive throws
/// instead of crashing, and every file is checked against the CRC-32 the archive recorded for it.
struct ZipArchive {

    /// A file in the archive, as the central directory describes it.
    struct Entry {
        let path: String
        /// 0 stored, 8 deflated
        let method: Int
        let flags: Int
        let crc32: UInt32
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    /// How a ZIP archive starts, with the header of its first file: "PK\u{3}\u{4}".
    static let signature: [UInt8] = [0x50, 0x4B, 0x03, 0x04]

    /// Far beyond any score; a bigger size is a damaged header, not a file worth the memory
    private static let maxFileSize = 128 << 20

    /// The files, in the order of the central directory.
    let entries: [Entry]
    private let bytes: [UInt8]

    init(data: Data) throws {
        let bytes = [UInt8](data)
        let directoryEnd = try Self.endOfCentralDirectory(in: bytes)
        let count = try Self.uint16(bytes, directoryEnd + 10)
        var offset = try Self.uint32(bytes, directoryEnd + 16)

        var entries: [Entry] = []
        for _ in 0..<count {
            guard try Self.uint32(bytes, offset) == 0x0201_4B50 else { throw ZipArchiveError.corrupted }
            let flags = try Self.uint16(bytes, offset + 8)
            let method = try Self.uint16(bytes, offset + 10)
            let crc32 = try Self.uint32(bytes, offset + 16)
            let compressedSize = try Self.uint32(bytes, offset + 20)
            let uncompressedSize = try Self.uint32(bytes, offset + 24)
            let nameLength = try Self.uint16(bytes, offset + 28)
            let extraLength = try Self.uint16(bytes, offset + 30)
            let commentLength = try Self.uint16(bytes, offset + 32)
            let localHeaderOffset = try Self.uint32(bytes, offset + 42)
            let nameStart = offset + 46
            guard nameStart + nameLength <= bytes.count else { throw ZipArchiveError.corrupted }

            entries.append(Entry(
                path: String(decoding: bytes[nameStart..<nameStart + nameLength], as: UTF8.self),
                method: method,
                flags: flags,
                crc32: UInt32(crc32),
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localHeaderOffset: localHeaderOffset
            ))
            offset = nameStart + nameLength + extraLength + commentLength
        }
        self.entries = entries
        self.bytes = bytes
    }

    /// The file at `path`, spelled as the archive stores it.
    func entry(atPath path: String) -> Entry? {
        entries.first { $0.path == path }
    }

    /// The file's bytes, inflated when deflated.
    func contents(of entry: Entry) throws -> Data {
        // Bit 0 marks an encrypted file
        guard (entry.flags & 1) == 0 else { throw ZipArchiveError.unsupported }
        let header = entry.localHeaderOffset
        guard try Self.uint32(bytes, header) == 0x0403_4B50 else { throw ZipArchiveError.corrupted }
        // The local header's name and extra field need not be as long as the central directory's
        let start = try header + 30 + Self.uint16(bytes, header + 26) + Self.uint16(bytes, header + 28)
        guard start + entry.compressedSize <= bytes.count else { throw ZipArchiveError.corrupted }
        let stored = Array(bytes[start..<start + entry.compressedSize])

        let file: [UInt8]
        switch entry.method {
        case 0:
            guard entry.compressedSize == entry.uncompressedSize else { throw ZipArchiveError.corrupted }
            file = stored
        case 8:
            file = try Self.inflate(stored, size: entry.uncompressedSize)
        default:
            throw ZipArchiveError.unsupported
        }
        guard Self.crc32(file) == entry.crc32 else { throw ZipArchiveError.corrupted }
        return Data(file)
    }

    // MARK: - Reading

    /// Where the end of central directory record starts: the last 22 bytes, or before a comment of up to 64 KB.
    private static func endOfCentralDirectory(in bytes: [UInt8]) throws -> Int {
        guard bytes.count >= 22 else { throw ZipArchiveError.corrupted }
        var offset = bytes.count - 22
        let lowest = max(0, offset - 0xFFFF)
        while offset >= lowest {
            if bytes[offset] == 0x50, bytes[offset + 1] == 0x4B, bytes[offset + 2] == 0x05, bytes[offset + 3] == 0x06 {
                return offset
            }
            offset -= 1
        }
        throw ZipArchiveError.corrupted
    }

    /// Raw DEFLATE (what `COMPRESSION_ZLIB` decodes, without a zlib header) into exactly `size` bytes.
    private static func inflate(_ deflated: [UInt8], size: Int) throws -> [UInt8] {
        guard size > 0 else { return [] }
        // DEFLATE shrinks data at most 1032 to 1
        guard !deflated.isEmpty, size <= min(maxFileSize, deflated.count * 1032) else { throw ZipArchiveError.corrupted }
        var inflated = [UInt8](repeating: 0, count: size)
        let written = deflated.withUnsafeBufferPointer { source in
            inflated.withUnsafeMutableBufferPointer { destination in
                compression_decode_buffer(destination.baseAddress!, size, source.baseAddress!, source.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written == size else { throw ZipArchiveError.corrupted }
        return inflated
    }

    private static func uint16(_ bytes: [UInt8], _ offset: Int) throws -> Int {
        guard offset >= 0, offset + 2 <= bytes.count else { throw ZipArchiveError.corrupted }
        return Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
    }

    private static func uint32(_ bytes: [UInt8], _ offset: Int) throws -> Int {
        guard offset >= 0, offset + 4 <= bytes.count else { throw ZipArchiveError.corrupted }
        return Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8) | (Int(bytes[offset + 2]) << 16) | (Int(bytes[offset + 3]) << 24)
    }

    // MARK: - CRC-32

    private static let crcTable: [UInt32] = (0..<256).map { index -> UInt32 in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = (value & 1) != 0 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1
        }
        return value
    }

    /// The CRC-32 ZIP records for each file (the polynomial of zlib and PNG).
    static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in bytes {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}
