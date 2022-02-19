//
//  File: ExpressibleByArgument.swift
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

public protocol ExpressibleByArgument {
    init?(_: String)
    static var possibleValues: [String] { get }
}

extension ExpressibleByArgument {
    public static var possibleValues: [String] { [] }
}

extension ExpressibleByArgument where Self: CaseIterable {
    public static var possibleValues: [String] { allCases.map { String(describing: $0) } }
}

extension ExpressibleByArgument where Self: CaseIterable, Self: RawRepresentable, RawValue == String {
    public static var possibleValues: [String] { allCases.map { $0.rawValue} }
}

extension RawRepresentable where Self: ExpressibleByArgument, RawValue: ExpressibleByArgument {
    public init?(argument: String) {
        guard let value = RawValue(argument) else { return nil }
        self.init(rawValue: value)
    }
}

extension String: ExpressibleByArgument {
    public init?(_ argument: String) { self = argument }
}

extension Int: ExpressibleByArgument {}
extension Int8: ExpressibleByArgument {}
extension Int16: ExpressibleByArgument {}
extension Int32: ExpressibleByArgument {}
extension Int64: ExpressibleByArgument {}
extension UInt: ExpressibleByArgument {}
extension UInt8: ExpressibleByArgument {}
extension UInt16: ExpressibleByArgument {}
extension UInt32: ExpressibleByArgument {}
extension UInt64: ExpressibleByArgument {}
extension Float: ExpressibleByArgument {}
extension Double: ExpressibleByArgument {}
extension Bool: ExpressibleByArgument {}

protocol Repeating {
    mutating func append(parsing: String) -> Bool
}

extension Array: ExpressibleByArgument, Repeating where Element: ExpressibleByArgument {
    public init?(_ argument: String) {
        self = .init()
        guard append(parsing: argument) else { return nil }
    }

    public mutating func append(parsing argument: String) -> Bool {
        if argument.contains(",") {
            var elements = [Element]()
            for var arg in argument.components(separatedBy: ",") {
                arg = arg.trimmingCharacters(in: .whitespaces)
                guard let element = Element(arg) else { return false }
                elements.append(element)
            }
            append(contentsOf: elements)
        } else {
            let arg = argument.trimmingCharacters(in: .whitespaces)
            guard let element = Element(arg) else { return false }
            append(element)
        }

        return true
    }
}
