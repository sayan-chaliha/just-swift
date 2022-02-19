//
//  File: Git.swift
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
import System

public struct Git {

    enum Error: Swift.Error {
        case gitFailed
    }

    public struct Commit {
        public enum Kind: String {
            case feature = "feat"
            case fix
            case chore
            case refactor
            case ci
            case build
            case docs
            case perf
            case style
            case test
            case revert
            case unknown
        }

        public let kind: Kind
        public let breaking: Bool
        public let scope: String
        public let title: String
        public let hash: String
        public let raw: String
        public let date: Date
        public let tags: String
        public let prNumber: String
        public let author: String
    }

    public struct Change {
        public enum Status: Character, Equatable {
            case added = "A"
            case deleted = "D"
            case modified = "M"
            case untracked = "?"
            case none = " "
        }

        public let status: (staged: Status, unstaged: Status)
        public let fileURL: URL
    }

    public enum Hook: String, CaseIterable {
        case preCommit = "pre-commit"
        case commitMsg = "commit-msg"
        case prePush = "pre-push"
        case postCheckout = "post-checkout"
        case applyPatchMsg = "applypatch-msg"
        case postUpdate = "post-update"
        case preApplyPatch = "pre-applypatch"
        case preMergeCommit = "pre-merge-commit"
        case preRebase = "pre-rebase"
        case preReceive = "pre-receive"
        case prepareCommitMsg = "prepare-commit-msg"
        case update
    }

    public static var contextParameter: String? {
        ProcessInfo.processInfo.environment["GIT_PARAMS"]
    }

    public var currentBranch: String {
        (try? Git.currentBranch()) ?? ""
    }

    public var lastTag: String? {
        (try? Git.tags())?.last
    }

    public var commitsSinceLastTag: [Commit] {
        (try? Git.commits(from: lastTag)) ?? []
    }

    public var changes: [Change] {
        (try? Git.changes()) ?? []
    }

    public static func commits(from tag: String? = nil) throws -> [Commit] {
        let scissor = "-------------------- >8 ------------------------"

        let output = try execute(command: .gitCommits(from: tag, scissor: scissor))
        guard !output.isEmpty else { return [] }

        return output.components(separatedBy: scissor)
            .compactMap { Commit(fromString: $0) }
    }

    public static func add(filePaths: [String]) throws {
        try execute(command: .gitAdd(filePaths: filePaths))
    }

    public static func currentBranch() throws -> String {
        try execute(command: .gitCurrentBranch())
    }

    public static func tags() throws -> [String] {
        let output = try execute(command: .gitTags())
        guard !output.isEmpty else { return [] }
        return output.components(separatedBy: .newlines)
    }

    public static func root() throws -> String {
        try execute(command: .gitRevParse(["--show-toplevel"]))
    }

    public static func userName() throws -> String {
        try execute(command: .gitConfig(get: "user.name"))
    }

    public static func userEmail() throws -> String {
        try execute(command: .gitConfig(get: "user.email"))
    }

    public static func changes() throws -> [Change] {
        let status = try execute(command: .gitStatus(options: .short))
        guard !status.isEmpty else { return [] }

        return status.components(separatedBy: .newlines)
            .compactMap { change in
                guard !change.isEmpty else { return nil }

                let rawStatus = change.prefix(2)
                let path = change.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\"", with: "")
                let url = URL(fileURLWithPath: path, relativeTo: Project.rootDirectory)
                guard rawStatus.count == 2,
                      let stagedStatus = Change.Status(rawValue: rawStatus[rawStatus.startIndex]),
                      let unstagedStatus =
                        Change.Status(rawValue: rawStatus[rawStatus.index(rawStatus.startIndex, offsetBy: 1)])
                else {
                    return nil
                }

                return .init(status: (stagedStatus, unstagedStatus), fileURL: url)
            }
    }

    public static func install(hook: Hook, task: String) throws {
        let script = """
        #! /usr/bin/env bash

        export GIT_PARAMS="${*}";

        if ! [ -x "\(Just.executableURL.path)" ]; then
            echo "just command not found.";
            echo "trying to build it ...";

            swift=$(which swift);
            if ! [ -x "${swift}" ]; then
                echo "`swift` not found!";
                exit -1;
            fi;

            pushd $(dirname "\(Just.executableURL.path)") 1>/dev/null 2>&1;
            ${swift} build;
            popd 1>/dev/null 2>&1;
        fi;

        if ! [ -x "\(Just.executableURL.path)" ]; then
            echo "`just` command not found."
            exit -1;
        fi;

        \(Just.executableURL.path) --root-directory="\(Project.rootDirectory.path)" \(task);
        """

        let hookFile = Project.rootDirectory.appendingPathComponent(".git")
            .appendingPathComponent("hooks")
            .appendingPathComponent(hook.rawValue)

        try script.write(to: hookFile, atomically: true, encoding: .utf8)

        let permissions: FilePermissions = .ownerReadWriteExecute
            .union(.groupReadExecute)
            .union(.otherExecute)

        try FileManager.default.setAttributes([.posixPermissions: permissions.rawValue], ofItemAtPath: hookFile.path)
    }

    @discardableResult
    private static func execute(command: Shell.Command) throws -> String {
        let output = Shell.execute(command: command)

        guard output.terminationStatus == 0 else {
            console.error("`\(command.description.green.bold)` failed: \(output.standardError)")
            throw Error.gitFailed
        }

        return output.standardOutput
    }
}

