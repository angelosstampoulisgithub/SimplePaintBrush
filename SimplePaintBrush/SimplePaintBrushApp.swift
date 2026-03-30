//
//  SimplePaintBrushApp.swift
//  SimplePaintBrush
//
//  Created by Angelos Staboulis on 29/3/26.
//

import SwiftUI

@main
struct SimplePaintBrushApp: App {
    @StateObject private var vm = CanvasViewModel()
    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm)
                .frame(width: 1200, height: 680)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
                   AppCommands(vm: vm)
        }
    }
}
