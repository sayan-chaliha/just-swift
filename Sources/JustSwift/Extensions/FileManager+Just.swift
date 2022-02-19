//
//  File: FileManager+Just.swift
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

extension FileManager {
    public struct FindFilesOptions: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let regularExpression = FindFilesOptions(rawValue: 1 << 0)
        public static let recursive = FindFilesOptions(rawValue: 1 << 1)
        public static let includeHidden = FindFilesOptions(rawValue: 1 << 2)
    }

    public func findFiles(named name: String, in directory: URL, options: FindFilesOptions = []) -> [URL] {
        var directoryEnumeratorOptions: DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        var stringCompareOptions: NSString.CompareOptions = []

        if options.contains(.includeHidden) {
            directoryEnumeratorOptions.remove(.skipsHiddenFiles)
        }

        if options.contains(.recursive) {
            directoryEnumeratorOptions.remove(.skipsSubdirectoryDescendants)
        }

        if options.contains(.regularExpression) {
            stringCompareOptions.update(with: .regularExpression)
        }

        var urls = [URL]()
        if let enumerator = enumerator(at: directory,
                                       includingPropertiesForKeys: [.isRegularFileKey],
                                       options: directoryEnumeratorOptions) {
            for case let fileURL as URL in enumerator {
                let attributes = try? fileURL.resourceValues(forKeys: [URLResourceKey.isRegularFileKey])
                guard attributes?.isRegularFile == true else { continue }
                guard fileURL.lastPathComponent.range(of: name, options: stringCompareOptions, range: nil) != nil else {
                    continue
                }

                urls.append(fileURL)
            }
        }

        return urls
    }

    public func findFiles(withExtension ext: String, in directory: URL, options: FindFilesOptions = []) -> [URL] {
        findFiles(named: #".*\."# + ext, in: directory, options: options.union(.regularExpression))
    }
}
