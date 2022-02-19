//
//  File: HelpRenderer.swift
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

protocol Renderable {
    func rendered(screenWidth: Int) -> String
}

struct HelpRenderer {
    struct Options: OptionSet {
        let rawValue: Int

        static let colorize = Options(rawValue: 1 << 0)
    }

    struct Section {
        enum Header: Equatable {
            case positional
            case commands
            case options
            case usage
            case description
        }

        struct Element {
            let label: String
            let synopsis: String
        }

        let header: Header
        let elements: [Renderable]
    }

    private let command: Command?
    private let arguments: Arguments

    init(_ args: Arguments? = nil, _ cmd: Command? = nil) {
        precondition(args != nil || cmd != nil, "Either arguments or command must be non-nil")

        self.arguments = cmd?.arguments ?? args!
        self.command = cmd
    }
}

extension HelpRenderer {
    private var commandName: String {
        if let name = command?.name {
            return " \(name)"
        }
        return ""
    }

    private var binaryName: String {
        "\(CommandLine.binary.bold.white)\(commandName) "
    }

    func renderUsage(screenWidth: Int = console.size.width) -> String {
        "USAGE: \(binaryName)" +
            (!arguments.commands.isEmpty ? "<command> " : "") +
            arguments.definitions.map(\.usage).joined(separator: " ").wrapped(to: screenWidth, wrappingIndent: 0)
    }

    func renderHelp(screenWidth: Int = console.size.width) -> String {
        let usage = "USAGE\n".yellow.bold +
            (binaryName + (!arguments.commands.isEmpty ? "<command> " : "")  +
                arguments.definitions.map(\.usage).joined(separator: " ")).wrapped(to: screenWidth, wrappingIndent: 2)

        let sections = Section.generate(from: arguments, command: command)

        return """
        \(usage)

        \(sections.map { $0.rendered(screenWidth: screenWidth) }.joined(separator: "\n"))
        """
    }

    func renderError(screenWidth: Int = console.size.width, error: ParserError) -> String {
        """
        ERROR: \(error)
        \(renderUsage(screenWidth: screenWidth))
          See `\(CommandLine.binary) \(command?.name ?? "") --help` for more information.
        """
    }
}

extension HelpRenderer.Section {
    func rendered(screenWidth: Int = console.size.width) -> String {
        guard !elements.isEmpty else { return "" }

        let rendered = elements.map { $0.rendered(screenWidth: screenWidth) }.joined(separator: "\n")
        return "\(String(describing: header).uppercased().yellow.bold)\n\(rendered)\n"
    }
}

extension HelpRenderer.Section {
    static func generate(from args: Arguments, command: Command? = nil) -> [HelpRenderer.Section] {
        var sections = [HelpRenderer.Section]()
        let options = args.definitions.filter { $0.kind == .named || $0.kind == .namedExpectingValue }
            .filter { $0.help.visibility != .private}
        let arguments = args.definitions.filter { $0.kind == .positional }.filter { $0.help.visibility != .private }
        let commands = args.commands.filter { $0.help.visibility != .private }

        if let command = command {
            sections.append(
                .init(header: .description, elements: [command.help.synopsis])
            )
        }

        if !arguments.isEmpty {
            sections.append(
                .init(
                    header: .positional,
                    elements: arguments.map { def in
                        let defaultValue = def.defaultValue.flatMap {
                            " (default: \(String(describing: $0).bold.white)"
                        } ?? ""
                        let possibleValues: String = {
                            guard !def.type.possibleValues.isEmpty else { return "" }
                            return " (choices: " +
                                "\(def.type.possibleValues.map { $0.white.bold }.joined(separator: ", ")))"
                        }()

                        return Element(label: def.label, synopsis: def.help.synopsis + possibleValues + defaultValue)
                    }
                )
            )
        }

        sections.append(
            .init(
                header: .options,
                elements: options.map { def in
                    let defaultValue = def.defaultValue.flatMap {
                        " (default: \(String(describing: $0).bold.white))"
                    } ?? ""
                    let possibleValues: String = {
                        guard !def.type.possibleValues.isEmpty else { return "" }
                        return " (choices: \(def.type.possibleValues.map { $0.white.bold }.joined(separator: ", ")))"
                    }()

                    return Element(label: def.label, synopsis: def.help.synopsis + possibleValues + defaultValue)
                }
            )
        )

        if !commands.isEmpty {
            sections.append(
                .init(
                    header: .commands,
                    elements: commands.map { cmd in Element(label: cmd.name, synopsis: cmd.help.synopsis) }
                )
            )
        }

        return sections
    }
}

extension HelpRenderer.Section.Header: CustomStringConvertible {
    var description: String {
        switch self {
        case .positional: return "Arguments"
        case .options: return "Options"
        case .commands: return "Commands"
        case .usage: return "Usage"
        case .description: return "Description"
        }
    }
}

extension HelpRenderer.Section.Element: Renderable {
    func rendered(screenWidth: Int = console.size.width) -> String {
        let synopsisColumn = 26
        let label = label.padded(by: 2)
        let synopsis = synopsis.wrapped(to: screenWidth, wrappingIndent: synopsisColumn)
        let renderedSynopsis: String = {
            if synopsis.isEmpty { return "" }
            if label.count < synopsisColumn {
                return String(synopsis.dropFirst(label.count))
            } else {
                return "\n" + synopsis
            }
        }()
        return label.white.bold + renderedSynopsis
    }
}

extension String: Renderable {
    func rendered(screenWidth: Int = console.size.width) -> String {
        wrapped(to: screenWidth, wrappingIndent: 2)
    }
}
