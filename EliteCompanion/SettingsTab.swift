import SwiftUI

struct SettingsTab: View {
     
    @AppStorage("highlightColor") private var highlightColorName: String = HighlightColor.orange.rawValue

    private var highlightColor: Color {
        HighlightColor(rawValue: highlightColorName)?.color ?? .orange
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Highlight Color")) {
                    Picker("Select Highlight Color", selection: $highlightColorName) {
                        ForEach(HighlightColor.allCases) { colorOption in
                            HStack {
                                Circle()
                                    .fill(colorOption.color)
                                    .frame(width: 20, height: 20)
                                Text(colorOption.rawValue.capitalized)
                            }
                            .tag(colorOption.rawValue)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                }
                
                Section(header: Text("Credits")) {
                    Text("Developed by R.S.D. 2025")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct SettingsTab_Previews: PreviewProvider {
    static var previews: some View {
        SettingsTab()
    }
}
