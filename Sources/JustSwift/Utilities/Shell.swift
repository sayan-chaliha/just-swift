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

    public enum TerminationReason: Sendable {
        case exit(Int)
        case uncaughtSignal
    }

    public struct Output: Error {
        public let terminationReason: TerminationReason
        public let standardOutput: String
        public let standardError: String

        init(
            terminationReason: TerminationReason,
            standardOutput: String = "",
            standardError: String = ""
        ) {
            self.terminationReason = terminationReason
            self.standardOutput = standardOutput
            self.standardError = standardError
        }
    }

    public struct Command {
        let executable: String
        let arguments: [String]
    }

    public static func execute(
        command: Command,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        qualityOfService: QualityOfService = .default
    ) async -> Output {
        return await execute(script: command.asString)
    }

    public static func execute(
        script: String,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        qualityOfService: QualityOfService = .default
    ) async -> Output {
        await withCheckedContinuation { continuation in
            let executablePath = "/bin/bash"
            let arguments = ["-c", script]
            let standardOutputPipe = Pipe()
            let standardErrorPipe = Pipe()
            let process = Process()
            var standardOutput: String = ""
            var standardError: String = ""

            standardOutputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                if let string = String(data: fileHandle.availableData, encoding: .utf8) {
                    standardOutput.append(string)
                }
            }

            standardErrorPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                if let string = String(data: fileHandle.availableData, encoding: .utf8) {
                    standardError.append(string)
                }
            }

            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.qualityOfService = qualityOfService
            process.currentDirectoryURL = URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
            process.standardOutput = standardOutputPipe
            process.standardError = standardErrorPipe
            process.terminationHandler = { process in
                continuation.resume(
                    returning: .init(
                        terminationReason: TerminationReason(process),
                        standardOutput: standardOutput.trimmingTrailingCharacters(in: .whitespacesAndNewlines),
                        standardError: standardError.trimmingTrailingCharacters(in: .whitespacesAndNewlines)
                    )
                )
            }

            do {
                try process.run()
            } catch {
                continuation.resume(
                    returning: .init(
                        terminationReason: TerminationReason(process),
                        standardOutput: "",
                        standardError: String(describing: error))
                )
                return
            }
        }
    }
}

private extension Shell.TerminationReason {
    init(_ process: Process) {
        switch process.terminationReason {
        case .exit:
            self = .exit(Int(process.terminationStatus))
        case .uncaughtSignal:
            self = .uncaughtSignal
        @unknown default:
            self = .exit(Int(process.terminationStatus))
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
