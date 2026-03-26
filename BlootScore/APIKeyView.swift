import SwiftUI

struct APIKeyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key = UserDefaults.standard.string(forKey: "anthropic_api_key") ?? ""

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    Text("مفتاح الذكاء الاصطناعي")
                        .font(.title2.bold())
                    Text("أدخل مفتاح Anthropic API لتفعيل التسجيل بالصوت")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                VStack(alignment: .trailing, spacing: 6) {
                    Text("API Key")
                        .font(.caption).foregroundColor(.secondary)
                    SecureField("sk-ant-...", text: $key)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.leading)
                        .environment(\.layoutDirection, .leftToRight)
                }
                .padding(.horizontal)

                Button {
                    UserDefaults.standard.set(key, forKey: "anthropic_api_key")
                    dismiss()
                } label: {
                    Text("حفظ")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(key.isEmpty ? Color(.systemGray5) : Color.blue)
                        .foregroundColor(key.isEmpty ? .secondary : .white)
                        .cornerRadius(12)
                }
                .disabled(key.isEmpty)
                .padding(.horizontal)

                Link("احصل على مفتاح مجاني من Anthropic",
                     destination: URL(string: "https://console.anthropic.com")!)
                    .font(.footnote)
                    .foregroundColor(.blue)

                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { dismiss() }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}
