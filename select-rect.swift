#!/usr/bin/env swift
// 画面領域選択ユーティリティ
// マウスでドラッグして始点・終点を指定 → --rect 引数を出力
// 使い方: swift select-rect.swift

import CoreGraphics
import Foundation

print("画面上でドラッグして領域を選択してください...")
print("(マウスボタンを押す → ドラッグ → 離す)")
print()

var startPoint: CGPoint?
var endPoint: CGPoint?

func isLeftButtonDown() -> Bool {
    // CGEventSourceButtonState でマウスボタン状態を取得
    return CGEventSource.buttonState(.combinedSessionState, button: .left)
}

func currentMousePosition() -> CGPoint {
    return CGEvent(source: nil)!.location
}

// マウスダウンを待つ（押されていない状態から押された状態への遷移）
while isLeftButtonDown() { usleep(10_000) } // 既に押されていたら離されるまで待つ
while !isLeftButtonDown() { usleep(10_000) }
startPoint = currentMousePosition()
print("始点: x=\(Int(startPoint!.x)), y=\(Int(startPoint!.y))")

// マウスアップを待つ
while isLeftButtonDown() { usleep(10_000) }
endPoint = currentMousePosition()
print("終点: x=\(Int(endPoint!.x)), y=\(Int(endPoint!.y))")

let x = min(Int(startPoint!.x), Int(endPoint!.x))
let y = min(Int(startPoint!.y), Int(endPoint!.y))
let w = abs(Int(endPoint!.x) - Int(startPoint!.x))
let h = abs(Int(endPoint!.y) - Int(startPoint!.y))

print()
print("--rect \(x),\(y),\(w),\(h)")
print()
print("実行例:")
print("./AutoCaptureOCR --rect \(x),\(y),\(w),\(h)")
