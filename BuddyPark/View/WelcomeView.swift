import SwiftUI

enum ConfigStep {
    case selectGender
    case selectRoleGender
    case enterName
    case enterBio
    case done
}

struct WelcomeView: View {
        
    enum ConfigStep: Int {
        case selectGender = 0
        case selectRoleGender = 1
        case enterName = 2
        case enterBio = 3
    }

    @State private var currentStep: ConfigStep = .selectGender
    @State private var selectedGender: String = ""
    @State private var selectedRoleGenders: [String] = []
    @State private var userName: String = ""
    @State private var userBio: String = ""
    @State private var isContinueButtonEnabled: Bool = false
    
    var body: some View {
        VStack {
            ScrollView {
                VStack {
                    if currentStep == .selectGender {
                        VStack(alignment: .leading) {
                            Text("我是...")
                                .bold()
                                .font(.system(size: 40))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        
                        HStack {
                            Button(action: {
                                selectedGender = "男"
                                isContinueButtonEnabled = true
                            }) {
                                Image(selectedGender == "男" ? "male_selected" : "male_unselected")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            }
                            
                            Button(action: {
                                selectedGender = "女"
                                isContinueButtonEnabled = true
                            }) {
                                Image(selectedGender == "女" ? "female_selected" : "female_unselected")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            }
                        }
                    }
                    
                    if currentStep == .selectRoleGender {
                        VStack(alignment: .leading) {
                            Text("我喜欢...")
                                .bold()
                                .font(.system(size: 40))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        
                        HStack {
                            Button(action: {
                                toggleRoleGender("男")
                            }) {
                                Image(selectedRoleGenders.contains("男") ? "male_character_selected" : "male_character_unselected")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 150, height: 150)
                            }
                            
                            Button(action: {
                                toggleRoleGender("女")
                            }) {
                                Image(selectedRoleGenders.contains("女") ? "female_character_selected" : "female_character_unselected")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 150, height: 150)
                            }
                        }
                    }
                    
                    if currentStep == .enterName || currentStep.rawValue >= ConfigStep.enterBio.rawValue {
                        VStack(alignment: .leading) {
                            Text("我叫...")
                                .bold()
                                .font(.system(size: 40))
                                .frame(maxWidth: .infinity, alignment: .leading) // 左对齐
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
                                .bold()
                                .font(.system(size: 40))
                                .frame(maxWidth: .infinity, alignment: .leading) // 左对齐
                            TextEditor(text: $userBio)
                                .frame(height: 100)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray))
                        }
                        .padding()
                    }
                }
                          .frame(width: 292)
                      }
                      
                      Spacer()
                      
                      Button(action: {
                          if isContinueButtonEnabled {
                              currentStep = ConfigStep(rawValue: currentStep.rawValue + 1) ?? .enterBio
                              isContinueButtonEnabled = false // Reset the button state
                          }
                      }) {
                          Text(currentStep == .enterBio ? "完成" : "继续")
                              .frame(width: 285, height: 66)
                              .background(isContinueButtonEnabled ? Color(red: 0/255, green: 255/255, blue: 178/255) : Color(red: 0/255, green: 173/255, blue: 121/255))
                              .cornerRadius(22)
                              .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.black, lineWidth: 3))
                      }
                      .disabled(!isContinueButtonEnabled)
                      .padding()
                  }
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
                  .background(Color(red: 255/255, green: 229/255, blue: 0/255).edgesIgnoringSafeArea(.all))
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

