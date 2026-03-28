import Foundation
import CoreGraphics
import CoreImage

/// 画面キャプチャと遷移検知を担当
/// - 指定間隔で画面をキャプチャし、前フレームとのピクセル差分を計算
/// - 差分が閾値を超えたら遷移と判定し、画像を保存
class CaptureManager {
    private let config: Config
    private var previousImage: CGImage?
    private var pageCount: Int = 0
    private var lastCaptureTime: Date = .distantPast
    private var isCapturing: Bool = false

    init(config: Config) {
        self.config = config
    }

    /// キャプチャを開始（RunLoopベース）
    func startCapture() {
        // TODO: macOS上で実装
        // 1. ScreenCaptureKit または CGWindowListCreateImage で画面キャプチャ
        // 2. Timer で定期的にフレームを取得
        // 3. calculateDiff() で遷移判定
        // 4. 遷移検知時に saveImage() で保存
        fatalError("macOS上でビルド・実行してください")
    }

    /// キャプチャを停止
    func stopCapture() {
        isCapturing = false
    }

    /// 保存済みページ数を返す
    var capturedPageCount: Int { pageCount }

    /// 2つの画像のピクセル差分率を計算 (0.0〜1.0)
    /// - Returns: 差分があるピクセルの割合
    func calculateDiff(image1: CGImage, image2: CGImage) -> Double {
        // TODO: CoreImage / vImage を使って高速に差分を計算
        // 1. 両画像を同サイズにリサイズ
        // 2. ピクセルデータを取得して差分を計算
        // 3. 差分ピクセル数 / 全ピクセル数 を返す
        return 0.0
    }

    /// 画像を連番ファイルとして保存
    func saveImage(_ image: CGImage) throws {
        pageCount += 1
        let fileName = String(format: "page_%03d.png", pageCount)
        let outputDir = URL(fileURLWithPath: config.outputDirectory)

        // 出力ディレクトリを作成
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let filePath = outputDir.appendingPathComponent(fileName)

        // TODO: CGImage → PNG保存
        // let destination = CGImageDestinationCreateWithURL(filePath as CFURL, ...)
        print("保存: \(filePath.path)")
    }
}
