//
//  ContentView.swift
//  SimplePaintBrush
//
//  Created by Angelos Staboulis on 29/3/26.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var vm:CanvasViewModel

    var body: some View {
        VStack {
            ZStack {
                Color.white

                Canvas { context, size in
                    context.scaleBy(x: vm.zoom, y: vm.zoom)
                    context.translateBy(x: vm.panOffset.width, y: vm.panOffset.height)
                    for shape in vm.shapes {

                        // Draw imported images
                        if let image = shape.image {
                            if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                                context.draw(
                                    Image(decorative: cg, scale: 1),
                                    in: shape.path.boundingRect
                                )
                            }
                            continue
                        }

                        // Draw vector shapes
                        if let fill = shape.fillColor {
                            context.fill(shape.path, with: .color(fill))
                        }

                        context.stroke(shape.path, with: .color(shape.strokeColor), lineWidth: 3)
                    }

                    // Draw the shape currently being drawn
                    context.stroke(vm.currentPath, with: .color(vm.strokeColor), lineWidth: 3)
                }
                
            }
            .frame(width: 1150, height: 600)
            .border(.gray)
            .gesture(drawingGesture)
            .gesture(zoomGesture)

            toolBar
        }
    }

    var toolBar: some View {
        HStack {
            Button("✏️") { vm.selectedTool = .pencil }
            Button("📏") { vm.selectedTool = .line }
            Button("⬛") { vm.selectedTool = .rectangle }
            Button("⚪") { vm.selectedTool = .circle }
            Button("🪣") { vm.selectedTool = .fill }
            Button("🔲") { vm.selectedTool = .select }

            Button("➕") { vm.zoom *= 1.1 }
            Button("➖") { vm.zoom /= 1.1 }

            Button("✂️") { vm.cutShape() }
            Button("📄") { vm.copyShape() }
            Button("📋") { vm.pasteShape() }

            ColorPicker("", selection: $vm.strokeColor).labelsHidden()
            ColorPicker("", selection: $vm.fillColor).labelsHidden()
        }
    }

    var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { vm.dragChanged($0.location) }
            .onEnded { vm.dragEnded($0.location) }
    }

    var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { vm.updateMagnification($0) }
            .onEnded { _ in vm.endMagnification() }
    }
}
