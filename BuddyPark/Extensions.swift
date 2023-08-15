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

struct UIKitTextFieldRepresentable: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFirstResponder: Bool
    var onCommit: () -> Void
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.returnKeyType = .send
        textField.enablesReturnKeyAutomatically = true
        
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: scrollView.topAnchor),
            textField.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            textField.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            textField.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if isFirstResponder && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: UIKitTextFieldRepresentable
        
        init(_ textField: UIKitTextFieldRepresentable) {
            self.parent = textField
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.text = textField.text ?? ""
            parent.onCommit()
            textField.text = "" // 清空输入框
            textField.becomeFirstResponder() // 保持键盘不收起
            if let scrollView = textField.superview as? UIScrollView {
                scrollView.setContentOffset(CGPoint(x: max(0, textField.frame.width - scrollView.frame.width), y: 0), animated: true)
            }
            return false // 这将阻止键盘的默认行为，即按下 "Return" 键后收起键盘
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.text = textField.text ?? ""
            parent.isFirstResponder = false
        }
    }
}


extension Date {
    func formatTimestamp() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: self, to: now)
        
        guard let day = components.day else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        
        if calendar.isDateInToday(self) {
            // 如果消息是今天发送的，只显示时间
            formatter.dateFormat = "ahh:mm"
        } else if calendar.isDateInYesterday(self) {
            // 如果消息是昨天发送的，显示昨天和时间
            formatter.dateFormat = "'昨天' ahh:mm"
        } else if day <= 7 {
            // 如果消息在7天内发送，显示星期几和时间
            formatter.dateFormat = "EEEE ahh:mm"
        } else {
            // 其他情况，显示日期和时间
            formatter.dateFormat = "MM月dd日 ahh:mm"
        }
        
        return formatter.string(from: self)
    }
}
