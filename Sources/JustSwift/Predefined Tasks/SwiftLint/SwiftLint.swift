//
//  File: SwiftLint.swift
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

public struct SwiftLint {
    enum Error: Swift.Error {
        case invalidArgument(String)
    }

    public struct Options {
        public enum Mode {
            case lint
            case analyze
        }

        public let mode: Mode
        public let paths: [String]
        public let configurationFiles: [String]
        public let strict: Bool
        public let lenient: Bool
        public let enableAllRules: Bool
        public let autocorrect: Bool
        public let format: Bool
        public let forceExclude: Bool
        public let excludeByPrefix: Bool
        public let compilerLogPath: String?
        public let compileCommands: String?
        public let reporter: Reporter?
        public let reportFile: String?
    }

    public enum Reporter: String, CaseIterable {
        case xcode
        case json
        case csv
        case checkstyle
        case junit
        case html
        case emoji
        case sonarQube = "sonarqube"
        case markdown
        case gitHubActionsLogging = "github-actions-logging"
        case gitLabJUnit = "gitlab"
        case codeClimate = "codeclimate"
    }
}

extension SwiftLint {
    public static func run(_ options: Options) async throws -> Report {
        try options.validate()

        let config = Configuration(options: options)
        let storage = RuleStorage()

        switch options.mode {
        case .lint:
            switch options.autocorrect {
            case false:
                return try await lint(options: options, configuration: config, storage: storage)
            case true:
                return await autocorrect(options: options, configuration: config, storage: storage)
            }
        case .analyze:
            fatalError("SwiftLint: analyze not yet implemented.")
        }
    }

    private static func lint(
        options: Options,
        configuration config: Configuration,
        storage: RuleStorage
    ) async throws -> Report {
        let violations = await options.paths.flatMapAsync {
            config.lintableFiles(inPath: $0,
                                 forceExclude: options.forceExclude,
                                 excludeByPrefix: options.excludeByPrefix)
        }.flatMapAsync { file -> [StyleViolation] in
            let fileConfig = config.configuration(for: file)

            if let filePath = file.path {
                let fileURL = URL(fileURLWithPath: filePath)
                let shouldSkip = fileConfig.excludedPaths.contains { excludedPath in
                    let excludedURL = URL(fileURLWithPath: excludedPath)
                    return fileURL.pathComponents.starts(with: excludedURL.pathComponents)
                }

                if shouldSkip { return [] }
            }

            let linter = Linter(file: file, configuration: fileConfig)
            let collectedLinter = autoreleasepool { linter.collect(into: storage) }
            return collectedLinter.styleViolations(using: storage).map { $0.applyingLeniency(options: options) }
        }

        if let reporter = options.reporter, let reportFile = options.reportFile {
            let report = reporter.report(violations: violations)
            try report.write(toFile: reportFile, atomically: true, encoding: .utf8)
        }

        return Report(fromViolations: violations)
    }

    private static func autocorrect(
        options: Options,
        configuration config: Configuration,
        storage: RuleStorage
    ) async -> Report{
        let corrections = await options.paths.flatMapAsync {
            config.lintableFiles(inPath: $0,
                                 forceExclude: options.forceExclude,
                                 excludeByPrefix: options.excludeByPrefix)
        }.flatMapAsync { file -> [Correction] in
            let fileConfig = config.configuration(for: file)

            if let filePath = file.path {
                let fileURL = URL(fileURLWithPath: filePath)
                let shouldSkip = fileConfig.excludedPaths.contains { excludedPath in
                    let excludedURL = URL(fileURLWithPath: excludedPath)
                    return fileURL.pathComponents.starts(with: excludedURL.pathComponents)
                }

                if shouldSkip { return [] }
            }

            let linter = Linter(file: file, configuration: fileConfig)
            let collectedLinter = autoreleasepool { linter.collect(into: storage) }

            if options.format {
                switch fileConfig.indentation {
                case .tabs:
                    collectedLinter.format(useTabs: true, indentWidth: 4)
                case let .spaces(count: indent):
                    collectedLinter.format(useTabs: false, indentWidth: indent)
                }
            }

            return collectedLinter.correct(using: storage)
        }

        return Report(fromCorrections: corrections)
    }
}

extension SwiftLint.Options {
    func validate() throws {
        switch (lenient, strict) {
        case (true, true):
            throw SwiftLint.Error.invalidArgument("`strict` and `lenient` are mutually exclusive")
        default:
            break
        }
    }
}

extension SwiftLint.Options {
    public static func lint(
        configurationFileURLs: [URL],
        directoryURLs: [URL] = [Project.sourcesDirectory, Project.testsDirectory],
        strict: Bool = true,
        reporter: SwiftLint.Reporter? = nil,
        reportFile: String? = nil
    ) -> Self {
        .init(
            mode: .lint,
            paths: directoryURLs.map(\.path),
            configurationFiles: configurationFileURLs.map(\.path),
            strict: strict,
            lenient: false,
            enableAllRules: false,
            autocorrect: false,
            format: false,
            forceExclude: false,
            excludeByPrefix: false,
            compilerLogPath: nil,
            compileCommands: nil,
            reporter: reporter,
            reportFile: reportFile)
    }

    public static func format(
        configurationFileURLs: [URL],
        directoryURLs: [URL] = [Project.sourcesDirectory, Project.testsDirectory]
    ) -> Self {
        .init(
            mode: .lint,
            paths: directoryURLs.map(\.path),
            configurationFiles: configurationFileURLs.map(\.path),
            strict: true,
            lenient: false,
            enableAllRules: false,
            autocorrect: true,
            format: true,
            forceExclude: false,
            excludeByPrefix: false,
            compilerLogPath: nil,
            compileCommands: nil,
            reporter: nil,
            reportFile: nil)
    }
}

extension SwiftLint.Reporter: ExpressibleByArgument {
    public init?(_ value: String) {
        self.init(rawValue: value)
    }
}

extension SwiftLint.Reporter {
    public func report(violations: [SwiftLintFramework.StyleViolation]) -> String {
        SwiftLintFramework.reporterFrom(identifier: rawValue).report(violations: violations)
    }
}

extension SwiftLintFramework.Configuration {
    init(options: SwiftLint.Options) {
        self.init(
            configurationFiles: options.configurationFiles,
            enableAllRules: options.enableAllRules
        )
    }
}

extension SwiftLintFramework.StyleViolation {
    func applyingLeniency(options: SwiftLint.Options) -> Self {
        switch (options.lenient, options.strict) {
        case (false, false):
            return self
        case (true, false):
            return with(severity: .warning)
        case (false, true):
            return with(severity: .error)
        default:
            return self
        }
    }
}

extension SwiftLintFramework.Reporter {
    static func report(violations: [SwiftLintFramework.StyleViolation]) -> String {
        return generateReport(violations)
    }
}
