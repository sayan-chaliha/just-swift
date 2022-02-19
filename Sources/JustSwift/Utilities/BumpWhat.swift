//
//  File: BumpWhat.swift
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

public enum Bump {
    case major
    case minor
    case patch
    case none
}

extension Bump {
    public static func what(_ commits: [Git.Commit]) -> Bump {
        let bumps: [Bump] = [.major, .minor, .patch, .none]
        var level = 3
        var breakings = 0
        var features = 0
        var fixes = 0

        commits.forEach { commit in
            if commit.breaking {
                breakings += 1
                level = 0
            } else if commit.kind == .feature {
                features += 1
                if level == 2 || level == 3 {
                    level = 1
                }
            } else if commit.kind == .fix {
                fixes += 1
                if level == 3 {
                    level = 2
                }
            } else if commit.kind == .revert {
                // Level is dependent on what was reverted.
                // For now, treating it as a FIX.
                if level == 3 {
                    level = 2
                }
            }
        }

        return bumps[level]
    }
}
