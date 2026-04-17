import SwiftUI

struct SettingsView: View {
    @AppStorage("openai_api_key") private var apiKey = ""
    @AppStorage("openai_base_url") private var baseURL = "https://api.openai.com/v1"
    @AppStorage("openai_model") private var model = "gpt-4o"
    @State private var showKey = false

    var body: some View {
        Form {
            Section("OpenAI 兼容接口") {
                HStack {
                    Text("API Key")
                    Spacer()
                    if showKey {
                        TextField("sk-", text: $apiKey).autocorrectionDisabled()
                    } else {
                        SecureField("sk-", text: $apiKey)
                    }
                    Button { showKey.toggle() } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye").foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text("Base URL")
                    Spacer()
                    TextField("URL", text: $baseURL)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("模型")
                    Spacer()
                    TextField("模型名称", text: $model)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        .multilineTextAlignment(.trailing)
                }
                // 快捷选择常用模型
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["gpt-4o", "gpt-4o-mini", "claude-3-5-sonnet-20241022", "deepseek-chat", "gemini-2.0-flash"], id: \.self) { m in
                            Button(m) { model = m }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(model == m ? Color.blue : Color(.tertiarySystemBackground))
                                .foregroundStyle(model == m ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }

            Section {
                HStack {
                    Text("状态")
                    Spacer()
                    Text(apiKey.isEmpty ? "未设置" : "已设置")
                        .foregroundStyle(apiKey.isEmpty ? .red : .green)
                }
            }
        }
        .navigationTitle("设置")
    }
}