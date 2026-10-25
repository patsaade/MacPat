// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation
import Security

/// Who signed a program, read with the Security framework. No process is started.
public struct Signature: Hashable, Sendable {
    public enum Kind: String, Sendable {
        case apple, appStore, developerID, otherSigned, adHoc, unsigned, missing
    }

    public let kind: Kind
    public let teamID: String?
    public let identifier: String?

    public init(kind: Kind, teamID: String? = nil, identifier: String? = nil) {
        self.kind = kind
        self.teamID = teamID
        self.identifier = identifier
    }

    public var summary: String {
        switch kind {
        case .apple: "Apple"
        case .appStore: "App Store" + (teamID.map { " (\($0))" } ?? "")
        case .developerID: "Developer ID" + (teamID.map { " (\($0))" } ?? "")
        case .otherSigned: "Signed, not by Developer ID" + (teamID.map { " (\($0))" } ?? "")
        case .adHoc: "Ad-hoc signed (no identity)"
        case .unsigned: "Unsigned"
        case .missing: "Program not found"
        }
    }
}

public enum Signing {
    // Requirements from Apple's code signing docs. 6.1.9 marks App Store, 6.1.13 marks Developer ID.
    static let apple = "anchor apple"
    static let appStore = "anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.9] exists"
    static let developerID =
        "anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"

    /// Classifies the signature. It checks the signing chain, not every resource hash,
    /// so it is fast and says who signed, not whether the bundle was altered since.
    public static func check(_ url: URL) -> Signature {
        guard FileManager.default.fileExists(atPath: url.path) else { return Signature(kind: .missing, teamID: nil, identifier: nil) }
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code else {
            return Signature(kind: .unsigned, teamID: nil, identifier: nil)
        }
        var info: CFDictionary?
        SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info)
        let dict = (info as? [String: Any]) ?? [:]
        let team = dict[kSecCodeInfoTeamIdentifier as String] as? String
        let ident = dict[kSecCodeInfoIdentifier as String] as? String
        guard ident != nil else { return Signature(kind: .unsigned, teamID: nil, identifier: nil) }
        let flags = (dict[kSecCodeInfoFlags as String] as? UInt32) ?? 0
        if flags & 0x2 != 0 { return Signature(kind: .adHoc, teamID: nil, identifier: ident) }  // kSecCodeSignatureAdhoc
        func meets(_ text: String) -> Bool {
            var req: SecRequirement?
            guard SecRequirementCreateWithString(text as CFString, [], &req) == errSecSuccess, let req else { return false }
            let quick = SecCSFlags(rawValue: kSecCSDoNotValidateResources | kSecCSDoNotValidateExecutable)
            return SecStaticCodeCheckValidity(code, quick, req) == errSecSuccess
        }
        let kind: Signature.Kind =
            meets(apple) ? .apple : meets(appStore) ? .appStore : meets(developerID) ? .developerID : .otherSigned
        return Signature(kind: kind, teamID: team, identifier: ident)
    }
}
