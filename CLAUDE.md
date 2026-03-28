# CLAUDE.md - AutoCaptureOCR

## プロジェクト概要

macOSネイティブの画面遷移自動検知＆一括OCRツール。
画面上のページめくりを自動検知してスクリーンショットを蓄積し、Vision FrameworkでOCR、オプションでLLM APIによるテキスト補正を行う。

## 技術スタック

- **言語**: Swift 5.9+
- **対象OS**: macOS 13.0+ (Ventura以降)
- **ビルド**: Swift Package Manager (`swift build`)
- **Apple専用フレームワーク使用**: CoreGraphics, ScreenCaptureKit, Vision, CoreImage, Accelerate
  - **Linux上ではビルド不可** — 必ずmacOS上で開発すること

## ビルド・実行

```bash
# ビルド
swift build

# 実行
swift run AutoCaptureOCR

# オプション付き実行
swift run AutoCaptureOCR --interval 0.3 --threshold 0.08 --rect 100,200,800,600

# LLM補正有効
ANTHROPIC_API_KEY=sk-... swift run AutoCaptureOCR --llm --provider anthropic
```

## ファイル構成

| ファイル | 責務 |
|---------|------|
| `main.swift` | エントリポイント。Phase1(キャプチャ)→Phase2(OCR)→Phase3(LLM補正)の実行フロー |
| `Config.swift` | CLI引数パース、設定値管理 |
| `CaptureManager.swift` | 画面キャプチャ、フレーム差分計算、遷移検知、画像保存 |
| `OCREngine.swift` | Vision Frameworkによるテキスト認識、結果のファイル出力 |
| `LLMClient.swift` | Anthropic/OpenAI APIへのテキスト補正リクエスト |

## 実装状況

現在はプロジェクト骨格のみ。各ファイルのTODO箇所をmacOS上で実装する必要がある。

### 実装タスク（優先順）

1. **CaptureManager.swift** — ScreenCaptureKit/CGWindowListCreateImageによるキャプチャ、vImageによるフレーム差分計算、PNG保存
2. **OCREngine.swift** — VNRecognizeTextRequestによるテキスト認識
3. **LLMClient.swift** — URLSessionによるAnthropic/OpenAI API呼び出し
4. **main.swift** — @mainとasync entrypointの動作確認（Swiftバージョンによる調整が必要な場合あり）

### macOS上でのみ可能な作業

- ビルド (`swift build`)
- 画面収録権限の付与（システム設定 → プライバシーとセキュリティ → 画面収録）
- 実機テスト（実際の画面遷移検知の動作確認）
- ScreenCaptureKitのAPI挙動確認（macOS 14以降で挙動が変わる場合あり）

## コーディング規約

- Swift標準のコーディングスタイル準拠
- エラーは `throws` で伝播、`fatalError` は未実装TODOのプレースホルダとしてのみ使用
- 日本語コメントOK
