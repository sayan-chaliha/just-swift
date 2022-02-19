//
//  File: BuildReport.swift
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
import Combine
import Rainbow

public struct BuildReport {

    public struct Diagnostic: Hashable {
        public enum Kind: String, Equatable {
            case note
            case warning
            case error
        }

        public let kind: Kind
        public let message: String
        public let fileURL: URL
        public let line: UInt
        public let column: UInt
    }

    public struct File {
        public var diagnostics: Set<Diagnostic> = Set()
    }

    public struct Module {
        public let name: String
        public var files: [String: File] = [:]
    }

    public let modules: [Module]
    public let warnings: [Diagnostic]
    public let errors: [Diagnostic]
    public let notes: [Diagnostic]
}

extension BuildReport {
    enum Error: Swift.Error {
        case badFormat
    }

    public init(parsing buildOutput: String) async throws {
        guard !buildOutput.isEmpty else { throw Error.badFormat }

        enum Artifact {
            case module(Module)
            case diagnostic(String, Diagnostic)
        }

        let modules = await buildOutput.components(separatedBy: .newlines)
            .compactMapAsync { string -> Artifact? in
                if let diagnostic = Diagnostic(parsing: string) {
                    let fileRelativePath = diagnostic.fileURL.relativePath
                    let moduleName = fileRelativePath[
                        fileRelativePath.startIndex ..< (fileRelativePath.firstIndex(of: "/") ??
                                                            fileRelativePath.endIndex)
                    ]

                    return .diagnostic(String(moduleName), diagnostic)
                }

                if let module = Module(parsing: string) {
                    return .module(module)
                }

                return nil
            }
            .reduce(into: [String: Module]()) { acc, cur in
                switch cur {
                case let .module(currentModule):
                    if var module = acc[currentModule.name] {
                        module.files.merge(currentModule.files, uniquingKeysWith: { first, _ in first })
                        acc[module.name] = module
                    } else {
                        acc[currentModule.name] = currentModule
                    }
                case let .diagnostic(module, diagnostic):
                    var file: File
                    if acc[module] == nil {
                        file = File(diagnostics: Set([diagnostic]))
                        acc[module] = Module(name: module)
                    } else if let existingFile = acc[module]?.files[diagnostic.fileURL.lastPathComponent] {
                        file = existingFile
                        file.diagnostics.update(with: diagnostic)
                    } else {
                        file = File(diagnostics: Set([diagnostic]))
                    }

                    acc[module]?.files[diagnostic.fileURL.lastPathComponent] = file
                }
            }

        self.modules = Array(modules.values)
        self.warnings = self.modules.flatMap(\.files).flatMap(\.value.diagnostics).filter { $0.kind == .warning }
        self.errors = self.modules.flatMap(\.files).flatMap(\.value.diagnostics).filter { $0.kind == .error }
        self.notes = self.modules.flatMap(\.files).flatMap(\.value.diagnostics).filter { $0.kind == .note }
    }
}

extension BuildReport.Module {
    public init?(parsing output: String) {
        let pattern = #"^\[[0-9]+/[0-9]+\] Compiling (?<module>.*) (?<file>.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            fatalError("BuildReport.Module: invalid regex pattern")
        }

        guard let match = regex.firstMatch(in: output, options: [], range: NSRange(0 ..< output.count)),
              let moduleRange = Range(match.range(withName: "module"), in: output),
              let fileRange = Range(match.range(withName: "file"), in: output)
        else {
            return nil
        }

        let file = BuildReport.File()
        var module = Self(name: String(output[moduleRange]))

        module.files[String(output[fileRange])] = file

        self = module
    }
}

extension BuildReport.Diagnostic {
    public init?(parsing output: String) {
        guard !output.isEmpty else { return nil }
        let pattern = #"^(?<file>.*):(?<line>[0-9]+):(?<column>[0-9]+): (?<kind>.*): (?<message>.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            fatalError("BuildReport.Diagnostic: invalid regex pattern")
        }

        guard let match = regex.firstMatch(in: output, options: [], range: NSRange(0 ..< output.count)),
              let fileRange = Range(match.range(withName: "file"), in: output),
              let lineRange = Range(match.range(withName: "line"), in: output),
              let line = UInt(String(output[lineRange])),
              let columnRange = Range(match.range(withName: "column"), in: output),
              let column = UInt(String(output[columnRange])),
              let kindRange = Range(match.range(withName: "kind"), in: output),
              let kind = Kind(rawValue: String(output[kindRange])),
              let messageRange = Range(match.range(withName: "message"), in: output)
        else {
            return nil
        }

        let filePath = String(output[fileRange])
        let fileURL: URL
        if filePath.starts(with: Project.sourcesDirectory.path) {
            fileURL = URL(
                fileURLWithPath: String(filePath.dropFirst(Project.sourcesDirectory.path.count + 1)),
                relativeTo: Project.sourcesDirectory)
        } else if filePath.starts(with: Project.testsDirectory.path) {
            fileURL = URL(
                fileURLWithPath: String(filePath.dropFirst(Project.testsDirectory.path.count + 1)),
                relativeTo: Project.testsDirectory)
        } else {
            console.warn("ignoring file `\(filePath.bold.white)` because it's not in sources root")
            return nil
        }

        self = .init(
            kind: kind,
            message: String(output[messageRange]),
            fileURL: fileURL,
            line: line,
            column: column
        )
    }
}
