import SwiftUI
import UIKit

enum SwipeAction{
    case swipeLeft, swipeRight, doNothing
}

struct SwipeView: View {
    @Binding var profiles: [ProfileCardModel]
    @State var swipeAction: SwipeAction = .doNothing
    var onSwiped: (ProfileCardModel, Bool) -> ()
    @ObservedObject var sessionManager: SessionManager
    
    var body: some View {
        VStack {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 130)
            VStack {
                ZStack {
                    Text("正在加载中...").font(.title3).fontWeight(.medium).foregroundColor(Color(UIColor.systemGray)).multilineTextAlignment(.center)
                    ForEach(profiles.reversed()) { profile in
                        SwipeableCardView(model: profile, swipeAction: $swipeAction, sessionManager: sessionManager, onSwiped: handleCardSwipedInternal)
                            .offset(x: profile == profiles.last ? 0 : 10, y: profile == profiles.last ? 0 : 10)
                    }
                }
            }
            Spacer()
            Rectangle()  // 添加的占位符矩形
                .fill(Color.clear) // 设置为透明颜色
                .frame(height: 130) // 设置高度为 90
        }
    }
    
    func handleCardSwipedInternal(model: ProfileCardModel, isLiked: Bool) {
        onSwiped(model, isLiked) // 调用传递给 SwipeView 的原有方法
        if let index = profiles.firstIndex(where: { $0.characterid == model.characterid }) {
            print(index)
            profiles.remove(at: index)
            // 如果是右滑喜欢，发送初始问候消息
            if isLiked {
                let messageManager = sessionManager.session(for: model.characterid)
                // 此处构造和发送消息
//                sendInitialGreeting(messageManager: messageManager, characterId: model.characterid)
            }
        }
    }
    
//    private func sendInitialGreeting(messageManager: MessageManager, characterId: Int32) {
//        messageManager.sendRequest(type: .greetingMessage)
//    }
    
}


struct SwipeableCardView: View {
    
    private let nope = "NOPE"
    private let like = "LIKE"
    private let screenWidthLimit = UIScreen.main.bounds.width * 0.5
    let model: ProfileCardModel
    @State private var dragOffset = CGSize.zero
    @Binding var swipeAction: SwipeAction
    var sessionManager: SessionManager  // 新增
    var onSwiped: (ProfileCardModel, Bool) -> ()
    
    var body: some View {
        VStack {
            GeometryReader { geometry in
                VStack {
                    let imageHeight = geometry.size.width * (4/3)  // 计算出按4:3比例的高度
                    Image(uiImage: model.image ?? UIImage())
                        .resizable()
                        .aspectRatio(contentMode: .fill) // 保持图片的原始比例
                        .frame(width: geometry.size.width - 26, height: imageHeight) // 设置frame
                        .clipped() // 裁剪超出容器的部分
                        .cornerRadius(18)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.black, lineWidth: 2))
                        .padding([.top, .leading, .trailing], 13)
                    Spacer()
                    VStack {
                        HStack(alignment: .firstTextBaseline) {
                            Text(model.name).font(.largeTitle).fontWeight(.semibold)
                            Text("\(model.age)").font(.title).fontWeight(.medium)
                            Spacer()
                        }
                        Spacer()
                        Text(model.intro).font(.body).fontWeight(.semibold)
                    }
                    .padding()
                    .foregroundColor(.black) // 修改为黑色
                    .padding(.bottom, 13)
                }
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width - 80, 313), maxHeight: min(UIScreen.main.bounds.height - 209, 643))
            .background(Color.white)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.black, lineWidth: 2)
            )
        }
        .overlay(
            HStack{
                Text(like).font(.largeTitle).bold().foregroundGradient(colors: AppColor.likeColors).padding().overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(LinearGradient(gradient: .init(colors: AppColor.likeColors),
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing), lineWidth: 4)
                ).rotationEffect(.degrees(-30)).opacity(getLikeOpacity())
                Spacer()
                Text(nope).font(.largeTitle).bold().foregroundGradient(colors: AppColor.dislikeColors).padding().overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(LinearGradient(gradient: .init(colors: AppColor.dislikeColors),
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing), lineWidth: 4)
                ).rotationEffect(.degrees(30)).opacity(getDislikeOpacity())
            }.padding(.top, 45).padding(.leading, 20).padding(.trailing, 20)
            ,alignment: .top)
        .offset(x: self.dragOffset.width,y: self.dragOffset.height)
        .rotationEffect(.degrees(self.dragOffset.width * 0.06), anchor: .center)
        .simultaneousGesture(DragGesture(minimumDistance: 0.0).onChanged{ value in
            self.dragOffset = value.translation
        }.onEnded{ value in
            performDragEnd(value.translation)
        }).onChange(of: swipeAction, perform: { newValue in
            if newValue != .doNothing {
                performSwipe(newValue)
            }
        })
    }
}

