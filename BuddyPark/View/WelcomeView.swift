import SwiftUI

enum ConfigStep {
    case selectGender
    case selectRoleGender
    case enterName
    case enterBio
    case done
}

struct WelcomeView: View {
    
    @State private var selectedGender: String = ""
    @State private var selectedRoleGenders: [String] = []
    @State private var userName: String = ""
    @State private var userBio: String = ""
    
    @State private var currentStep: ConfigStep = .selectGender
    
    var body: some View {
        VStack {
            ScrollView {
                VStack {
                    if currentStep == .selectGender || currentStep.rawValue >= ConfigStep.selectRoleGender.rawValue {
                        VStack(alignment: .leading) {
                            Text("我是...")
                                .bold() // 加粗
                                .font(.system(size: 40))
                        }
                        .padding()
                        
                        HStack {
                            Button(action: {
                                selectedGender = "男"
                                currentStep = .selectRoleGender
                            }) {
                                Image(selectedGender == "男" ? "male_selected" : "male_unselected")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            }
                            
                            Button(action: {
                                selectedGender = "女"
                                currentStep = .selectRoleGender
                            }) {
                                Image(selectedGender == "女" ? "female_selected" : "female_unselected")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            }
                        }
                    }
                    
                    if currentStep == .selectRoleGender || currentStep.rawValue >= ConfigStep.enterName.rawValue {
                        VStack(alignment: .leading) {
                            Text("我喜欢...")
                                .bold() // 加粗
                                .font(.system(size: 40))
                        }
                        .padding()
                        
                        HStack {
                            Button(action: {
                                toggleRoleGender("男")
                            }) {
                                Image(selectedRoleGenders.contains("男") ? "male_character_selected" : "male_character_unselected")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 150, height: 150) // 根据需要调整尺寸
                            }
                            
                            Button(action: {
                                toggleRoleGender("女")
                            }) {
                                Image(selectedRoleGenders.contains("女") ? "female_character_selected" : "female_character_unselected")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 150, height: 150) // 根据需要调整尺寸
                            }
                        }
                    }
                    
                    if currentStep == .enterName || currentStep.rawValue >= ConfigStep.enterBio.rawValue {
                        VStack(alignment: .leading) {
                            Text("我叫...")
                                .bold() // 加粗
                                .font(.system(size: 40))
                            TextField("名字", text: $userName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding()
                        
                        Button("继续") {
                            currentStep = .enterBio
                        }
                    }
                    
                    if currentStep == .enterBio {
                        VStack(alignment: .leading) {
                            Text("自我介绍一下...")
                                .bold() // 加粗
                                .font(.system(size: 40))
                            TextEditor(text: $userBio)
                                .frame(height: 100)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray))
                        }
                        .padding()
                    }
                }
                .frame(width: 292)  // 整体内容的宽度设为 292
            }
            
            // Continue/Done button at the bottom
            Spacer()
            Button(currentStep == .enterBio ? "完成" : "继续") {
                advanceToNextStep()
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // 确保 VStack 占据整个屏幕
        .background(Color(red: 255/255, green: 229/255, blue: 0/255).edgesIgnoringSafeArea(.all))  // 设置整体背景颜色
        .ignoresSafeArea(.all, edges: .all)
    }
    
    
    func toggleRoleGender(_ gender: String) {
        if selectedRoleGenders.contains(gender) {
            selectedRoleGenders.removeAll { $0 == gender }
        } else {
            selectedRoleGenders.append(gender)
        }
        currentStep = .enterName
    }
    
    func advanceToNextStep() {
        if currentStep == .enterBio {
            currentStep = .done
        }
    }
}

extension ConfigStep: Comparable {
    static func < (lhs: ConfigStep, rhs: ConfigStep) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var rawValue: Int {
        switch self {
        case .selectGender:
            return 1
        case .selectRoleGender:
            return 2
        case .enterName:
            return 3
        case .enterBio:
            return 4
        case .done:
            return 5
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
    }
}

