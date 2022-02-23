//
//  File: Version.swift
//
//  MIT License
//
//  Copyright (c) 2022 Sayan Chaliha
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//
//
//  Created by Sayan Chaliha on 2022-02-19.
//

import Foundation

/// A version according to the semantic versioning specification.
public struct Version {
    /// The major version according to the semantic versioning standard.
    public let major: Int

    /// The minor version according to the semantic versioning standard.
    public let minor: Int

    /// The patch version according to the semantic versioning standard.
    public let patch: Int

    /// The pre-release identifier according to the semantic versioning standard, such as `-beta.1`.
    public let prereleaseIdentifiers: [String]

    /// The build metadata of this version according to the semantic versioning standard, such as a commit hash.
    public let buildMetadataIdentifiers: [String]

    /// Initializes a version struct with the provided components of a semantic version.
    ///
    /// - Parameters:
    ///   - major: The major version number.
    ///   - minor: The minor version number.
    ///   - patch: The patch version number.
    ///   - prereleaseIdentifiers: The pre-release identifier.
    ///   - buildMetaDataIdentifiers: Build metadata that identifies a build.
    ///
    /// - Precondition: `major >= 0 && minor >= 0 && patch >= 0`.
    /// - Precondition: `prereleaseIdentifiers` can conatin only ASCII alpha-numeric characters and "-".
    /// - Precondition: `buildMetaDataIdentifiers` can conatin only ASCII alpha-numeric characters and "-".
    public init(
        _ major: Int,
        _ minor: Int,
        _ patch: Int,
        prereleaseIdentifiers: [String] = [],
        buildMetadataIdentifiers: [String] = []
    ) {
        precondition(major >= 0 && minor >= 0 && patch >= 0, "Negative versioning is invalid.")
        precondition(
            prereleaseIdentifiers.allSatisfy {
                $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
            },
            #"Pre-release identifiers can contain only ASCII alpha-numeric characters and "-"."#
        )
        precondition(
            buildMetadataIdentifiers.allSatisfy {
                $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
            },
            #"Build metadata identifiers can contain only ASCII alpha-numeric characters and "-"."#
        )
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prereleaseIdentifiers = prereleaseIdentifiers
        self.buildMetadataIdentifiers = buildMetadataIdentifiers
    }
}

extension Version: Comparable {
    @inlinable
    public static func == (lhs: Version, rhs: Version) -> Bool {
        !(lhs < rhs) && !(lhs > rhs)
    }

    public static func < (lhs: Version, rhs: Version) -> Bool {
        let lhsComparators = [lhs.major, lhs.minor, lhs.patch]
        let rhsComparators = [rhs.major, rhs.minor, rhs.patch]

        if lhsComparators != rhsComparators {
            return lhsComparators.lexicographicallyPrecedes(rhsComparators)
        }

        guard !lhs.prereleaseIdentifiers.isEmpty else {
            return false // Non-prerelease lhs >= potentially prerelease rhs
        }

        guard !rhs.prereleaseIdentifiers.isEmpty else {
            return true // Prerelease lhs < non-prerelease rhs
        }

        for (lhsPrereleaseIdentifier, rhsPrereleaseIdentifier) in
            zip(lhs.prereleaseIdentifiers, rhs.prereleaseIdentifiers)
        {
            if lhsPrereleaseIdentifier == rhsPrereleaseIdentifier {
                continue
            }

            // Check if either of the 2 pre-release identifiers is numeric.
            let lhsNumericPrereleaseIdentifier = Int(lhsPrereleaseIdentifier)
            let rhsNumericPrereleaseIdentifier = Int(rhsPrereleaseIdentifier)

            if let lhsNumericPrereleaseIdentifier = lhsNumericPrereleaseIdentifier,
               let rhsNumericPrereleaseIdentifier = rhsNumericPrereleaseIdentifier
            {
                return lhsNumericPrereleaseIdentifier < rhsNumericPrereleaseIdentifier
            } else if lhsNumericPrereleaseIdentifier != nil {
                return true // numeric pre-release < non-numeric pre-release
            } else if rhsNumericPrereleaseIdentifier != nil {
                return false // non-numeric pre-release > numeric pre-release
            } else {
                return lhsPrereleaseIdentifier < rhsPrereleaseIdentifier
            }
        }

        return lhs.prereleaseIdentifiers.count < rhs.prereleaseIdentifiers.count
    }
}

