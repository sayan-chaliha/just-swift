//
//  File: TaskLogger.swift
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

enum TaskLogger {
    @Sendable
    static func log(taskEvent event: TaskEvent) { // swiftlint:disable:this cyclomatic_complexity
        func isLoggable(_ name: String) -> Bool { return !name.starts(with: "<") }

        switch event {
        case .willConfigure:
            break
        case .didConfigure:
            break
        case let .upToDate(name):
            guard isLoggable(name) else { break }
            console.info("`\(name.colorized)` is already up-to-date")
        case let .willExecute(name):
            guard isLoggable(name) else { break }
            console.info("`\(name.colorized)` executing ...")
        case let .didExecute(name, result):
            guard isLoggable(name) else { break }
            switch result {
            case .success:
                console.info("`\(name.colorized)` done executing")
            case let .failure(error):
                console.error("`\(name.colorized)` execution failed: \(error)")
            }
        case let .conditionUnment(name):
            guard isLoggable(name) else { break }
            console.info("`\(name.colorized)` condition unmet; not executing")
        }
    }
}
