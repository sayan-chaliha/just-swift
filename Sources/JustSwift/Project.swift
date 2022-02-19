//
//  File: Project.swift
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

public enum Project {
    public static var rootDirectory: URL {
        if let optionRootDirectory = optionRootDirectory {
            return optionRootDirectory
        } else if let gitRoot = try? Git.root() {
            return URL(fileURLWithPath: gitRoot, isDirectory: true)
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    }

    public static var sourcesDirectory: URL {
        return rootDirectory.appendingPathComponent("Sources")
    }

    public static var testsDirectory: URL {
        return rootDirectory.appendingPathComponent("Tests")
    }

    public static let git = Git()
    public static let version: (current: Version, next: Version) = (Versions.current, Versions.next)
}

extension Project {
    private static var lock = DispatchQueue(label: "com.microsoft.just.Project", qos: .default, attributes: .concurrent)
    private static var _optionRootDirectory: URL?

    static var optionRootDirectory: URL? {
        get {
            lock.sync { _optionRootDirectory }
        }
        set {
            lock.async(flags: .barrier) { _optionRootDirectory = newValue }
        }
    }

    static var optionRootDirectoryPath: String? {
        get {
            optionRootDirectory?.path
        }
        set {
            if let newValue = newValue {
                optionRootDirectory = URL(fileURLWithPath: newValue, isDirectory: true).standardized
            } else {
                optionRootDirectory = nil
            }
        }
    }
}
