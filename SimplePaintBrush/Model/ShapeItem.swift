//
//  ShapeItem.swift
//  SimplePaintBrush
//
//  Created by Angelos Staboulis on 30/3/26.
//

import Foundation
import SwiftUI
struct ShapeItem: Identifiable, Equatable {
    let id = UUID()
    var path: Path
    var strokeColor: Color
    var fillColor: Color?
    var image: NSImage? = nil

    static func == (lhs: ShapeItem, rhs: ShapeItem) -> Bool {
        lhs.id == rhs.id
    }
}
