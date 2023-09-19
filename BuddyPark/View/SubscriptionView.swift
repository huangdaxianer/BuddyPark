//
//  SubscriptionView.swift
//  BuddyPark
//
//  Created by 黄鹏昊 on 2023/9/19.
//

import SwiftUI



struct SubscriptionView: View {
    @Binding var isShowingOverlay: Bool
    
    var body: some View {
        ZStack {
            // 遮罩层
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { // 添加点击手势关闭视图
                    isShowingOverlay = false
                }
            
            // 圆角矩形窗口
            RoundedRectangle(cornerRadius: 15)
                .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.5)
                .foregroundColor(.white)
        }
    }
}


//struct SubscriptionView_Previews: PreviewProvider {
//    static var previews: some View {
//        SubscriptionView()
//    }
//}
