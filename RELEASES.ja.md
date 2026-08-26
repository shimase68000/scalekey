# scalekey version 1.11

[English](RELEASES.md) | 日本語

**更新日:** 2026年8月26日  
**作成者:** UG.

---

## 概要

MIDI 出力をサポートする外部サウンドドライバとの併用に対応しました。

---

## 1. 新機能・機能拡張

- **MIDI I/F（YM3802）に触らないモード** を追加しました。

  `-n` スイッチを指定して常駐させると、scalekey は MIDI I/F を初期化しません。
  MIDI 出力をサポートするサウンドドライバを常駐させたまま使う場合に指定します。
  この場合、MIDI 入力による演奏はできません（キーボードからの演奏は可能です）。

  ```
  scalekey -n
  ```

  このモードは常駐時に決まり、後から変更することはできません。

---

## 2. 制限事項・動作条件

- MIDI 入力には **MIDI ボード** が必要です。
  ボードが無い場合、キーボードからの演奏のみ利用できます。
- **1 つの scalekey を複数のホストから同時に使うことはできません。**
  先に確保したホストが、終了するまで使用権を保持します。
- **v1.11 の常駐は、v1.10 以降の scalekey で解除してください。**
  v1.00 / v1.01 とは互いを認識しないため、旧版で v1.11 は解除できません。
- 動作確認は X68000 エミュレータ環境で行っています。

---

## 3. 備考

- scalekey は TSR（Terminate and Stay Resident）常駐プロセスとして動作します。
- **[OPM Tone Editor 'Ｎ'](https://github.com/shimase68000/opm-tone-editor-n) v1.21** と組み合わせて利用することを前提に設計されています。
  エディタ側からは `oe.jsn` の `scalekey.midi_enable` で `-n` 相当の設定を行えます。
  詳しくはエディタ側の [RELEASES](https://github.com/shimase68000/opm-tone-editor-n/blob/main/RELEASES.ja.md) をご覧ください。

---

<footer>
<p align="center">Copyright (c) 2026 UG. All rights reserved.</p>
</footer>
