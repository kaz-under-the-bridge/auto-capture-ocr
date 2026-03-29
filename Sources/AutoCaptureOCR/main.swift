import Foundation

/// AutoCaptureOCR - 画面遷移自動検知＆一括OCRツール
///
/// 使い方:
///   1. ツールを起動すると画面キャプチャが開始される
///   2. 画面遷移（ページめくり等）を自動検知してスクリーンショットを保存
///   3. Ctrl+C または Enter で キャプチャを停止
///   4. 保存された画像に対して一括OCRを実行
///   5. (オプション) LLM APIでテキスト補正

@main
struct AutoCaptureOCR {
    static func main() async {
        let config = Config.fromCommandLine()

        print("=== AutoCaptureOCR ===")
        print("キャプチャ間隔: \(config.captureInterval)秒")
        print("差分閾値: \(config.diffThreshold)")
        print("クールダウン: \(config.cooldownDuration)秒")
        print("出力先: \(config.outputDirectory)")
        if let rect = config.captureRect {
            print("キャプチャ領域: \(rect)")
        } else {
            print("キャプチャ領域: 全画面")
        }
        print()

        if !config.ocrOnly {
            // Phase 1: 画面キャプチャ
            let captureManager = CaptureManager(config: config)

            // 開始前の待機（画面切り替え猶予）
            if config.startDelay > 0 {
                let delaySec = Int(config.startDelay)
                for remaining in stride(from: delaySec, through: 1, by: -1) {
                    print("\r\(remaining)秒後にキャプチャを開始します... ", terminator: "")
                    fflush(stdout)
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
                print("\rキャプチャを開始しました。Enterキーで停止...      ")
            } else {
                print("画面キャプチャを開始します。Enterキーで停止...")
            }
            print()

            // キャプチャをバックグラウンドで開始
            captureManager.startCapture()

            // Enterキー待ち（メインスレッド）
            _ = readLine()
            captureManager.stopCapture()

            let pageCount = captureManager.capturedPageCount
            print()
            print("キャプチャ完了: \(pageCount)ページ")

            guard pageCount > 0 else {
                print("キャプチャされた画像がありません。終了します。")
                return
            }
        } else {
            print("OCRのみモード: \(config.outputDirectory) の画像を処理します")
        }

        // Phase 2: OCR処理
        print()
        print("OCR処理を開始...")

        let ocrEngine = OCREngine(config: config)
        do {
            let results = try await ocrEngine.processImages()
            try ocrEngine.saveResults(results)

            // Phase 3: LLM補正（オプション）
            if config.enableLLMCorrection {
                print()
                print("LLMテキスト補正を実行...")

                let llmClient = LLMClient(config: config)
                var correctedResults: [(page: Int, text: String)] = []

                for result in results {
                    let corrected = try await llmClient.correctText(result.text)
                    correctedResults.append((page: result.page, text: corrected))
                    print("補正完了: Page \(result.page)")
                }

                // 補正結果を上書き保存
                try ocrEngine.saveResults(correctedResults)
                print("LLM補正済みテキストを保存しました。")
            }

            print()
            print("完了: \(config.ocrOutputPath)")

        } catch {
            print("エラー: \(error.localizedDescription)")
            exit(1)
        }
    }
}
