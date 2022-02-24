//
//  File: SwiftLintTask.swift
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

public struct SwiftLintTask: TaskProvider {
    enum Error: Swift.Error {
        case configFileNotFound
        case lintFailed
    }

    enum Reporter: String, CaseIterable, ExpressibleByArgument {
        case sarif

        init?(_ string: String) {
            self.init(rawValue: string)
        }
    }

    let werror: Bool

    public init(
        werror: Bool = true
    ) {
        self.werror = werror
    }

    public func callAsFunction(_ args: inout ArgumentBuilder) -> TaskFunction {
        let builtinConfigURL = Bundle.module.url(forResource: "swiftlint", withExtension: "yml")

        addOptions(to: &args)

        return { argv in
            let reporter: Reporter? = argv.reporter
            let reportFilePath: String? = argv["report-file"]
            let configFilePath: String? = argv.configuration
            let configFileURL: URL

            if let configFilePath = configFilePath {
                configFileURL = URL(fileURLWithPath: configFilePath)
            } else {
                guard let builtinConfigURL = builtinConfigURL else {
                    console.error("unable to determine path to built-in config file")
                    throw Error.configFileNotFound
                }

                configFileURL = builtinConfigURL
            }

            console.info("config file: \(configFileURL)")
            console.info("warnings \(!werror ? "not ": "")treated as errors")

            let report = try await SwiftLint.run(.lint(configurationFileURLs: [configFileURL], strict: werror))
            try SwiftLintTask.process(report: report)

            if let reporter = reporter, let reportFilePath = reportFilePath {
                switch reporter {
                case .sarif:
                    try await SARIFReporter.write(report: report, toPath: reportFilePath)
                }
            }

            guard report.errors.isEmpty else { throw Error.lintFailed }

            if werror {
                guard report.warnings.isEmpty else { throw Error.lintFailed }
            }
        }
    }

    private func addOptions(to args: inout ArgumentBuilder) {
        args
            .option(
                "configuration",
                alias: "c",
                type: String.self,
                help: "Path to SwiftLint configuration YAML (defaults to built-in YAML)")
            .flag(
                "werror",
                alias: "w",
                help: "Treat warnings as errors",
                default: werror)
            .option(
                "reporter",
                alias: "r",
                type: Reporter.self,
                help: "Format to write reports in; not using a reporter will disable report file generation")
            .option(
                "report-file",
                alias: "f",
                type: String.self,
                help: "File to write report to; not setting a value will disable report file generation")
    }

    private static func process(report: SwiftLint.Report) throws {
        guard !report.diagnostics.isEmpty else { return }

        report.diagnostics.forEach { (file, diagnostics) in
            console.info("File [\(file)]:")
            diagnostics.forEach { diagnostic in
                switch diagnostic.kind {
                case .error:
                    console.error("Error: \(diagnostic.ruleDescription, .red)", indent: 4)
                    console.error("Line: \(file.lastPathComponent):\(diagnostic.line):\(diagnostic.column)",
                                  indent: 8)
                    console.error("Reason: \(diagnostic.reason, .green)", indent: 8)
                    console.error("Rule: \(diagnostic.rule, .white)", indent: 8)
                case .warning:
                    console.warn("Warning: \(diagnostic.ruleDescription, .yellow)", indent: 4)
                    console.warn("Line: \(file.lastPathComponent):\(diagnostic.line):\(diagnostic.column)",
                                 indent: 8)
                    console.warn("Reason: \(diagnostic.reason, .green)", indent: 8)
                    console.warn("Rule: \(diagnostic.rule, .white)", indent: 8)
                case .correction:
                    break
                }
            }
        }
    }
}
