//
//  File: ArgumentBuilder.swift
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

/// Allows configuration of command line arguments
/// expected by the application.
///
/// Arguments can be options that can take values, for example
/// `--foo=bar` or `-f bar`, or flags which are boolean values,
/// for example `--foo`, `--enable-foo`, or `-f`.
///
/// Additionally, positionals allow for consuming values specified on the
/// command line, for example `./cli foo bar` translates into two
/// positionals with values `foo` and `bar`.
public protocol ArgumentBuilder {
    @discardableResult
    func positional<Argument: ExpressibleByArgument>(
        _ name: String,
        type: Argument.Type,
        help: ArgumentHelp,
        required: Bool
    ) -> Self

    @discardableResult
    // swiftlint:disable:next function_parameter_count
    func option<Argument: ExpressibleByArgument>(
        _ name: String,
        alias: Character?,
        type: Argument.Type,
        help: ArgumentHelp,
        required: Bool,
        default: Argument?
    ) -> Self

    @discardableResult
    func flag(
        _ name: String,
        inversionPrefix: InversionPrefix,
        alias: Character?,
        help: ArgumentHelp,
        default: Bool
    ) -> Self
}

extension ArgumentBuilder {
    @discardableResult
    public func option<Argument: ExpressibleByArgument>(
        _ name: String,
        alias: Character? = nil,
        type: Argument.Type,
        help: ArgumentHelp,
        required: Bool = false,
        default: Argument? = nil
    ) -> Self {
        option(
            name,
            alias: alias,
            type: type,
            help: help,
            required: required,
            default: `default`
        )
    }

    @discardableResult
    public func flag(
        _ name: String,
        inversionPrefix: InversionPrefix = .none,
        alias: Character? = nil,
        help: ArgumentHelp,
        default: Bool = false
    ) -> Self {
        flag(
            name,
            inversionPrefix: inversionPrefix,
            alias: alias,
            help: help,
            default: `default`
        )
    }

    @discardableResult
    public func positional<Argument: ExpressibleByArgument>(
        _ name: String,
        type: Argument.Type,
        help: ArgumentHelp,
        required: Bool = false
    ) -> Self {
        positional(name, type: type, help: help, required: required)
    }
}

/// Defines how to render a flag name.
public enum InversionPrefix {
    /// Render flag name as is. Appearance of
    /// the flag implies a `true` value.
    case none

    /// Inversions are prefixed with `--enable-*` or
    /// `--disable-*`.
    case enableDisable

    /// The negative inversion is rendered as `--no-*`.
    case no
}
