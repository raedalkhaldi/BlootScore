import SwiftUI

struct APIKeyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key = UserDefaults.standard.string(forKey: "anthropic_api_key") ?? ""

    var body: some View {
        NavigationView {
            VStack(spacing: Theme.Space.xl) {
                VStack(spacing: Theme.Space.sm) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.Color.accent)
                    Text("مفتاح الذكاء الاصطناعي")
                        .font(Theme.Font.title)
                        .foregroundColor(Theme.Color.ink)
                    Text("أدخل مفتاح Anthropic API لتفعيل التسجيل بالصوت")
                        .font(Theme.Font.body)
                        .foregroundColor(Theme.Color.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Theme.Space.xl)

                VStack(alignment: .trailing, spacing: Theme.Space.xs + 2) {
                    Text("API Key")
                        .font(Theme.Font.caption)
                        .foregroundColor(Theme.Color.muted)
                    SecureField("sk-ant-...", text: $key)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.leading)
                        .environment(\.layoutDirection, .leftToRight)
                }
                .padding(.horizontal, Theme.Space.lg)

                Button {
                    Theme.Haptic.success()
                    UserDefaults.standard.set(key, forKey: "anthropic_api_key")
                    dismiss()
                } label: {
                    Text("حفظ")
                        .font(Theme.Font.title)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Space.md + 2)
                        .background(key.isEmpty ? Theme.Color.canvas : Theme.Color.accent)
                        .foregroundColor(key.isEmpty ? Theme.Color.muted : Theme.Color.onAccent)
                        .cornerRadius(Theme.Radius.md)
                        .themeHairline(key.isEmpty ? Theme.Color.border : Color.clear,
                                       cornerRadius: Theme.Radius.md)
                }
                .disabled(key.isEmpty)
                .padding(.horizontal, Theme.Space.lg)

                Link("احصل على مفتاح مجاني من Anthropic",
                     destination: URL(string: "https://console.anthropic.com")!)
                    .font(Theme.Font.caption)
                    .foregroundColor(Theme.Color.accent)

                Spacer()
            }
            .background(Theme.Color.canvas.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { dismiss() }
                        .foregroundColor(Theme.Color.ink)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}
