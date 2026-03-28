import Foundation

/// アプリケーション設定
struct Config {
    /// キャプチャ対象領域 (nil = 全画面)
    var captureRect: CGRect?

    /// キャプチャ間隔（秒）
    var captureInterval: TimeInterval = 0.5

    /// 画面遷移と判定するピクセル差分の閾値 (0.0〜1.0)
    var diffThreshold: Double = 0.05

    /// 遷移検知後のクールダウン（秒） - アニメーション中の連続キャプチャを防止
    var cooldownDuration: TimeInterval = 1.0

    /// 画像保存先ディレクトリ
    var outputDirectory: String = "./Output/Images"

    /// OCR結果の出力先
    var ocrOutputPath: String = "./Output/result.txt"

    /// OCR対象言語
    var recognitionLanguages: [String] = ["ja", "en"]

    /// LLM補正を有効にするか
    var enableLLMCorrection: Bool = false

    /// LLMプロバイダ ("anthropic" or "openai")
    var llmProvider: String = "anthropic"

    /// LLM APIキー（環境変数から取得）
    var llmApiKey: String? {
        switch llmProvider {
        case "anthropic":
            return ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        case "openai":
            return ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        default:
            return nil
        }
    }

    /// コマンドライン引数からConfigを生成
    static func fromCommandLine() -> Config {
        var config = Config()
        let args = CommandLine.arguments

        var i = 1
        while i < args.count {
            switch args[i] {
            case "--interval":
                i += 1
                if i < args.count, let val = TimeInterval(args[i]) {
                    config.captureInterval = val
                }
            case "--threshold":
                i += 1
                if i < args.count, let val = Double(args[i]) {
                    config.diffThreshold = val
                }
            case "--cooldown":
                i += 1
                if i < args.count, let val = TimeInterval(args[i]) {
                    config.cooldownDuration = val
                }
            case "--output":
                i += 1
                if i < args.count {
                    config.outputDirectory = args[i]
                }
            case "--rect":
                // --rect x,y,width,height
                i += 1
                if i < args.count {
                    let parts = args[i].split(separator: ",").compactMap { Double($0) }
                    if parts.count == 4 {
                        config.captureRect = CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
                    }
                }
            case "--llm":
                config.enableLLMCorrection = true
            case "--provider":
                i += 1
                if i < args.count {
                    config.llmProvider = args[i]
                }
            case "--help":
                printUsage()
                exit(0)
            default:
                break
            }
            i += 1
        }

        return config
    }

    static func printUsage() {
        let usage = """
        Usage: AutoCaptureOCR [OPTIONS]

        Options:
          --interval <sec>           キャプチャ間隔（デフォルト: 0.5秒）
          --threshold <0.0-1.0>      遷移検知の差分閾値（デフォルト: 0.05）
          --cooldown <sec>           遷移後のクールダウン（デフォルト: 1.0秒）
          --output <dir>             画像保存先（デフォルト: ./Output/Images）
          --rect <x,y,w,h>          キャプチャ領域（デフォルト: 全画面）
          --llm                      LLMテキスト補正を有効化
          --provider <name>          LLMプロバイダ: anthropic|openai（デフォルト: anthropic）
          --help                     ヘルプを表示
        """
        print(usage)
    }
}
