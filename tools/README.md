# 報讀音檔批次產生器

將一份報讀腳本，一次產出逐題音檔與曲目對照表。
作法比照國中教育會考語音報讀服務：一題一軌、另附曲目對照表，
不報讀之題目仍產生一軌並提示自行閱讀試題本，使軌號與題號一致。

## 檔案

| 檔案 | 用途 |
|---|---|
| `make-readaloud.sh` | macOS 版，使用內建 `say` |
| `make-readaloud.ps1` | Windows 版，使用內建 System.Speech |
| `範例腳本.txt` | 輸入格式範例，含兩題不報讀 |

## 腳本格式

每題以 `# 題號` 起始。依會考規範不報讀之題目（圖形、表格、
特殊符號、形音義辨、區辨整合），於題號後加 `[不報讀]`。

```
# 01
下列選項中，何者為質數？
選項 A，四。
選項 B，七。

# 04 [不報讀]
本題含幾何圖形。
```

## 執行

macOS：

```
chmod +x make-readaloud.sh
./make-readaloud.sh 報讀腳本.txt 報讀音檔
```

Windows（PowerShell）：

```
.\make-readaloud.ps1 -Script 報讀腳本.txt -Out 報讀音檔
```

## 參數

以環境變數調整（macOS）或以參數傳入（Windows）：

| 項目 | 預設 | 說明 |
|---|---|---|
| 語音 | Meijia | macOS 以 `say -v '?'` 查看可用語音 |
| 語速 | 150 字／分 | 報讀建議 140 至 160 |
| 位元率 | 64 kbps | 語音已足夠 |

```
VOICE=Sinji RATE=140 ./make-readaloud.sh 報讀腳本.txt
```

## 輸出格式

macOS 內建的 `afconvert` 只能解碼 MP3、無法編碼，Windows 內建
語音合成亦僅輸出 WAV。腳本會自動偵測：

| 環境 | 有 lame 或 ffmpeg | 沒有 |
|---|---|---|
| macOS | MP3 | M4A |
| Windows | MP3 | WAV |

需要 MP3 時，macOS 執行 `brew install lame`，Windows 安裝
ffmpeg 並加入 PATH。M4A 與 WAV 多數播放器亦可播放。

## 使用前須確認

- 題目文字以裝置內建功能於本機擷取，不上傳試卷影像
- 系統可重複播放，與人工報讀一至二次不等值，屬不同強度之
  評量調整，須於個別化教育計畫會議記載
- 題目文字用畢即移除，音檔於考試結束後一併刪除
