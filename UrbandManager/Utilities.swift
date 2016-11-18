//
//  Utilities.swift
//  UrbandManager
//
//  Created by specktro on 11/18/16.
//  Copyright © 2016 specktro. All rights reserved.
//

import Foundation

// MARK: Data utilities
extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}