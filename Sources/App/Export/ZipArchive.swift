import Foundation

/// Minimaler ZIP-Writer (unkomprimiert / "stored") – reicht für .xlsx-Dateien
/// und kommt ohne Fremdbibliotheken aus.
struct ZipArchive {
    private struct Entry {
        let name: Data
        let crc: UInt32
        let size: UInt32
        let offset: UInt32
    }

    private var body = Data()
    private var entries: [Entry] = []
    private let dosTime: UInt16
    private let dosDate: UInt16

    init(date: Date = .now) {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        dosTime = UInt16((c.hour ?? 0) << 11 | (c.minute ?? 0) << 5 | ((c.second ?? 0) / 2))
        dosDate = UInt16(max(0, (c.year ?? 1980) - 1980) << 9 | (c.month ?? 1) << 5 | (c.day ?? 1))
    }

    mutating func addFile(_ path: String, data: Data) {
        let name = Data(path.utf8)
        let crc = CRC32.checksum(data)
        let entry = Entry(name: name, crc: crc, size: UInt32(data.count), offset: UInt32(body.count))

        body.appendLE(UInt32(0x0403_4B50))   // Local file header
        body.appendLE(UInt16(20))            // Version needed
        body.appendLE(UInt16(0x0800))        // Flags: UTF-8-Namen
        body.appendLE(UInt16(0))             // Methode: stored
        body.appendLE(dosTime)
        body.appendLE(dosDate)
        body.appendLE(crc)
        body.appendLE(entry.size)            // komprimiert
        body.appendLE(entry.size)            // unkomprimiert
        body.appendLE(UInt16(name.count))
        body.appendLE(UInt16(0))             // Extra-Feld
        body.append(name)
        body.append(data)

        entries.append(entry)
    }

    func finalize() -> Data {
        var out = body
        let directoryOffset = UInt32(out.count)

        for e in entries {
            out.appendLE(UInt32(0x0201_4B50))  // Central directory header
            out.appendLE(UInt16(20))           // Version made by
            out.appendLE(UInt16(20))           // Version needed
            out.appendLE(UInt16(0x0800))
            out.appendLE(UInt16(0))
            out.appendLE(dosTime)
            out.appendLE(dosDate)
            out.appendLE(e.crc)
            out.appendLE(e.size)
            out.appendLE(e.size)
            out.appendLE(UInt16(e.name.count))
            out.appendLE(UInt16(0))            // Extra
            out.appendLE(UInt16(0))            // Kommentar
            out.appendLE(UInt16(0))            // Disk
            out.appendLE(UInt16(0))            // interne Attribute
            out.appendLE(UInt32(0))            // externe Attribute
            out.appendLE(e.offset)
            out.append(e.name)
        }

        let directorySize = UInt32(out.count) - directoryOffset
        out.appendLE(UInt32(0x0605_4B50))      // End of central directory
        out.appendLE(UInt16(0))
        out.appendLE(UInt16(0))
        out.appendLE(UInt16(entries.count))
        out.appendLE(UInt16(entries.count))
        out.appendLE(directorySize)
        out.appendLE(directoryOffset)
        out.appendLE(UInt16(0))
        return out
    }
}

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 {
            c = (c & 1) != 0 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1)
        }
        return c
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func appendLE(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func appendLE(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}
