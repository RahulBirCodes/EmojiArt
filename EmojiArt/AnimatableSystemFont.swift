//
//  AnimatableSystemFont.swift
//  EmojiArt
//
//  Created by Rahul Bir on 7/14/22.
//

import SwiftUI

struct AnimatableSystemFont: ViewModifier, Animatable {
    
    var fontSize: CGFloat
    
    var animatableData: CGFloat {
        get { fontSize }
        set { fontSize = newValue }
    }
    
    func body(content: Content) -> some View {
        content.font(.system(size: fontSize))
    }
}

extension View {
    func animatableSystemFont(size: CGFloat) -> some View {
        self.modifier(AnimatableSystemFont(fontSize: size))
    }
}
