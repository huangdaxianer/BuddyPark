//
//  SwipeView.swift
//  tinder-clone
//
//  Created by Alejandro Piguave on 1/1/22.
//

import SwiftUI
import UIKit

enum SwipeAction{
    case swipeLeft, swipeRight, doNothing
}

struct SwipeView: View {
    @Binding var profiles: [ProfileCardModel]
    @State var swipeAction: SwipeAction = .doNothing
    //Bool: true if it was a like (swipe to the right
    var onSwiped: (ProfileCardModel, Bool) -> ()
    
    var body: some View {
        VStack{
            Spacer()
            VStack{
                ZStack{
                    Text("no-more-profiles").font(.title3).fontWeight(.medium).foregroundColor(Color(UIColor.systemGray)).multilineTextAlignment(.center)
                    ForEach(profiles.indices, id: \.self){ index  in
                        let model: ProfileCardModel = profiles[index]
                        
                        if(index == profiles.count - 1){
                            SwipeableCardView(model: model, swipeAction: $swipeAction, onSwiped: performSwipe)
                        }
                        else if(index == profiles.count - 2){
                            SwipeableCardView(model: model, swipeAction: $swipeAction, onSwiped: performSwipe)
                        }

                    }
                }
            }.padding()
            Spacer()
            HStack{
                Spacer()
                //      GradientOutlineButton(action:{swipeAction = .swipeLeft}, iconName: "multiply", colors: AppColor.dislikeColors)
                Spacer()
                //       GradientOutlineButton(action: {swipeAction = .swipeRight}, iconName: "heart", colors: AppColor.likeColors)
                Spacer()
            }.padding(.bottom)
        }
    }
    
    private func performSwipe(userProfile: ProfileCardModel, hasLiked: Bool){
        removeTopItem()
        onSwiped(userProfile, hasLiked)
    }
    
    private func removeTopItem(){
        profiles.removeLast()
        print("the last one was removed")
    }
}

//Swipe functionality
struct SwipeableCardView: View {
    
    private let nope = "NOPE"
    private let like = "LIKE"
    private let screenWidthLimit = UIScreen.main.bounds.width * 0.5
    
    let model: ProfileCardModel
    @State private var dragOffset = CGSize.zero
    @Binding var swipeAction: SwipeAction
    
    var onSwiped: (ProfileCardModel, Bool) -> ()
    
    var body: some View {
        ZStack(alignment: .bottom){
            GeometryReader { geometry in
                Image(uiImage: model.pictures.first ?? UIImage())
                    .centerCropped()
            }
            VStack{
                Spacer()
                VStack{
                    HStack(alignment: .firstTextBaseline){
                        Text(model.name).font(.largeTitle).fontWeight(.semibold)
                        Text("\(model.age)").font(.title).fontWeight(.medium)
                        Spacer()
                    }
                }
                .padding()
                .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(0.7, contentMode: .fit)
        .background(.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black, lineWidth: 2)
        )
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
        ProfileCardModel(characterId: Int32(arc4random_uniform(1000)), name: "11111", age: 50, pictures: [UIImage(named: "elon_musk")!]),
        ProfileCardModel(characterId: Int32(arc4random_uniform(1000)), name: "22222", age: 50, pictures: [UIImage(named: "jeff_bezos")!]),
        ProfileCardModel(characterId: Int32(arc4random_uniform(1000)), name: "33333", age: 50, pictures: [UIImage(named: "elon_musk")!]),
        ProfileCardModel(characterId: Int32(arc4random_uniform(1000)), name: "44444", age: 50, pictures: [UIImage(named: "jeff_bezos")!])
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
}