extension Git.Commit {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public init?(fromString log: String)  {
        guard !log.isEmpty else { return nil }

        let log = log.components(separatedBy: .newlines)
            .filter { !$0.starts(with: "#") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let mergePattern = #"Merged PR (?<prNumber>(\d)+): (?<header>(.*))"#
        let headerPattern = #"(?<kind>\w*)(?<scope>\((.*)\))?(?<breaking>!)?: (?<title>(.*))"#
        let breakingPattern = #"(BREAKING)"#

        guard let mergeRegex = try? NSRegularExpression(pattern: mergePattern, options: []) else {
            fatalError("Git.Commit: invalid merge regex pattern")
        }

        guard let headerRegex = try? NSRegularExpression(pattern: headerPattern, options: []) else {
            fatalError("Git.Commit: invalid header regex pattern")
        }

        guard let breakingRegex = try? NSRegularExpression(pattern: breakingPattern, options: []) else {
            fatalError("Git.Commit: invalid breaking regex pattern")
        }

        var kind: Kind?
        var breaking = false
        var scope = ""
        var title = ""
        var header = ""
        var prNumber = ""

        if let match = mergeRegex.firstMatch(in: log, options: [], range: NSRange(0 ..< log.count)) {
            if let substringRange = Range(match.range(withName: "prNumber"), in: log) {
                prNumber = String(log[substringRange])
            }
            if let substringRange = Range(match.range(withName: "header"), in: log) {
                header = String(log[substringRange])
            }
        } else if let match = headerRegex.firstMatch(in: log, options: [], range: NSRange(0 ..< log.count)) {
            if let substringRange = Range(match.range, in: log) {
                header = String(log[substringRange])
            }
        }

        if let match = headerRegex.firstMatch(in: header, options: [], range: NSRange(0 ..< header.count)) {
            if let substringRange = Range(match.range(withName: "kind"), in: log) {
                kind = Kind(rawValue: String(header[substringRange]))
            }

            if let substringRange = Range(match.range(withName: "scope"), in: log) {
                scope = header[substringRange]
                    .replacingOccurrences(of: "[(|)]", with: "", options: .regularExpression, range: nil)
            }

            if Range(match.range(withName: "breaking"), in: log) != nil {
                breaking = true
            }

            if let substringRange = Range(match.range(withName: "title"), in: log) {
                title = String(header[substringRange])
            }
        }

        if !breaking {
            if breakingRegex.firstMatch(in: log, options: [], range: NSRange(0 ..< log.count)) != nil {
                breaking = true
            }
        }

        let lines = log.components(separatedBy: .newlines)

        var hash = ""
        var gitTags = ""
        var committerDate = Date()
        var author = ""

        if title.isEmpty {
            title = lines.first { !$0.isEmpty } ?? ""
        }

        for idx in 0 ..< lines.count {
            if lines[idx] == "-hash-" {
                hash = lines[idx + 1]
            }

            if lines[idx] == "-gitTags-" {
                gitTags = lines[idx + 1]
            }

            if lines[idx] == "-comitterDate-" {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy'-'MM'-'dd HH':'mm':'ss ZZZZZ"

                committerDate = dateFormatter.date(from: lines[idx + 1]) ?? Date()
            }

            if lines[idx] == "-author-" {
                author = lines[idx + 1]
            }
        }

        self = .init(
            kind: kind ?? .unknown,
            breaking: breaking,
            scope: scope,
            title: title,
            hash: hash,
            raw: log,
            date: committerDate,
            tags: gitTags,
            prNumber: prNumber,
            author: author
        )
    }
}

extension Shell.Command {
    private static let git = "git"

    public struct GitStatusOptions: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        static let short = GitStatusOptions(rawValue: 1 << 0)
    }

    public static func gitCurrentBranch() -> Shell.Command {
        "\(git) branch --show-current"
    }

    public static func gitTags() -> Shell.Command {
        "\(git) tag"
    }

    public static func gitTag(_ tag: String, hash: String = "") -> Shell.Command {
        "\(git) tag \(tag) \(hash)"
    }

    public static func gitCommits(from tag: String? = nil, scissor: String = "") -> Shell.Command {
        let format = "--format=%B%n-hash-%n%H%n-gitTags-%n%d%n" +
            "-committerDate-%n%ci%n-author-%n%aN\" <\"%ae\">\"%n\"\(scissor)\""

        var spec = "HEAD"
        if let tag = tag {
            spec = "\(tag)..HEAD"
        }

        return "\(git) log \(format) \(spec)"
    }

    public static func gitRevParse(_ args: [String]) -> Shell.Command {
        Shell.Command(executable: "\(git) rev-parse", arguments: args)
    }

    public static func gitFetch() -> Shell.Command {
        "\(git) fetch"
    }

    public static func gitAdd(filePaths: [String]? = nil) -> Shell.Command {
        "\(git) add \(filePaths?.map { "\"\($0)\"" }.joined(separator: " ") ?? ".")"
    }

    public static func gitAdd(fileURLs: [URL]? = nil) -> Shell.Command {
        "\(git) add \(fileURLs?.map(\.path).joined(separator: " ") ?? ".")"
    }

    public static func gitConfig(get: String) -> Shell.Command {
        "\(git) config \(get)"
    }

    public static func gitStatus(options: GitStatusOptions = []) -> Shell.Command {
        var args = [
            "status"
        ]

        if options.contains(.short) {
            args.append("--short")
        }

        return Shell.Command(executable: git, arguments: args)
    }
}
