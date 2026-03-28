# 画面遷移自動検知＆一括OCRツール (macOS Native / Swift) 設計ドキュメント

## 1. プロジェクト概要
Macの画面上でページめくり（画面遷移）が行われたことを自動検知してスクリーンショットを蓄積し、キャプチャ終了後に一括でOCR（文字起こし）を行うmacOSネイティブツール。
大規模な画像データを扱う際のLLMのAPIコスト（トークン消費）を削減するため、OCRにはApple純正の `Vision Framework` を使用し、最終的なテキストの整形のみをLLM APIに任せるハイブリッド構成とする。Python等の外部依存をなくし、Swift単体で高速かつ省電力に動作させる。

## 2. 主要な機能
1. **画面キャプチャ**: `CoreGraphics` または `ScreenCaptureKit` を利用して、指定領域のスクリーンショットを定期的に取得する。
2. **画面遷移の自動検知**: 取得したフレームと前回のフレームを比較し、ピクセルの差分（一定以上の変化）が発生したタイミングを検知する。
3. **画像の自動保存**: 遷移を検知した際、対象領域の画像を連番（例: `page_001.png`）としてローカルディレクトリに保存する。アニメーション中の連続キャプチャを防ぐためのクールダウン（遅延）処理を設ける。
4. **ローカル一括OCR**: 保存された複数枚の画像に対して、`Vision Framework` を利用して文字認識を行い、テキストを抽出する。縦書き・横書きの日本語および英語に対応。
5. **テキスト補正（LLM連携・オプション）**: 抽出したテキストデータを `URLSession` を用いて Anthropic (Claude) または OpenAI APIに送信し、誤字脱字の修正と自然な文章への整形を行う。

## 3. 技術スタック
* **言語**: Swift 5.0+
* **ターゲットOS**: macOS 13.0+ (Ventura以降推奨)
* **主要フレームワーク (Apple Native)**:
  * `CoreGraphics` / `ScreenCaptureKit`: 画面キャプチャ用
  * `CoreImage` / `Accelerate` (vImage): 画像の高速な差分計算用
  * `Vision`: オフライン高精度OCR (`VNRecognizeTextRequest`)
  * `Foundation` (`URLSession`): LLM APIとの非同期通信用

## 4. プロジェクト構成案 (Swift Package Manager または Xcode Project)
```text
AutoCaptureOCR/
├── Package.swift (または .xcodeproj)
├── Sources/
│   ├── AutoCaptureOCR/
│   │   ├── main.swift             # エントリポイント
│   │   ├── Config.swift           # 領域設定、閾値、APIキーなどの設定
│   │   ├── CaptureManager.swift   # 画面キャプチャ・差分検知・保存ロジック
│   │   ├── OCREngine.swift        # Vision FrameworkによるOCR処理
│   │   └── LLMClient.swift        # URLSessionを用いたテキスト補正処理
├── Output/
│   ├── Images/                    # 保存されたスクリーンショット
│   └── result.txt                 # 最終的な文字起こし結果