//
//  File: ParsedArgument.swift
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

enum Name {
    /// Multi-character name prefixed with `--`.
    case long(String)

    /// Single character name prefixed with `-`.
    case short(Character)
}

extension Name {
    init?<S: StringProtocol>(fromArgument baseName: S) where S.SubSequence == Substring {
        guard baseName.starts(with: "-") else { return nil }

        if baseName.starts(with: "--") {
            self = .long(String(baseName.dropFirst(2)))
        } else if baseName.count == 2, let character = baseName.last {
            self = .short(character)
        } else {
            return nil
        }
    }
}

extension Name: Equatable {}
extension Name: Hashable {}

extension Name: CustomStringConvertible {
    var description: String {
        switch self {
        case let .long(name): return "--\(name)"
        case let .short(character): return "-\(character)"
        }
    }
}

enum ParsedArgument {
    /// `--option` or `-f`.
    case name(Name)

    /// `--option=value`.
    case nameWithValue(Name, String)
}

extension ParsedArgument {
    init?<S: StringProtocol>(_ argument: S) where S.SubSequence == Substring {
        let enable = "--enable-"
        let disable = "--disable-"
        let no = "--no-"

        let indexOfEqualSign = argument.firstIndex(of: "=") ?? argument.endIndex
        var (baseName, value) = (argument[..<indexOfEqualSign], argument[indexOfEqualSign...].dropFirst())

        if baseName.hasPrefix(enable) {
            guard value.isEmpty else { return nil }
            baseName = "--\(baseName.dropFirst(enable.count))"
            value = "true"
        } else if baseName.hasPrefix(disable) {
            guard value.isEmpty else { return nil }
            baseName = "--\(baseName.dropFirst(disable.count))"
            value = "false"
        } else if baseName.hasPrefix(no) {
            guard value.isEmpty else { return nil }
            baseName = "--\(baseName.dropFirst(no.count))"
            value = "false"
        }

        guard let name = Name(fromArgument: baseName) else { return nil }

        self = value.isEmpty
            ? .name(name)
            : .nameWithValue(name, String(value))
    }

    var name: Name? {
        switch self {
        case let .name(name): return name
        case let .nameWithValue(name, _): return name
        }
    }

    var value: String? {
        switch self {
        case .name: return nil
        case let .nameWithValue(_, value): return value
        }
    }
}

extension ParsedArgument: CustomStringConvertible {
    var description: String {
        switch self {
        case let .name(name): return name.description
        case let .nameWithValue(name, value): return "\(name)=\(value)"
        }
    }
}

struct ParsedArguments {
    struct Element {
        enum Value {
            case option(ParsedArgument)
            case value(String)
            case terminator

            var valueString: String? {
                switch self {
                case .option, .terminator: return nil
                case let .value(str): return str
                }
            }
        }

        let value: Value
        let index: Index

        static func option(_ arg: ParsedArgument, index: Index) -> Element {
            Element(value: .option(arg), index: index)
        }

        static func value(_ str: String, index: Index) -> Element {
            Element(value: .value(str), index: index)
        }

        static func terminator(index: Index) -> Element {
            Element(value: .terminator, index: index)
        }
    }

    /// Represents an index into the original input.
    struct Index: RawRepresentable, Hashable, Comparable {
        let rawValue: Int

        static func < (lhs: Index, rhs: Index) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    private var _elements: [Element] = []
    private var firstUnused: Int = 0
    private var originalInput: [String]

    var elements: ArraySlice<Element> {
        _elements[firstUnused...]
    }
}

extension ParsedArguments.Element {
    var isValue: Bool {
        switch value {
        case .value: return true
        case .option, .terminator: return false
        }
    }

