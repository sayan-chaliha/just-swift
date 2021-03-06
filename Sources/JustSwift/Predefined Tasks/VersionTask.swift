//
//  File: VersionTask.swift
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

public struct VersionTask: TaskProvider {
    public init() {}

    public func callAsFunction(_: inout ArgumentBuilder) -> TaskFunction {
        return { _ in
            console.info("current version: \(try await Project.version.current.description, .white)")
            console.info("   next version: \(try await Project.version.next.description, .green)")

            let commits = try await Project.git.commitsSinceLastTag
            if !commits.isEmpty {
                console.info("commits considered for next version bump:")
                commits.forEach { commit in
                    console.info("Commit:")
                    console.info("Title: \(commit.title, .green)", indent: 4)
                    console.info(
                        "Meta: \(commit.kind, .cyan)(\(commit.scope.isEmpty ? "<no scope>" : commit.scope, .white))",
                        indent: 4
                    )
                    console.info("Breaking: \(commit.breaking)", indent: 4)
                    console.info("Author: \(commit.author)", indent: 4)
                    console.info("PR #\(commit.prNumber)", indent: 4)
                    console.info("Bumps \(Bump.what([commit]), .blue)", indent: 4)
                }
            }
        }
    }
}
