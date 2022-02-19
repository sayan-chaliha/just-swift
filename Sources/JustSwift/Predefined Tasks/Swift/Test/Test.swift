//
//  File: Test.swift
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

public enum Test {
    public enum Result: String, Codable {
        case passed
        case failed
    }

    public struct Error: Swift.Error, Codable {
        let file: String
        let line: Int
        let reason: String
    }

    public struct Case: Codable {
        let module: String
        let `class`: String
        let test: String
        let duration: TimeInterval
        let result: Result
        let errors: [Error]
    }

    public struct Suite: Codable {
        let name: String
        let startDate: Date
        let endDate: Date
        let result: Result
        let testCases: [Case]
        let testSuites: [Suite]
    }
}

extension Test.Suite {
    class Builder {
        enum Error: Swift.Error {
            case illegalArgument(String)
        }

        private var name: String?
        private var startDate: Date?
        private var endDate: Date?
        private var result: Test.Result?
        private var testCases: [Test.Case] = []
        private var testSuites: [Test.Suite] = []

        @discardableResult
        func with(name: String) -> Self {
            self.name = name
            return self
        }

        @discardableResult
        func with(startDate: Date) -> Self {
            self.startDate = startDate
            return self
        }

        @discardableResult
        func with(endDate: Date) -> Self {
            self.endDate = endDate
            return self
        }

        @discardableResult
        func with(result: Test.Result) -> Self {
            self.result = result
            return self
        }

        @discardableResult
        func append(testCase: Test.Case) -> Self {
            testCases.append(testCase)
            return self
        }

        @discardableResult
        func append(testSuite: Test.Suite) -> Self {
            testSuites.append(testSuite)
            return self
        }

        func build() throws -> Test.Suite {
            guard let name = name else { throw Error.illegalArgument("name") }
            guard let startDate = startDate else { throw Error.illegalArgument("startDate") }
            guard let endDate = endDate else { throw Error.illegalArgument("endDate") }
            guard let result = result else { throw Error.illegalArgument("result") }

            return Test.Suite(
                name: name,
                startDate: startDate,
                endDate: endDate,
                result: result,
                testCases: testCases,
                testSuites: testSuites
            )
        }
    }
}

