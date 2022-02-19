//
//  File: SwiftTestTask.swift
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
import Rainbow

public struct SwiftTestTask: TaskProvider {

    enum Error: Swift.Error {
        case testFailed(String)
        case testsFailed
        case testReportGenerationFailed
        case coverageReportGenerationFailed
        case buildFailed
        case profdataNotFound(String)
        case coveredBinaryNotFound
        case coveredBinaryNotReadable(String)
        case coverageThresholdBroken
    }

    public enum CoverageReportFormat: String, CaseIterable, ExpressibleByArgument {
        case cobertura

        public init?(_ value: String) {
            self.init(rawValue: value)
        }
    }

    public enum TestReportFormat: String, CaseIterable, ExpressibleByArgument {
        case junit

        public init?(_ value: String) {
            self.init(rawValue: value)
        }
    }

    private static let testReporters: [TestReportFormat: TestReporter.Type] = [
        .junit: JUnitReporter.self
    ]

    private static let coverageReporters: [CoverageReportFormat: CoverageReporter.Type] = [
        .cobertura: CoberturaReporter.self
    ]

    private var testReportPath: String
    private var testReportFormat: TestReportFormat
    private var enableCoverage: Bool
    private var coverageThreshold: Double
    private var coverageReportFormat: CoverageReportFormat
    private var coverageReportIgnorePattern: String?
    private var coverageReportPath: String

    public init(
        testReportFormat: TestReportFormat = .junit,
        testReportPath: String = ".build/test.xml",
        enableCoverage: Bool = false,
        coverageThreshold: Double = 85.0,
        coverageReportFormat: CoverageReportFormat = .cobertura,
        coverageReportIgnorePattern: String? = nil,
        coverageReportPath: String = ".build/coverage.xml"
    ) {
        self.testReportFormat = testReportFormat
        self.testReportPath = testReportPath
        self.enableCoverage = enableCoverage
        self.coverageThreshold = coverageThreshold
        self.coverageReportFormat = coverageReportFormat
        self.coverageReportIgnorePattern = coverageReportIgnorePattern
        self.coverageReportPath = coverageReportPath
    }

    // swiftlint:disable:next function_body_length
    public func callAsFunction(_ argumentBuilder: inout ArgumentBuilder) -> TaskFunction {
        argumentBuilder
            .option(
                "test-report-format",
                type: TestReportFormat.self,
                help: "Format of the test report",
                default: testReportFormat)
            .option(
                "test-report-path",
                type: String.self,
                help: "Relative or absolute path to write test reports to",
                default: testReportPath)
            .flag(
                "coverage",
                inversionPrefix: .enableDisable,
                help: "Enable code coverage reporting",
                default: enableCoverage)
            .option(
                "coverage-threshold",
                type: Double.self,
                help: "Line coverage threshold; if coverage falls below this value the task will fail",
                default: coverageThreshold)
            .option(
                "coverage-report-format",
                type: CoverageReportFormat.self,
                help: "Format of the coverage report",
                default: coverageReportFormat)
            .option(
                "coverage-report-ignore-pattern",
                type: String.self,
                help: "File/directory patterns to ignore",
                default: coverageReportIgnorePattern ?? "<none>")
            .option(
                "coverage-report-path",
                type: String.self,
                help: "Relative or absolute path to write code coverage reports to",
                default: coverageReportPath)

        return { argv in
            let testReportFormat: TestReportFormat = argv["test-report-format"] ?? testReportFormat
            let testReportPath: String = argv["test-report-path"] ?? testReportPath
            let enableCoverage: Bool = argv.coverage ?? enableCoverage
            let coverageThreshold: Double = argv["coverage-threshold"] ?? coverageThreshold
            let coverageReportFormat: CoverageReportFormat = argv["coverage-report-format"] ?? coverageReportFormat
            let coverageReportIgnorePattern: String? = argv["coverage-report-ignore-pattern"]
                ?? coverageReportIgnorePattern
            let coverageReportPath: String = argv["coverage-report-path"] ?? coverageReportPath

            var options = Shell.Command.SwiftTestOptions()

            if argv.coverage ?? enableCoverage {
                options.insert(.enableCoverage)
            }

            let output = Shell.execute(command: .testSwiftPackage(options: options))

            try await SwiftTestTask.processTestReport(from: output,
                                                      format: testReportFormat,
                                                      path: testReportPath)

            if enableCoverage {
                try await SwiftTestTask.processCoverageReport(threshold: coverageThreshold,
                                                              format: coverageReportFormat,
                                                              path: coverageReportPath,
                                                              ignorePattern: coverageReportIgnorePattern)
            }
        }
    }

