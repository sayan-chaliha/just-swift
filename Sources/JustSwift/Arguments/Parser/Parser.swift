//
//  File: Parser.swift
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

@dynamicMemberLookup
public struct ParsedValues {
    public let command: String?
    public let options: [String: ExpressibleByArgument]
    public let data: String?

    public subscript<T: ExpressibleByArgument>(dynamicMember member: String) -> T? {
        return options[member] as? T
    }
}

extension ParsedValues: CustomStringConvertible {
    public var description: String {
        "Command: \(command ?? "<none>")\n" +
            "Options:\n" +
            options.map { (name, value) -> String in
                "\(name) = \(value) [\(type(of: value))]".padded(by: 4)
            }.joined(separator: "\n") +
            "\nData: \(data ?? "<empty>")"
    }
}

struct Parser {
    private let arguments: Arguments
    private let parsedArguments: ParsedArguments

    init(
        arguments: Arguments,
        commandLineArguments: [String] = CommandLine.arguments
    ) throws {
        precondition(!commandLineArguments.isEmpty, "Command line arguments should at least have the binary name.")
        self.arguments = arguments
        self.parsedArguments = try ParsedArguments(commandLineArguments: commandLineArguments.dropFirst())
    }
}

// MARK: Parsing

extension Parser {
    public func parse(helpKey: String = "help") throws -> ParsedValues {
        var parsedArguments = parsedArguments
        var parsedValues = [String: ExpressibleByArgument]()

        var command: Command?
        do {
            // Check if we have any commands configured ...
            command = try Parser.parseCommand(arguments, from: &parsedArguments)
            if let command = command {
                // ... if we do, descend into it for parsing.
                let commandParsedValues = try Parser.lenientParse(command.arguments, &parsedArguments)
                parsedValues.merge(commandParsedValues, uniquingKeysWith: { _, value in value })
            }

            let globalParsedValues = try Parser.lenientParse(arguments, &parsedArguments)
            parsedValues.merge(globalParsedValues, uniquingKeysWith: { value, _ in value })

            let data = Parser.parseData(from: &parsedArguments)

            guard parsedArguments.isEmpty else {
                throw ParserError.unknownArguments(parsedArguments.elements.map(\.description))
            }

            let missingArgs = arguments.definitions.filter(\.isRequired)
                .filter { parsedValues[$0.name] == nil }
                .map(\.name)

            guard missingArgs.isEmpty else {
                throw ParserError.missingValueForOptions(missingArgs)
            }

            if hasOption(forKey: helpKey, parsedArguments: parsedArguments, parsedValues: Array(parsedValues.keys)) {
                throw ParserError.parseError(command, .helpRequested)
            }

            return .init(command: command?.name, options: parsedValues, data: data)
        } catch let error as ParserError {
            if case .parseError = error { throw error }

            if hasOption(forKey: helpKey, parsedArguments: parsedArguments, parsedValues: Array(parsedValues.keys)) {
                throw ParserError.parseError(command, .helpRequested)
            }

            throw ParserError.parseError(command, error)
        }
    }

    // swiftlint:disable:next function_body_length
    private static func lenientParse(
        _ arguments: Arguments,
        _ parsedArgs: inout ParsedArguments
    ) throws -> [String: ExpressibleByArgument] {
        var args = parsedArgs
        var parsedValues = [String: ExpressibleByArgument]()
        var allUsedIndices = [ParsedArguments.Index]()

        // swiftlint:disable:next cyclomatic_complexity
        func parseOne(
            _ def: ArgumentDefinition,
            _ arg: ParsedArgument,
            _ index: ParsedArguments.Index,
            _ args: ParsedArguments,
            _ parsedValues: inout [String: ExpressibleByArgument]
        ) throws -> [ParsedArguments.Index] {
            var args = args
            var usedIndices = [ParsedArguments.Index]()
            switch def.kind {
            case .named:
                guard parsedValues[def.name] == nil else { throw ParserError.duplicateOption(def.name) }

                var value: Bool = true
                if let argValueStr = arg.value {
                    guard let argValue = Bool(argValueStr) else {
                        throw ParserError.unexpectedValueForOption(def.name, argValueStr)
                    }
                    value = argValue
                }

                parsedValues[def.name] = value
                usedIndices.append(index)
            case .namedExpectingValue:
                let value: String
                if let argValue = arg.value {
                    value = argValue
                } else if let (nextIndex, next) = args.popNext(), next.isValue, let valueStr = next.value.valueString {
                    value = valueStr
                    usedIndices.append(nextIndex)
                } else {
                    throw ParserError.missingValueForOptions([def.name])
                }

                if var repeating = parsedValues[def.name] as? Repeating {
                    guard repeating.append(parsing: value) else {
                        throw ParserError.unexpectedValueForOption(def.name, value)
                    }
                    parsedValues[def.name] = repeating as? ExpressibleByArgument
                } else {
                    guard (!def.isRepeating && parsedValues[def.name] == nil),
                          let element = def.type.init(value)
                    else {
                        throw ParserError.unexpectedValueForOption(def.name, value)
                    }

                    parsedValues[def.name] = element
                }

                usedIndices.append(index)
            case .positional:
                // Will parse positionals later.
                break
            }

            return usedIndices
        }

        while let (index, next) = args.popNext() {
            var usedIndices = [ParsedArguments.Index]()
            defer { allUsedIndices.append(contentsOf: usedIndices) }

            switch next.value {
            case let .option(arg):
                guard let def = arguments.first(matching: arg) else { continue }
                usedIndices.append(contentsOf: try parseOne(def, arg, index, args, &parsedValues))
            case .terminator:
                break
            case .value:
                // Will parse positionals later.
                break
            }
        }

        parsedArgs.removeAll(in: allUsedIndices)
        try parsePositionals(arguments, from: &parsedArgs, into: &parsedValues)

        arguments.definitions.forEach { def in
            if parsedValues[def.name] == nil, let defaultValue = def.defaultValue {
                parsedValues[def.name] = defaultValue
            }
        }

        return parsedValues
    }

