# CLAUDE.md - AutoCaptureOCR

## プロジェクト概要

macOSネイティブの画面遷移自動検知＆一括OCRツール。
画面上のページめくりを自動検知してスクリーンショットを蓄積し、Vision FrameworkでOCR、オプションでLLM APIによるテキスト補正を行う。

## 技術スタック

- **言語**: Swift 5.9+
- **対象OS**: macOS 13.0+ (Ventura以降)
- **ビルド**: `./build.sh`（推奨）または `swift build`（Xcode環境）
- **Apple専用フレームワーク使用**: CoreGraphics, ScreenCaptureKit, Vision, CoreImage, Accelerate, ImageIO
  - **Linux上ではビルド不可** — 必ずmacOS上で開発すること

## ビルド・実行

```bash
# ビルド（推奨）
./build.sh          # メインバイナリのみ
./build.sh all      # ユーティリティ含む全ビルド
./build.sh clean    # 成果物削除

# SPM（Xcode環境のみ。Command Line Tools 26.2ではManifestAPIバグあり）
swift build

# 実行
./AutoCaptureOCR
./AutoCaptureOCR --interval 0.3 --threshold 0.08 --rect 100,200,800,600

# LLM補正有効
ANTHROPIC_API_KEY=sk-... ./AutoCaptureOCR --llm --provider anthropic
```

## ファイル構成

| ファイル | 責務 |
|---------|------|
| `main.swift` | エントリポイント。Phase1(キャプチャ)→Phase2(OCR)→Phase3(LLM補正)の実行フロー |
| `Config.swift` | CLI引数パース、設定値管理 |
| `CaptureManager.swift` | CGWindowListCreateImageによる画面キャプチャ、ピクセル差分計算、遷移検知、PNG保存 |
| `OCREngine.swift` | VNRecognizeTextRequestによるテキスト認識（日英対応、.accurate、言語補正有効） |
| `LLMClient.swift` | Anthropic Messages API / OpenAI Chat Completions APIによるテキスト補正 |
| `build.sh` | swiftc直接ビルドスクリプト（SPMバグ回避用） |
| `select-rect.swift` | ドラッグで画面領域を選択→--rect引数を出力するユーティリティ |
| `get-mouse-pos.swift` | マウスカーソル座標を表示するユーティリティ |

## 実装状況

全コア機能は実装済み。

| モジュール | 状態 | 実装内容 |
|-----------|------|---------|
| `Config.swift` | 実装済み | CLI引数パース、設定値管理 |
| `main.swift` | 実装済み | Phase1→2→3のフロー制御、@main + async |
| `CaptureManager.swift` | 実装済み | CGWindowListCreateImage、Timer/RunLoopベース定期キャプチャ、ピクセル差分計算、CGImageDestinationによるPNG保存 |
| `OCREngine.swift` | 実装済み | VNRecognizeTextRequest（.accurate、日英、言語補正有効）、withCheckedThrowingContinuation |
| `LLMClient.swift` | 実装済み | Anthropic Messages API (claude-sonnet-4-20250514)、OpenAI Chat Completions API (gpt-4o) |

## ビルドに関する注意事項

- `@main` + 複数ソースファイルのswiftcビルドでは `-parse-as-library` が必須
- Command Line Tools 26.2（macOS 26 beta）では以下の既知バグあり:
  - SPM ManifestAPI のシンボル不整合（`SwiftVersion` vs `SwiftLanguageMode`）→ `swift build` 不可
  - `/usr/include/swift/` 配下の `module.modulemap` と `bridging.modulemap` で `SwiftBridging` モジュールが重複定義 → 退避が必要
  - コンパイラとSDKのSwiftバージョン微差（swiftlang-6.2.3.3.21 vs swiftlang-6.2.3.3.2）
- Xcode がインストールされた環境では上記の問題は発生しない可能性が高い

## 実行に必要な権限

- **画面収録**: システム設定 → プライバシーとセキュリティ → 画面収録 でターミナル（またはiTerm等）を許可
- **アクセシビリティ**（select-rect使用時）: CGEventSource.buttonState に必要

## コーディング規約

- Swift標準のコーディングスタイル準拠
- エラーは `throws` で伝播
- 日本語コメントOK
