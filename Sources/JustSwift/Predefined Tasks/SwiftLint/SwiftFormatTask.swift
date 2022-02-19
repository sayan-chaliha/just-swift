//
//  File: SwiftFormatTask.swift
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

public struct SwiftFormatTask: TaskProvider {
    enum Error: Swift.Error {
        case configFileNotFound
    }

    public init() {}

    public func callAsFunction(_ args: inout ArgumentBuilder) -> TaskFunction {
        let builtinConfigURL = Bundle.module.url(forResource: "swiftlint", withExtension: "yml")

        args
            .option(
                "configuration",
                alias: "c",
                type: String.self,
                help: "Path to SwiftLint configuration YAML (defaults to built-in YAML)")

        return { argv in
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

            let report = try await SwiftLint.run(.format(configurationFileURLs: [configFileURL]))
            try SwiftFormatTask.process(report: report)
        }
    }

    private static func process(report: SwiftLint.Report) throws {
        guard !report.corrections.isEmpty else { return }

        let changes = try Git.changes()
        var gitAddFiles: [String] = []

        report.diagnostics.forEach { (file, diagnostics) in
            console.info("File [\(file)]:")
            diagnostics.forEach { diagnostic in
                switch diagnostic.kind {
                case .error, .warning:
                    break
                case .correction:
                    console.info("Correction: \(diagnostic.ruleDescription, .cyan)", indent: 4)
                    console.info("Reason: \(diagnostic.reason, .green)", indent: 8)
                    console.info("Rule:   \(diagnostic.rule, .white)", indent: 8)

                    // Add changed files
                    changes.filter {
                        $0.fileURL == diagnostic.fileURL
                    }.forEach { change in
                        let staged = change.status.staged
                        switch staged {
                        case .added, .modified:
                            gitAddFiles.append(diagnostic.fileURL.path)
                        default:
                            break
                        }
                    }
                }
            }
        }

        guard !gitAddFiles.isEmpty else { return }
        try Git.add(filePaths: gitAddFiles)
    }
}
