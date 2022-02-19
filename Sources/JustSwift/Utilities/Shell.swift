//
//  File: Shell.swift
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

public enum Shell {

    public struct Output: Error {
        let terminationStatus: Int
        let standardOutput: String
        let standardError: String

        init(
            terminationStatus: Int = 0,
            standardOutput: String = "",
            standardError: String = ""
        ) {
            self.terminationStatus = terminationStatus
            self.standardOutput = standardOutput
            self.standardError = standardError
        }
    }

    public struct Command {
        let executable: String
        let arguments: [String]
    }

    static func execute(
        command: Command,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        qualityOfService: QualityOfService = .default
    ) -> Output {
        return execute(script: command.asString)
    }

    static func execute(
        script: String,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        qualityOfService: QualityOfService = .default
    ) -> Output {
        let executablePath = "/bin/bash"
        let arguments = ["-c", script]
        let outputQueue = DispatchQueue(label: "com.microsoft.just.shell.IO")
        let standardOutputPipe = Pipe()
        let standardErrorPipe = Pipe()
        let process = Process()
        var standardOutputData = Data()
        var standardErrorData = Data()

        standardOutputPipe.fileHandleForReading.readabilityHandler = { handler in
            outputQueue.async { standardOutputData.append(handler.availableData) }
        }

        standardErrorPipe.fileHandleForReading.readabilityHandler = { handler in
            outputQueue.async { standardErrorData.append(handler.availableData) }
        }

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.qualityOfService = qualityOfService
        process.currentDirectoryURL = URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
        process.standardOutput = standardOutputPipe
        process.standardError = standardErrorPipe

        do {
            try process.run()
        } catch {
            return .init(
                terminationStatus: Int(process.terminationStatus),
                standardOutput: "",
                standardError: String(describing: error)
            )
        }
        process.waitUntilExit()

        return outputQueue.sync {
            let standardOutput = String(data: standardOutputData, encoding: .utf8)?
                .trimmingTrailingCharacters(in: .whitespacesAndNewlines) ?? ""
            let standardError = String(data: standardErrorData, encoding: .utf8)?
                .trimmingTrailingCharacters(in: .whitespaces) ?? ""

            guard process.terminationStatus == 0 else {
                return .init(
                    terminationStatus: Int(process.terminationStatus),
                    standardOutput: standardOutput,
                    standardError: standardError
                )
            }

            return .init(standardOutput: standardOutput, standardError: standardError)
        }
    }
}

private extension Shell.Command {
    var asString: String { "\(executable) \(arguments.joined(separator: " "))" }
}

extension Shell.Command: CustomStringConvertible {
    public var description: String { asString }
}

extension Shell.Command: ExpressibleByStringInterpolation {
    public init(stringLiteral value: StringLiteralType) {
        self.executable = value
        self.arguments = []
    }
}
