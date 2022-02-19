//
//  File: Arguments.swift
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

public class Arguments {
    var definitions: [ArgumentDefinition] = []
    var commands: [Command] = []

    public init() {}
}

// MARK: Builder

extension Arguments: ArgumentBuilder {
    @discardableResult
    public func option<Argument: ExpressibleByArgument>(
        _ name: String,
        alias: Character? = nil,
        type: Argument.Type,
        help: ArgumentHelp,
        required: Bool = false,
        default: Argument? = nil
    ) -> Self {
        definitions.append(.init(
            name: name,
            alias: alias,
            type: type,
            help: help,
            kind: .namedExpectingValue,
            defaultValue: `default`,
            options: required ? .init() : .isOptional
        ))

        return self
    }

    @discardableResult
    public func flag(
        _ name: String,
        inversionPrefix: InversionPrefix = .none,
        alias: Character? = nil,
        help: ArgumentHelp,
        default: Bool = false
    ) -> Self {
        definitions.append(.init(
            name: name,
            alias: alias,
            inversionPrefix: inversionPrefix,
            type: Bool.self,
            help: help,
            kind: .named,
            defaultValue: `default`,
            options: .isOptional
        ))

        return self
    }

    @discardableResult
    public func positional<Argument: ExpressibleByArgument>(
        _ name: String,
        type: Argument.Type,
        help: ArgumentHelp,
        required: Bool = false
    ) -> Self {
        var options = ArgumentDefinition.Options()

        if !required { options.update(with: .isOptional) }

        definitions.append(.init(
            name: name,
            type: type,
            help: help,
            kind: .positional,
            defaultValue: nil,
            options: options
        ))

        return self
    }

    @discardableResult
    public func command(
        _ name: String,
        help: ArgumentHelp,
        argumentBuilder: ((inout ArgumentBuilder) -> Void)? = nil
    ) -> Self {
        let arguments = Arguments()

        argumentBuilder.let { argumentBuilder in
            var builder = arguments as ArgumentBuilder
            argumentBuilder(&builder)
        }

        commands.append(.init(name: name, help: help, arguments: arguments))

        return self
    }
}

// MARK: Validator

extension Arguments {
    private static let validators: [ArgumentValidator.Type] = [
        PositionalArgumentValidator.self,
        NameArgumentValidator.self,
        DuplicateNameArgumentValidator.self
    ]

    private func validate() throws {
        let passed = Arguments.validators.map { validator -> Bool in
            var errors: [ArgumentValidatorError] = []

            validator.validate(definitions).let { errors.append($0) }
            validator.validate(commands).let { errors.append($0) }

            guard !errors.isEmpty else { return true }

            errors.forEach { error in
                if error.kind == .warning {
                    console.warn("\(error)")
                } else {
                    console.error("\(error)")
                }
            }

            return !errors.contains(where: { $0.kind == .failure })
        }.reduce(into: true, { finalResult, result in
            finalResult = finalResult && result
        })

        guard passed else { throw ArgumentBuilderError.validationFailed }
    }
}

// MARK: Parser

extension Arguments {
    static let builtInOptions: [ArgumentDefinition] = [
        .init(
            name: "help",
            alias: "h",
            type: Bool.self,
            help: .init("Show help information", visibility: .hidden),
            kind: .named,
            options: .isOptional
        )
    ]

    public func parse() throws -> ParsedValues {
        // Add built-in options.
        definitions.append(contentsOf: Arguments.builtInOptions)

        // Validate.
        try validate()

        do {
            return try Parser(arguments: self).parse(helpKey: "help")
        } catch let error as ParserError {
            guard case let .parseError(command, underlyingError) = error else {
                throw error
            }

            let helpRenderer = HelpRenderer(self, command)

            switch underlyingError {
            case .helpRequested:
                print(helpRenderer.renderHelp())
                exit(0)
            default:
                print(helpRenderer.renderError(error: underlyingError))
                exit(-1)
            }
        }
    }
}
