//
//  File: EventBus.swift
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

protocol Event: Sendable {}

enum EventBus {
    struct Handle {
        fileprivate let cancellable: AnyCancellable
    }

    private static let lock = DispatchQueue(label: "com.microsoft.just.EventBus.Lock")
    private static let publisher = PassthroughSubject<Event, Never>()
    private static var cancellables: Set<AnyCancellable> = Set()

    static func publish<E: Event>(event: E) {
        publisher.send(event)
    }

    @discardableResult
    static func subscribe<E: Event, S: Scheduler>(
        to type: E.Type,
        on scheduler: S,
        handler: @escaping @Sendable (E) -> Void
    ) -> Handle {
        let cancellable = publisher
            .receive(on: scheduler)
            .compactMap { $0 as? E }
            .sink(receiveValue: handler)

        lock.async(flags: .barrier) {
            cancellables.update(with: cancellable)
        }

        return Handle(cancellable: cancellable)
    }

    @discardableResult
    static func subscribe<E: Event>(
        to type: E.Type,
        handler: @escaping @Sendable (E) -> Void
    ) -> Handle {
        subscribe(to: type, on: ImmediateScheduler.shared, handler: handler)
    }

    static func unsubscribe(handle: Handle) {
        lock.async(flags: .barrier) {
            cancellables.remove(handle.cancellable)?.cancel()
        }
    }
}
