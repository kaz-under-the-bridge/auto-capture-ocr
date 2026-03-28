import Foundation
import Vision

/// Vision Framework を使ったローカルOCR処理
/// - 保存された画像群に対して一括でテキスト認識を実行
/// - 日本語・英語の縦書き・横書きに対応
class OCREngine {
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    /// 指定ディレクトリ内の画像を連番順にOCR処理
    /// - Returns: ページ番号とテキストのペア配列
    func processImages() async throws -> [(page: Int, text: String)] {
        let imageDir = URL(fileURLWithPath: config.outputDirectory)
        let files = try FileManager.default.contentsOfDirectory(at: imageDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var results: [(page: Int, text: String)] = []

        for (index, fileURL) in files.enumerated() {
            let text = try await recognizeText(in: fileURL)
            results.append((page: index + 1, text: text))
            print("OCR完了: \(fileURL.lastPathComponent) (\(text.count)文字)")
        }

        return results
    }

    /// 単一画像のテキスト認識
    func recognizeText(in imageURL: URL) async throws -> String {
        // TODO: macOS上で実装
        // 1. CGImage を読み込み
        // 2. VNRecognizeTextRequest を作成
        //    - recognitionLanguages = config.recognitionLanguages
        //    - recognitionLevel = .accurate
        //    - usesLanguageCorrection = true
        // 3. VNImageRequestHandler で実行
        // 4. 結果の VNRecognizedTextObservation からテキストを抽出
        fatalError("macOS上でビルド・実行してください")
    }

    /// OCR結果をファイルに保存
    func saveResults(_ results: [(page: Int, text: String)]) throws {
        let outputURL = URL(fileURLWithPath: config.ocrOutputPath)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var output = ""
        for result in results {
            output += "--- Page \(result.page) ---\n"
            output += result.text
            output += "\n\n"
        }

        try output.write(to: outputURL, atomically: true, encoding: .utf8)
        print("OCR結果を保存: \(outputURL.path)")
    }
}
