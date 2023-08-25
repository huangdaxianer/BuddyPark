import SwiftUI

struct ProfileView: View {
    // 一些假设的用户数据
    let profile = Profile(name: "张三", bio: "iOS 开发者。喜欢编程、读书和旅行。", profileImageName: "profileImage")

    @State private var showingActionSheet: Bool = false
    @State private var isImagePickerShown: Bool = false
    @State private var selectedUserAvatar: UIImage?  // 选择的新头像

    var body: some View {
        VStack(spacing: 20) {
            // 头像
            Button(action: {
                showingActionSheet = true  // 点击头像时展示 ActionSheet
            }) {
                Image(uiImage: loadImageFromSharedContainer(named: "profile.jpeg") ?? UIImage(named: profile.profileImageName) ?? UIImage())
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .shadow(radius: 5)
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .padding()
            }
            .actionSheet(isPresented: $showingActionSheet) {
                ActionSheet(title: Text("我的设置"), buttons: [
                    .default(Text("更改头像")) {
                        isImagePickerShown = true
                    },
                    .cancel()
                ])
            }
            .sheet(isPresented: $isImagePickerShown) {
                ImagePicker(selectedImage: $selectedUserAvatar)
            }
        }
    }

    func loadImageFromSharedContainer(named imageName: String) -> UIImage? {
        UIImage.loadImageFromSharedContainer(named: imageName)
    }

}

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

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}

struct Profile {
    let name: String
    let bio: String
    let profileImageName: String
}
