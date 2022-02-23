//
//  File: Demangler.swift
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

/// Encapsulates the `swift_demangle` symbol which is available on
/// all platforms but not exposed as an API.
public enum Demangler {
    typealias SwiftDemangle = @convention(c) (_ mangledName: UnsafePointer<UInt8>?,
                                              _ mangledNameLength: Int,
                                              _ outputBuffer: UnsafeMutablePointer<UInt8>?,
                                              _ outputBufferSize: UnsafeMutablePointer<Int>?,
                                              _ flags: UInt32) -> UnsafeMutablePointer<Int8>?

    private static var demangler: SwiftDemangle? = {
        let rtldDefault = dlopen(nil, RTLD_NOW)
        if let sym = dlsym(rtldDefault, "swift_demangle") {
            return unsafeBitCast(sym, to: SwiftDemangle.self)
        } else {
            return nil
        }
    }()

    /// Demangles a Swift symbol.
    ///
    /// - Parameter symbol: Swift symbol to demangle.
    /// - Returns: Demangled symbol name or `nil` if it couldn't be demangled.
    public static func demangle(symbol: String) -> String? {
        if let cString = demangler?(symbol, symbol.count, nil, nil, 0) {
            defer { cString.deallocate() }
            return String(cString: cString)
        } else {
            return nil
        }
    }
}
