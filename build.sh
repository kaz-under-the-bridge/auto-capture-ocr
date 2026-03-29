#!/bin/bash
# AutoCaptureOCR ビルドスクリプト
#
# 使い方:
#   ./build.sh            # メインバイナリをビルド
#   ./build.sh all        # メイン + ユーティリティをすべてビルド
#   ./build.sh clean      # ビルド成果物を削除
#
# 備考:
#   SPM (swift build) が使える環境ではそちらも利用可能。
#   Command Line Tools 26.2 では SPM の ManifestAPI にバグがあるため、
#   このスクリプトで swiftc 直接ビルドを行う。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

SDK=$(xcrun --show-sdk-path 2>/dev/null || echo "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk")
TARGET="arm64-apple-macosx13.0"

MAIN_SOURCES=(
  Sources/AutoCaptureOCR/Config.swift
  Sources/AutoCaptureOCR/CaptureManager.swift
  Sources/AutoCaptureOCR/OCREngine.swift
  Sources/AutoCaptureOCR/LLMClient.swift
  Sources/AutoCaptureOCR/main.swift
)

MAIN_FRAMEWORKS=(
  -framework ScreenCaptureKit
  -framework CoreGraphics
  -framework CoreImage
  -framework Vision
  -framework Accelerate
  -framework ImageIO
)

build_main() {
  echo "ビルド中: AutoCaptureOCR ..."
  swiftc \
    -parse-as-library \
    -o AutoCaptureOCR \
    -sdk "$SDK" \
    -target "$TARGET" \
    "${MAIN_FRAMEWORKS[@]}" \
    "${MAIN_SOURCES[@]}"
  echo "  → ./AutoCaptureOCR"
}

build_select_rect() {
  echo "ビルド中: select-rect ..."
  swiftc \
    -o select-rect \
    -sdk "$SDK" \
    -target "$TARGET" \
    -framework CoreGraphics \
    select-rect.swift
  echo "  → ./select-rect"
}

build_get_mouse_pos() {
  echo "ビルド中: get-mouse-pos ..."
  swiftc \
    -o get-mouse-pos \
    -sdk "$SDK" \
    -target "$TARGET" \
    -framework CoreGraphics \
    get-mouse-pos.swift
  echo "  → ./get-mouse-pos"
}

case "${1:-}" in
  all)
    build_main
    build_select_rect
    build_get_mouse_pos
    echo "すべてのビルドが完了しました。"
    ;;
  clean)
    rm -f AutoCaptureOCR select-rect get-mouse-pos
    echo "ビルド成果物を削除しました。"
    ;;
  *)
    build_main
    echo "ビルド完了。"
    echo "ユーティリティもビルドするには: ./build.sh all"
    ;;
esac
