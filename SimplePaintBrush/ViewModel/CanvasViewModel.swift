//
//  CanvasViewModel.swift
//  SimplePaintBrush
//
//  Created by Angelos Staboulis on 30/3/26.
//

import Foundation
import SwiftUI

@MainActor
class CanvasViewModel: ObservableObject {
    @Published var selectedTool: PaintTool = .pencil
    @Published var shapes: [ShapeItem] = []
    @Published var currentPath = Path()
    @Published var strokeColor: Color = .black
    @Published var fillColor: Color = .yellow
    @Published var zoom: CGFloat = 1.0
    @Published var currentFileURL: URL? = nil
    @Published var selectedShapeID: UUID?
    @Published var canvasSize: CGSize = CGSize(width: 1150, height: 600)
    var pencilPoints: [CGPoint] = []
    var linePoints: [CGPoint] = []
    var startPoint: CGPoint?
    var lastMagnification: CGFloat = 1.0
    var lastDragPoint: CGPoint?
    var clipboardShape: ShapeItem?
    @Published var panOffset: CGSize = .zero
    var lastPanOffset: CGSize = .zero
    // MARK: - Undo / Redo
    private var undoStack: [[ShapeItem]] = []
    private var redoStack: [[ShapeItem]] = []
    
    private func pushUndoState() {
        undoStack.append(shapes)
        redoStack.removeAll()
    }
    
    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(shapes)
        shapes = previous
    }
    
    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(shapes)
        shapes = next
    }
    
    // MARK: - Zoom
    func updateMagnification(_ value: CGFloat) {
        zoom = lastMagnification * value
    }
    
    func endMagnification() {
        lastMagnification = zoom
    }
    
    // MARK: - Drawing
    func dragChanged(_ point: CGPoint) {
        switch selectedTool {
            
        case .pencil:
            pencilPoints.append(point)
            rebuildPencilPath()
            
        case .line:
            linePoints.append(point)
            rebuildLinePath()
            
        case .rectangle, .circle:
            startPoint = startPoint ?? point
            currentPath = shapePath(from: startPoint!, to: point)
            
        case .fill:
            break
            
        case .select:
            handleSelectionDrag(point)
        }
    }
    
    func dragEnded(_ point: CGPoint) {
        switch selectedTool {
            
        case .pencil:
            pushUndoState()
            finalizePencil()
            
        case .line:
            pushUndoState()
            finalizeLine()
            
        case .rectangle, .circle:
            pushUndoState()
            shapes.append(ShapeItem(path: currentPath, strokeColor: strokeColor, fillColor: nil))
            currentPath = Path()
            startPoint = nil
            
        case .fill:
            if let index = indexOfSmallestShape(at: point) {
                pushUndoState()
                shapes[index].fillColor = fillColor
            }
            
        case .select:
            lastDragPoint = nil
        }
    }
    
    // MARK: - Pencil
    private func rebuildPencilPath() {
        currentPath = Path()
        guard pencilPoints.count > 1 else { return }
        currentPath.move(to: pencilPoints.first!)
        for p in pencilPoints.dropFirst() { currentPath.addLine(to: p) }
    }
    
    private func finalizePencil() {
        shapes.append(ShapeItem(path: currentPath, strokeColor: strokeColor, fillColor: nil))
        currentPath = Path()
        pencilPoints.removeAll()
    }
    
    // MARK: - Line
    private func rebuildLinePath() {
        currentPath = Path()
        guard linePoints.count > 1 else { return }
        currentPath.move(to: linePoints.first!)
        for p in linePoints.dropFirst() { currentPath.addLine(to: p) }
    }
    
    private func finalizeLine() {
        shapes.append(ShapeItem(path: currentPath, strokeColor: strokeColor, fillColor: nil))
        currentPath = Path()
        linePoints.removeAll()
        startPoint = nil
    }
    
    // MARK: - Selection & Move
    private func handleSelectionDrag(_ point: CGPoint) {
        if selectedShapeID == nil {
            // First time selecting a shape
            for shape in shapes.reversed() {
                if shape.path.contains(point) {
                    selectedShapeID = shape.id
                    lastDragPoint = point
                    break
                }
            }
        } else if let last = lastDragPoint,
                  let index = shapes.firstIndex(where: { $0.id == selectedShapeID }) {
            
            // First movement → record undo state
            if lastDragPoint == last {
                pushUndoState()
            }
            
            let dx = point.x - last.x
            let dy = point.y - last.y
            
            var newPath = Path()
            newPath.addPath(shapes[index].path, transform: .init(translationX: dx, y: dy))
            shapes[index].path = newPath
            
            lastDragPoint = point
        }
    }
    
    // MARK: - Fill
    func indexOfSmallestShape(at point: CGPoint) -> Int? {
        var bestIndex: Int?
        var smallestArea: CGFloat?
        
        for (index, shape) in shapes.enumerated() {
            if shape.path.contains(point) {
                let rect = shape.path.boundingRect
                let area = rect.width * rect.height
                if smallestArea == nil || area < smallestArea! {
                    smallestArea = area
                    bestIndex = index
                }
            }
        }
        return bestIndex
    }
    
    // MARK: - Copy / Cut / Paste
    func copyShape() {
        guard let id = selectedShapeID,
              let shape = shapes.first(where: { $0.id == id }) else { return }
        clipboardShape = shape
    }
    
    func cutShape() {
        guard let id = selectedShapeID,
              let index = shapes.firstIndex(where: { $0.id == id }) else { return }
        pushUndoState()
        clipboardShape = shapes[index]
        shapes.remove(at: index)
        selectedShapeID = nil
    }
    
    func pasteShape() {
        guard var shape = clipboardShape else { return }
        pushUndoState()
        
        let offset: CGFloat = 20
        var newPath = Path()
        newPath.addPath(shape.path, transform: .init(translationX: offset, y: offset))
        shape.path = newPath
        
        let newShape = ShapeItem(path: shape.path, strokeColor: shape.strokeColor, fillColor: shape.fillColor)
        shapes.append(newShape)
        selectedShapeID = newShape.id
    }
    
    // MARK: - Shape Builder
    func shapePath(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        switch selectedTool {
        case .line:
            path.move(to: start)
            path.addLine(to: end)
        case .rectangle:
            path.addRect(CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            ))
        case .circle:
            path.addEllipse(in: CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            ))
        default:
            break
        }
        return path
    }
}

