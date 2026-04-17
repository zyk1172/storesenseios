import SwiftUI

struct SettingsView: View {
    @AppStorage("openai_api_key") private var apiKey = ""
    @AppStorage("openai_base_url") private var baseURL = "https://api.openai.com/v1"
    @AppStorage("openai_model") private var model = "gpt-4o"
    @State private var showKey = false
    @State private var isTesting = false
    @State private var testResult: String?

    // 默认的建议模型列表
    private let suggestedModels = [
        "gpt-4o", 
        "gpt-4o-mini", 
        "claude-3-5-sonnet-20241022", 
        "deepseek-chat", 
        "gemini-2.0-flash"
    ]

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("API Key")
                    Spacer()
                    if showKey {
                        TextField("sk-...", text: $apiKey)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    } else {
                        SecureField("sk-...", text: $apiKey)
                            .multilineTextAlignment(.trailing)
                    }
                    Button { showKey.toggle() } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye").foregroundStyle(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Base URL")
                    TextField("https://api.openai.com/v1", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                }
                .padding(.vertical, 4)
            } header: {
                Text("API 配置")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("当前模型名称")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // 💡 这里是手动填写的地方，点击即可输入任何模型名
                    TextField("输入自定义模型名称...", text: $model)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                    
                    Text("常用模型快捷选择：")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    // 快捷选择列表
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestedModels, id: \.self) { m in
                                Button(m) {
                                    model = m // 点击自动填入上方输入框
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(model == m ? Color.blue : Color(.tertiarySystemBackground))
                                .foregroundStyle(model == m ? .white : .primary)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                                )
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("模型设置")
            } footer: {
                Text("你可以手动输入任何兼容 OpenAI 接口的模型名称（如 deepseek-reasoner 等）。")
            }

            Section {
                HStack {
                    Text("服务状态")
                    Spacer()
                    if apiKey.isEmpty {
                        Label("未配置 API Key", systemImage: "xmark.circle.fill").foregroundStyle(.red)
                    } else {
                        Label("已就绪", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
            }

            Section {
                Button {
                    Task { await testAPIConnection() }
                } label: {
                    HStack {
                        Spacer()
                        if isTesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding(.trailing, 8)
                        }
                        Text(isTesting ? "测试中..." : "测试 API 连接")
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
                .disabled(apiKey.isEmpty || isTesting)

                if let result = testResult {
                    HStack {
                        Spacer()
                        Text(result)
                            .font(.subheadline)
                            .foregroundStyle(result.hasPrefix("✅") ? .green : .red)
                        Spacer()
                    }
                }
            } header: {
                Text("连接测试")
            } footer: {
                Text("使用当前配置的 API Key、Base URL 和模型发送测试请求。")
            }
            
            Section {
                Button {
                    rebuildSearchIndex()
                } label: {
                    HStack {
                        Spacer()
                        Text("重建搜索索引")
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
                
                Button(role: .destructive) {
                    clearSearchIndex()
                } label: {
                    HStack {
                        Spacer()
                        Text("清空搜索索引")
                        Spacer()
                    }
                }
            } header: {
                Text("搜索索引")
            } footer: {
                Text("重建索引可解决Siri和Spotlight搜索不到物品的问题。清空索引会移除所有Siri搜索建议。")
            }
        }
        .navigationTitle("设置")
    }
    
    @EnvironmentObject var appState: AppState
    
    private func rebuildSearchIndex() {
        appState.rebuildSearchIndex()
    }
    
    private func clearSearchIndex() {
        appState.clearSearchIndex()
    }

    private func testAPIConnection() async {
        isTesting = true
        testResult = nil

        do {
            var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            while base.hasSuffix("/") {
                base.removeLast()
            }

            let urlString = base.appending("/chat/completions")
            guard let url = URL(string: urlString) else {
                testResult = "❌ 无效的 URL"
                isTesting = false
                return
            }

            let testBody: [String: Any] = [
                "model": model,
                "messages": [
                    ["role": "user", "content": "测试连接，请回复'连接成功'"]
                ],
                "max_tokens": 50
            ]

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey.trimmingCharacters(in: .whitespaces))", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30
            request.httpBody = try? JSONSerialization.data(withJSONObject: testBody)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                testResult = "❌ 无效的响应"
                isTesting = false
                return
            }

            if httpResponse.statusCode == 200 {
                testResult = "✅ API 连接成功！"
            } else {
                let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let detail = (errorJson?["error"] as? [String: Any])?["message"] as? String
                            ?? (errorJson?["message"] as? String)
                            ?? "HTTP \(httpResponse.statusCode)"
                testResult = "❌ 连接失败: \(detail)"
            }
        } catch {
            testResult = "❌ 连接失败: \(error.localizedDescription)"
        }

        isTesting = false
    }
}
