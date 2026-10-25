// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

import Foundation

public enum BundleName {
    /// `com.example.app.plist` → `com.example.app`. Strips the suffixes Library files add to a bundle ID.
    public static func base(_ name: String) -> String {
        name.replacingOccurrences(of: #"\.(plist|savedState|binarycookies)$"#, with: "", options: .regularExpression)
    }

    /// A bundle ID worth matching on: at least three parts, and not Apple's.
    public static func isSpecific(_ id: String) -> Bool {
        let lower = id.lowercased()
        return lower.split(separator: ".").count >= 3 && lower != "com.apple" && !lower.hasPrefix("com.apple.")
    }
}
