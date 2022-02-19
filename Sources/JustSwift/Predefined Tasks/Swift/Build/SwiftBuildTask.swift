//
//  File: SwiftBuildTask.swift
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

import Rainbow

public struct SwiftBuildTask: TaskProvider {

    enum Error: Swift.Error {
        case buildFailed
        case buildReportGenerationFailed
    }

    public enum BuildConfiguration: String, ExpressibleByArgument {
        case debug
        case release

        public init?(_ stringValue: String) {
            self.init(rawValue: stringValue)
        }

        var asSwiftBuildConfiguration: Shell.Command.SwiftBuildConfiguration {
            switch self {
            case .debug: return .debug
            case .release: return .release
            }
        }
    }

    private let werror: Bool
    private let buildConfiguration: BuildConfiguration

    public init(
        werror: Bool = true,
        buildConfiguration: BuildConfiguration = .debug
    ) {
        self.werror = werror
        self.buildConfiguration = buildConfiguration
    }

    public func callAsFunction(_ argumentBuilder: inout ArgumentBuilder) -> TaskFunction {
        argumentBuilder
            .flag("werror",
                  alias: "w",
                  help: "Treat warnings as errors",
                  default: werror)
            .option("config",
                    alias: "c",
                    type: BuildConfiguration.self,
                    help: "Build configuration",
                    default: buildConfiguration)

        return { argv in
            let werror: Bool = argv.werror ?? werror
            let buildConfiguration: BuildConfiguration = argv.config ?? buildConfiguration

            let output = Shell.execute(
                command: .buildSwiftPackage(withConfiguration: buildConfiguration.asSwiftBuildConfiguration)
            )

            let buildReport: BuildReport
            do {
                console.info("generating build report ...")
                buildReport = try await BuildReport(parsing: output.standardOutput)
            } catch {
                console.error("error generating build report: \(error)")
                throw Error.buildReportGenerationFailed
            }

            guard buildReport.errors.isEmpty else {
                console.error("build failed:")
                SwiftBuildTask.log(diagnosticsFrom: buildReport, keyPath: \.errors, error: true)

                throw Error.buildFailed
            }

            if !buildReport.warnings.isEmpty {
                console.warn("warnings:")
                SwiftBuildTask.log(diagnosticsFrom: buildReport, keyPath: \.warnings, error: false)
            }

            if werror {
                guard buildReport.warnings.isEmpty else {
                    console.error("warnings are errors")
                    throw Error.buildFailed
                }
            }
        }
    }

    private static func log(
        diagnosticsFrom buildReport: BuildReport,
        keyPath: KeyPath<BuildReport, [BuildReport.Diagnostic]>,
        error: Bool
    ) {
        let log = error ? console.error : console.warn
        let color: NamedColor = error ? .red : .yellow
        buildReport[keyPath: keyPath].forEach { diag in
            log("File: \(diag.fileURL):\("\(diag.line)", .yellow):\("\(diag.column)", .red)", 0)
            log("\(error ? "Error" : "Warning"): \(diag.message, color)", 4)
            let notes = buildReport.notes.filter { $0.line == diag.line && $0.column == diag.column }
            if !notes.isEmpty {
                log("Notes:", 4)
                notes.forEach { note in
                    log("\(note.message)", 8)
                }
            }
        }
    }
}
