#!/bin/bash
# ═══════════════════════════════════════════════════════════
# 報讀音檔批次產生器
#
#   用法： ./make-readaloud.sh 報讀腳本.txt [輸出資料夾]
#
#   輸入格式：每題以 # 題號 起始，不報讀者於題號後加 [不報讀]
#
#     # 01
#     下列選項中，何者為質數？
#     選項 A，四。
#     選項 B，七。
#
#     # 05 [不報讀]
#     本題含圖形。
#
#   產出： 逐題 MP3、曲目對照表（CSV 與 HTML）
#
#   仿國中教育會考語音報讀之作法：一題一軌，另附曲目對照表，
#   不報讀之題目仍產生一軌並提示自行閱讀試題本，使軌號與題號一致。
# ═══════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_FILE="${1:-}"
OUT_DIR="${2:-報讀音檔}"
VOICE="${VOICE:-Meijia}"     # 臺灣中文語音，可用 say -v '?' 查看
RATE="${RATE:-150}"          # 每分鐘字數，報讀建議 140–160
BITRATE="${BITRATE:-64}"     # kbps，語音 64 已足夠

if [ -z "$SCRIPT_FILE" ] || [ ! -f "$SCRIPT_FILE" ]; then
  echo "用法：$0 報讀腳本.txt [輸出資料夾]" >&2
  exit 1
fi

# ── 偵測可用的編碼器 ─────────────────────────────
if command -v lame >/dev/null 2>&1;        then ENC=lame;    EXT=mp3
elif command -v ffmpeg >/dev/null 2>&1;    then ENC=ffmpeg;  EXT=mp3
else                                            ENC=afconvert; EXT=m4a
  echo "※ 未偵測到 lame 或 ffmpeg，改輸出 M4A（多數播放器可播）。"
  echo "  需要 MP3 請先安裝：brew install lame"
fi

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR"/*."$EXT" "$OUT_DIR"/曲目對照表.* 2>/dev/null || true
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

CSV="$OUT_DIR/曲目對照表.csv"
printf '\xEF\xBB\xBF' > "$CSV"          # BOM，Excel 才不會亂碼
echo "軌號,題號,類別,內容摘要,長度秒,檔名" >> "$CSV"

count=0; skipped=0; total=0

emit() {                                 # $1 題號  $2 是否不報讀  $3 內容檔
  local no="$1" skip="$2" body="$3"
  local pad; pad=$(printf "%02d" "$((10#$no))")
  local out="$OUT_DIR/$pad.$EXT"

  if [ "$skip" = "yes" ]; then
    echo "第 ${no} 題不報讀，請自行閱讀試題本。" > "$body"
    skipped=$((skipped+1))
  fi

  say -v "$VOICE" -r "$RATE" -f "$body" -o "$TMP/x.aiff"
  case "$ENC" in
    lame)      lame --quiet -h -b "$BITRATE" -m m "$TMP/x.aiff" "$out" ;;
    ffmpeg)    ffmpeg -loglevel error -y -i "$TMP/x.aiff" -codec:a libmp3lame -b:a "${BITRATE}k" -ac 1 "$out" ;;
    afconvert) afconvert -f m4af -d aac -b "$((BITRATE*1000))" "$TMP/x.aiff" "$out" ;;
  esac

  local dur; dur=$(afinfo "$out" 2>/dev/null | awk -F': ' '/estimated duration/{printf "%.1f",$2}')
  # 依「字元」而非位元組截斷，中文才不會斷成半個字；逗號改為全形避免破壞 CSV
  local sum; sum=$(tr -d '\n' < "$body" | perl -CS -ne 'print substr($_,0,24)' | tr ',"' '，、')
  local kind; [ "$skip" = "yes" ] && kind="不報讀" || kind="報讀"
  echo "$pad,$no,$kind,$sum,$dur,$pad.$EXT" >> "$CSV"
  printf '%s\t%s\t%s\t%s\n' "$pad" "$no" "$kind" "${dur:-0}" >> "$TMP/rows.tsv"
  total=$(echo "$total + ${dur:-0}" | bc)
  count=$((count+1))
  printf "  %s  %-6s %5ss  %s\n" "$pad" "$kind" "${dur:-?}" "$sum"
}

# ── 逐題切分 ─────────────────────────────────────
cur=""; skip="no"; body="$TMP/body.txt"; : > "$body"
while IFS= read -r line || [ -n "$line" ]; do
  if [[ "$line" =~ ^#[[:space:]]*([0-9]+) ]]; then
    [ -n "$cur" ] && emit "$cur" "$skip" "$body"
    cur="${BASH_REMATCH[1]}"
    [[ "$line" == *"[不報讀]"* ]] && skip="yes" || skip="no"
    : > "$body"
  else
    [ -n "$cur" ] && printf '%s\n' "$line" >> "$body"
  fi
done < "$SCRIPT_FILE"
[ -n "$cur" ] && emit "$cur" "$skip" "$body"

# ── 曲目對照表 HTML（可列印，發給學生）────────────
{
  echo '<!DOCTYPE html><html lang="zh-Hant-TW"><head><meta charset="UTF-8">'
  echo '<title>曲目對照表</title><style>'
  echo 'body{font-family:"PingFang TC","Microsoft JhengHei",sans-serif;font-size:18px;line-height:1.7;padding:2rem;max-width:44rem;margin:0 auto}'
  echo 'table{width:100%;border-collapse:collapse;margin-top:1rem}'
  echo 'th,td{border:1px solid #999;padding:.5rem .7rem;text-align:left}'
  echo 'th{background:#eee}td.skip{background:#fbe6de;font-weight:700}'
  echo '@media print{body{padding:0}}</style></head><body>'
  echo '<h1>報讀音檔曲目對照表</h1>'
  echo "<p>共 $count 軌，其中 $skipped 題不報讀，總長度約 $(echo "$total/60" | bc) 分鐘。</p>"
  echo '<table><thead><tr><th>軌號</th><th>題號</th><th>類別</th><th>長度</th></tr></thead><tbody>'
  while IFS=$'\t' read -r trk no kind dur; do
    cls=""; [ "$kind" = "不報讀" ] && cls=' class="skip"'
    echo "<tr><td>$trk</td><td>$no</td><td$cls>$kind</td><td>${dur} 秒</td></tr>"
  done < "$TMP/rows.tsv"
  echo '</tbody></table>'
  echo '<p><strong>不報讀之題目請自行閱讀試題本。</strong></p></body></html>'
} > "$OUT_DIR/曲目對照表.html"

echo
echo "完成：$count 軌（$skipped 題不報讀），總長約 $(echo "$total/60" | bc) 分鐘"
echo "輸出：$OUT_DIR/"
echo "語音 $VOICE　語速 $RATE　編碼 $ENC → .$EXT"
