import SwiftUI

struct PushNotificationPromptView: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).edgesIgnoringSafeArea(.all) // 覆盖满整个屏幕的背景

            VStack {
                Spacer()

                VStack {
                    Spacer(minLength: 74)
                    
                    Text("打开通知")
                        .font(.system(size: 30))
                        .fontWeight(.bold)
                        .foregroundColor(.black)

                    Spacer(minLength: 6)

                    Text("BuddyPark 利用 iOS 系统推送给你发消息\n打开通知才能正常收到消息")
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Button("我知道了") {
                        isPresented = false
                    }
                    .font(.system(size: 20))
                    .frame(width: 325, height: 56)
                    .foregroundColor(.black)
                    .fontWeight(.bold)
                    .background(Color.white)
                    .cornerRadius(19)
                    .overlay(
                        RoundedRectangle(cornerRadius: 19)
                            .stroke(Color.black, lineWidth: 3)
                    )
                    .padding(.top, 27)
                    Spacer(minLength: 27)

                }
                .frame(width: UIScreen.main.bounds.width - 26, height: 274) // 设置固定高度
                .background(Color(red: 208.0/255.0, green: 219.0/255.0, blue: 235.0/255.0))
                .cornerRadius(21)
                .overlay(
                    RoundedRectangle(cornerRadius: 21)
                        .stroke(Color.black, lineWidth: 3)
                )
                .padding(.bottom, 27)
            }
            .edgesIgnoringSafeArea(.bottom)

            // 浮动在圆角矩形顶部的图片
            Image("NotificationPrompt")
                .resizable()
                .scaledToFit()
                .frame(height: 128)
                .offset(y: +UIScreen.main.bounds.height/2-320) // 根据屏幕高度进行偏移
        }
    }
}





struct PushNotificationPromptView_Previews: PreviewProvider {
    static var previews: some View {
        PushNotificationPromptView(isPresented: .constant(true))
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
