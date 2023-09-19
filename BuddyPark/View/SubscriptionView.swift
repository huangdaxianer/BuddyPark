//
//  SubscriptionView.swift
//  BuddyPark
//
//  Created by 黄鹏昊 on 2023/9/19.
//

import SwiftUI



struct SubscriptionView: View {
    @Binding var isShowingOverlay: Bool
    
    // 偏移量状态
    @State private var yOffset: CGFloat = UIScreen.main.bounds.height
    
    var body: some View {
        ZStack {
            // 遮罩层
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation {
                        yOffset = UIScreen.main.bounds.height
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isShowingOverlay = false
                        }
                    }
                }
            
            ZStack(alignment: .top) {
                
                VStack {
                    
                    RoundedRectangle(cornerRadius: 21)
                        .fill(Color(red: 208.0/255.0, green: 219.0/255.0, blue: 235.0/255.0))
                        .shadow(color: .black, radius: 0, x: 2, y: 2)
                        .frame(width: UIScreen.main.bounds.width - 28, height: 343) // 左右间隔 14
                        .overlay(RoundedRectangle(cornerRadius: 21).stroke(Color.black, lineWidth: 3))
                        .padding(.top)
                }
                
                VStack {
                    Image("vip_logo")
                        .resizable()
                        .scaledToFit()
                    .frame(width: 197)
                    HStack(alignment: .top){
                        Image("default_avatar")
                            .resizable()
                            .scaledToFit()
                        .frame(width: 60)
                        .padding(.horizontal)
                        VStack(alignment: .leading) {
                            Text("还想和哥哥继续聊天！")
                                .fontWeight(.bold)
                                .foregroundColor(Color.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(29)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 29)
                                        .stroke(Color.black, lineWidth: 2)
                                )
                            Text("我还有机会吗")
                                .fontWeight(.bold)
                                .foregroundColor(Color.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(29)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 29)
                                        .stroke(Color.black, lineWidth: 2)
                                )
                            Text("和我再见一次吧！")
                                .fontWeight(.bold)
                                .foregroundColor(Color.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(29)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 29)
                                        .stroke(Color.black, lineWidth: 2)
                                )
                        }
                    }
                    Button(action: {
                        // your action
                    }) {
                        Text("退出登录")
                            .font(.system(size: 20))
                            .fontWeight(.bold)
                            .foregroundColor(Color.red)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 59)
                    .background(
                        Color.white
                            .cornerRadius(19)
                            .shadow(color: .black, radius: 0, x: 2, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.black, lineWidth: 2)
                    )
                    .padding(.horizontal, 30)
                    .padding(.top, 10)
                    .padding(.bottom, 5)
                    Text("订阅 VIP 和你喜欢的角色畅聊，256/元每年")
                        .font(.system(size: 15))

                }
            }
            .offset(y: yOffset) // 应用偏移
            .onAppear {
                withAnimation { // 当视图出现时使用动画
                    yOffset = UIScreen.main.bounds.height / 2 - 230
                }
            }
        }
    }
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView(isShowingOverlay: .constant(true))
    }
}

