//
//  File: Sequence+Just.swift
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

extension Sequence {
    @inlinable
    func forEachAsync(
        priority: TaskPriority = .medium,
        _ body: @escaping (_: Element) async throws -> Void
    ) async rethrows {
        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            forEach { element in
                taskGroup.addTask(priority: priority) {
                    try await body(element)
                }
            }

            try await taskGroup.waitForAll()
        }
    }

    @inlinable
    func flatMapAsync<Output>(
        priority: TaskPriority = .medium,
        _ transformer: @escaping (_: Element) async throws -> [Output]
    ) async rethrows -> [Output] {
        try await withThrowingTaskGroup(of: [Output].self, returning: [Output].self) { taskGroup in
            forEach { element in
                taskGroup.addTask { try await transformer(element) }
            }

            var elements = [Output]()
            for try await element in taskGroup {
                elements.append(contentsOf: element)
            }

            return elements
        }
    }

    @inlinable
    func mapAsync<Output>(
        priority: TaskPriority = .medium,
        _ transformer: @escaping  (_: Element) async throws -> Output
    ) async rethrows -> [Output] {
        try await withThrowingTaskGroup(of: Output.self, returning: [Output].self) { taskGroup in
            forEach { element in
                taskGroup.addTask { try await transformer(element) }
            }

            var elements = [Output]()
            for try await element in taskGroup {
                elements.append(element)
            }

            return elements
        }
    }

    @inlinable
    func compactMapAsync<Output>(
        priority: TaskPriority = .medium,
        _ transformer: @escaping  (_: Element) async throws -> Output?
    ) async rethrows -> [Output] {
        try await withThrowingTaskGroup(of: Output?.self, returning: [Output].self) { taskGroup in
            forEach { element in
                taskGroup.addTask { try await transformer(element) }
            }

            var elements = [Output]()
            for try await element in taskGroup {
                guard let element = element else { continue }
                elements.append(element)
            }

            return elements
        }
    }
}