// MARK: - File Operations
extension CanvasViewModel {
    func flippedImage(_ image: NSImage) -> NSImage {
        let flipped = NSImage(size: image.size)
        flipped.lockFocus()

        NSGraphicsContext.current?.cgContext.translateBy(x: 0, y: image.size.height)
        NSGraphicsContext.current?.cgContext.scaleBy(x: 1, y: -1)

        image.draw(at: .zero, from: CGRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1)

        flipped.unlockFocus()
        return flipped
    }
    func pixelSize(of image: NSImage) -> CGSize {
        guard let rep = image.representations.first else { return image.size }
        return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff]
        panel.allowsMultipleSelection = false

        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let nsImage = NSImage(contentsOf: url) {

                    self.pushUndoState()
                    self.currentFileURL = url

                    // 1. Πάρε το πραγματικό pixel size
                    let pixelSize = self.pixelSize(of: nsImage)

                    // 2. Path που ταιριάζει 1:1 με το PNG
                    var path = Path()
                    path.addRect(CGRect(origin: .zero, size: pixelSize))

                    // 3. Background image layer
                    let imageShape = ShapeItem(
                        path: path,
                        strokeColor: .clear,
                        fillColor: nil,
                        image: nsImage
                    )

                    // 4. ΜΗΝ αλλάζεις το canvasSize
                    // canvasSize πρέπει να μένει σταθερό

                    // 5. Βάλε την εικόνα ως ΠΡΩΤΟ layer
                    self.shapes.insert(imageShape, at: 0)
                }
            }
        }
    }

    func renderCanvasImage(size: CGSize, applyViewTransform: Bool) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        context.saveGState()

        // 1. Background
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        // 2. SwiftUI-like coordinates (bottom-left origin)
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)

        // 3. Προαιρετικά pan + zoom (μόνο για export/preview)
        if applyViewTransform {
            context.translateBy(x: panOffset.width, y: panOffset.height)
            context.scaleBy(x: zoom, y: zoom)
        }

        // 4. Draw shapes
        for shape in shapes {

            if let img = shape.image,
               let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                context.draw(cg, in: shape.path.boundingRect)
                continue
            }

            if let fill = shape.fillColor {
                context.setFillColor(NSColor(fill).cgColor)
                context.addPath(shape.path.cgPath)
                context.drawPath(using: .fill)
            }

            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setLineWidth(3 / (applyViewTransform ? zoom : 1))
            context.setStrokeColor(NSColor(shape.strokeColor).cgColor)

            context.addPath(shape.path.cgPath)
            context.drawPath(using: .stroke)
        }

        context.restoreGState()
        image.unlockFocus()
        return image
    }



    
    func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return png
    }
    func saveDocument() {
        let targetURL: URL

        if let openedURL = currentFileURL {
            targetURL = openedURL

            // Αν υπάρχει background image, σώσε στο δικό του μέγεθος
            if let bgImage = shapes.first?.image {
                let size = pixelSize(of: bgImage)
                let image = renderCanvasImage(size: size, applyViewTransform: false)

                if let data = pngData(from: image) {
                    try? data.write(to: targetURL)
                    print("Saved to:", targetURL.path)
                }
                return
            }
        } else {
            let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            targetURL = desktop.appendingPathComponent("SimplePaintBrush.png")
        }

        // Γενική περίπτωση: σώσε το canvas όπως το βλέπεις (με pan/zoom)
        let image = renderCanvasImage(size: canvasSize, applyViewTransform: true)

        if let data = pngData(from: image) {
            try? data.write(to: targetURL)
            print("Saved to:", targetURL.path)
        }
    }

    func saveDocumentAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "Canvas.png"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                let image = self.renderCanvasImage(size: self.canvasSize, applyViewTransform: true)

                if let data = self.pngData(from: image) {
                    try? data.write(to: url)
                    print("Saved As:", url.path)
                }
            }
        }
    }

    func printCanvas() {
            guard let data = try? Data(contentsOf: currentFileURL!),
                 let image = NSImage(data: data) else {
               print("Failed to load PNG from URL")
               return
           }

           // 2. NSImageView με σωστό frame
           let imageView = NSImageView(image: image)
           imageView.frame = NSRect(origin: .zero, size: image.size)

           // 3. Print info
           let printInfo = NSPrintInfo()
           printInfo.horizontalPagination = .automatic
           printInfo.verticalPagination = .automatic
           printInfo.topMargin = 20
           printInfo.bottomMargin = 20
           printInfo.leftMargin = 20
           printInfo.rightMargin = 20

           // 4. Print operation
           let printOp = NSPrintOperation(view: imageView, printInfo: printInfo)
           printOp.showsPrintPanel = true
           printOp.showsProgressPanel = true
        DispatchQueue.main.async {
            printOp.run()
        }

    }
}
