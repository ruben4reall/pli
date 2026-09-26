// swift scripts/verify-update.swift <Info.plist> <appcast.xml> <version> <file.dmg>
//
// Checks what Sparkle checks before it installs an update: the appcast offers <version>, and <file.dmg> has that
// item's exact length and a valid EdDSA (Ed25519) signature under the public key in <Info.plist> (SUPublicEDKey).
// finish-release.sh runs it on the local image; publish.sh runs it on the published download.
import CryptoKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("verify-update: \(message)\n".utf8))
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count == 5 else { fail("usage: verify-update.swift <Info.plist> <appcast.xml> <version> <file.dmg>") }
let (plistPath, appcastPath, version, archivePath) = (arguments[1], arguments[2], arguments[3], arguments[4])

guard let plistData = FileManager.default.contents(atPath: plistPath),
      let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
      let keyString = plist["SUPublicEDKey"] as? String, let keyData = Data(base64Encoded: keyString),
      let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData)
else { fail("no valid SUPublicEDKey in \(plistPath)") }

guard let feed = try? XMLDocument(contentsOf: URL(fileURLWithPath: appcastPath), options: []) else { fail("cannot read \(appcastPath)") }
let items = ((try? feed.nodes(forXPath: "/rss/channel/item")) ?? []).compactMap { $0 as? XMLElement }
let offered = items.first { item in
    let element = item.elements(forName: "sparkle:version").first?.stringValue
    let attribute = item.elements(forName: "enclosure").first?.attribute(forName: "sparkle:version")?.stringValue
    return (element ?? attribute) == version
}
guard let offered, let enclosure = offered.elements(forName: "enclosure").first else { fail("\(appcastPath) offers no \(version)") }
guard let signatureString = enclosure.attribute(forName: "sparkle:edSignature")?.stringValue,
      let signature = Data(base64Encoded: signatureString) else { fail("the \(version) item has no EdDSA signature") }
guard let lengthString = enclosure.attribute(forName: "length")?.stringValue, let length = Int(lengthString) else {
    fail("the \(version) item has no length")
}
guard let archive = FileManager.default.contents(atPath: archivePath) else { fail("cannot read \(archivePath)") }
guard archive.count == length else { fail("\(archivePath) is \(archive.count) bytes, the appcast says \(length)") }
guard publicKey.isValidSignature(signature, for: archive) else { fail("the EdDSA signature does not match \(archivePath)") }
print("OK: \(version), \(length) bytes, signature valid, \(enclosure.attribute(forName: "url")?.stringValue ?? "no url")")
