//
//  File: GitCommitMessageLint.swift
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

public struct GitCommitMessageLint: TaskProvider {
    enum Error: Swift.Error {
        case invalidArgument
        case invalidCommitMessage
        case fileNotReadable(String)
    }

    public init() {}

    public func callAsFunction(_: inout ArgumentBuilder) -> TaskFunction {
        return { _ in
            guard let commitMessageFilePath = Git.contextParameter else {
                console.error("commit message file parameter missing")
                throw Error.invalidArgument
            }

            let commitMessageFileURL = URL(fileURLWithPath: commitMessageFilePath,
                                           relativeTo: Project.rootDirectory)

            guard FileManager.default.isReadableFile(atPath: commitMessageFileURL.path),
                  let commitMessage = try? String(contentsOf: commitMessageFileURL, encoding: .utf8)
            else {
                console.error("commit message file not readable: \(commitMessageFileURL.path.white.bold)")
                throw Error.fileNotReadable(commitMessageFileURL.path)
            }

            guard let commit = Git.Commit(fromString: commitMessage) else {
                console.error("unable to parse commit message")
                throw Error.invalidCommitMessage
            }

            console.info("commit:")
            console.info("title: \(commit.title, .green)", indent: 4)
            console.info("kind: \(String(describing: commit.kind), .white)", indent: 4)
            console.info("scope: \(commit.scope, .green)", indent: 4)
            console.info("breaking: \(String(describing: commit.breaking), .yellow)", indent: 4)

            guard commit.kind != .unknown else {
                console.error("commit kind is unknown")
                throw Error.invalidCommitMessage
            }

            if commit.scope.isEmpty {
                console.warn("commit scope is empty")
            }
        }
    }
}
