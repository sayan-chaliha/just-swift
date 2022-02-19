//
//  File: CoverageReport.swift
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

public struct CoverageReport: Codable {
    enum Error: Swift.Error {
        case badInput(String)
    }

    public struct Coverage: Codable {
        public let count: Int
        public let covered: Int
        public let percent: Double
    }

    public struct Summary: Codable {
        public let branches: Coverage
        public let functions: Coverage
        public let instantiations: Coverage
        public let lines: Coverage
        public let regions: Coverage
    }

    public struct Segment: Codable {
        public let line: UInt
        public let column: UInt
        public let count: UInt64
        public let hasCount: Bool
        public let isRegionEntry: Bool
        public let isGapRegion: Bool
    }

    public struct Region: Codable {
        public enum Kind: UInt, Codable {
            case code = 0
            case expansion = 1
            case skipped = 2
            case gap = 3
            case branch = 4
        }

        public let lineStart: UInt
        public let columnStart: UInt
        public let lineEnd: UInt
        public let columnEnd: UInt
        public let count: UInt64
        public let fileID: UInt
        public let expandedFileID: UInt
        public let kind: Kind
    }

    public struct File: Codable {
        public let filename: String
        public let summary: Summary
        public let branches: [String]
        public let segments: [Segment]
    }

    public struct Function: Codable {
        public let count: Int
        public let filenames: [String]
        public let name: String
        public let branches: [String]
        public let regions: [Region]
    }

    public struct Data: Codable {
        public let files: [File]
        public let functions: [Function]
        public let totals: Summary
    }

    public let data: [Data]
    public let type: String
    public let version: String

    init(fromJSON json: String) throws {
        guard let data = json.data(using: .utf8) else { throw Error.badInput(json) }
        self = try JSONDecoder().decode(CoverageReport.self, from: data)
    }
}

extension CoverageReport.Segment {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.line = try container.decode(UInt.self)
        self.column = try container.decode(UInt.self)
        self.count = try container.decode(UInt64.self)
        self.hasCount = try container.decode(Bool.self)
        self.isRegionEntry = try container.decode(Bool.self)
        self.isGapRegion = try container.decode(Bool.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.line)
        try container.encode(self.column)
        try container.encode(self.count)
        try container.encode(self.hasCount)
        try container.encode(self.isRegionEntry)
        try container.encode(self.isGapRegion)
    }
}

extension CoverageReport.Region {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.lineStart = try container.decode(UInt.self)
        self.columnStart = try container.decode(UInt.self)
        self.lineEnd = try container.decode(UInt.self)
        self.columnEnd = try container.decode(UInt.self)
        self.count = try container.decode(UInt64.self)
        self.fileID = try container.decode(UInt.self)
        self.expandedFileID = try container.decode(UInt.self)
        self.kind = try container.decode(Kind.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.lineStart)
        try container.encode(self.columnStart)
        try container.encode(self.lineEnd)
        try container.encode(self.columnEnd)
        try container.encode(self.count)
        try container.encode(self.fileID)
        try container.encode(self.expandedFileID)
        try container.encode(self.kind.rawValue)
    }
}
