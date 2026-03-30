//
//  AppCommands.swift
//  SimplePaintBrush
//
//  Created by Angelos Staboulis on 30/3/26.
//

import Foundation
import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var vm: CanvasViewModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
                Button("New") {
                    vm.shapes.removeAll()
                    vm.currentPath = Path()
                }
                .keyboardShortcut("n")

                Button("Open…") {
                    vm.openDocument()
                }
                .keyboardShortcut("o")

                Button("Save") {
                    vm.saveDocument()
                }
                .keyboardShortcut("s")

                Button("Save As…") {
                    vm.saveDocumentAs()
                }

                Divider()

                Button("Print…") {
                    vm.printCanvas()
                }
                .keyboardShortcut("p")
            
        }

        CommandGroup(replacing: .pasteboard) {

            Button("Cut") { vm.cutShape() }
                .keyboardShortcut("x")

            Button("Copy") { vm.copyShape() }
                .keyboardShortcut("c")

            Button("Paste") { vm.pasteShape() }
                .keyboardShortcut("v")

            Divider()

            Button("Clear All") {
                vm.shapes.removeAll()
            }
        }
    
        CommandGroup(replacing: .undoRedo) {
            Button("Undo Drawing") {
                vm.undo()
            }
            .keyboardShortcut("z", modifiers: [.command])

            Button("Redo Drawing") {
                vm.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }


        
    }
}
