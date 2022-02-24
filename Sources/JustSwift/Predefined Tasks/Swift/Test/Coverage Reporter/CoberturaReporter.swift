//
//  File: CoberturaReporter.swift
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

public struct CoberturaReporter: CoverageReporter {
    enum Error: Swift.Error {
        case coverageDataMissing
    }

    private static let version = "2.0.3"
    private static let dtdSystemID = "http://cobertura.sourceforge.net/xml/coverage-04.dtd"

    public static let id = "cobertura"

    public static func write(_ report: CoverageReport, to url: URL, sourcesDirectory: URL) async throws {
        guard let data = report.data.first else {
            console.error("no coverage data in report")
            throw Error.coverageDataMissing
        }

        let classes = await withTaskGroup(of: Class?.self, returning: [String: Class].self) { taskGroup in
            data.files.forEach { file in
                taskGroup.addTask { process(file: file, sourcesDirectory: sourcesDirectory) }
            }

            var classes = [String: Class]()
            for await classObject in taskGroup {
                guard let classObject = classObject else { continue }
                classes[classObject.filename.path] = classObject
            }

            return classes
        }

        var packages = [String: Package]()
        classes.values.forEach { classObject in
            let packageName = classObject.filename
                .deletingLastPathComponent()
                .relativePath
                .replacingOccurrences(of: "/", with: ".")
            let package = packages[packageName] ?? Package(name: packageName)
            package.classes.append(classObject)
            packages[packageName] = package
        }

        await withTaskGroup(of: Method.self) { taskGroup in
            data.functions.forEach { function in
                taskGroup.addTask { process(function: function) }
            }

            for await method in taskGroup {
                classes.filter { (file, _) in method.filenames.contains(file) }
                    .forEach { $0.value.methods.append(method) }
            }
        }

        try write(data: data, packages: Array(packages.values), sourcesDirectory: sourcesDirectory, to: url)
    }

    private static func process(file: CoverageReport.File, sourcesDirectory: URL) -> Class? {
        guard file.filename.hasPrefix(sourcesDirectory.path) else {
            console.warn("file is not in sources directory: ")
            console.warn("Sources Directory: \(sourcesDirectory)", indent: 4)
            console.warn("File: \(file.filename, .white)", indent: 4)
            return nil
        }

        let fileURL = URL(
            fileURLWithPath: String(file.filename.dropFirst(sourcesDirectory.path.count + 1)),
            relativeTo: sourcesDirectory
        )
        let className = fileURL.deletingPathExtension().lastPathComponent
        let lines = file.segments.compactMap { segment -> Line? in
            guard segment.hasCount else { return nil }
            return Line(
                branch: false,
                hits: segment.count,
                number: segment.line
            )
        }

        let branchesCovered = Double(file.summary.branches.covered)
        let branchCount = Double(file.summary.branches.count)
        let linesCovered = Double(file.summary.lines.covered)
        let lineCount = Double(file.summary.lines.count)

        let branchRate = branchCount > 0 ? branchesCovered / branchCount : 0.0
        let lineRate = lineCount > 0 ? linesCovered / lineCount : 0.0

        return Class(
            name: className,
            filename: fileURL,
            branchRate: branchRate,
            complexity: 0.0,
            lineRate: lineRate,
            lines: lines
        )
    }

    private static func process(function: CoverageReport.Function) -> Method {
        let functionName: String
        let signature: String

        if let demangledName = Demangler.demangle(symbol: function.name) {
            functionName = demangledName
            signature = function.name
        } else {
            console.warn("unable to demangle name: \(function.name.yellow.bold)")
            functionName = function.name
            signature = ""
        }

        let lines = function.regions.map { Line(branch: false, hits: $0.count, number: $0.lineStart) }
        let linesCovered = lines.map { $0.hits > 0 }
            .reduce(into: 0) { result, current in
                if current {
                    result += 1
                }
            }
        let lineRate = lines.isEmpty ? 0.0 : Double(linesCovered) / Double(lines.count)

        // Branches are not reported by llvm-cov for Swift yet, so don't know how to compute!
        let branchRate = lineRate

        return .init(
            name: functionName,
            signature: signature,
            branchRate: branchRate,
            lineRate: lineRate,
            lines: lines,
            filenames: function.filenames
        )
    }

