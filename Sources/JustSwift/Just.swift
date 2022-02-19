//
//  File: Just.swift
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

public struct Just {
    static var executableURL: URL = URL(fileURLWithPath: CommandLine.arguments[0])

    private let arguments: Arguments
    private let executor: TaskExecutor

    private init(
        arguments: Arguments,
        executor: TaskExecutor
    ) {
        self.arguments = arguments
        self.executor = executor
    }
}

extension Just {
    public static func configure(closure: (inout ArgumentBuilder) throws -> Void) async throws -> Just {
        let arguments = Arguments()
        var argumentBuilder = arguments as ArgumentBuilder

        // add the default `verbose` option
        arguments.flag("verbose", alias: "v", help: "Enable verbose logging")
        // default sources directory
        arguments.option("root-directory",
                         alias: "r",
                         type: String.self,
                         help: "Path to root directory of Swift Package")

        if Just.executableURL.pathComponents.first != "/" {
            Just.executableURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(CommandLine.arguments[0])
                .standardized
        }

        EventBus.subscribe(to: TaskEvent.self, handler: TaskLogger.log)

        do {
            try closure(&argumentBuilder)
            try TaskRegistry.shared.validate()
            let executor = try AsyncExecutor.configure(tasks: TaskRegistry.shared.tasks, arguments: arguments)

            return Just(arguments: arguments, executor: executor)
        } catch {
            console.error("\(error)")
            throw error
        }
    }
}

extension Just {
    enum Error: Swift.Error {
        case rootDirectoryDoesNotExist(String)
        case rootDirectoryMissingPackageFile(String)
        case sourcesDirectoryDoesNotExist(String)
    }

    public func execute() async throws {
        let parsedValues = try arguments.parse()

        Project.optionRootDirectoryPath = parsedValues[dynamicMember: "root-directory"]

        try validateDirectories()

        guard let command = parsedValues.command else {
            console.error("you need to specify a command to run")
            console.error("try running `\(CommandLine.binary + " --help", .green)`")
            return
        }

        try await executor.execute(taskWithName: command, argv: Argv(parsedValues: parsedValues))
    }

    private func validateDirectories() throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: Project.rootDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue == true
        else {
            console.error("root directory does not exist or is not a directory: \(Project.rootDirectory)")
            throw Error.rootDirectoryDoesNotExist(Project.rootDirectory.path)
        }

        guard FileManager.default.fileExists(
            atPath: Project.rootDirectory.appendingPathComponent("Package.swift").path
        ) else {
            console.error("\("Package.swift", .yellow) not found in \(Project.rootDirectory)")
            throw Error.rootDirectoryMissingPackageFile(Project.rootDirectory.path)
        }

        isDirectory = false
        guard FileManager.default.fileExists(atPath: Project.sourcesDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue == true
        else {
            console.error("sources directory does not exist or is not a directory: \(Project.sourcesDirectory)")
            throw Error.sourcesDirectoryDoesNotExist(Project.rootDirectory.path)
        }

        FileManager.default.changeCurrentDirectoryPath(Project.rootDirectory.path)

        console.info("current directory: \(FileManager.default.currentDirectoryPath, .white)")
        console.info("sources directory: \(Project.sourcesDirectory)")
    }
}
