//
//  File: TaskValidator.swift
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

protocol TaskValidatorError: TaskError {
}

protocol TaskValidator {
    static func validate(_ tasks: [TaskWrapper]) -> TaskValidatorError?
}

struct TaskNameValidator: TaskValidator {

    struct Error: TaskValidatorError, CustomStringConvertible {
        let names: [String]

        var description: String {
            """
            Names are not correctly formatted.
            Valid names begin with `a-z` followed by `0-9` or the `:` or `-` characters.
            Names: \(names.map { $0.bold.yellow }.joined(separator: ", "))
            """
        }
    }

    static func validate(_ tasks: [TaskWrapper]) -> TaskValidatorError? {
        let badNames = tasks.map(\.name).filter {
            $0.range(of: #"^([a-z]|[0-9])+([-|:]([a-z]|[0-9])+)*$"#, options: .regularExpression) == nil
        }

        guard !badNames.isEmpty else { return nil }

        return Error(names: badNames)
    }
}

struct DuplicateTasksValidator: TaskValidator {
    struct Error: TaskValidatorError, CustomStringConvertible {
        let names: [String: Int]

        var description: String {
            names.map { (name, count) in
                "There are duplicate (\(count)) tasks with the name `\(name)`"
            }.joined(separator: "\n")
        }
    }

    static func validate(_ tasks: [TaskWrapper]) -> TaskValidatorError? {
        var names = [String: Int]()

        tasks.forEach { task in
            let count = (names[task.name] ?? 0) + 1
            names[task.name] = count
        }

        let duplicateNames = names.filter { (_, count) in count > 1 }
        guard !duplicateNames.isEmpty else { return nil }

        return Error(names: duplicateNames)
    }
}

struct UndefinedTasksValidator: TaskValidator {
    struct Error: TaskValidatorError, CustomStringConvertible {
        let undefined: [String]

        var description: String {
            undefined.map { name in
                "No function named `\(name)` defined"
            }.joined(separator: "\n")
        }
    }

    static func validate(_ tasks: [TaskWrapper]) -> TaskValidatorError? {
        var defined: Set<String> = []
        var undefined: Set<String> = []

        for task in tasks {
            validate(task: task, definedFunctions: &defined, undefinedFunctions: &undefined)
        }

        if !undefined.isEmpty {
            for task in tasks {
                validate(task: task, definedFunctions: &defined, undefinedFunctions: &undefined)
            }
        }

        guard !undefined.isEmpty else { return nil }

        return Error(undefined: Array(undefined))
    }

    private static func validate(
        task: TaskWrapper,
        definedFunctions: inout Set<String>,
        undefinedFunctions: inout Set<String>
    ) {
        switch task.value {
        case .provider, .function:
            undefinedFunctions.remove(task.name)
        case let .continuation(continuation):
            validate(continuation: continuation,
                     definedFunctions: definedFunctions,
                     undefinedFunctions: &undefinedFunctions)
        }

        definedFunctions.update(with: task.name)
    }

    private static func validate(
        continuation: TaskContinuation,
        definedFunctions: Set<String>,
        undefinedFunctions: inout Set<String>
    ) {
        switch continuation.kind {
        case let .single(name), let .condition(name, _):
            if !definedFunctions.contains(name) {
                undefinedFunctions.update(with: name)
            }
        case let .parallel(continuations), let .series(continuations):
            continuations.forEach {
                validate(continuation: $0, definedFunctions: definedFunctions, undefinedFunctions: &undefinedFunctions)
            }
        }
    }
}
