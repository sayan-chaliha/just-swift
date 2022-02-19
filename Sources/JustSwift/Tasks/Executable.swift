//
//  File: Executable.swift
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

protocol Executable: AnyObject {
    var name: String { get }
    func execute(_: Argv) async -> Result<Void, Error>
}

extension Executable {
    func logUpToDate() {
        EventBus.publish(event: TaskEvent.upToDate(name))
    }

    func logStart() {
        EventBus.publish(event: TaskEvent.willExecute(name))
    }

    func logEnd() {
        EventBus.publish(event: TaskEvent.didExecute(name, .success(())))
    }

    func logError(error: Error) {
        EventBus.publish(event: TaskEvent.didExecute(name, .failure(error)))
    }
}

enum FunctionIdentifiers {
    private static var _collectionID = 0
    private static var _conditionalID = 0

    private static var collectionID: Int {
        defer { _collectionID += 1 }
        return _collectionID
    }

    private static var conditionalID: Int {
        defer { _conditionalID += 1 }
        return _conditionalID
    }

    static var parallel: String {
        "<parallel:\(collectionID)>"
    }

    static var series: String {
        "<series:\(collectionID)>"
    }

    static func conditional(_ name: String) -> String {
        "<conditional:\(name):\(conditionalID)>"
    }
}

enum FunctionState {
    case none
    case executing(Task<Void, Error>)
    case executed(Result<Void, Error>)
}

actor Function {
    let name: String
    private var state: FunctionState = .none
    private let taskFunction: TaskFunction

    init(_ name: String, taskFunction: @escaping TaskFunction) {
        self.name = name
        self.taskFunction = taskFunction
    }
}

extension Function: Executable {
    func execute(_ argv: Argv) async -> Result<Void, Error> {
        switch state {
        case let .executed(result):
            logUpToDate()
            return result
        case let .executing(task):
            defer { logUpToDate() }
            return await task.result
        default:
            break
        }

        let task = Task {
            logStart()
            do {
                try await taskFunction(argv)
                logEnd()
            } catch {
                logError(error: error)
                throw error
            }
        }

        state = .executing(task)
        let result = await task.result
        state = .executed(result)

        return result
    }
}

actor ConditionalFunction {
    let name: String
    private let function: Function

    init(executable: Executable, condition: @escaping (Argv) -> Bool) {
        self.name = FunctionIdentifiers.conditional(executable.name)
        self.function = .init(self.name) { [weak executable] argv in
            guard let executable = executable else { return }
            guard condition(argv) else {
                EventBus.publish(event: TaskEvent.conditionUnment(executable.name))
                return
            }

            try await executable.execute(argv).get()
        }
    }
}

extension ConditionalFunction: Executable {
    func execute(_ argv: Argv) async -> Result<Void, Error> {
        await function.execute(argv)
    }
}

actor FunctionCollection {
    enum Kind: Equatable {
        case parallel
        case serial
    }

    struct WeakExecutable {
        weak var executable: Executable?
    }

    let name: String
    private let kind: Kind
    private let executables: [WeakExecutable]
    private var state: FunctionState = .none

    init(_ name: String, executables: [Executable], kind: Kind) {
        self.name = name
        self.executables = executables.map { WeakExecutable(executable: $0) }
        self.kind = kind
    }
}

extension FunctionCollection: Executable {
    func execute(_ argv: Argv) async -> Result<Void, Error> {
        switch state {
        case let .executed(result):
            logUpToDate()
            return result
        case let .executing(task):
            defer { logUpToDate() }
            return await task.result
        default:
            break
        }

        let task = Task {
            let executables = executables.compactMap(\.executable)
            guard !executables.isEmpty else { return }

            logStart()
            do {
                if kind == .parallel {
                    try await executables.forEachAsync { executable in
                        try await executable.execute(argv).get()
                    }
                } else {
                    for executeable in executables {
                        try await executeable.execute(argv).get()
                    }
                }
                logEnd()
            } catch {
                logError(error: error)
                throw error
            }
        }

        state = .executing(task)
        let result = await task.result
        state = .executed(result)

        return result
    }
}
