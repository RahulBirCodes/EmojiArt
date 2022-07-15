//
//  EmojiArtDocumentView.swift
//  EmojiArt
//
//  Created by CS193p Instructor on 4/26/21.
//  Copyright © 2021 Stanford University. All rights reserved.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    
    let defaultEmojiFontSize: CGFloat = 40
    
    var body: some View {
        VStack(spacing: 0) {
            deleteSelectedEmojisButton
            documentBody
            palette
        }
        .onTapGesture {
            deselectAllEmojis()
        }
    }
    
    var documentBody: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.overlay(
                    OptionalImage(uiImage: document.backgroundImage)
                        .scaleEffect(zoomScale)
                        .position(convertFromEmojiCoordinates((0,0), in: geometry))
                )
                .gesture(doubleTapToZoom(in: geometry.size))
                if document.backgroundImageFetchStatus == .fetching {
                    ProgressView().scaleEffect(2)
                } else {
                    ForEach(document.emojis) { emoji in
                        Text(emoji.text)
                            .border(.red, width: isSelected(emoji) ? 3 / emojiZoomScale: 0)
                            .animatableSystemFont(size: fontSize(for: emoji))
                            .scaleEffect(isSelected(emoji) ? emojiZoomScale : zoomScale)
                            .position(position(for: emoji, in: geometry))
                            .onTapGesture {
                                selectedEmojis.toggleMatched(emoji.id)
                            }
                            .simultaneousGesture(emojiPanGesture(emoji: emoji))
                    }
                }
            }
            .clipped()
            .onDrop(of: [.plainText,.url,.image], isTargeted: nil) { providers, location in
                drop(providers: providers, at: location, in: geometry)
            }
            .gesture(panGesture().simultaneously(with: zoomGesture()))
        }
    }
    
    var deleteSelectedEmojisButton: some View {
        Button {
            document.deleteSelectedEmojis(selectedEmojis)
        } label: {
            Image(systemName: "trash")
                .font(.largeTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(selectedEmojis.isEmpty)
                .padding()
        }
    }
    
    // MARK: - Drag and Drop
    
    private func drop(providers: [NSItemProvider], at location: CGPoint, in geometry: GeometryProxy) -> Bool {
        var found = providers.loadObjects(ofType: URL.self) { url in
            document.setBackground(.url(url.imageURL))
        }
        if !found {
            found = providers.loadObjects(ofType: UIImage.self) { image in
                if let data = image.jpegData(compressionQuality: 1.0) {
                    document.setBackground(.imageData(data))
                }
            }
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                if let emoji = string.first, emoji.isEmoji {
                    document.addEmoji(
                        String(emoji),
                        at: convertToEmojiCoordinates(location, in: geometry),
                        size: defaultEmojiFontSize / zoomScale
                    )
                }
            }
        }
        return found
    }
    
    // MARK: - Positioning/Sizing Emoji
    
    private func position(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        var location = (emoji.x, emoji.y)
        if emojiPanOffset.groupToDrag.contains(emoji.id) {
            location.0 += Int(emojiPanOffset.translation.width)
            location.1 += Int(emojiPanOffset.translation.height)
        }
        return convertFromEmojiCoordinates((location.0, location.1), in: geometry)
    }
    
    private func fontSize(for emoji: EmojiArtModel.Emoji) -> CGFloat {
        CGFloat(emoji.size)
    }
    
    private func convertToEmojiCoordinates(_ location: CGPoint, in geometry: GeometryProxy) -> (x: Int, y: Int) {
        let center = geometry.frame(in: .local).center
        let location = CGPoint(
            x: (location.x - panOffset.width - center.x) / zoomScale,
            y: (location.y - panOffset.height - center.y) / zoomScale
        )
        return (Int(location.x), Int(location.y))
    }
    
    private func convertFromEmojiCoordinates(_ location: (x: Int, y: Int), in geometry: GeometryProxy) -> CGPoint {
        let center = geometry.frame(in: .local).center
        return CGPoint(
            x: center.x + CGFloat(location.x) * zoomScale + panOffset.width,
            y: center.y + CGFloat(location.y) * zoomScale + panOffset.height
        )
    }
    
    // MARK: - Zooming
    
    @State private var steadyStateZoomScale: CGFloat = 1
    @GestureState private var gestureZoomScale: CGFloat = 1
    
    private var zoomScale: CGFloat {
        selectedEmojis.isEmpty ? steadyStateZoomScale * gestureZoomScale : steadyStateZoomScale
    }
    
    private var emojiZoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale
    }
    
    private func scaleAllSelectedEmojis(by scale: CGFloat) {
        selectedEmojis.forEach {
            if let emoji = findEmojiFromID($0) {
                document.scaleEmoji(emoji, by: scale)
            }
        }
    }
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating($gestureZoomScale) { latestGestureScale, gestureZoomScale, _ in
                gestureZoomScale = latestGestureScale
            }
            .onEnded { gestureScaleAtEnd in
                if selectedEmojis.isEmpty {
                    steadyStateZoomScale *= gestureScaleAtEnd
                } else {
                    scaleAllSelectedEmojis(by: gestureScaleAtEnd)
                }
            }
    }
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    zoomToFit(document.backgroundImage, in: size)
                }
            }
    }
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0, size.width > 0, size.height > 0  {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            steadyStatePanOffset = .zero
            steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
    // MARK: - Emoji Selection
    
    @State private var selectedEmojis = Set<Int>()
    
    private func isSelected(_ emoji: EmojiArtModel.Emoji) -> Bool {
        selectedEmojis.contains(emoji.id)
    }
    
    private func deselectAllEmojis() {
        selectedEmojis.removeAll()
    }
    
    private func findEmojiFromID(_ id: Int) -> EmojiArtModel.Emoji? {
        document.emojis.first(where: { $0.id == id })
    }
    
    // MARK: - Emoji Dragging
    
    @GestureState private var emojiPanOffset = DragGroup.allSelectedEmojis(Set<Int>(), CGSize.zero)
    
    private enum DragGroup {
        case singleEmoji(Int, CGSize)
        case allSelectedEmojis(Set<Int>, CGSize)
        
        var groupToDrag: Set<Int> {
            switch self {
            case .singleEmoji(let id, _):
                return [id]
            case.allSelectedEmojis(let selectedEmojiIDS, _):
                return selectedEmojiIDS
            }
        }
        
        var translation: CGSize {
            switch self {
            case .singleEmoji(_, let translation), .allSelectedEmojis(_, let translation):
                return translation
            }
        }
    }

    private func moveSelectedEmojis(by translation: CGSize) {
        selectedEmojis.forEach {
            if let emoji = findEmojiFromID($0) {
                document.moveEmoji(emoji, by: translation)
            }
        }
    }
    
    private func emojiPanGesture(emoji: EmojiArtModel.Emoji) -> some Gesture {
        DragGesture()
            .updating($emojiPanOffset) { latestDragGestureValue, emojiPanOffset, _ in
                if isSelected(emoji) {
                    emojiPanOffset = .allSelectedEmojis(selectedEmojis, latestDragGestureValue.translation / zoomScale)
                } else {
                    emojiPanOffset = .singleEmoji(emoji.id, latestDragGestureValue.translation / zoomScale)
                }
            }
            .onEnded { finalDragGestureValue in
                if isSelected(emoji) {
                    moveSelectedEmojis(by: finalDragGestureValue.translation / zoomScale)
                } else {
                    document.moveEmoji(emoji, by: finalDragGestureValue.translation / zoomScale)
                }
            }
    }
    
    // MARK: - Panning
    
    @State private var steadyStatePanOffset: CGSize = CGSize.zero
    @GestureState private var gesturePanOffset: CGSize = CGSize.zero
    
    private var panOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, _ in
                gesturePanOffset = latestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                steadyStatePanOffset = steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale)
            }
    }

    // MARK: - Palette
    
    var palette: some View {
        ScrollingEmojisView(emojis: testEmojis)
            .font(.system(size: defaultEmojiFontSize))
    }
    
    let testEmojis = "😀😷🦠💉👻👀🐶🌲🌎🌞🔥🍎⚽️🚗🚓🚲🛩🚁🚀🛸🏠⌚️🎁🗝🔐❤️⛔️❌❓✅⚠️🎶➕➖🏳️"
}

struct ScrollingEmojisView: View {
    let emojis: String

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(emojis.map { String($0) }, id: \.self) { emoji in
                    Text(emoji)
                        .onDrag { NSItemProvider(object: emoji as NSString) }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
    }
}