extension Test.Suite {
    enum Error: Swift.Error {
        case badFormat
        case badState
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public init(fromString content: String) throws {
        guard !content.isEmpty else { throw Error.badFormat }

        let testSuiteStartPattern = #"^Test Suite '(?<suiteName>.*)' started at (?<startDate>.*)$"#
        let testSuiteEndPattern = #"^Test Suite '(?<suiteName>.*)' (?<result>passed|failed) at (?<endDate>.*)\."#
        let testCaseStartPattern = #"^Test Case .* started.$"#
        // swiftlint:disable:next line_length
        let testCaseEndPattern = #"^Test Case '-\[(?<module>.*)\.(?<class>.*) (?<test>.*)\]' (?<result>passed|failed) \((?<duration>.*) seconds\)"#

        let testSuiteStartRegex = try NSRegularExpression(pattern: testSuiteStartPattern, options: [])
        let testSuiteEndRegex = try NSRegularExpression(pattern: testSuiteEndPattern, options: [])
        let testCaseStartRegex = try NSRegularExpression(pattern: testCaseStartPattern, options: [])
        let testCaseEndRegex = try NSRegularExpression(pattern: testCaseEndPattern, options: [])

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        dateFormatter.timeZone = TimeZone.current

        var rootSuiteBuilder: Test.Suite.Builder?
        var testSuiteBuilders = [Test.Suite.Builder]()

        var testCaseOutput = [String]()
        var gatherTestCaseOutput = false

        try content.components(separatedBy: .newlines).forEach { line in
            if let match = testSuiteStartRegex.firstMatch(in: line, options: [], range: NSRange(0 ..< line.count)) {
                guard let startDateRange = Range(match.range(withName: "startDate"), in: line),
                      let startDate = dateFormatter.date(from: String(line[startDateRange])),
                      let suiteNameRange = Range(match.range(withName: "suiteName"), in: line)
                else {
                    throw Error.badFormat
                }

                let builder = Test.Suite.Builder()
                testSuiteBuilders.append(builder)

                builder.with(name: String(line[suiteNameRange]))
                builder.with(startDate: startDate)

                if rootSuiteBuilder == nil { rootSuiteBuilder = builder }
            } else if let match = testSuiteEndRegex
                        .firstMatch(in: line, options: [], range: NSRange(0 ..< line.count)) {
                guard let resultRange = Range(match.range(withName: "result"), in: line),
                      let result = Test.Result(rawValue: String(line[resultRange])),
                      let endDateRange = Range(match.range(withName: "endDate"), in: line),
                      let endDate = dateFormatter.date(from: String(line[endDateRange])),
                      let suiteNameRange = Range(match.range(withName: "suiteName"), in: line)
                else {
                    throw Error.badFormat
                }

                let builder = testSuiteBuilders.removeLast()
                let parentSuite = testSuiteBuilders.last ?? rootSuiteBuilder

                builder.with(result: result)
                builder.with(endDate: endDate)

                let testSuite = try builder.build()
                guard testSuite.name == String(line[suiteNameRange]) else { throw Error.badState }

                if builder !== parentSuite { parentSuite?.append(testSuite: testSuite) }
            } else if testCaseStartRegex.firstMatch(in: line, options: [], range: NSRange(0 ..< line.count)) != nil {
                gatherTestCaseOutput = true
            } else if let match = testCaseEndRegex.firstMatch(in: line, options: [], range: NSRange(0 ..< line.count)) {
                guard let moduleRange = Range(match.range(withName: "module"), in: line),
                      let classRange = Range(match.range(withName: "class"), in: line),
                      let testRange = Range(match.range(withName: "test"), in: line),
                      let resultRange = Range(match.range(withName: "result"), in: line),
                      let result = Test.Result(rawValue: String(line[resultRange])),
                      let durationRange = Range(match.range(withName: "duration"), in: line),
                      let duration = Double(String(line[durationRange]))
                else {
                    throw Error.badFormat
                }

                guard let testSuiteBuilder = testSuiteBuilders.last else { throw Error.badState }

                defer {
                    testCaseOutput.removeAll()
                    gatherTestCaseOutput = false
                }

                let testCase = Test.Case(
                    module: String(line[moduleRange]),
                    class: String(line[classRange]),
                    test: String(line[testRange]),
                    duration: duration,
                    result: result,
                    errors: testCaseOutput.compactMap { Test.Error(fromString: $0) }
                )

                testSuiteBuilder.append(testCase: testCase)
            } else if gatherTestCaseOutput, !line.isEmpty {
                testCaseOutput.append(line)
            }
        }

        guard let suite = try rootSuiteBuilder?.build() else { throw Error.badFormat }
        self = suite
    }
}

extension Test.Error {
    public init?(fromString content: String) {
        let testCaseErrorPattern = #"^(?<file>.*):(?<line>.*): error: .* : (?<reason>.*)$"#
        guard let testCaseErrorRegex = try? NSRegularExpression(pattern: testCaseErrorPattern, options: []) else {
            return nil
        }

        guard let match = testCaseErrorRegex.firstMatch(in: content, options: [], range: NSRange(0 ..< content.count)),
              let fileRange = Range(match.range(withName: "file"), in: content),
              let lineRange = Range(match.range(withName: "line"), in: content),
              let line = Int(String(content[lineRange])),
              let reasonRange = Range(match.range(withName: "reason"), in: content)
        else {
            return nil
        }

        self = Test.Error(
            file: String(content[fileRange]),
            line: line,
            reason: String(content[reasonRange])
        )
    }
}

extension Test.Suite {
    var failedTestCases: [Test.Case] {
        var failedTestCases = testCases.filter { testCase in
            if case .failed = testCase.result {
                return true
            }
            return false
        }

        failedTestCases.append(contentsOf: testSuites.flatMap(\.failedTestCases))

        return failedTestCases
    }
}
