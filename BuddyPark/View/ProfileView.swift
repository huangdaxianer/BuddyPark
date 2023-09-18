import SwiftUI

struct CustomCell: View {
    var icon: String
    var label: String
    var rightTextOrImage: AnyView
    var height: CGFloat
    
    var body: some View {
        HStack(spacing: 16) {
            Image(icon)
                .resizable()
                .frame(width: 24, height: 24)
            Text(label)
                .font(.system(size: 20))
                .fontWeight(.bold)
                .frame(alignment: .leading)
            Spacer()
            rightTextOrImage
            Image("right_arrow")
                .resizable()
                .frame(width: 24, height: 24)
        }
        .padding(.leading, 22)
        .padding(.trailing, 14)
        .frame(height: height)
        .background(
            Color.white
                .cornerRadius(20)
                .shadow(color: .black, radius: 0, x: 2, y: 2)

        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black, lineWidth: 2)
        )
    }
}

struct ProfileView: View {
    // Just as placeholders for UserDefaults. You can replace these with the actual UserDefaults logic.
    let name = UserDefaults.standard.string(forKey: "UserName") ?? "默认名字"
    let intro = UserDefaults.standard.string(forKey: "UserIntro") ?? "默认简介"
    let subscription = UserDefaults.standard.string(forKey: "UserSubscription") ?? "默认订阅"
    
    var body: some View {
        VStack(spacing: 12) {
            CustomCell(icon: "avatar_icon", label: "头像", rightTextOrImage: AnyView(
                Image("placeholder") // Placeholder image. Replace with your image.
                    .resizable()
                    .scaledToFit()
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
                    .frame(width: 77, height: 77)
            ), height: 128)
            
            CustomCell(icon: "name_icon", label: "名字", rightTextOrImage: AnyView(Text(name).font(.system(size: 20)).frame(width: 120, alignment: .trailing)), height: 71)
            
            CustomCell(icon: "intro_icon", label: "简介", rightTextOrImage: AnyView(Text(intro).font(.system(size: 20)).frame(width: 120, alignment: .trailing)), height: 71)
            
            CustomCell(icon: "subscription_icon", label: "订阅", rightTextOrImage: AnyView(Text(subscription).font(.system(size: 20)).frame(width: 120, alignment: .trailing)), height: 71)
        }
        .padding(.horizontal, 19)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}




//struct ProfileView: View {
//    // 一些假设的用户数据
//    let profile = Profile(name: "张三", bio: "iOS 开发者。喜欢编程、读书和旅行。", profileImageName: "profileImage")
//
//    @State private var showingActionSheet: Bool = false
//    @State private var isImagePickerShown: Bool = false
//    @State private var selectedUserAvatar: UIImage?  // 选择的新头像
//
//    var body: some View {
//        VStack(spacing: 20) {
//            // 头像
//            Button(action: {
//                showingActionSheet = true  // 点击头像时展示 ActionSheet
//            }) {
//                Image(uiImage: loadImageFromSharedContainer(named: "profile.jpeg") ?? UIImage(named: profile.profileImageName) ?? UIImage())
//                    .resizable()
//                    .scaledToFill()
//                    .frame(width: 120, height: 120)
//                    .clipShape(Circle())
//                    .shadow(radius: 5)
//                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
//                    .padding()
//            }
//            .actionSheet(isPresented: $showingActionSheet) {
//                ActionSheet(title: Text("我的设置"), buttons: [
//                    .default(Text("更改头像")) {
//                        isImagePickerShown = true
//                    },
//                    .cancel()
//                ])
//            }
//            .sheet(isPresented: $isImagePickerShown) {
//                ImagePicker(selectedImage: $selectedUserAvatar)
//            }
//        }
//    }
//
//    func loadImageFromSharedContainer(named imageName: String) -> UIImage? {
//        UIImage.loadImageFromSharedContainer(named: imageName)
//    }
//
//}

struct DetailRow: View {
    let iconName: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .frame(width: 24, height: 24)
            Text(text)
        }
    }
}


struct Profile {
    let name: String
    let bio: String
    let profileImageName: String
}
