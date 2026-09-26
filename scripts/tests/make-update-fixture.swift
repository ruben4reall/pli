// swift scripts/tests/make-update-fixture.swift <dir>: a fake release signed the way Sparkle signs one (Ed25519 over
// the whole file): <dir>/Info.plist (SUPublicEDKey), <dir>/Pli-1.0.0.dmg (4096 bytes of "A"), <dir>/appcast.xml.
import CryptoKit
import Foundation

let dir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
let key = Curve25519.Signing.PrivateKey()
let archive = Data(repeating: 0x41, count: 4096)
let signature = try key.signature(for: archive).base64EncodedString()
try archive.write(to: dir.appendingPathComponent("Pli-1.0.0.dmg"))
let plist: [String: Any] = ["SUPublicEDKey": key.publicKey.rawRepresentation.base64EncodedString()]
try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: dir.appendingPathComponent("Info.plist"))
let appcast = """
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Pli</title>
    <item>
      <title>1.0.0</title>
      <sparkle:version>1.0.0</sparkle:version>
      <sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>
      <enclosure url="https://github.com/ruben4reall/pli/releases/download/v1.0.0/Pli-1.0.0.dmg" length="\(archive.count)" type="application/octet-stream" sparkle:edSignature="\(signature)"/>
    </item>
  </channel>
</rss>
"""
try appcast.write(to: dir.appendingPathComponent("appcast.xml"), atomically: true, encoding: .utf8)