    private static func processTestReport(
        from output: Shell.Output,
        format: TestReportFormat,
        path: String
    ) async throws {
        guard !output.standardError.contains("error: fatalError") else {
            console.error("build failed:")
            console.error("\(output.standardOutput)", indent: 4)
            throw Error.buildFailed
        }

        let report: Test.Suite
        do {
            console.info("processing test report ...")
            report = try Test.Suite(fromString: output.standardError)
        } catch {
            console.error("test report generation failed: \(error)")
            throw Error.testReportGenerationFailed
        }

        if let reporter = testReporters[format] {
            console.info("writing test results to \(path.white.bold) ...")
            try await reporter.write(report,
                                     toPath: path,
                                     standardOutput: output.standardOutput,
                                     standardError: output.standardError)
        }

        guard case .passed = report.result else {
            console.error("tests failed:")
            report.failedTestCases.forEach { test in
                console.error("\(test.module, .green).\(test.class, .green) \(test.test, .green)", indent: 4)
                test.errors.forEach { error in
                    console.error("File: \(error.file, .white):\(String(describing: error.line), .yellow)", indent: 8)
                    console.error("Reason: \(error.reason, .red)", indent: 8)
                }
            }
            console.error("\("Standard Output:", .yellow)", indent: 4)
            console.error("\(output.standardOutput)", indent: 8)
            throw Error.testsFailed
        }
    }

    private static func processCoverageReport(
        threshold: Double,
        format: CoverageReportFormat,
        path: String,
        ignorePattern: String?
    ) async throws {
        console.info("processing coverage information ...")

        let (profdata, coveredBinary) = try findCoverageData()

        console.verbose("profdata: \(profdata)")
        console.verbose("covered binary: \(coveredBinary)")

        let output = Shell.execute(
            command: .llvmCovExport(
                instrumentationProfileURL: profdata,
                outputFormat: .text,
                sourceDirectoryURL: Project.sourcesDirectory,
                coveredExecutableURL: coveredBinary,
                ignoreFilenameRegex: ignorePattern
            )
        )

        guard output.terminationStatus == 0 else {
            console.error("llvm-cov exited with error: \(output.standardError)")
            throw Error.coverageReportGenerationFailed
        }

        let coverageReport: CoverageReport
        do {
            coverageReport = try CoverageReport(fromJSON: output.standardOutput)
        } catch {
            console.error("coverage report generation failed: \(error)")
            throw Error.coverageReportGenerationFailed
        }

        try await SwiftTestTask.coverageReporters[format]?
            .write(coverageReport, toPath: path, sourcesDirectoryPath: Project.sourcesDirectory.path)

        if let linesCoveredPercent = coverageReport.data.last?.totals.lines.percent {
            console.info("line coverage: \(String(describing: linesCoveredPercent).green.bold)%")
            console.info("threshold: \(String(describing: threshold).yellow.bold)%")

            guard linesCoveredPercent >= threshold else {
                console.error("coverage is lower than threshold")
                throw Error.coverageThresholdBroken
            }
        }
    }

    private static func findCoverageData() throws -> (profdataURL: URL, xctestURL: URL) {
        let output = Shell.execute(command: .testSwiftPackage(options: .showCodecovPath))
        let codecovDirectory = URL(fileURLWithPath: output.standardOutput, isDirectory: false)
            .standardizedFileURL
            .deletingLastPathComponent()
        let profdata = codecovDirectory.appendingPathComponent("default.profdata")

        guard FileManager.default.isReadableFile(atPath: profdata.path) else {
            console.error("profdata not readable: \(profdata)")
            throw Error.profdataNotFound(profdata.path)
        }

        let xctestDirectory = codecovDirectory.appendingPathComponent("..", isDirectory: true).standardizedFileURL
        let xctestFile: String?
        do {
            xctestFile = try FileManager.default.contentsOfDirectory(atPath: xctestDirectory.path)
                .first(where: { $0.hasSuffix("xctest") })
        } catch {
            console.error("xctest not found: \(error)")
            throw Error.coveredBinaryNotFound
        }

        guard let xctestFile = xctestFile else {
            console.error("xctest not found")
            throw Error.coveredBinaryNotFound
        }

        let packageName = xctestFile.replacingOccurrences(of: ".xctest", with: "")
        let coveredBinary = xctestDirectory
            .appendingPathComponent(xctestFile)
            .appendingPathComponent("Contents")
            .appendingPathComponent("MacOS")
            .appendingPathComponent(packageName)

        guard FileManager.default.isReadableFile(atPath: coveredBinary.path) else {
            console.error("covered binary not readable: \(coveredBinary.path.green)")
            throw Error.coveredBinaryNotReadable(coveredBinary.path)
        }

        return (profdata, coveredBinary)
    }
}