    var isTerminator: Bool {
        switch value {
        case .terminator: return true
        case .value, .option: return false
        }
    }
}

extension ParsedArguments.Element: CustomStringConvertible {
    var description: String {
        switch value {
        case let .option(arg): return String(describing: arg)
        case let .value(value): return value
        case .terminator: return "--"
        }
    }
}

extension ParsedArguments {
    init(commandLineArguments: ArraySlice<String> = CommandLine.arguments.dropFirst()) throws {
        self.originalInput = Array(commandLineArguments)

        var position = 0
        var args = commandLineArguments[...]

        while let arg = args.popFirst() {
            defer { position += 1 }

            let element = try ParsedArguments.parseOne(argument: arg, at: position)
            _elements.append(element)

            if element.isTerminator {
                break
            }
        }

        for arg in args {
            defer { position += 1 }
            _elements.append(.value(arg, index: Index(rawValue: position)))
        }
    }

    private static func parseOne(argument arg: String, at position: Int) throws -> Element {
        let index = ParsedArguments.Index(rawValue: position)
        if let nonDashIndex = arg.firstIndex(where: { $0 != "-" }) {
            let dashCount = arg.distance(from: arg.startIndex, to: nonDashIndex)
            switch dashCount {
            case 0: return .value(arg, index: index)
            default:
                guard let parsedArgument = ParsedArgument(arg) else { throw ParserError.invalidOption(arg) }
                return .option(parsedArgument, index: index)
            }
        } else {
            let dashCount = arg.count
            switch dashCount {
            case 0, 1: return .value(arg, index: index)
            case 2: return .terminator(index: index)
            default: throw ParserError.invalidOption(arg)
            }
        }
    }
}

extension ParsedArguments {
    var isEmpty: Bool { elements.isEmpty }

    func position(after origin: Index) -> Int? {
        return elements.firstIndex(where: { $0.index > origin })
    }

    func originalInput(at position: Index) -> String {
        return originalInput[position.rawValue]
    }

    mutating func popNext() -> (Index, Element)? {
        guard let element = elements.first else { return nil }
        removeFirst()
        return (element.index, element)
    }

    func peekNext() -> (Index, Element)? {
        guard let element = elements.first else { return nil }
        return (element.index, element)
    }

    mutating func popNextIfValue(after origin: Index) -> (Index, String)? {
        guard let start = position(after: origin) else { return nil }
        let element = elements[start]
        guard case let .value(value) = element.value else { return nil }

        defer { remove(at: start) }

        return (element.index, value)
    }

    mutating func removeFirst() {
        firstUnused += 1
    }

    mutating func remove(at position: Int) {
        guard position >= firstUnused else { return }

        for idx in (firstUnused..<position).reversed() {
            _elements[idx + 1] = _elements[idx]
        }
        firstUnused += 1
    }

    mutating func remove(subrange: Range<Int>) {
        var lo = subrange.startIndex
        var hi = subrange.endIndex

        while lo > firstUnused {
            hi -= 1
            lo -= 1
            _elements[hi] = _elements[lo]
        }

        firstUnused += subrange.count
    }

    mutating func remove(at position: Index) {
        guard !isEmpty else { return }

        var start = elements.startIndex
        while start < elements.endIndex {
            if elements[start].index == position { break }
            if elements[start].index > position { break }
            start += 1
        }
        guard start < elements.endIndex else { return }
        let end = elements[start...].firstIndex(where: { $0.index != position }) ?? elements.endIndex

        remove(subrange: start ..< end)
    }

    mutating func removeAll(in indices: [Index]) {
        indices.forEach { remove(at: $0) }
    }
}

extension ParsedArguments.Index: CustomStringConvertible {
    var description: String { "\(rawValue)" }
}

extension ParsedArguments: CustomStringConvertible {
    var description: String {
        guard !isEmpty else { return "<empty>" }
        return elements.map { element -> String in
            switch element.value {
            case let .option(argument): return "[\(element.index)] \(argument)"
            case let .value(value): return "[\(element.index)] \(value)"
            case .terminator: return "[\(element.index)] --"
            }
        }
        .joined(separator: "\n")
    }
}
