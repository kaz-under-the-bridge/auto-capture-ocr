import Foundation

/// Tesseract を使ったOCR処理
/// - 保存された画像群に対して一括でテキスト認識を実行
/// - jpn_vert + jpn で縦書き・横書きの日本語に対応
class OCREngine {
    private let config: Config
    private let tesseractPath: String

    init(config: Config) {
        self.config = config
        // tesseractのパスを検出
        self.tesseractPath = OCREngine.findTesseract()
    }

    /// tesseractバイナリを探す
    private static func findTesseract() -> String {
        let candidates = [
            "/opt/homebrew/bin/tesseract",
            "/usr/local/bin/tesseract",
            "/usr/bin/tesseract",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "tesseract"
    }

    /// 指定ディレクトリ内の画像を連番順にOCR処理
    func processImages() async throws -> [(page: Int, text: String)] {
        // tesseractの存在確認
        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: tesseractPath)
        checkProcess.arguments = ["--version"]
        checkProcess.standardOutput = FileHandle.nullDevice
        checkProcess.standardError = FileHandle.nullDevice
        do {
            try checkProcess.run()
            checkProcess.waitUntilExit()
        } catch {
            throw NSError(domain: "OCREngine", code: 10,
                          userInfo: [NSLocalizedDescriptionKey: "tesseractが見つかりません。brew install tesseract tesseract-lang でインストールしてください"])
        }

        let imageDir = URL(fileURLWithPath: config.outputDirectory)
        let files = try FileManager.default.contentsOfDirectory(at: imageDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        let totalCount = files.count
        let workerCount = min(ProcessInfo.processInfo.activeProcessorCount, totalCount)
        print("並列OCR: \(workerCount)ワーカーで\(totalCount)ページを処理")

        // ページ番号付きタスクリストを作成
        let tasks: [(page: Int, url: URL)] = files.enumerated().map { (index, url) in
            (page: index + 1, url: url)
        }

        // 結果格納用（スレッドセーフ）
        let lock = NSLock()
        var results: [(page: Int, text: String)] = []
        var completedCount = 0

        // DispatchGroupで並列実行
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "ocr.parallel", attributes: .concurrent)
        let semaphore = DispatchSemaphore(value: workerCount)

        for task in tasks {
            group.enter()
            semaphore.wait()
            queue.async { [self] in
                defer {
                    semaphore.signal()
                    group.leave()
                }
                do {
                    let text = try self.recognizeText(in: task.url)
                    lock.lock()
                    results.append((page: task.page, text: text))
                    completedCount += 1
                    let count = completedCount
                    lock.unlock()
                    print("OCR完了: \(task.url.lastPathComponent) (\(text.count)文字) [\(count)/\(totalCount)]")
                } catch {
                    lock.lock()
                    results.append((page: task.page, text: ""))
                    completedCount += 1
                    lock.unlock()
                    print("OCRエラー: \(task.url.lastPathComponent) - \(error.localizedDescription)")
                }
            }
        }

        group.wait()

        // ページ番号順にソート
        return results.sorted { $0.page < $1.page }
    }

    /// 単一画像のテキスト認識（tesseract呼び出し）
    func recognizeText(in imageURL: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tesseractPath)
        process.arguments = [
            imageURL.path(percentEncoded: false),
            "stdout",              // 標準出力にテキストを出力
            "-l", "jpn_vert+jpn+eng",  // 縦書き日本語 + 横書き日本語 + 英語
            "--psm", "5",          // 縦書きテキストブロック
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return text
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
        print("OCR結果を保存: \(outputURL.absoluteString.removingPercentEncoding ?? "")")
    }
}
