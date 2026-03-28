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
        // TODO: macOS上で実装
        // 1. URLRequest を構築 (POST https://api.anthropic.com/v1/messages)
        // 2. ヘッダー: x-api-key, anthropic-version, content-type
        // 3. Body: model, max_tokens, messages (system + user)
        // 4. URLSession.shared.data(for:) で送信
        // 5. レスポンスJSONからテキストを抽出
        fatalError("macOS上でビルド・実行してください")
    }

    // MARK: - OpenAI API

    private func callOpenAI(text: String, apiKey: String) async throws -> String {
        // TODO: macOS上で実装
        // 1. URLRequest を構築 (POST https://api.openai.com/v1/chat/completions)
        // 2. ヘッダー: Authorization: Bearer ..., content-type
        // 3. Body: model, messages
        // 4. URLSession.shared.data(for:) で送信
        // 5. レスポンスJSONからテキストを抽出
        fatalError("macOS上でビルド・実行してください")
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
