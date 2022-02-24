//
//  File: JUnitReporter.swift
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

public struct JUnitReporter: TestReporter {
    public static let id = "junit"

    public static func write(
        _ suite: TestReport.Suite,
        to url: URL,
        standardOutput: String,
        standardError: String
    ) async throws {
        let root = XMLElement(name: "testsuites")
        var processingSuites = [suite]

        while let suite = processingSuites.first {
            defer { processingSuites.removeFirst() }

            console.info("[junit] processing suite \(suite.name, .green) ...")
            processingSuites.append(contentsOf: suite.testSuites)

            guard !suite.testCases.isEmpty else { continue }

            let element = suite.asXMLElement

            if case .failed = suite.result {
                let systemOut = XMLElement(name: "system-out")
                let systemErr = XMLElement(name: "system-err")
                let systemOutCDATA = XMLElement(kind: .text, options: .nodeIsCDATA)
                let systemErrCDATA = XMLElement(kind: .text, options: .nodeIsCDATA)

                systemOutCDATA.stringValue = standardOutput
                systemErrCDATA.stringValue = standardError

                systemOut.addChild(systemOutCDATA)
                systemErr.addChild(systemErrCDATA)

                element.addChild(systemOut)
                element.addChild(systemErr)
            }

            root.addChild(element)
        }

        let document = XMLDocument(rootElement: root)
        document.version = "1.0"
        document.documentContentKind = .xml
        document.characterEncoding = "UTF-8"

        try document.xmlData(options: .nodePrettyPrint).write(to: url, options: .atomic)
    }
}

private extension TestReport.Suite {
    var asXMLElement: XMLElement {
        let element = XMLElement(name: "testsuite")
        let dateFormatter = DateFormatter()

        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        element.setAttributesWith([
            "name": name,
            "tests": "\(testCases.count)",
            "skipped": "0",
            "failures": "\(failedTestCases.count)",
            "errors": "0",
            "timestamp": dateFormatter.string(from: startDate),
            "time": "\(String(format: "%.3f", endDate.timeIntervalSince(startDate)))",
        ])

        element.addChild(XMLElement(name: "properties"))
        testCases.map(\.asXMLElement).forEach { element.addChild($0) }

        return element
    }
}

private extension TestReport.Case {
    var asXMLElement: XMLElement {
        let element = XMLElement(name: "testcase")
        element.setAttributesWith([
            "name": test,
            "classname": "\(module).\(`class`)",
            "time": "\(String(format: "%.3f", duration))",
        ])

        errors.forEach { element.addChild($0.asXMLElement) }

        return element
    }
}

private extension TestReport.Error {
    var asXMLElement: XMLElement {
        let element = XMLElement(name: "failure", stringValue: "at \(file):\(line)")
        element.setAttributesWith(["message": reason])

        return element
    }
}