extension Version: CustomStringConvertible {
    /// A textual description of the version object.
    public var description: String {
        var base = "\(major).\(minor).\(patch)"
        if !prereleaseIdentifiers.isEmpty {
            base += "-" + prereleaseIdentifiers.joined(separator: ".")
        }
        if !buildMetadataIdentifiers.isEmpty {
            base += "+" + buildMetadataIdentifiers.joined(separator: ".")
        }
        return base
    }
}

extension Version {
    /// Initializes a version struct from a semantic version string.
    ///
    /// - Parameter from: Semantic version string.
    public init?(parsing version: String) {
        // See: https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
        // swiftlint:disable:next line_length
        let pattern = #"(?<major>(0|[1-9]\d*))\.(?<minor>(0|[1-9]\d*))\.(?<patch>(0|[1-9]\d*))(?:-(?<prerelease>(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+(?<buildmetadata>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: version, options: [], range: NSRange(0 ..< version.count)),
              let majorRange = Range(match.range(withName: "major"), in: version),
              let minorRange = Range(match.range(withName: "minor"), in: version),
              let patchRange = Range(match.range(withName: "patch"), in: version),
              let major = Int(String(version[majorRange])),
              let minor = Int(String(version[minorRange])),
              let patch = Int(String(version[patchRange]))
        else {
            return nil
        }

        var prerelase = [String]()
        var buildMetadata = [String]()

        if let prereleaseRange = Range(match.range(withName: "prerelease"), in: version) {
            prerelase.append(contentsOf: version[prereleaseRange].components(separatedBy: "."))
        }

        if let buildMetadataRange = Range(match.range(withName: "buildmetadata"), in: version) {
            buildMetadata.append(contentsOf: version[buildMetadataRange].components(separatedBy: "."))
        }

        self.init(major, minor, patch, prereleaseIdentifiers: prerelase, buildMetadataIdentifiers: buildMetadata)
    }

    public func incrementingPatch(
        by increment: Int = 1,
        prereleaseIdentifiers: [String]? = nil,
        buildMetadataIdentifiers: [String]? = nil
    ) -> Version {
        Version(
            major,
            minor,
            patch + increment,
            prereleaseIdentifiers: prereleaseIdentifiers ?? [],
            buildMetadataIdentifiers: buildMetadataIdentifiers ?? [])
    }

    public func incrementingMinor(
        by increment: Int = 1,
        prereleaseIdentifiers: [String]? = nil,
        buildMetadataIdentifiers: [String]? = nil
    ) -> Version {
        Version(
            major,
            minor + increment,
            0,
            prereleaseIdentifiers: prereleaseIdentifiers ?? [],
            buildMetadataIdentifiers: buildMetadataIdentifiers ?? [])
    }

    public func incrementingMajor(
        by increment: Int = 1,
        prereleaseIdentifiers: [String]? = nil,
        buildMetadataIdentifiers: [String]? = nil
    ) -> Version {
        Version(
            major + increment,
            0,
            0,
            prereleaseIdentifiers: prereleaseIdentifiers ?? [],
            buildMetadataIdentifiers: buildMetadataIdentifiers ?? [])
    }

    public func removingIdentifiers() -> Version {
        Version(major, minor, patch)
    }
}

public actor Versions {
    private var _current: Version?
    private var _next: Version?

    public var current: Version {
        get async throws {
            if let current = _current {
                return current
            }

            let prerelease = try await Project.git.commitsSinceLastTag.isEmpty ? "" : "-dev"
            let version: String

            if let lastTag = try await Project.git.lastTag {
                version = "\(lastTag)\(prerelease)"
            } else {
                version = "0.0.1\(prerelease)"
            }

            let current = Version(parsing: version) ?? Version(0, 0, 1)
            _current = current

            return current
        }
    }

    public var next: Version {
        get async throws {
            if let next = _next {
                return next
            }

            let next: Version
            switch Bump.what(try await Project.git.commitsSinceLastTag) {
            case .major: next = try await current.incrementingMajor()
            case .minor: next = try await current.incrementingMinor()
            case .patch: next = try await current.incrementingPatch()
            case .none: next = try await current.removingIdentifiers()
            }
            _next = next

            return next
        }
    }
}
