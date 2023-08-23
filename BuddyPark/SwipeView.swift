import SwiftUI
import UIKit

enum SwipeAction{
    case swipeLeft, swipeRight, doNothing
}

struct SwipeView: View {
    @Binding var profiles: [ProfileCardModel]
    @State var swipeAction: SwipeAction = .doNothing
    var onSwiped: (ProfileCardModel, Bool) -> ()
    
    var body: some View {
        VStack {
            Spacer()
            Image("Logo") // Add this line to display the image
                .resizable()
                .scaledToFit()
                .frame(width: 150) // Set the width of the image
                .padding()
            VStack {
                ZStack {
                    Text("no-more-profiles").font(.title3).fontWeight(.medium).foregroundColor(Color(UIColor.systemGray)).multilineTextAlignment(.center)
                    ForEach(profiles.indices.reversed(), id: \.self) { index in // Reverse the loop to put the last item on top
                        let model: ProfileCardModel = profiles[index]
                        SwipeableCardView(model: model, swipeAction: $swipeAction, onSwiped: onSwiped)
                            .offset(x: index == profiles.count - 1 ? 0 : 10, y: index == profiles.count - 1 ? 0 : 10) // Offset the bottom card
                    }
                }
            }.padding()
        }
    }
}

struct SwipeableCardView: View {
    
    private let nope = "NOPE"
    private let like = "LIKE"
    private let screenWidthLimit = UIScreen.main.bounds.width * 0.5
    let model: ProfileCardModel
    @State private var shouldBeHidden: Bool = false
    @State private var dragOffset = CGSize.zero
    @Binding var swipeAction: SwipeAction
    
    var onSwiped: (ProfileCardModel, Bool) -> ()
    
    var body: some View {
        if !shouldBeHidden {
            VStack {
                GeometryReader { geometry in
                    VStack {
                        Image(uiImage: model.pictures.first ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: geometry.size.width - 26, maxHeight: geometry.size.height - 100)
                            .cornerRadius(18)
                            .clipped()
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.black, lineWidth: 2)) // 添加这一行
                        
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
                self.shouldBeHidden = true
                onSwiped(model, true)
            }
        } else if(hasDisliked(translationX)){
            withAnimation(.linear(duration: 0.3)){
                self.dragOffset = translation
                self.dragOffset.width -= screenWidthLimit
                self.dragOffset.height += screenWidthLimit // 增加竖直方向的偏移
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.shouldBeHidden = true
                onSwiped(model, false)
            }
        } else{
            withAnimation(.default){
                self.dragOffset = .zero
            }
        }
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


struct SwipeView_Previews: PreviewProvider {
    @State static private var profiles: [ProfileCardModel] = [
        ProfileCardModel(characterId: Int32(arc4random_uniform(1000)), name: "俊熙一号", age: 50, pictures: [UIImage(named: "junxi")!], intro: "体育校队队长，母胎单身，肌肉发达头脑也不简单，喜欢大哥哥。"),
        ProfileCardModel(characterId: Int32(arc4random_uniform(1000)), name: "22222", age: 50, pictures: [UIImage(named: "junxi")!], intro: "体育校队队长，母胎单身，肌肉发达头脑也不简单，喜欢大哥哥。"),
        ProfileCardModel(characterId: Int32(arc4random_uniform(1000)), name: "33333", age: 50, pictures: [UIImage(named: "elon_musk")!], intro: "体育校队队长，母胎单身，肌肉发达头脑也不简单，喜欢大哥哥。"),
        ProfileCardModel(characterId: Int32(arc4random_uniform(1000)), name: "44444", age: 50, pictures: [UIImage(named: "jeff_bezos")!],  intro: "体育校队队长，母胎单身，肌肉发达头脑也不简单，喜欢大哥哥。"),
        ProfileCardModel(characterId: Int32(arc4random_uniform(1000)), name: "俊熙一号", age: 25, pictures: [UIImage(named: "junxi")!], intro: "体育校队队长，母胎单身，肌肉发达头脑也不简单，喜欢大哥哥。")
    ]
    static var previews: some View {
        SwipeView(profiles: $profiles, onSwiped: {_,_ in})
    }
}


struct ProfileCardModel {
    let characterId: Int32
    let name: String
    let age: Int
    let pictures: [UIImage]
    let intro: String
}

