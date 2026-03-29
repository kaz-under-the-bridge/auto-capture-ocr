# 画面遷移自動検知＆一括OCRツール (macOS Native / Swift) 設計ドキュメント

## 1. プロジェクト概要
Macの画面上でページめくり（画面遷移）が行われたことを自動検知してスクリーンショットを蓄積し、キャプチャ終了後に一括でOCR（文字起こし）を行うmacOSネイティブツール。
大規模な画像データを扱う際のLLMのAPIコスト（トークン消費）を削減するため、OCRにはApple純正の `Vision Framework` を使用し、最終的なテキストの整形のみをLLM APIに任せるハイブリッド構成とする。Python等の外部依存をなくし、Swift単体で高速かつ省電力に動作させる。

## 2. 主要な機能
1. **画面キャプチャ**: `CGWindowListCreateImage` を利用して、指定領域のスクリーンショットを定期的に取得する。
2. **画面遷移の自動検知**: 取得したフレームと前回のフレームをピクセル単位で比較し、差分率が閾値を超えたタイミングを遷移として検知する。
3. **画像の自動保存**: 遷移を検知した際、対象領域の画像を連番（例: `page_001.png`）としてローカルディレクトリに保存する。アニメーション中の連続キャプチャを防ぐためのクールダウン（遅延）処理を設ける。
4. **ローカル一括OCR**: 保存された複数枚の画像に対して、`Vision Framework` (`VNRecognizeTextRequest`) を利用して文字認識を行い、テキストを抽出する。縦書き・横書きの日本語および英語に対応。
5. **テキスト補正（LLM連携・オプション）**: 抽出したテキストデータを `URLSession` を用いて Anthropic (Claude) または OpenAI APIに送信し、誤字脱字の修正と自然な文章への整形を行う。

## 3. 技術スタック
* **言語**: Swift 5.9+
* **ターゲットOS**: macOS 13.0+ (Ventura以降)
* **主要フレームワーク (Apple Native)**:
  * `CoreGraphics`: 画面キャプチャ (`CGWindowListCreateImage`)
  * `ImageIO`: PNG画像の書き出し (`CGImageDestination`)
  * `Vision`: オフライン高精度OCR (`VNRecognizeTextRequest`)
  * `Foundation` (`URLSession`): LLM APIとの非同期通信

### 3.1 採用しなかった技術と理由

| 技術 | 不採用の理由 |
|------|------------|
| `ScreenCaptureKit` | macOS 12.3+だが権限モデルが複雑（SCContentFilter設定が必要）。`CGWindowListCreateImage` の方がシンプルで十分な性能 |
| `CoreImage` / `Accelerate (vImage)` | 差分計算に検討したが、CGContextでピクセルデータを直接比較する方がシンプルで依存が少ない |
| Python (`pyautogui`, `pytesseract` 等) | 外部依存が増える。Swift単体でVision Frameworkが使えるため不要 |

## 4. プロジェクト構成

```text
AutoCaptureOCR/
├── Package.swift              # SPM設定（Xcode環境用）
├── build.sh                   # swiftc直接ビルドスクリプト（推奨）
├── Sources/
│   └── AutoCaptureOCR/
│       ├── main.swift         # エントリポイント（@main + async）
│       ├── Config.swift       # CLI引数パース、設定値管理
│       ├── CaptureManager.swift   # 画面キャプチャ・差分検知・PNG保存
│       ├── OCREngine.swift    # Vision FrameworkによるOCR処理
│       └── LLMClient.swift    # LLM APIによるテキスト補正
├── select-rect.swift          # 領域選択ユーティリティ
├── get-mouse-pos.swift        # マウス座標確認ユーティリティ
├── Output/
│   ├── Images/                # 保存されたスクリーンショット
│   └── result.txt             # 最終的な文字起こし結果
└── docs/
    └── design.md              # 本ドキュメント
```

## 5. 実装詳細

### 5.1 画面キャプチャ (`CaptureManager`)

* **キャプチャAPI**: `CGWindowListCreateImage(.optionOnScreenOnly, kCGNullWindowID, .bestResolution)`
  * 全画面または `--rect` で指定した `CGRect` 領域をキャプチャ
* **定期取得**: `Timer` + `RunLoop` ベース。`config.captureInterval`（デフォルト0.5秒）間隔で `captureFrame()` を呼び出し
* **遷移検知**: 前フレームとの差分率を計算し、`config.diffThreshold`（デフォルト0.05 = 5%）を超えたら遷移と判定
* **クールダウン**: 遷移検知後 `config.cooldownDuration`（デフォルト1.0秒）は追加キャプチャをスキップし、アニメーション中の連続保存を防止
* **初回フレーム**: 基準フレームとして保持するのみで保存しない

### 5.2 差分計算アルゴリズム

