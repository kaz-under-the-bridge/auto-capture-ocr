import Foundation
import CoreGraphics
import CoreImage
import ImageIO

/// 画面キャプチャと遷移検知を担当
/// - 指定間隔で画面をキャプチャし、前フレームとのピクセル差分を計算
/// - 差分が閾値を超えたら遷移と判定し、画像を保存
class CaptureManager {
    private let config: Config
    private var previousImage: CGImage?
    private var pageCount: Int = 0
    private var lastCaptureTime: Date = .distantPast
    private var isCapturing: Bool = false
    private var dispatchTimer: DispatchSourceTimer?
    private let captureQueue = DispatchQueue(label: "capture.timer")

    init(config: Config) {
        self.config = config
    }

    /// キャプチャを開始（DispatchSourceTimerベース）
    func startCapture() {
        isCapturing = true

        let timer = DispatchSource.makeTimerSource(queue: captureQueue)
        timer.schedule(
            deadline: .now() + config.captureInterval,
            repeating: config.captureInterval
        )
        timer.setEventHandler { [weak self] in
            self?.captureFrame()
        }
        self.dispatchTimer = timer
        timer.resume()
    }

    /// キャプチャを停止
    func stopCapture() {
        isCapturing = false
        dispatchTimer?.cancel()
        dispatchTimer = nil
    }

    /// 保存済みページ数を返す
    var capturedPageCount: Int { pageCount }

    /// 1フレーム分のキャプチャ処理
    private func captureFrame() {
        guard isCapturing else { return }

        // クールダウン中はスキップ
        let now = Date()
        if now.timeIntervalSince(lastCaptureTime) < config.cooldownDuration {
            return
        }

        guard let currentImage = captureScreen() else { return }

        // 初回は基準フレームとして保存
        guard let previous = previousImage else {
            previousImage = currentImage
            return
        }

        let diff = calculateDiff(image1: previous, image2: currentImage)

        if diff > config.diffThreshold {
            do {
                try saveImage(currentImage)
                lastCaptureTime = now
            } catch {
                print("画像保存エラー: \(error.localizedDescription)")
            }
        }

        previousImage = currentImage
    }

    /// CGWindowListCreateImageで画面をキャプチャ
    private func captureScreen() -> CGImage? {
        let rect: CGRect
        if let r = config.captureRect {
            rect = r
        } else {
            rect = CGRect.infinite
        }
        return CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        )
    }

    /// 2つの画像のピクセル差分率を計算 (0.0〜1.0)
    func calculateDiff(image1: CGImage, image2: CGImage) -> Double {
        let width = min(image1.width, image2.width)
        let height = min(image1.height, image2.height)
        guard width > 0 && height > 0 else { return 0.0 }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = bytesPerRow * height

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        var data1 = [UInt8](repeating: 0, count: totalBytes)
        var data2 = [UInt8](repeating: 0, count: totalBytes)

        guard let ctx1 = CGContext(data: &data1, width: width, height: height,
                                   bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                   space: colorSpace, bitmapInfo: bitmapInfo),
              let ctx2 = CGContext(data: &data2, width: width, height: height,
                                   bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                   space: colorSpace, bitmapInfo: bitmapInfo)
        else { return 0.0 }

        ctx1.draw(image1, in: CGRect(x: 0, y: 0, width: width, height: height))
        ctx2.draw(image2, in: CGRect(x: 0, y: 0, width: width, height: height))

        // ピクセル単位で差分を計算（RGB各チャンネルの差の絶対値が閾値以上なら差分ピクセルとカウント）
        let pixelThreshold: UInt8 = 30
        var diffCount = 0
        let totalPixels = width * height

        for i in stride(from: 0, to: totalBytes, by: bytesPerPixel) {
            let dr = abs(Int(data1[i]) - Int(data2[i]))
            let dg = abs(Int(data1[i+1]) - Int(data2[i+1]))
            let db = abs(Int(data1[i+2]) - Int(data2[i+2]))
            if dr > Int(pixelThreshold) || dg > Int(pixelThreshold) || db > Int(pixelThreshold) {
                diffCount += 1
            }
        }

        return Double(diffCount) / Double(totalPixels)
    }

    /// 画像を連番ファイルとして保存
    func saveImage(_ image: CGImage) throws {
        pageCount += 1
        let fileName = String(format: "page_%03d.png", pageCount)
        let outputDir = URL(fileURLWithPath: config.outputDirectory)

        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let filePath = outputDir.appendingPathComponent(fileName)

        guard let destination = CGImageDestinationCreateWithURL(
            filePath as CFURL,
            "public.png" as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "CaptureManager", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "PNG書き出し先を作成できません"])
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "CaptureManager", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "PNG書き出しに失敗しました"])
        }

        print("保存: \(filePath.absoluteString.removingPercentEncoding ?? filePath.absoluteString)")
    }
}
