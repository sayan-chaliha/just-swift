//
//  File: ArgumentDefinition.swift
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

struct ArgumentDefinition {
    enum Kind: Equatable {
        case named
        case namedExpectingValue
        case positional
    }

    struct Options: OptionSet {
        let rawValue: Int

        static let isOptional = Options(rawValue: 1 << 0)
        static let isRepeating = Options(rawValue: 1 << 1)
    }

    let name: String
    let alias: Character?
    let inversionPrefix: InversionPrefix
    let type: ExpressibleByArgument.Type
    let kind: Kind
    let defaultValue: ExpressibleByArgument?
    let options: Options
    let help: ArgumentHelp

    init<Argument: ExpressibleByArgument>(
        name: String,
        alias: Character? = nil,
        inversionPrefix: InversionPrefix = .none,
        type: Argument.Type,
        help: ArgumentHelp,
        kind: Kind,
        defaultValue: Argument? = nil,
        options: Options = []
    ) {
        self.name = name
        self.alias = alias
        self.inversionPrefix = inversionPrefix
        self.type = type
        self.help = help
        self.kind = kind
        self.defaultValue = defaultValue

        if type is Repeating.Type {
            self.options = options.union(.isRepeating)
        } else {
            self.options = options
        }
    }
}

struct Command {
    let name: String
    let help: ArgumentHelp
    let arguments: Arguments
}

extension ArgumentDefinition: CustomStringConvertible {
    var description: String {
        "\(name) [\(kind)]"
    }
}

extension ArgumentDefinition {
    var isRepeating: Bool { options.contains(.isRepeating) }

    var isRepeatingPositional: Bool {
        options.contains(.isRepeating) && kind == .positional
    }

    var isPositional: Bool { kind == .positional }

    var isRequired: Bool { !options.contains(.isOptional) }
}

extension ArgumentDefinition.Kind: CustomStringConvertible {
    var description: String {
        switch self {
        case .positional: return "positional"
        case .namedExpectingValue: return "optional"
        case .named: return "boolean"
        }
    }
}