* 両画像を同一サイズの `CGContext`（RGBA 8bit/channel）に描画してピクセルデータを取得
* ピクセル単位でRGB各チャンネルの差の絶対値を計算
* いずれかのチャンネルで差が30を超えるピクセルを「差分ピクセル」としてカウント
* `差分ピクセル数 / 全ピクセル数` を差分率として返す（0.0〜1.0）
* ピクセル閾値30は、JPEG圧縮アーティファクトやディスプレイのサブピクセルレンダリング差異を無視するため

### 5.3 PNG保存

* `CGImageDestinationCreateWithURL` + `CGImageDestinationAddImage` + `CGImageDestinationFinalize` でPNG書き出し
* UTI は `"public.png"` を使用
* ファイル名は `page_001.png`, `page_002.png`, ... の連番形式

### 5.4 OCR (`OCREngine`)

* `CGImageSourceCreateWithURL` → `CGImageSourceCreateImageAtIndex` で画像読み込み
* `VNRecognizeTextRequest` を使用:
  * `recognitionLanguages = ["ja", "en"]`（日本語優先）
  * `recognitionLevel = .accurate`（高精度モード）
  * `usesLanguageCorrection = true`（言語モデルベースの補正有効）
* `VNImageRequestHandler(cgImage:)` で実行
* 結果の `VNRecognizedTextObservation` から `topCandidates(1)` でテキスト抽出、改行で結合
* `withCheckedThrowingContinuation` で同期コールバックAPIをasync/awaitに変換

### 5.5 LLMテキスト補正 (`LLMClient`)

#### Anthropic API
* エンドポイント: `POST https://api.anthropic.com/v1/messages`
* モデル: `claude-sonnet-4-20250514`
* ヘッダー: `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`
* systemプロンプトでOCR後処理専門家として振る舞わせ、誤認識修正・改行整理・誤字修正を指示

#### OpenAI API
* エンドポイント: `POST https://api.openai.com/v1/chat/completions`
* モデル: `gpt-4o`
* ヘッダー: `Authorization: Bearer ...`, `content-type: application/json`
* system/userメッセージ構成で同一のプロンプトを使用

#### APIキー
* 環境変数から取得: `ANTHROPIC_API_KEY` または `OPENAI_API_KEY`

## 6. ビルドシステム

### 6.1 推奨: `build.sh`（swiftc直接ビルド）

`swiftc` でソースファイルを直接コンパイルする。SPMに依存しないため、Command Line Toolsのみの環境でも安定して動作する。

* `-parse-as-library`: `@main` 属性と複数ソースファイルの組み合わせで必要
* `-sdk`: `xcrun --show-sdk-path` で自動検出
* `-target arm64-apple-macosx13.0`: 最低デプロイメントターゲット

### 6.2 代替: Swift Package Manager

`Package.swift` を用意しており、Xcode環境では `swift build` / `swift run` が使用可能。
`swiftSettings` に `-parse-as-library` を、`linkerSettings` にすべてのフレームワーク（ImageIO含む）を指定済み。

## 7. 既知の問題とワークアラウンド

### 7.1 Command Line Tools 26.2 (macOS 26 beta) のSPMバグ

**症状**: `swift build` 実行時に `Undefined symbols: PackageDescription.Package.__allocating_init` エラー

**原因**: ManifestAPIの `libPackageDescription.dylib` が `SwiftLanguageMode` 型のシンボルのみ公開しているが、コンパイラが生成するPackage.swiftのオブジェクトファイルは `SwiftVersion` 型のシンボルを参照する。両者はtypealias関係だがマングル名が異なるため、リンクに失敗する。

**回避策**: `./build.sh` でswiftcを直接使用する。

### 7.2 SwiftBridging モジュール重複定義

**症状**: `swiftc` 直接ビルド時に `redefinition of module 'SwiftBridging'` エラー

**原因**: `/Library/Developer/CommandLineTools/usr/include/swift/` 配下に `module.modulemap` と `bridging.modulemap` の2ファイルが同じ `SwiftBridging` モジュールを定義している。

**回避策**:
```bash
sudo mv /Library/Developer/CommandLineTools/usr/include/swift/module.modulemap \
        /Library/Developer/CommandLineTools/usr/include/swift/module.modulemap.bak
```

### 7.3 コンパイラ/SDKバージョン微差

**症状**: `this SDK is not supported by the compiler` エラー

**原因**: Command Line Toolsのコンパイラ (swiftlang-6.2.3.3.21) と SDK (swiftlang-6.2.3.3.2) のパッチバージョンが一致しない。

**回避策**: 7.2の回避策適用後は、macOS 26.2 SDKで正常にビルド可能。Xcodeをインストールしている環境では発生しない可能性が高い。

## 8. 今後の拡張案

- [ ] ScreenCaptureKitベースの高効率キャプチャ（CGWindowListCreateImageからの移行）
- [ ] 差分計算のvImage/Accelerateによる高速化（大画面キャプチャ時のパフォーマンス改善）
- [ ] OCR結果のページ単位Markdown出力
- [ ] 複数ディスプレイ対応
- [ ] キャプチャ中のリアルタイムプレビュー表示
