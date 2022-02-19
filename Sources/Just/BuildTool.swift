//
//  File: BuildTool.swift
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

import JustSwift

@main
struct BuildTool {
    static func main() async throws {
        let just = try await Just.configure { _ in
            task("build", help: "Build the Swift package", SwiftBuildTask())
            task("clean", help: "Clean build output", SwiftCleanTask())
            task("test", help: "Run unit tests", SwiftTestTask())
            task("rebuild", help: "Clean and build Swift package", .series("clean", "build"))
            task("lint", help: "Run lint on sources", SwiftLintTask())
            task("format", help: "Run format on sources", SwiftFormatTask())
            task("check", help: "Format, lint and test code", .series("format", "lint", "rebuild", "test"))
            task("versions", help: "Prints computed current and next versions of the project", VersionTask())
            task("changelog", help: "Generate changelog based on commits", ChangelogTask())
            task("git:pre-commit", help: "Run pre-commit validation", "check")
            task("git:commit-msg", help: "Lint commit message", GitCommitMessageLint())

            try Git.install(hook: .preCommit, task: "git:pre-commit")
            try Git.install(hook: .commitMsg, task: "git:commit-msg")
        }

        try await just.execute()
    }
}
