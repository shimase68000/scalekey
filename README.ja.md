# scalekey

[English](README.md) | [日本語](README.ja.md)

scalekey は、X68000 上の Human68k で動作するYM2151（OPM）用の常駐型演奏モジュールです。
X68000 のキーボードと MIDI 入力による OPM の発音機能をホストアプリケーションに提供します。

---

## Overview

scalekey は常駐して、**OPM の発音制御**を担当します。

ホストアプリケーションが演奏を依頼し、scalekey がキー入力・チャンネル割り当て・
OPM レジスタの操作を引き受けます。
発音処理は scalekey が担当するため、ホストは自身の処理に専念できます。

v1.10 では演奏機能を拡張しました。
**ユニゾン・ディレイ・ディチューン**を追加し、1 つのノートを複数の OPM チャンネルで鳴らせるようになりました。
あわせて、OPM チャンネルへのアサイン方式を拡張し、**Slotmask** にも対応しました。

---

## Key Features

- **X68000 キーボードで OPM を演奏**（2 オクターブ＋オクターブシフト）
- **MIDI IN で OPM を演奏**（MIDI ボードが必要）
- **ユニゾン（0〜8 音）**、**ディレイ**、**チャンネルごとのディチューン**
- **演奏に使用する OPM チャンネルの選択**と、**アサイン開始チャンネル**の指定
- **チャンネルアサイン方式** … Sequential / RoundRobin、それぞれに Hold / Over
- **Slotmask** … キーオンする operator を指定
- **MIDI チャンネルフィルタ** … OFF / Any / Ch.1～16
- **チャンネルの状態と発音中のノートを画面に表示**
- **コマンドラインから常駐・解除**

---

## System Structure

scalekey は、2 つに分かれたシステムの演奏側を担います。

- **ホスト** (Tone Editor) … 音色パラメータの編集・設定
- **scalekey** … キー入力・チャンネル割り当て・発音制御

両者は TRAP #7 のインターフェースでやり取りします。
scalekey はどのホストからでも使える設計ですが、
現在のホストは **[OPM Tone Editor 'Ｎ'](https://github.com/shimase68000/opm-tone-editor-n)** のみです。

現時点で、TRAP #7 のインターフェースをドキュメントでは公開していません。
scalekey の制御に関しては、`proj/src/trap7.s` をご覧ください。

> 1 つの scalekey を複数のホストから同時に使うことはできません。
> 先に確保したホストが、終了するまで使用権を保持します。

---

## Usage

```
usage: scalekey [switch]
switch:  -r  常駐解除
         -s  非表示モード
```

スイッチなしで `scalekey` を実行すると常駐します。
`scalekey -r` で常駐を解除します。

OPM Tone Editor 'Ｎ' と組み合わせて使う場合、通常は手動で実行する必要はありません。
エディタが scalekey の常駐・解除を行います
（`oe.jsn` の `scalekey.load_on_startup` / `unload_on_exit`）。

---

## Requirements

- Human68k が動作する X68000
- MIDI 入力には MIDI ボードが必要です。キーボード演奏は MIDI ボードが無くても動作します。

X68000 エミュレータ環境で動作を確認しています。

---

## Installation

Releases から配布アーカイブをダウンロードし、任意の場所に展開してください。

- [Releases](../../releases)

OPM Tone Editor 'Ｎ' と組み合わせて使う場合は、
`scalekey.r` を `PATH` の通った場所に置いてください。

- [OPM Tone Editor 'Ｎ'](https://github.com/shimase68000/opm-tone-editor-n) / [Releases](https://github.com/shimase68000/opm-tone-editor-n/releases)

OPM Tone Editor 'Ｎ' v1.20 は scalekey v1.10 以降と組み合わせて動作します。

---

## Source Code

`proj/` にソースコード（`inc/` `src/` `Makefile`）を収めています。
これは参考公開であり、ビルド環境の詳細な説明は現状では用意していません。
通常は、Releases の配布アーカイブをご利用ください。

---

## License

This project is released under the MIT License.

Copyright (c) 2025-2026 UG.
