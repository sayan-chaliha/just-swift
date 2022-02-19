//
//  File: Tasks.swift
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

@dynamicMemberLookup
public struct Argv {
    private let parsedValues: ParsedValues

    init(parsedValues: ParsedValues) {
        self.parsedValues = parsedValues
    }

    public subscript<T: ExpressibleByArgument>(dynamicMember member: String) -> T? {
        parsedValues[dynamicMember: member]
    }

    public subscript<T: ExpressibleByArgument>(_ member: String) -> T? {
        parsedValues[dynamicMember: member]
    }
}

public typealias TaskFunction = @Sendable (_: Argv) async throws -> Void

public protocol TaskProvider {
    func callAsFunction(_: inout ArgumentBuilder) -> TaskFunction
}

public struct TaskContinuation {
    enum Kind {
        case single(String)
        case parallel([TaskContinuation])
        case series([TaskContinuation])
        case condition(String, (Argv) -> Bool)
    }

    let kind: Kind

    private init(kind: Kind) {
        self.kind = kind
    }
}

extension TaskContinuation: ExpressibleByStringLiteral {
    public init(stringLiteral name: String) {
        self.init(kind: .single(name))
    }
}

extension TaskContinuation {
    public static func series(_ continuations: TaskContinuation...) -> TaskContinuation {
        .init(kind: .series(continuations))
    }

    public static func parallel(_ continuations: TaskContinuation...) -> TaskContinuation {
        .init(kind: .parallel(continuations))
    }

    public static func condition(_ task: String, _ conditional: @escaping (Argv) -> Bool) -> TaskContinuation {
        .init(kind: .condition(task, conditional))
    }
}

public func task(_ name: String, help: String, _ provider: TaskProvider) {
    TaskRegistry.shared.append(
        .init(name: name, help: help, value: .provider(provider))
    )
}

public func task(_ name: String, help: String, _ function: @escaping TaskFunction) {
    TaskRegistry.shared.append(
        .init(name: name, help: help, value: .function(function))
    )
}

public func task(_ name: String, help: String, _ continuation: TaskContinuation) {
    TaskRegistry.shared.append(
        .init(name: name, help: help, value: .continuation(continuation))
    )
}

struct TaskWrapper {
    enum Value {
        case continuation(TaskContinuation)
        case provider(TaskProvider)
        case function(TaskFunction)
    }

    let name: String
    let help: String
    let value: Value
}

extension TaskWrapper: Equatable {
    static func == (lhs: TaskWrapper, rhs: TaskWrapper) -> Bool {
        lhs.name == rhs.name
    }
}

extension TaskWrapper: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