extension SwipeableCardView {
    
    private func performSwipe(_ swipeAction: SwipeAction){
        withAnimation(.linear(duration: 0.3)){
            if(swipeAction == .swipeRight){
                self.dragOffset.width += screenWidthLimit * 2
            } else if(swipeAction == .swipeLeft){
                self.dragOffset.width -= screenWidthLimit * 2
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSwiped(model, swipeAction == .swipeRight)
        }
        self.swipeAction = .doNothing
    }
    
    private func performDragEnd(_ translation: CGSize){
        let translationX = translation.width
        if(hasLiked(translationX)){
            withAnimation(.linear(duration: 0.3)){
                self.dragOffset = translation
                self.dragOffset.width += screenWidthLimit
                self.dragOffset.height += screenWidthLimit // 增加竖直方向的偏移
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onSwiped(model, true)
                // 如果用户右滑喜欢，发送初始问候消息
                sendInitialGreeting(characterId: model.characterid)
                
                if let image = model.image {
                    detectAndCropFaces(image: image) { croppedImage in
                        CharacterManager.shared.saveImage(characterid: model.characterid, image: croppedImage, type: .avatar)
                    }
                }
            }
        } else if(hasDisliked(translationX)){
            withAnimation(.linear(duration: 0.3)){
                self.dragOffset = translation
                self.dragOffset.width -= screenWidthLimit
                self.dragOffset.height += screenWidthLimit // 增加竖直方向的偏移
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onSwiped(model, false)
            }
        } else{
            withAnimation(.default){
                self.dragOffset = .zero
            }
        }
    }
    
    private func sendInitialGreeting(characterId: Int32) {
        sessionManager.session(for: characterId).sendRequest(type: .greetingMessage)
    }
    
    private func hasLiked(_ value: Double) -> Bool{
        let ratio: Double = dragOffset.width / screenWidthLimit
        return ratio >= 1
    }
    
    private func hasDisliked(_ value: Double) -> Bool{
        let ratio: Double = -dragOffset.width / screenWidthLimit
        return ratio >= 1
    }
    
    private func getLikeOpacity() -> Double{
        let ratio: Double = dragOffset.width / screenWidthLimit;
        if(ratio >= 1){
            return 1.0
        } else if(ratio <= 0){
            return 0.0
        } else {
            return ratio
        }
    }
    
    private func getDislikeOpacity() -> Double{
        let ratio: Double = -dragOffset.width / screenWidthLimit;
        if(ratio >= 1){
            return 1.0
        } else if(ratio <= 0){
            return 0.0
        } else {
            return ratio
        }
    }
}

//
//struct SwipeView_Previews: PreviewProvider {
//    @State static private var profiles: [ProfileCardModel] = [
//        ProfileCardModel(characterId: Int32(arc4random_uniform(1000)), name: "俊熙一号", age: 50, pictures: [UIImage(named: "junxi")!], intro: "体育校队队长，母胎单身，肌肉发达头脑也不简单，喜欢大哥哥。"),
//        ProfileCardModel(characterId: Int32(arc4random_uniform(1000)), name: "22222", age: 50, pictures: [UIImage(named: "junxi")!], intro: "体育校队队长，母胎单身，肌肉发达头脑也不简单，喜欢大哥哥。"),
//        ProfileCardModel(characterId: Int32(arc4random_uniform(1000)), name: "33333", age: 50, pictures: [UIImage(named: "elon_musk")!], intro: "体育校队队长，母胎单身，肌肉发达头脑也不简单，喜欢大哥哥。"),
//        ProfileCardModel(characterId: Int32(arc4random_uniform(1000)), name: "44444", age: 50, pictures: [UIImage(named: "jeff_bezos")!],  intro: "体育校队队长，母胎单身，肌肉发达头脑也不简单，喜欢大哥哥。"),
//        ProfileCardModel(characterId: Int32(arc4random_uniform(1000)), name: "俊熙一号", age: 25, pictures: [UIImage(named: "junxi")!], intro: "体育校队队长，母胎单身，肌肉发达头脑也不简单，喜欢大哥哥。")
//    ]
//    static var previews: some View {
//        SwipeView(profiles: $profiles, onSwiped: {_,_ in})
//    }
//}



