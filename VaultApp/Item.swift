//
//  Item.swift
//  VaultApp
//
//  Created by Dhruvil Patel on 04/08/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
