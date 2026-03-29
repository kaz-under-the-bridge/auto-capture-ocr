#!/usr/bin/env swift
// マウスカーソルの現在位置を表示するユーティリティ
// 使い方: swift get-mouse-pos.swift

import CoreGraphics

let event = CGEvent(source: nil)!
let point = event.location
print("x=\(Int(point.x)), y=\(Int(point.y))")
print("(CoreGraphics座標系: 左上原点)")
print()
print("--rect の例: --rect \(Int(point.x)),\(Int(point.y)),800,600")
