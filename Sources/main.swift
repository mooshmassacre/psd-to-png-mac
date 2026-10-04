// Copyright (c) 2026 Moosh Massacre — gustavo@mooshmassacre.studio
// SPDX-License-Identifier: MIT
import Foundation
import AppKit
import CZlib

struct Failure: Error, CustomStringConvertible { let description: String; init(_ s: String) { description = s } }
struct Reader {
    let data: Data
    var pos = 0
    mutating func bytes(_ n: Int) throws -> Data {
        guard n >= 0, n <= data.count - pos else { throw Failure("Truncated or invalid document.") }
        defer { pos += n }; return data.subdata(in: pos..<pos+n)
    }
    mutating func number(_ n: Int) throws -> Int {
        let b = try bytes(n); var v: UInt64 = 0
        for x in b { v = (v << 8) | UInt64(x) }
        guard v <= UInt64(Int.max) else { throw Failure("Document is too large.") }; return Int(v)
    }
    mutating func skip(_ n: Int) throws { guard n >= 0, n <= data.count-pos else { throw Failure("Invalid section length.") }; pos += n }
}
func be(_ value: Int, _ count: Int) -> Data { Data((0..<count).reversed().map { UInt8(truncatingIfNeeded: value >> ($0*8)) }) }
func deflate(_ data: Data) throws -> Data {
    var length = compressBound(uLong(data.count)); var output = Data(count: Int(length))
    let status = output.withUnsafeMutableBytes { dst in data.withUnsafeBytes { src in
        compress2(dst.bindMemory(to: Bytef.self).baseAddress!, &length, src.bindMemory(to: Bytef.self).baseAddress!, uLong(data.count), 6)
    } }
    guard status == Z_OK else { throw Failure("PNG compression failed.") }; output.count = Int(length); return output
}
func chunk(_ name: String, _ data: Data) -> Data {
    let payload = Data(name.utf8) + data
    let crc = payload.withUnsafeBytes { crc32(0, $0.bindMemory(to: Bytef.self).baseAddress!, uInt(payload.count)) }
    return be(data.count,4) + payload + be(Int(crc),4)
}
func convert(_ url: URL) throws -> Data {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    guard (attributes[.size] as? NSNumber)?.uint64Value ?? UInt64.max <= 2_147_483_648 else { throw Failure("Input exceeds the v1.0 2 GiB file limit.") }
    var r = Reader(data: try Data(contentsOf: url, options: .mappedIfSafe))
    guard try r.bytes(4) == Data("8BPS".utf8) else { throw Failure("Not a PSD/PSB document.") }
    let version = try r.number(2)
    guard version == 1 || version == 2 else { throw Failure("Unsupported document version.") }
    guard try r.bytes(6) == Data(repeating: 0, count: 6) else { throw Failure("Invalid reserved header bytes.") }
    let channels = try r.number(2), height = try r.number(4), width = try r.number(4)
    let depth = try r.number(2), mode = try r.number(2)
    guard width > 0, height > 0, width <= (version == 1 ? 30_000 : 300_000), height <= (version == 1 ? 30_000 : 300_000),
          depth == 8 || depth == 16, mode == 1 || mode == 3 else {
        throw Failure("v1.0 supports RGB and grayscale composites at 8 or 16 bits. CMYK, Lab, indexed and HDR documents are not supported.")
    }
    let colors = mode == 3 ? 3 : 1
    guard channels >= colors, channels <= 56 else { throw Failure("Invalid channel count.") }
    let rowSize = width * (depth / 8), plane = rowSize * height, total = plane * channels
    guard total <= 536_870_912 else { throw Failure("Decoded composite exceeds the v1.0 512 MiB limit.") }
    let colorLength = try r.number(4); try r.skip(colorLength)
    let resourceLength = try r.number(4)
    var resources = Reader(data: try r.bytes(resourceLength))
    var profile = Data(), hasComposite = true
    while resources.pos < resources.data.count {
        guard try resources.bytes(4) == Data("8BIM".utf8) else { throw Failure("Invalid image resource signature.") }
        let id = try resources.number(2), nameLength = try resources.number(1)
        try resources.skip(nameLength); if (nameLength + 1) % 2 != 0 { try resources.skip(1) }
        let length = try resources.number(4), value = try resources.bytes(length)
        if length % 2 != 0 { try resources.skip(1) }
        if id == 1039 { profile = value }
        if id == 1057 {
            guard value.count >= 5 else { throw Failure("Invalid version resource.") }
            hasComposite = value[4] != 0
        }
    }
    guard hasComposite else { throw Failure("No real merged composite is stored. Save with Maximize PSD and PSB File Compatibility enabled.") }
    let layerLength = try r.number(version == 2 ? 8 : 4)
    let layerStart = r.pos
    guard layerLength <= r.data.count - layerStart else { throw Failure("Invalid layer section.") }
    let layerEnd = layerStart + layerLength
    var hasAlpha = false
    if layerLength > 0 {
        let infoLength = try r.number(version == 2 ? 8 : 4)
        let infoStart = r.pos
        guard infoLength <= layerEnd-infoStart else { throw Failure("Invalid layer info.") }
        if infoLength >= 2 { hasAlpha = try r.number(2) >= 32768 }
        r.pos = infoStart; try r.skip(infoLength)
        if r.pos + 4 <= layerEnd && r.data.subdata(in: r.pos..<r.pos+4) != Data("8BIM".utf8) && r.data.subdata(in: r.pos..<r.pos+4) != Data("8B64".utf8) {
            let maskLength = try r.number(4)
            guard maskLength <= layerEnd-r.pos else { throw Failure("Invalid global mask.") }
            try r.skip(maskLength)
        }
        let largeKeys: Set<String> = ["LMsk","Lr16","Lr32","Layr","Mt16","Mt32","Mtrn","Alph","FMsk","lnk2","FEid","FXid","PxSD","lnk3","lnkE","FELS","pths","extn","extd","cinf","artd"]
        while r.pos+12 <= layerEnd {
            let signature = String(data: try r.bytes(4), encoding: .ascii)
            guard signature == "8BIM" || signature == "8B64" else { throw Failure("Invalid layer tag.") }
            let key = String(data: try r.bytes(4), encoding: .ascii) ?? ""
            let length = try r.number(version == 2 && largeKeys.contains(key) ? 8 : 4)
            let start = r.pos
            guard length <= layerEnd-start else { throw Failure("Invalid layer tag length.") }
            if ["Layr","Lr16","Lr32"].contains(key), length >= 2 { let negativeCount = try r.number(2) >= 32768; hasAlpha = hasAlpha || negativeCount }
            if key == (depth == 16 ? "Mt16" : "Mtrn") { hasAlpha = true }
            r.pos = start; try r.skip(length)
            // Global additional-layer blocks use four-byte padding.
            let padding = (4 - length % 4) % 4
            if padding <= layerEnd-r.pos { try r.skip(padding) }
        }
    }
    r.pos = layerEnd
    let compression = try r.number(2)
    var decoded = Data()
    switch compression {
    case 0: decoded = try r.bytes(total)
    case 1:
        var lengths: [Int] = []
        for _ in 0..<channels*height { lengths.append(try r.number(version == 2 ? 4 : 2)) }
        decoded.reserveCapacity(total)
        for length in lengths {
            var row = Reader(data: try r.bytes(length)); let start = decoded.count
            while row.pos < row.data.count {
                let control = try row.number(1)
                if control <= 127 { decoded.append(try row.bytes(control + 1)) }
                else if control >= 129 { let b = try row.number(1); decoded.append(Data(repeating: UInt8(b), count: 257-control)) }
                guard decoded.count-start <= rowSize else { throw Failure("Invalid RLE scanline.") }
            }
            guard decoded.count-start == rowSize else { throw Failure("Incomplete RLE scanline.") }
        }
    case 2, 3:
        let compressed = try r.bytes(r.data.count-r.pos); decoded = Data(count: total); var count = uLongf(total)
        let status = decoded.withUnsafeMutableBytes { dst in compressed.withUnsafeBytes { src in
            uncompress(dst.bindMemory(to: Bytef.self).baseAddress!, &count, src.bindMemory(to: Bytef.self).baseAddress!, uLong(compressed.count))
        } }
        guard status == Z_OK, count == total else { throw Failure("Invalid ZIP composite.") }
        if compression == 3 {
            for row in 0..<channels*height {
                let base = row*rowSize
                if depth == 8 {
                    for x in 1..<rowSize { decoded[base+x] = decoded[base+x] &+ decoded[base+x-1] }
                } else {
                    for x in 1..<width {
                        let i = base+x*2, previous = (Int(decoded[i-2])<<8)|Int(decoded[i-1])
                        let current = (Int(decoded[i])<<8)|Int(decoded[i+1]), sum = (previous+current)&65535
                        decoded[i] = UInt8(sum>>8); decoded[i+1] = UInt8(sum&255)
                    }
                }
            }
        }
    default: throw Failure("Unsupported composite compression.")
    }
    guard !hasAlpha || channels > colors else { throw Failure("Missing composite transparency channel.") }
    let outputChannels = colors + (hasAlpha ? 1 : 0), sampleBytes = depth/8
    var scanlines = Data(count: (width*outputChannels*sampleBytes+1)*height)
    decoded.withUnsafeBytes { sourceBuffer in
        scanlines.withUnsafeMutableBytes { outputBuffer in
            let src = sourceBuffer.bindMemory(to: UInt8.self), dst = outputBuffer.bindMemory(to: UInt8.self)
            let maxSample = depth == 8 ? 255 : 65535
            for y in 0..<height {
                var out = y*(width*outputChannels*sampleBytes+1)+1
                for x in 0..<width {
                    let pixel = y*rowSize+x*sampleBytes
                    let alphaOffset = colors*plane+pixel
                    let alpha = hasAlpha ? (depth == 8 ? Int(src[alphaOffset]) : Int(src[alphaOffset])*256+Int(src[alphaOffset+1])) : maxSample
                    for c in 0..<outputChannels {
                        let offset = c*plane+pixel
                        var sample = depth == 8 ? Int(src[offset]) : Int(src[offset])*256+Int(src[offset+1])
                        if hasAlpha && c < colors {
                            sample = alpha == 0 ? 0 : max(0, min(maxSample, ((sample+alpha-maxSample)*maxSample + alpha/2)/alpha))
                        }
                        if depth == 8 { dst[out] = UInt8(sample); out += 1 }
                        else { dst[out] = UInt8(sample>>8); dst[out+1] = UInt8(sample&255); out += 2 }
                    }
                }
            }
        }
    }
    let type = colors == 3 ? (hasAlpha ? 6 : 2) : (hasAlpha ? 4 : 0)
    var png = Data([137,80,78,71,13,10,26,10])
    png += chunk("IHDR", be(width,4)+be(height,4)+Data([UInt8(depth),UInt8(type),0,0,0]))
    if !profile.isEmpty { png += chunk("iCCP", Data("Document ICC".utf8)+Data([0,0])+(try deflate(profile))) }
    png += chunk("IDAT", try deflate(scanlines)); png += chunk("IEND", Data()); return png
}
func alert(_ title: String, _ message: String, _ buttons: [String]) -> Int {
    NSApplication.shared.setActivationPolicy(.accessory); NSApplication.shared.activate(ignoringOtherApps: true)
    let dialog = NSAlert(); dialog.messageText = title; dialog.informativeText = message
    for button in buttons { dialog.addButton(withTitle: button) }
    return dialog.runModal().rawValue - 1000
}
func save(_ png: Data, source: URL, choice: String?) throws -> URL? {
    let fm = FileManager.default, base = source.deletingPathExtension()
    var target = base.appendingPathExtension("png"), replace = false, copy = false
    if fm.fileExists(atPath: target.path) {
        let decision = choice ?? ["replace","copy","cancel"][alert("PSD to PNG", "\(target.lastPathComponent) already exists. Replace it?", ["Replace","Save a Copy","Cancel"])]
        if decision == "cancel" { return nil }; replace = decision == "replace"; copy = decision == "copy"
    }
    // Publish in the same directory. Exclusive links avoid clobbering a concurrent export.
    let temp = source.deletingLastPathComponent().appendingPathComponent(".psd-to-png-\(UUID().uuidString).tmp")
    try png.write(to: temp, options: .withoutOverwriting); defer { try? fm.removeItem(at: temp) }
    if replace {
        guard rename(temp.path, target.path) == 0 else { throw Failure("Could not replace destination: \(String(cString: strerror(errno))).") }
    } else {
        var index = 1
        while true {
            if copy { target = URL(fileURLWithPath: base.path + (index == 1 ? " copy" : " copy \(index)") + ".png") }
            if link(temp.path, target.path) == 0 { break }
            guard errno == EEXIST else { throw Failure("Could not save PNG: \(String(cString: strerror(errno))).") }
            if !copy { throw Failure("Destination appeared during conversion. Run again to choose Replace or Save a Copy.") }
            index += 1
        }
    }; return target
}
var args = Array(CommandLine.arguments.dropFirst()), choice: String? = nil
if args.first == "--register-services" { NSUpdateDynamicServices(); exit(0) }
if args.first == "--version" { print("PSD to PNG 1.0.0 — Moosh Massacre — gustavo@mooshmassacre.studio"); exit(0) }
if args.first == "--collision", args.count >= 2 {
    choice = args[1]; args.removeFirst(2)
    guard ["replace","copy","cancel"].contains(choice!) else { fputs("Invalid collision choice.\n",stderr); exit(2) }
}
if args.isEmpty { fputs("Usage: psd-to-png [--collision replace|copy|cancel] file.psd [file.psb ...]\n",stderr); exit(2) }
var failures: [String] = []
for path in args {
    autoreleasepool {
        do {
            let source = URL(fileURLWithPath: path).standardizedFileURL
            guard ["psd","psb"].contains(source.pathExtension.lowercased()) else { throw Failure("Select a .psd or .psb file.") }
            let png = try convert(source)
            if let output = try save(png, source: source, choice: choice) { print(output.path) }
        } catch { failures.append("\(URL(fileURLWithPath:path).lastPathComponent): \(error)") }
    }
}
if !failures.isEmpty {
    let text = failures.joined(separator: "\n\n"); fputs(text+"\n",stderr)
    if choice == nil { _ = alert("PSD to PNG — Conversion failed", text, ["OK"]) }; exit(1)
}
