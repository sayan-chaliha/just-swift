//
//  File: SwiftLint+Report.swift
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
import SwiftLintFramework

extension SwiftLint {
    public struct Report: Codable {
        struct Diagnostic: Codable, Hashable {
            enum Kind: String, Codable, Equatable {
                case error
                case warning
                case correction
            }

            let fileURL: URL
            let line: UInt
            let column: UInt
            let kind: Kind
            let ruleDescription: String
            let reason: String
            let rule: String
        }

        let diagnostics: [URL: Set<Diagnostic>]
        let warnings: [Diagnostic]
        let errors: [Diagnostic]
        let corrections: [Diagnostic]
    }
}

extension SwiftLint.Report {
    init(fromViolations violations: [SwiftLintFramework.StyleViolation]) {
        let diagnostics = violations.compactMap { Diagnostic(fromViolation: $0) }
            .reduce(into: [URL: Set<Diagnostic>]()) { result, current in
                result[current.fileURL, default: Set()].update(with: current)
            }

        self.diagnostics = diagnostics
        self.warnings = diagnostics.flatMap(\.value).filter { $0.kind == .warning }
        self.errors = diagnostics.flatMap(\.value).filter { $0.kind == .error }
        self.corrections = []
    }

    init(fromCorrections corrections: [SwiftLintFramework.Correction]) {
        let diagnostics = corrections.compactMap { Diagnostic(fromCorrection: $0) }
            .reduce(into: [URL: Set<Diagnostic>]()) { result, current in
                result[current.fileURL, default: Set()].update(with: current)
            }

        self.diagnostics = diagnostics
        self.warnings = []
        self.errors = []
        self.corrections = diagnostics.flatMap(\.value)
    }
}

extension SwiftLint.Report.Diagnostic {
    init?(fromViolation violation: SwiftLintFramework.StyleViolation) {
        guard let relativePath = violation.location.relativeFile,
              let absolutePath = violation.location.file
        else {
            return nil
        }

        let line = violation.location.line ?? 1
        let col = violation.location.character ?? 1

        self = .init(
            fileURL: URL(
                fileURLWithPath: relativePath,
                relativeTo: URL(fileURLWithPath: String(absolutePath.dropLast(relativePath.count)))),
            line: UInt(line),
            column: UInt(col),
            kind: .init(fromViolationSeverity: violation.severity),
            ruleDescription: violation.ruleName,
            reason: violation.reason,
            rule: violation.ruleIdentifier)
    }

    init?(fromCorrection correction: SwiftLintFramework.Correction) {
        guard let relativePath = correction.location.relativeFile,
              let absolutePath = correction.location.file
        else {
            return nil
        }

        let line = correction.location.line ?? 1
        let col = correction.location.character ?? 1

        self = .init(
            fileURL: URL(
                fileURLWithPath: relativePath,
                relativeTo: URL(fileURLWithPath: String(absolutePath.dropLast(relativePath.count)))),
            line: UInt(line),
            column: UInt(col),
            kind: .correction,
            ruleDescription: correction.ruleDescription.name,
            reason: correction.consoleDescription,
            rule: correction.ruleDescription.identifier)
    }
}

extension SwiftLint.Report.Diagnostic.Kind {
    init(fromViolationSeverity severity: ViolationSeverity) {
        switch severity {
        case .warning:
            self = .warning
        case .error:
            self = .error
        }
    }
}
