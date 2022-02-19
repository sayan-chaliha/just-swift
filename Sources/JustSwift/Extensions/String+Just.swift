//
//  File: String+Just.swift
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

extension String {
    func padded(by pad: Int) -> String {
        guard pad > 0 else { return self }
        return String(repeating: " ", count: pad) + self
    }

    func wrapped(to cols: Int = console.size.width, wrappingIndent: Int = 0) -> String {
        let columns = cols - wrappingIndent
        guard columns > 0 else { return "" }

        var result = [Substring]()
        var currentIndex = startIndex

        while true {
            let next = self[currentIndex...].prefix(columns)

            // `next` may have a line breaks in it.
            if let lineBreakIndex = next.lastIndex(of: "\n") {
                result.append(contentsOf: self[currentIndex..<lineBreakIndex]
                                .split(separator: "\n", omittingEmptySubsequences: false))
                currentIndex = index(after: lineBreakIndex)
            } else if next.endIndex == endIndex {
                // `next` is the last chunk of the string.
                result.append(self[currentIndex...])
                break
            } else if let lastSpace = next.lastIndex(of: " ") {
                // If there's more, break at the last space of the current
                // substring.
                result.append(self[currentIndex..<lastSpace])
                currentIndex = index(after: lastSpace)
            } else if let nextSpace = self[currentIndex...].firstIndex(of: " ") {
                // The current substring hasn't got any spaces or new lines,
                // find the next space in the full string.
                result.append(self[currentIndex..<nextSpace])
                currentIndex = index(after: nextSpace)
            } else {
                result.append(self[currentIndex...])
                break
            }
        }

        return result.map { $0.isEmpty ? $0 : String(repeating: " ", count: wrappingIndent) + $0 }
            .joined(separator: "\n")
    }
}

extension String {
    private static let namedColors: [NamedColor] = [.blue, .white, .green, .cyan, .magenta, .yellow]
    private static var assignedColors: [String: NamedColor] = [:]

    var colorized: String {
        let queue = DispatchQueue.global(qos: .default)
        let color = queue.sync { () -> NamedColor in
            if let color = String.assignedColors[self] { return color }
            let randomColor = String.namedColors[Int.random(in: 0..<String.namedColors.count)]
            String.assignedColors[self] = randomColor
            return randomColor
        }

        return applyingColor(color).bold
    }
}
