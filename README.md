# AutoCaptureOCR

macOSネイティブの画面遷移自動検知＆一括OCRツール。

画面上のページめくりを自動検知してスクリーンショットを蓄積し、Apple Vision Frameworkでローカル一括OCRを行う。オプションでLLM API（Anthropic / OpenAI）によるテキスト補正にも対応。

## 特徴

- **画面遷移の自動検知** — ピクセル差分で画面変化を検知し、自動でスクリーンショットを保存
- **ローカルOCR** — Vision Framework による高精度テキスト認識（日本語・英語、縦書き・横書き対応）
- **LLMテキスト補正（オプション）** — OCR結果の誤字脱字修正をAnthropic/OpenAI APIで実行
- **外部依存なし** — Swift単体で動作、Python等不要

## 動作環境

- macOS 13.0 (Ventura) 以降
- Swift 5.9+ / Xcode 15+ または Command Line Tools
- 画面収録の権限（システム設定 → プライバシーとセキュリティ → 画面収録）

## ビルド

```bash
# 方法1: ビルドスクリプト（推奨）
./build.sh          # メインバイナリのみ
./build.sh all      # ユーティリティ含む全ビルド
./build.sh clean    # ビルド成果物を削除

# 方法2: Swift Package Manager（Xcode環境）
swift build
```

> **注意**: Command Line Tools 26.2（macOS 26 beta）では SPM の ManifestAPI にバグがあり `swift build` が失敗します。その場合は `./build.sh` を使用してください。

## 使い方

### 基本

```bash
# 全画面キャプチャで開始
./AutoCaptureOCR

# Enterキーで停止 → 自動でOCR処理
```

### オプション

```bash
./AutoCaptureOCR [OPTIONS]

Options:
  --interval <sec>        キャプチャ間隔（デフォルト: 0.5秒）
  --threshold <0.0-1.0>   遷移検知の差分閾値（デフォルト: 0.05）
  --cooldown <sec>        遷移後のクールダウン（デフォルト: 1.0秒）
  --output <dir>          画像保存先（デフォルト: ./Output/Images）
  --rect <x,y,w,h>       キャプチャ領域（デフォルト: 全画面）
  --llm                   LLMテキスト補正を有効化
  --provider <name>       LLMプロバイダ: anthropic|openai（デフォルト: anthropic）
  --help                  ヘルプを表示
```

### 使用例

```bash
# 指定領域をキャプチャ（間隔0.3秒、閾値0.08）
./AutoCaptureOCR --interval 0.3 --threshold 0.08 --rect 100,200,800,600

# LLM補正付き
ANTHROPIC_API_KEY=sk-... ./AutoCaptureOCR --llm --provider anthropic
```

### キャプチャ領域の選択

```bash
# 方法1: ドラッグで領域選択 → --rect 引数を出力
./select-rect

# 方法2: マウス位置の座標を確認
swift get-mouse-pos.swift

# 方法3: Cmd+Shift+4 でmacOS標準のクロスヘア表示
```

## 出力

```
Output/
├── Images/
│   ├── page_001.png
│   ├── page_002.png
│   └── ...
└── result.txt          # OCR結果テキスト
```

## ファイル構成

```
Sources/AutoCaptureOCR/
├── main.swift             # エントリポイント（Phase1→2→3の実行フロー）
├── Config.swift           # CLI引数パース、設定値管理
├── CaptureManager.swift   # 画面キャプチャ・差分検知・画像保存
├── OCREngine.swift        # Vision FrameworkによるOCR処理
└── LLMClient.swift        # Anthropic/OpenAI APIによるテキスト補正

build.sh                   # swiftc直接ビルドスクリプト
select-rect.swift          # ドラッグで領域選択するユーティリティ
get-mouse-pos.swift        # マウス座標確認ユーティリティ
Package.swift              # Swift Package Manager設定
```

## ライセンス

MIT
