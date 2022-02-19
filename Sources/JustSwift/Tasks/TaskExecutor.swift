//
//  File: TaskExecutor.swift
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
import Combine

enum TaskExecutorError: TaskError {
    case taskNotFound(String)
    case cyclesDetected
    case dependencyError
}

protocol TaskExecutor {
    func execute(taskWithName: String, argv: Argv) async throws
    static func configure(tasks: [TaskWrapper], arguments: Arguments) throws -> TaskExecutor
}

enum TaskEvent: Event {
    case willConfigure(String)
    case didConfigure(String, Result<Void, Error>)
    case upToDate(String)
    case conditionUnment(String)
    case willExecute(String)
    case didExecute(String, Result<Void, Error>)
}

// MARK: AsyncExecutor

struct AsyncExecutor {
    let tasks: [String: Executable]
}

extension AsyncExecutor: TaskExecutor {
    static func configure(tasks: [TaskWrapper], arguments: Arguments) throws -> TaskExecutor {
        var undefined: [TaskWrapper] = []
        var defined: [String: Executable] = [:]

        // Functions that have no deps
        tasks.forEach { task in
            var taskFunction: TaskFunction?
            var taskProvider: ((inout ArgumentBuilder) -> Void)?

            switch task.value {
            case let .function(function):
                taskFunction = function
            case let .provider(provider):
                taskProvider = { args in
                    taskFunction = provider(&args)
                }
            case .continuation:
                undefined.append(task)
                return
            }

            EventBus.publish(event: TaskEvent.willConfigure(task.name))
            arguments.command(task.name, help: .init(task.help), argumentBuilder: taskProvider)

            guard let taskFunction = taskFunction else {
                EventBus.publish(event: TaskEvent.didConfigure(
                                    task.name, .failure(TaskExecutorError.taskNotFound(task.name))))
                return
            }
            EventBus.publish(event: TaskEvent.didConfigure(task.name, .success(())))

            defined[task.name] = Function(task.name, taskFunction: taskFunction)
        }

        // Functions that have deps on raw functions
        resolve(undefined: &undefined, into: &defined, arguments: arguments)

        if !undefined.isEmpty {
            // Some functions may depend on other continuations
            resolve(undefined: &undefined, into: &defined, arguments: arguments)
        }

        guard undefined.isEmpty else { throw TaskExecutorError.cyclesDetected }

        return AsyncExecutor(tasks: defined)
    }

    func execute(taskWithName name: String, argv: Argv) async throws {
        guard let executable = tasks[name] else { throw TaskExecutorError.taskNotFound(name) }
        try await executable.execute(argv).get()
    }
}

// MARK: AsyncExecutor -- Resolution

extension AsyncExecutor {

    private static func resolve(
        undefined: inout [TaskWrapper],
        into defined: inout [String: Executable],
        arguments: Arguments
    ) {
        var indices = [Int]()

        for (index, task) in undefined.enumerated() {
            guard case let .continuation(continuation) = task.value else {
                assertionFailure("Functions and providers cannot be undefined!")
                break
            }
            let result = AsyncExecutor.resolve(continuation: continuation,
                                               withName: task.name,
                                               into: &defined)
            if result != nil {
                EventBus.publish(event: TaskEvent.willConfigure(task.name))
                arguments.command(task.name, help: .init(task.help))
                EventBus.publish(event: TaskEvent.didConfigure(task.name, .success(())))
                indices.append(index)
            }
        }
        indices.sorted(by: >).forEach { undefined.remove(at: $0) }
    }

    @discardableResult
    private static func resolve(
        continuation: TaskContinuation,
        withName name: String? = nil,
        into defined: inout [String: Executable]
    ) -> Executable? {
        switch continuation.kind {
        case let .condition(task, condition):
            return resolve(conditional: task, withName: name, withCondition: condition, into: &defined)
        case let .single(task):
            return resolve(single: task, withName: name, into: &defined)
        case let .series(continuations):
            return resolve(continuations: continuations, withName: name, withKind: .serial, into: &defined)
        case let .parallel(continuations):
            return resolve(continuations: continuations, withName: name, withKind: .parallel, into: &defined)
        }
    }

    private static func resolve(
        single task: String,
        withName name: String?,
        into defined: inout [String: Executable]
    ) -> Executable? {
        guard let executable = defined[task] else { return nil }
        let functionCollection = FunctionCollection(name ?? FunctionIdentifiers.series,
                                                    executables: [executable],
                                                    kind: .serial)
        defined[functionCollection.name] = functionCollection
        return functionCollection
    }

    private static func resolve(
        conditional task: String,
        withName name: String?,
        withCondition condition: @escaping (Argv) -> Bool,
        into defined: inout [String: Executable]
    ) -> Executable? {
        guard let executable = defined[task] else { return nil }
        let conditionalFunction = ConditionalFunction(executable: executable, condition: condition)
        let functionCollection = FunctionCollection(name ?? FunctionIdentifiers.series,
                                                    executables: [conditionalFunction],
                                                    kind: .serial)
        defined[conditionalFunction.name] = conditionalFunction
        defined[functionCollection.name] = functionCollection
        return functionCollection
    }

    private static func resolve(
        continuations: [TaskContinuation],
        withName name: String?,
        withKind kind: FunctionCollection.Kind,
        into defined: inout [String: Executable]
    ) -> Executable? {
        var resolved = [Executable]()
        for continuation in continuations {
            guard let executable = resolve(continuation: continuation, into: &defined)
            else {
                return nil
            }
            resolved.append(executable)
        }
        let functionCollection = FunctionCollection(name ?? FunctionIdentifiers.parallel,
                                                    executables: resolved,
                                                    kind: kind)
        defined[functionCollection.name] = functionCollection
        return functionCollection
    }
}
