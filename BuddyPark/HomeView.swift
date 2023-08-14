//
//  HomeView.swift
//  BuddyPark
//
//  Created by 黄鹏昊 on 2023/8/11.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var profileData = ProfileData()

    var body: some View {
        TabView {
            // 第一个 Tab，展示 SwipeView
            SwipeView(profiles: $profileData.profiles, onSwiped: { _, _ in
                // 这里是 swipeUser 的方法，你可以留空或添加自己的逻辑
            })
            .tabItem {
                Label("Swipe", systemImage: "rectangle.stack")
            }
            .environmentObject(profileData) // 将 profileData 作为环境对象传递
            
            // 第二个 Tab，进入已经写好的 ContentView
            MessageListView()
                .tabItem {
                    Label("Tab 2", systemImage: "square.and.pencil")
                }

            // 第三个 Tab，进入已经写好的 ContentView
            ContentView()
                .tabItem {
                    Label("Tab 3", systemImage: "plus")
                }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
