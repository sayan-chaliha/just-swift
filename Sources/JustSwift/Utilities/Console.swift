//
//  File: Console.swift
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

public let console = Console()

public struct ConsoleLogInterpolation: StringInterpolationProtocol {
    public typealias StringLiteralType = String

    var output: String = ""

    public init(literalCapacity: Int, interpolationCount: Int) {
        self.output.reserveCapacity(literalCapacity * 2)
    }

    public mutating func appendLiteral(_ literal: StringLiteralType) {
        output += literal
    }

    public mutating func appendInterpolation(_ error: Error) {
        output += String(describing: error).red.bold
    }

    public mutating func appendInterpolation(_ string: String, _ color: NamedColor? = nil) {
        if let color = color {
            output += string.applyingColor(color).applyingStyle(.bold)
        } else {
            output += string
        }
    }

    public mutating func appendInterpolation(_ url: URL) {
        if url.isFileURL {
            output += url.relativePath.white.bold
        } else {
            output += String(describing: url).white.bold
        }
    }

    public mutating func appendInterpolation(_ uint: UInt) {
        output += String(describing: uint).white.bold
    }
}

public struct ConsoleLogMessage: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    public typealias StringLiteralType = String
    public typealias ExtendedGraphemeClusterLiteralType = String
    public typealias UnicodeScalarLiteralType = String

    var output: [String] = []

    public init(stringLiteral value: String) {
        output.append(contentsOf: value.wrapped().components(separatedBy: .newlines))
    }

    public init(stringInterpolation: ConsoleLogInterpolation) {
        output.append(contentsOf: stringInterpolation.output.wrapped().components(separatedBy: .newlines))
    }
}

public struct Console {
    private let startTime = DispatchTime.now()

    public var size: (width: Int, length: Int) = {
        var windowSize = winsize()
        guard ioctl(STDOUT_FILENO, TIOCGWINSZ, &windowSize) == 0 else { return (85, 25) }
        return (Int(windowSize.ws_col), Int(windowSize.ws_row))
    }()

    private var timeSince: String {
        String(format: "+%.12d", startTime.distance(to: DispatchTime.now()).milliseconds)
            .applyingColor(.lightBlue)
            .applyingStyle(.bold)
    }

    public func info(_ message: @autoclosure () -> ConsoleLogMessage, indent: Int = 0) {
        let message = message().output.map { timeSince + " I".cyan.bold + " \($0)".padded(by: indent) }
            .joined(separator: "\n")
        print(message)
    }

    public func error(_ message: @autoclosure () -> ConsoleLogMessage, indent: Int = 0) {
        let message = message().output.map { timeSince + " E".red.bold + " \($0)".padded(by: indent) }
            .joined(separator: "\n")
        print(message)
    }

    public func warn(_ message: @autoclosure () -> ConsoleLogMessage, indent: Int = 0) {
        let message = message().output.map { timeSince + " W".yellow.bold + " \($0)".padded(by: indent) }
            .joined(separator: "\n")
        print(message)
    }

    public func verbose(_ message: @autoclosure () -> ConsoleLogMessage, indent: Int = 0) {
        let message = message().output.map { timeSince + " V".bold + " \($0)".padded(by: indent) }
            .joined(separator: "\n")
        print(message)
    }
}

private extension DispatchTimeInterval {
    var milliseconds: Int {
        switch self {
        case let .nanoseconds(time): return time / 1000_000
        case let .microseconds(time): return time / 1000
        case let .milliseconds(time): return time
        case let .seconds(time): return time * 1000
        case .never: fallthrough
        @unknown default: return 0
        }
    }
}
