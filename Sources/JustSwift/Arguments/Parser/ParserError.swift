//
//  File: ParserError.swift
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

indirect enum ParserError: ArgumentError {
    case invalidOption(String)
    case unexpectedValueForOption(String, String)
    case missingValueForOptions([String])
    case duplicateOption(String)
    case unknownCommand(String)
    case unknownArguments([String])
    case helpRequested

    case parseError(Command?, ParserError)
}

extension ParserError: CustomStringConvertible {
    var description: String {
        switch self {
        case let .invalidOption(option): return "Invalid option `\(option)`"
        case let .unexpectedValueForOption(name, value): return "Invalid value `\(value)` for option `\(name)`"
        case let .missingValueForOptions(options): return "Missing values for \(options.joined(separator: ", "))"
        case let .duplicateOption(option): return "`\(option)` specified more than once"
        case let .unknownCommand(command): return "Unknown command `\(command)`"
        case let .unknownArguments(args): return "Unknown arguments: \(args.joined(separator: ", "))"
        default: return ""
        }
    }
}