    private static func write(
        data: CoverageReport.Data,
        packages pkgs: [Package],
        sourcesDirectory: URL, to url: URL
    ) throws {
        let coverage = XMLElement(name: "coverage")
        let sources = XMLElement(name: "sources")
        let source = XMLElement(name: "source")
        let packages = XMLElement(name: "packages")

        source.stringValue = sourcesDirectory.path
        sources.addChild(source)
        coverage.addChild(sources)

        pkgs.map(\.asXMLElement).forEach { packages.addChild($0) }
        coverage.addChild(packages)

        let branchesCovered = data.totals.branches.covered
        let branchCount = data.totals.branches.count
        let branchRate = branchCount > 0 ? Double(branchesCovered) / Double(branchCount) : 0.0

        let linesCovered = data.totals.lines.covered
        let lineCount = data.totals.lines.count
        let lineRate = lineCount > 0 ? Double(linesCovered) / Double(lineCount) : 0.0

        coverage.setAttributesWith([
            "branch-rate": String(describing: branchRate),
            "branches-covered": String(describing: branchesCovered),
            "branches-valid": String(describing: branchCount),
            "line-rate": String(describing: lineRate),
            "lines-covered": String(describing: linesCovered),
            "lines-valid": String(describing: lineCount),
            "complexity": "0.0",
            "timestamp": String(describing: Int64(Date().timeIntervalSince1970)),
            "version": CoberturaReporter.version
        ])

        let dtd = XMLDTD()
        dtd.name = "coverage"
        dtd.systemID = CoberturaReporter.dtdSystemID

        let document = XMLDocument(rootElement: coverage)
        document.version = "1.0"
        document.documentContentKind = .xml
        document.characterEncoding = "UTF-8"
        document.dtd = dtd

        console.info("writing cobertura report to \(url.path.yellow.bold) ...")
        try document.xmlData(options: .nodePrettyPrint).write(to: url, options: .atomic)
    }
}

extension CoberturaReporter {
    private class Package {
        let name: String
        var complexity: Double = 0
        var classes: [Class] = []

        var branchRate: Double {
            guard !classes.isEmpty else { return 0.0 }
            let total = classes.map(\.branchRate).reduce(into: 0.0) { res, cur in res += cur }
            return total / Double(classes.count)
        }

        var lineRate: Double {
            guard !classes.isEmpty else { return 0.0 }
            let total = classes.map(\.lineRate).reduce(into: 0.0) { res, cur in res += cur }
            return total / Double(classes.count)
        }

        var asXMLElement: XMLElement {
            let element = XMLElement(name: "package")
            element.setAttributesWith([
                "name": name,
                "branch-rate": String(describing: branchRate),
                "complexity": String(describing: complexity),
                "line-rate": String(describing: lineRate)
            ])
            let classesElement = XMLElement(name: "classes")
            classes.map(\.asXMLElement).forEach { classesElement.addChild($0) }
            element.addChild(classesElement)

            return element
        }

        init(name: String) {
            self.name = name
        }
    }

    private class Class {
        let name: String
        let filename: URL
        let branchRate: Double
        let complexity: Double
        let lineRate: Double
        var methods: [Method] = []
        var lines: [Line]

        var asXMLElement: XMLElement {
            let element = XMLElement(name: "class")
            element.setAttributesWith([
                "name": name,
                "filename": filename.relativePath,
                "branch-rate": String(describing: branchRate),
                "line-rate": String(describing: lineRate),
                "complexity": String(describing: complexity)
            ])

            let methodsElement = XMLElement(name: "methods")
            methods.map(\.asXMLElement).forEach { methodsElement.addChild($0) }
            element.addChild(methodsElement)

            let linesElement = XMLElement(name: "lines")
            lines.map(\.asXMLElement).forEach { linesElement.addChild($0) }
            element.addChild(linesElement)

            return element
        }

        init(name: String, filename: URL, branchRate: Double, complexity: Double, lineRate: Double, lines: [Line]) {
            self.name = name
            self.filename = filename
            self.branchRate = branchRate
            self.complexity = complexity
            self.lineRate = lineRate
            self.lines = lines
        }
    }

    private struct Method {
        let name: String
        let signature: String
        let branchRate: Double
        let lineRate: Double
        let lines: [Line]
        let filenames: [String]

        var asXMLElement: XMLElement {
            let element = XMLElement(name: "method")
            element.setAttributesWith([
                "name": name,
                "branch-rate": String(describing: branchRate),
                "line-rate": String(describing: lineRate),
                "signature": signature
            ])

            let linesElement = XMLElement(name: "lines")
            lines.map(\.asXMLElement).forEach { linesElement.addChild($0) }
            element.addChild(linesElement)

            return element
        }
    }

    private struct Line {
        let branch: Bool
        let hits: UInt64
        let number: UInt

        var asXMLElement: XMLElement {
            let element = XMLElement(name: "line")
            element.setAttributesWith([
                "number": String(describing: number),
                "branch": String(describing: branch),
                "hits": String(describing: hits)
            ])

            return element
        }
    }
}
