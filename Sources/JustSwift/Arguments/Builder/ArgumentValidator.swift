//
//  File: ArgumentValidator.swift
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

enum ArgumentValidatorErrorKind {
    case warning
    case failure
}

protocol ArgumentValidatorError: Error {
    var kind: ArgumentValidatorErrorKind { get }
}

protocol ArgumentValidator {
    static func validate(_ args: [ArgumentDefinition]) -> ArgumentValidatorError?
    static func validate(_ cmds: [Command]) -> ArgumentValidatorError?
}

extension ArgumentValidator {
    static func validate(_: [ArgumentDefinition]) -> ArgumentValidatorError? { nil }
    static func validate(_: [Command]) -> ArgumentValidatorError? { nil }
}

struct PositionalArgumentValidator: ArgumentValidator {

    struct Error: ArgumentValidatorError, CustomStringConvertible {
        let repeatedPositionalArgument: String
        let positionalArgumentFollowingRepeated: String
        let kind: ArgumentValidatorErrorKind = .failure

        var description: String {
            "Can't have a positional argument `\(positionalArgumentFollowingRepeated.bold.yellow)` following an "
                + "array of positional arguments `\(repeatedPositionalArgument.bold.yellow)`."
        }
    }

    static func validate(_ args: [ArgumentDefinition]) -> ArgumentValidatorError? {
        guard let repeatingPositionalIndex = args.firstIndex(where: { $0.isRepeatingPositional }) else { return nil }
        guard let positionalAfterRepeating = args[(repeatingPositionalIndex+1)...].first(where: { $0.isPositional })
        else {
            return nil
        }

        return Error(
            repeatedPositionalArgument: String(describing: args[repeatingPositionalIndex].name),
            positionalArgumentFollowingRepeated: String(describing: positionalAfterRepeating.name)
        )
    }
}

struct NameArgumentValidator: ArgumentValidator {

    struct Error: ArgumentValidatorError, CustomStringConvertible {
        let names: [String]
        let kind: ArgumentValidatorErrorKind = .failure

        var description: String {
            """
            Names are not correctly formatted.
            Valid names begin with `a-z` followed by `0-9` or the `-` character. A name cannot also end in `-`.
            Names: \(names.map { $0.bold.yellow }.joined(separator: ", "))
            """
        }
    }

    static func validate(_ args: [ArgumentDefinition]) -> ArgumentValidatorError? {
        let badNames = args.map(\.name).filter {
            $0.range(of: #"^([a-z]|[0-9])+(-([a-z]|[0-9])+)*$"#, options: .regularExpression) == nil
        }

        guard !badNames.isEmpty else { return nil }

        return Error(names: badNames)
    }

    static func validate(_ cmds: [Command]) -> ArgumentValidatorError? {
        let badNames = cmds.map(\.name).filter {
            $0.range(of: #"^([a-z]|[0-9])+([-|:]([a-z]|[0-9])+)*$"#, options: .regularExpression) == nil
        }

        guard !badNames.isEmpty else { return nil }

        return Error(names: badNames)
    }
}

struct DuplicateNameArgumentValidator: ArgumentValidator {

    struct Error: ArgumentValidatorError, CustomStringConvertible {
        let names: [String: Int]
        let aliases: [Character: Int]
        let kind: ArgumentValidatorErrorKind = .failure

        var description: String {
            (names.map { (name, count) in
                "There are (\(String(describing: count).bold.yellow)) duplicates of the name `\(name.bold.yellow)`."
            } + aliases.map { (alias, count) in
                "There are (\(String(describing: count).bold.yellow)) duplicates of the alias "
                    + "`\("\(alias)".bold.yellow)`."
            }).joined(separator: "\n")
        }
    }

    static func validate(_ args: [ArgumentDefinition]) -> ArgumentValidatorError? {
        var names: [String: Int] = [:]
        var aliases: [Character: Int] = [:]
        var hasDuplicates = false

        args.forEach { arg in
            let nameCount = (names[arg.name] ?? 0) + 1

            names[arg.name] = nameCount
            var aliasCount: Int = 0

            arg.alias.let {
                aliasCount = (aliases[$0] ?? 0) + 1
                aliases[$0] = aliasCount
            }

            if !hasDuplicates && (nameCount > 1 || aliasCount > 1) {
                hasDuplicates = true
            }
        }

        guard hasDuplicates else { return nil }

        return Error(
            names: names.filter { (_, value) in value > 1 },
            aliases: aliases.filter { (_, value) in value > 1 }
        )
    }

    static func validate(_ cmds: [Command]) -> ArgumentValidatorError? {
        var names: [String: Int] = [:]
        var hasDuplicates = false

        cmds.forEach { cmd in
            let nameCount = (names[cmd.name] ?? 0) + 1

            names[cmd.name] = nameCount
            if !hasDuplicates, nameCount > 1 {
                hasDuplicates = true
            }
        }

        guard hasDuplicates else { return nil }

        return Error(names: names, aliases: [:])
    }
}
