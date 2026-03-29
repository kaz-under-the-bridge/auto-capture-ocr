import Foundation

/// LLM APIを使ったテキスト補正クライアント
/// - OCRで抽出したテキストの誤字脱字修正と整形を行う
/// - Anthropic (Claude) と OpenAI に対応
class LLMClient {
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    /// OCR結果テキストをLLMで補正
    /// - Parameter text: OCRで抽出した生テキスト
    /// - Returns: 補正後のテキスト
    func correctText(_ text: String) async throws -> String {
        guard let apiKey = config.llmApiKey else {
            throw LLMError.missingApiKey(provider: config.llmProvider)
        }

        switch config.llmProvider {
        case "anthropic":
            return try await callAnthropic(text: text, apiKey: apiKey)
        case "openai":
            return try await callOpenAI(text: text, apiKey: apiKey)
        default:
            throw LLMError.unsupportedProvider(config.llmProvider)
        }
    }

    // MARK: - Anthropic API

    private func callAnthropic(text: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 4096,
            "system": LLMClient.systemPrompt,
            "messages": [
                ["role": "user", "content": text]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.apiError(statusCode: 0, message: "レスポンスを取得できません")
        }
        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "不明なエラー"
            throw LLMError.apiError(statusCode: httpResponse.statusCode, message: message)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let resultText = firstBlock["text"] as? String else {
            throw LLMError.apiError(statusCode: 200, message: "レスポンスの解析に失敗")
        }
        return resultText
    }

    // MARK: - OpenAI API

    private func callOpenAI(text: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": LLMClient.systemPrompt],
                ["role": "user", "content": text]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.apiError(statusCode: 0, message: "レスポンスを取得できません")
        }
        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "不明なエラー"
            throw LLMError.apiError(statusCode: httpResponse.statusCode, message: message)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let resultText = message["content"] as? String else {
            throw LLMError.apiError(statusCode: 200, message: "レスポンスの解析に失敗")
        }
        return resultText
    }

    /// テキスト補正用のシステムプロンプト
    static let systemPrompt = """
    あなたはOCR（光学文字認識）の後処理を行う専門家です。
    以下のルールに従って、入力テキストを修正してください：

    1. OCRの誤認識を修正する（例: 「0」と「O」、「1」と「l」の混同など）
    2. 不自然な改行や空白を整理する
    3. 日本語の文脈に基づいて誤字脱字を修正する
    4. 原文の意味や構造は変えない
    5. 修正後のテキストのみを返す（説明は不要）
    """
}

enum LLMError: LocalizedError {
    case missingApiKey(provider: String)
    case unsupportedProvider(String)
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingApiKey(let provider):
            return "APIキーが設定されていません。環境変数を確認してください (provider: \(provider))"
        case .unsupportedProvider(let provider):
            return "未対応のLLMプロバイダ: \(provider)"
        case .apiError(let code, let message):
            return "API Error (\(code)): \(message)"
        }
    }
}
