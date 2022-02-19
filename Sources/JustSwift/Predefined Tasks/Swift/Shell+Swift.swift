//
//  File: Shell+Swift.swift
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

extension Shell.Command {
    private static let swift = "swift"
    private static let llvmCov = "xcrun llvm-cov"

    public enum SwiftBuildConfiguration {
        case debug
        case release
    }

    public struct SwiftTestOptions: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let enableCoverage = SwiftTestOptions(rawValue: 1 << 0)
        public static let verbose = SwiftTestOptions(rawValue: 1 << 1)
        public static let showCodecovPath = SwiftTestOptions(rawValue: 1 << 2)
        public static let listTests = SwiftTestOptions(rawValue: 1 << 3)
    }

    public enum LLVMCovExportOutputFormat {
        case text
        case html
        case lcov
    }

    public static func buildSwiftPackage(
        withConfiguration config: SwiftBuildConfiguration = .debug,
        arguments: [String] = []
    ) -> Shell.Command {
        let args = ["build", "-c", "\(config)"]
        return Shell.Command(executable: swift, arguments: args)
    }

    public static func testSwiftPackage(
        withConfiguration config: SwiftBuildConfiguration = .debug,
        filter: String? = nil,
        options: SwiftTestOptions = []
    ) -> Shell.Command {
        var args = ["test", "-c", "\(config)"]

        if options.contains(.enableCoverage) {
            args.append("--enable-code-coverage")
        }

        if options.contains(.verbose) {
            args.append("--verbose")
        }

        if options.contains(.showCodecovPath) {
            args.append("--show-codecov-path")
        }

        if options.contains(.listTests) {
            args.append("--list-tests")
        }

        if let filter = filter {
            args.append(contentsOf: ["--filter", filter])
        }

        return Shell.Command(executable: swift, arguments: args)
    }

    public static func cleanSwiftPackage() -> Shell.Command {
        return Shell.Command(executable: swift, arguments: ["package", "clean"])
    }

    public static func llvmCovExport(
        instrumentationProfileURL: URL,
        outputFormat: LLVMCovExportOutputFormat,
        sourceDirectoryURL: URL = Project.sourcesDirectory,
        coveredExecutableURL: URL,
        ignoreFilenameRegex: String? = nil
    ) -> Shell.Command {
        var args = [
            "export",
            "--instr-profile=\(instrumentationProfileURL.path)",
            "--format=\(outputFormat)"
        ]

        if let ignoreFilenameRegex = ignoreFilenameRegex {
            args.append("--ignore-filename-regex=\"\(ignoreFilenameRegex)\"")
        }

        args.append(contentsOf: [coveredExecutableURL.path, sourceDirectoryURL.path])

        return Shell.Command(executable: llvmCov, arguments: args)
    }
}
