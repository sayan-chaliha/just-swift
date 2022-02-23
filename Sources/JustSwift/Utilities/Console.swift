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

// case `default` = 0
// case bold = 1
// case dim = 2
// case italic = 3
// case underline = 4
// case blink = 5
// case swap = 7
// case strikethrough = 9

// case black = 30
// case red
// case green
// case yellow
// case blue
// case magenta
// case cyan
// case white
// case `default` = 39
// case lightBlack = 90
// case lightRed
// case lightGreen
// case lightYellow
// case lightBlue
// case lightMagenta
// case lightCyan
// case lightWhite

public struct ConsoleTextDecoration: OptionSet, Hashable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let `default` = ConsoleTextDecoration(rawValue: 1 << 0)
    public static let bold = ConsoleTextDecoration(rawValue: 1 << 1)
    public static let dim = ConsoleTextDecoration(rawValue: 1 << 2)
    public static let italic = ConsoleTextDecoration(rawValue: 1 << 3)
    public static let underline = ConsoleTextDecoration(rawValue: 1 << 4)
    public static let blink = ConsoleTextDecoration(rawValue: 1 << 5)
    public static let swap = ConsoleTextDecoration(rawValue: 1 << 6)
    public static let strikethrough = ConsoleTextDecoration(rawValue: 1 << 7)
}

extension ConsoleTextDecoration: ModeCode {
    private static let translations: [ConsoleTextDecoration: Style] = [
        .default: .default,
        .bold: .bold,
        .blink: .blink,
        .dim: .dim,
        .italic: .italic,
        .strikethrough: .strikethrough,
        .swap: .swap,
        .underline: .underline
    ]

    public var value: [UInt8] {
        ConsoleTextDecoration.translations.flatMap { (option, style) -> [UInt8] in
            if contains(option) { return style.value } else { return [] }
        }
    }
}

struct ConsoleTextFragment {
    let output: String
    let color: Color?
    let decoration: ConsoleTextDecoration

    init(
        output: String,
        color: Color? = nil,
        decoration: ConsoleTextDecoration = []
    ) {
        self.output = output
        self.color = color
        self.decoration = decoration
    }
}

public struct ConsoleLogInterpolation: StringInterpolationProtocol {
    public typealias StringLiteralType = String

    var consoleTextFragments: [ConsoleTextFragment] = []

    public init(literalCapacity: Int, interpolationCount: Int) {
        self.consoleTextFragments.reserveCapacity(literalCapacity * 2)
    }

    public mutating func appendLiteral(_ literal: StringLiteralType) {
        consoleTextFragments.append(.init(output: literal))
    }

    public mutating func appendInterpolation(_ error: Error) {
        consoleTextFragments.append(.init(output: String(describing: error), color: .red, decoration: .bold))
    }

    public mutating func appendInterpolation(
        _ string: String,
        _ color: Color? = nil,
        _ decoration: ConsoleTextDecoration = .bold
    ) {
        consoleTextFragments.append(.init(output: string, color: color, decoration: decoration))
    }

    public mutating func appendInterpolation(
        _ url: URL,
        _ color: Color = .white,
        _ decoration: ConsoleTextDecoration = .bold
    ) {
        if url.isFileURL {
            consoleTextFragments.append(.init(output: url.relativePath, color: color, decoration: decoration))
        } else {
            consoleTextFragments.append(.init(output: String(describing: url), color: color, decoration: decoration))
        }
    }

    public mutating func appendInterpolation(
        _ uint: UInt,
        _ color: Color = .white,
        _ decoration: ConsoleTextDecoration = .bold
    ) {
        consoleTextFragments.append(.init(output: String(describing: uint), color: color, decoration: decoration))
    }
}

public struct ConsoleLogMessage: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    public typealias StringLiteralType = String
    public typealias ExtendedGraphemeClusterLiteralType = String
    public typealias UnicodeScalarLiteralType = String

    var consoleTextFragments: [ConsoleTextFragment]

    public init(stringLiteral value: String) {
        consoleTextFragments = [.init(output: value)]
    }

    public init(stringInterpolation: ConsoleLogInterpolation) {
        consoleTextFragments = stringInterpolation.consoleTextFragments
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

    private func makeString(from message: ConsoleLogMessage, withPrefix prefix: String, indent: Int = 0) -> String {
        let prefix = "\(timeSince) \(prefix) "
        return message.consoleTextFragments.wrapped(to: size.width - prefix.count, wrappingIndent: indent)
            .map { prefix + $0 }
            .joined(separator: "\n")
    }

    public func info(_ message: ConsoleLogMessage, indent: Int = 0) {
        print(makeString(from: message, withPrefix: "I".cyan.bold, indent: indent))
    }

    public func error(_ message: ConsoleLogMessage, indent: Int = 0) {
        print(makeString(from: message, withPrefix: "E".red.bold, indent: indent))
    }

    public func warn(_ message: ConsoleLogMessage, indent: Int = 0) {
        print(makeString(from: message, withPrefix: "W".yellow.bold, indent: indent))
    }

    public func verbose(_ message: ConsoleLogMessage, indent: Int = 0) {
        print(makeString(from: message, withPrefix: "V".lightBlue.bold, indent: indent))
    }
}

private extension Array where Element == ConsoleTextFragment {
    func wrapped(to width: Int, wrappingIndent: Int = 0) -> [String] {
        reduce(into: "") { string, fragment in
            var output = fragment.output
            fragment.color.let { color in
                output = output.applyingColor(color)
            }
            output = output.applyingCodes(fragment.decoration)
            string += output
        }
        .split(separator: "\n")
        .map { String($0) }
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
