import SwiftUI

struct ProfileView: View {
    // 一些假设的用户数据
    let profile = Profile(name: "张三", bio: "iOS 开发者。喜欢编程、读书和旅行。", profileImageName: "profileImage")

    var body: some View {
        VStack(spacing: 20) {
            // 头像
            Image(profile.profileImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .shadow(radius: 5)
                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                .padding()

            // 用户名
            Text(profile.name)
                .font(.title)
                .fontWeight(.bold)
            
            // 简介
            Text(profile.bio)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // 其他详细信息，例如位置、关注者等
            VStack(alignment: .leading, spacing: 10) {
                DetailRow(iconName: "mappin.and.ellipse", text: "北京, 中国")
                DetailRow(iconName: "person.2", text: "150 关注")
                DetailRow(iconName: "heart", text: "1.2k 喜欢")
            }
            .padding()

            Spacer()
        }
        .padding()
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
