//
//  File: SARIFReporter.swift
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
//  Created by Sayan Chaliha on 23/02/22.
//

import Foundation
import CryptoKit

public struct SARIFReporter: LintReporter {
    public static let id = "sarif"

    public static func write(report: SwiftLint.Report, to url: URL) async throws {
        let sarifReport = await SARIFReport(fromLintReport: report)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        try encoder.encode(sarifReport).write(to: url, options: .atomic)
    }
}

private struct SARIFReport: Encodable {
    let schema = "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json"
    let version = "2.1.0"
    let runs: [SARIFRun]

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case version
        case runs
    }
}

private struct SARIFRun: Encodable {
    let tool: SARIFTool
    let results: [SARIFResult]
    let originalURIBaseIDs: [String: SARIFURI]

    enum CodingKeys: String, CodingKey {
        case tool
        case results
        case originalURIBaseIDs = "originalUriBaseIds"
    }
}

private struct SARIFResult: Encodable {
    struct Message: Codable {
        let text: String
    }

    let ruleID: String
    let ruleIndex: Int
    let level: String
    let message: Message
    let locations: [SARIFLocation]

    enum CodingKeys: String, CodingKey {
        case ruleID = "ruleId"
        case ruleIndex
        case level
        case message
        case locations
    }
}

private struct SARIFURI: Codable {
    let uri: URL
}

private struct SARIFLocation: Encodable {
    struct Region: Codable {
        let startLine: UInt
        let startColumn: UInt
    }

    struct ArtifactLocation: Codable {
        let uriBaseID: String = "%SRCROOT%"
        let uri: String

        enum CodingKeys: String, CodingKey {
            case uriBaseID = "uriBaseId"
            case uri
        }
    }

    struct PhysicalLocation: Codable {
        let artifactLocation: ArtifactLocation
        let region: Region
    }

    let physicalLocation: PhysicalLocation
}

private struct SARIFTool: Encodable {
    let driver: SARIFDriver
}

private struct SARIFDriver: Encodable {
    let name = "SwiftLint (JustSwift)"
    let language = "en"
    let informationURI = "https://realm.github.io/SwiftLint/"
    let organization = "Realm"
    let version: String = "0.46.2"
    let semanticVersion: String = "0.46.2"
    let rules: [SARIFRule]

    enum CodingKeys: String, CodingKey {
        case name
        case language
        case informationURI = "informationUri"
        case organization
        case version
        case semanticVersion
        case rules
    }
}

private struct SARIFRule: Encodable {
    struct Description: Codable {
        let text: String
    }

    struct Properties: Codable {
        let tags: [String]
    }

    let id: String
    let name: String?
    let helpURI: String
    let shortDescription: Description
    let fullDescription: Description
    let properties: Properties

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case helpURI = "helpUri"
        case shortDescription
        case fullDescription
        case properties
    }
}

private extension SARIFReport {
    init(fromLintReport report: SwiftLint.Report) async {
        self.runs = [await .init(fromLintReport: report)]
    }
}

private extension SARIFRun {
    init(fromLintReport report: SwiftLint.Report) async {
        self.originalURIBaseIDs = ["%SRCROOT%": .init(uri: Project.rootDirectory)]
        self.tool = await .init(fromLintReport: report)
        let rules = self.tool.driver.rules
        self.results = await report.diagnostics.flatMapAsync { (_, diagnostics) in
            diagnostics.map { SARIFResult(fromDiagnostic: $0, rules: rules) }
        }
    }
}

private extension SARIFTool {
    init(fromLintReport report: SwiftLint.Report) async {
        self.driver = await .init(fromLintReport: report)
    }
}

private extension SARIFDriver {
    init(fromLintReport report: SwiftLint.Report) async {
        self.rules = await report.rules.mapAsync { .init(fromRule: $0) }
    }
}

private extension SARIFRule {
    init(fromRule rule: SwiftLint.Report.Rule) {
        self = .init(id: rule.id,
                     name: nil,
                     helpURI: rule.helpURI,
                     shortDescription: .init(text: rule.name),
                     fullDescription: .init(text: rule.description),
                     properties: .init(tags: [rule.kind.rawValue]))
    }
}

extension SARIFResult {
    init(fromDiagnostic diagnostic: SwiftLint.Report.Diagnostic, rules: [SARIFRule]) {
        self.ruleID = diagnostic.rule
        self.ruleIndex = rules.firstIndex(where: { diagnostic.rule == $0.id }) ?? -1
        self.level = diagnostic.kind.rawValue
        self.message = .init(text: diagnostic.reason)
        self.locations = [.init(fromDiagnostic: diagnostic)]
    }
}

extension SARIFLocation {
    init(fromDiagnostic diagnostic: SwiftLint.Report.Diagnostic) {
        let fileURI = diagnostic.fileURL.relativePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        self.physicalLocation = .init(artifactLocation: .init(uri: fileURI ?? ""),
                                      region: .init(startLine: diagnostic.line, startColumn: diagnostic.column))
    }
}
