//
//  File: ArgumentHelp.swift
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

import AppKit

public struct ArgumentHelp {
    public enum Visibility: Equatable {
        case `default`
        case visible
        case hidden
        case `private`
    }

    let synopsis: String
    let visibility: Visibility

    public init(_ synopsis: String, visibility: Visibility = .default) {
        self.synopsis = synopsis
        self.visibility = visibility
    }
}

extension ArgumentHelp: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.synopsis = value
        self.visibility = .default
    }
}

extension ArgumentHelp {
    private init(visibility: Visibility) {
        self.synopsis = ""
        self.visibility = visibility
    }

    static let hidden = ArgumentHelp(visibility: .hidden)
    static let `private` = ArgumentHelp(visibility: .private)
}

extension ArgumentDefinition {
    private var unadornedUsage: String {
        var usageString: String

        switch kind {
        case .named:
            switch inversionPrefix {
            case .none:
                usageString = "--\(name)"
            case .enableDisable:
                usageString = "--enable-\(name)|--disable-\(name)"
            case .no:
                usageString = "--\(name)|--no-\(name)"
            }
        case .namedExpectingValue:
            usageString = "--\(name)=<\(name)>"
        case .positional:
            usageString = "<\(name)>"
        }

        return usageString
    }

    var usage: String {
        guard help.visibility == .visible || help.visibility == .default else { return "" }

        var usage: String = unadornedUsage

        if options.contains(.isRepeating) {
            usage += " ..."
        }

        if options.contains(.isOptional) {
            usage = "[\(usage)]"
        }

        return usage
    }

    var label: String {
        var aliasString: String = ""
        if let alias = alias { aliasString = "-\(alias), " }
        return "\(aliasString)\(unadornedUsage)"
    }
}
