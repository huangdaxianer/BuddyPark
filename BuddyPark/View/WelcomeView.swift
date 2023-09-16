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
    
    var isContinueButtonEnabled: Bool {
        switch currentStep {
        case .selectGender:
            return !selectedGender.isEmpty
        case .selectRoleGender:
            return !selectedRoleGenders.isEmpty
        case .enterName:
            return !userName.isEmpty
        case .enterBio:
            return !userBio.isEmpty
        }
    }
    
    
    
    
    var body: some View {
        ScrollViewReader { scrollView in
            ZStack {
                VStack {
                    ScrollView(showsIndicators: false) {
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(height: UIScreen.main.bounds.height - 400)

                        if currentStep.rawValue >= ConfigStep.selectGender.rawValue {
                            genderSection.frame(maxWidth: 330)
                        }
                        
                        if currentStep.rawValue >= ConfigStep.selectRoleGender.rawValue {
                            roleGenderSection.frame(maxWidth: 330)
                        }
                        
                        if currentStep.rawValue >= ConfigStep.enterName.rawValue {
                            nameSection.frame(maxWidth: 330)
                        }
                        
                        if currentStep.rawValue >= ConfigStep.enterBio.rawValue {
                            bioSection.frame(maxWidth: 330)
                        }
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(height: 100)
                            .id("bottom")
                    }
                    .onChange(of: currentStep) { newValue in
                        withAnimation {
                            scrollView.scrollTo("bottom")
                        }
                    }
                }

                VStack {
                    Spacer()
                    Button(action: nextStep) {
                        Text(currentStep == .enterBio ? "Continue" : "Next")
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                            .foregroundColor(isContinueButtonEnabled ? Color.black : Color.black.opacity(0.2))
                            .frame(width: 300, height: 66)
                            .background(isContinueButtonEnabled ? Color(red: 0/255, green: 255/255, blue: 178/255) : Color(red: 0/255, green: 173/255, blue: 121/255))
                            .cornerRadius(22)
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.black, lineWidth: 3))
                    }
                    .disabled(!isContinueButtonEnabled)
                    .padding()

                }
            }
            .background(Color(red: 255/255, green: 229/255, blue: 0/255).edgesIgnoringSafeArea(.all))

        }
    }
    
    
    var genderSection: some View {
        VStack {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .frame(width: 110, height: 10)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("我是...")
                    .bold()
                    .font(.system(size: 40))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button(action: { selectedGender = "男" }) {
                    Image(selectedGender == "男" ? "male_selected" : "male_unselected")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                Button(action: { selectedGender = "女" }) {
                    Image(selectedGender == "女" ? "female_selected" : "female_unselected")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
        }
        .padding()
    }
    
    var roleGenderSection: some View {
        VStack {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .frame(width: 150, height: 10)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("我喜欢...")
                    .bold()
                    .font(.system(size: 40))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button(action: { toggleRoleGender("男") }) {
                    Image(selectedRoleGenders.contains("男") ? "male_character_selected" : "male_character_unselected")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                Button(action: { toggleRoleGender("女") }) {
                    Image(selectedRoleGenders.contains("女") ? "female_character_selected" : "female_character_unselected")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
        }
        .padding()
    }
    
    var nameSection: some View {
        VStack {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .frame(width: 110, height: 10)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("我叫...")
                    .bold()
                    .font(.system(size: 40))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            TextField("名字", text: $userName)
                .padding()
                .frame(height: 74)
                .font(.system(size: 30))
                .foregroundColor(.black)
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.black, lineWidth: 6))
                .cornerRadius(22)
        }

        .padding()
    }
    
    var bioSection: some View {
        VStack {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .frame(width: 260, height: 10)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("自我介绍一下...")
                    .bold()
                    .font(.system(size: 40))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            TextEditor(text: $userBio)
                .padding()
                .frame(height: 200)
                .font(.system(size: 30))
                .foregroundColor(.black)
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.black, lineWidth: 6))
                .cornerRadius(22)
        }
        .padding()
    }
    
    func nextStep() {
        if isContinueButtonEnabled {
            if let nextStep = ConfigStep(rawValue: currentStep.rawValue + 1) {
                currentStep = nextStep
            }
        }
    }
    
    func toggleRoleGender(_ gender: String) {
        if selectedRoleGenders.contains(gender) {
            selectedRoleGenders.removeAll { $0 == gender }
        } else {
            selectedRoleGenders.append(gender)
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