    private static func parseCommand(
        _ arguments: Arguments,
        from parsedArgs: inout ParsedArguments
    ) throws -> Command? {
        guard !arguments.commands.isEmpty else { return nil }

        var args = parsedArgs
        var usedIndex: ParsedArguments.Index?
        defer { usedIndex.let { parsedArgs.removeAll(in: [$0]) } }

        while args.peekNext()?.1.isValue == false {
            _ = args.popNext()
        }

        guard let arg = args.popNext(), arg.1.isValue else { return nil }
        if let command = arguments.commands.first(where: { $0.name == arg.1.value.valueString }) {
            usedIndex = arg.0
            return command
        }
        throw ParserError.unknownCommand(arg.1.value.valueString!)
    }

    private static func parsePositionals(
        _ arguments: Arguments,
        from parsedArgs: inout ParsedArguments,
        into parsedValues: inout [String: ExpressibleByArgument]
    ) throws {
        guard !parsedArgs.isEmpty else { return }

        var usedIndices = [ParsedArguments.Index]()
        defer { parsedArgs.removeAll(in: usedIndices) }

        var args = parsedArgs

        func skipNonValues() {
            while args.peekNext()?.1.isValue == false {
                _ = args.popNext()
            }
        }

        func next() -> (ParsedArguments.Index, ParsedArguments.Element)? {
            skipNonValues()
            return args.popNext()
        }

        ArgumentLoop:
        for def in arguments.definitions {
            guard case .positional = def.kind else { continue }
            repeat {
                guard let (index, arg) = next() else {
                    break ArgumentLoop
                }

                guard let value = arg.value.valueString else {
                    fatalError("Value expected for `.value` argument.")
                }

                if var repeating = parsedValues[def.name] as? Repeating {
                    guard repeating.append(parsing: value) else {
                        throw ParserError.unexpectedValueForOption(def.name, value)
                    }
                    parsedValues[def.name] = repeating as? ExpressibleByArgument
                } else {
                    guard def.isRepeating || parsedValues[def.name] == nil, let element = def.type.init(value) else {
                        throw ParserError.unexpectedValueForOption(def.name, value)
                    }

                    parsedValues[def.name] = element
                }

                usedIndices.append(index)
            } while def.isRepeatingPositional
        }
    }

    private static func parseData(from parsedArgs: inout ParsedArguments) -> String? {
        var args = parsedArgs
        var usedIndices = [ParsedArguments.Index]()
        var data = [String]()
        defer { parsedArgs.removeAll(in: usedIndices) }

        var isData = false
        while let (index, next) = args.popNext() {
            if isData {
                usedIndices.append(index)
                data.append(args.originalInput(at: index))
                continue
            }

            switch next.value {
            case .terminator:
                usedIndices.append(index)
                isData = true
            default:
                continue
            }
        }

        return data.isEmpty ? nil : data.joined(separator: " ")
    }

    private func hasOption(forKey key: String, parsedArguments: ParsedArguments, parsedValues: [String]) -> Bool {
        guard let def = arguments.definitions.first(where: { $0.name == key }), !def.isPositional else {
            return false
        }

        if parsedValues.contains(key) {
            return true
        }

        for element in parsedArguments.elements {
            switch element.value {
            case let .option(arg):
                switch arg.name {
                case let .long(name):
                    guard def.name == name else { break }
                    return true
                case let .short(alias):
                    guard def.alias == alias else { break }
                    return true
                default:
                    break
                }
            default:
                break
            }
        }

        return false
    }
}

extension Arguments {
    func first(matching parsed: ParsedArgument) -> ArgumentDefinition? {
        switch parsed {
        case let .name(name), let .nameWithValue(name, _):
            switch name {
            case let .long(long):
                return definitions.first(where: { $0.name == long })
            case let .short(alias): return definitions.first(where: { $0.alias == alias })
            }
        }
    }
}
