//
//  Extensions.swift
//  BuddyPark
//
//  Created by 黄鹏昊 on 2023/8/11.
//

import Foundation
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension View {
    public func foregroundGradient(colors: [Color]) -> some View {
        self.overlay(LinearGradient(gradient: .init(colors: colors),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing))
            .mask(self)
    }
    
    @ViewBuilder
    public func showLoading(_ showLoading: Bool) -> some View{
        self.allowsHitTesting(!showLoading)
        .overlay(ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(UIColor.systemGray5)).opacity( showLoading ? 0.75 : 0.0))
    }
}

extension Image {
    func centerCropped() -> some View {
        GeometryReader { geo in
            self
            .resizable()
            .scaledToFill()
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }
}

class AppColor{
    static let dislikeColors = [Color(hex: "ff6560"), Color(hex: "f83770")]
    static let likeColors = [Color(hex: "6ceac5"), Color(hex: "16dba1")]
    static let appColors = [Color(hex: "e83984"), Color(hex: "f47d55")]
    static let purpleColors = [Color(hex: "831bfc"),Color(hex: "9c59ea")]
    
    static let appRed = Color(hex: "ff4457")
    static let lighterGray = Color(hex: "f0f2f4")
    static let lightGray = Color(hex: "e9ebee")
    static let darkerGray = Color(hex: "d2d4d6")
    static let darkestGray = Color(hex: "d5d7df")
    static let blueGray = Color(hex: "505966")
    
}

