//
//  Collection+Extension.swift
//  myTinder
//
//  Created by Ismail on 09.11.2026.
//

import Foundation

extension Collection {
    
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
