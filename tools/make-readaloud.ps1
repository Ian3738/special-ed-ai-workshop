# ═══════════════════════════════════════════════════════════
# 報讀音檔批次產生器（Windows 版）
#
#   用法（PowerShell）：
#     .\make-readaloud.ps1 -Script 報讀腳本.txt -Out 報讀音檔
#
#   輸入格式：每題以 # 題號 起始，不報讀者於題號後加 [不報讀]
#
#     # 01
#     下列選項中，何者為質數？
#     選項 A，四。
#
#     # 05 [不報讀]
#     本題含圖形。
#
#   產出：逐題音檔、曲目對照表（CSV 與 HTML）
#
#   語音合成使用 Windows 內建 System.Speech，無須安裝。
#   內建僅能輸出 WAV；若電腦已安裝 ffmpeg，會自動轉為 MP3。
# ═══════════════════════════════════════════════════════════
param(
  [Parameter(Mandatory=$true)][string]$Script,
  [string]$Out = "報讀音檔",
  [string]$Voice = "",          # 留空則用系統預設中文語音
  [int]$Rate = -2,              # -10 至 10，報讀建議 -3 至 -1
  [int]$Bitrate = 64
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Speech

if (-not (Test-Path $Script)) { Write-Error "找不到腳本檔：$Script"; exit 1 }
New-Item -ItemType Directory -Force -Path $Out | Out-Null

# ── 偵測 ffmpeg，決定輸出格式 ──────────────────────
$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($ffmpeg) { $Ext = "mp3" } else {
  $Ext = "wav"
  Write-Host "※ 未偵測到 ffmpeg，改輸出 WAV（檔案較大，仍可播放）。"
  Write-Host "  需要 MP3 請先安裝 ffmpeg 並加入 PATH。"
}

$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
if ($Voice) { $synth.SelectVoice($Voice) }
else {
  $zh = $synth.GetInstalledVoices() | Where-Object {
    $_.VoiceInfo.Culture.Name -like "zh-TW*" } | Select-Object -First 1
  if ($zh) { $synth.SelectVoice($zh.VoiceInfo.Name) }
  else { Write-Host "※ 未找到繁體中文語音，使用系統預設。" }
}
$synth.Rate = $Rate

# ── 逐題切分 ───────────────────────────────────────
$items = @(); $cur = $null; $buf = @()
foreach ($line in Get-Content $Script -Encoding UTF8) {
  if ($line -match '^\s*#\s*(\d+)') {
    if ($cur) { $items += [pscustomobject]@{No=$cur.No; Skip=$cur.Skip; Body=($buf -join "`n")} }
    $cur = @{ No = [int]$Matches[1]; Skip = ($line -like "*[不報讀]*") }
    $buf = @()
  } elseif ($cur) { $buf += $line }
}
if ($cur) { $items += [pscustomobject]@{No=$cur.No; Skip=$cur.Skip; Body=($buf -join "`n")} }

# ── 逐題合成 ───────────────────────────────────────
$rows = @(); $skipped = 0; $total = 0.0
foreach ($it in $items) {
  $pad  = "{0:d2}" -f $it.No
  $text = if ($it.Skip) { "第 $($it.No) 題不報讀，請自行閱讀試題本。" } else { $it.Body }
  if ($it.Skip) { $skipped++ }

  $wav = Join-Path $Out "$pad.wav"
  $synth.SetOutputToWaveFile($wav)
  $synth.Speak($text)
  $synth.SetOutputToDefaultAudioDevice()

  $final = $wav
  if ($Ext -eq "mp3") {
    $mp3 = Join-Path $Out "$pad.mp3"
    & ffmpeg -loglevel error -y -i $wav -codec:a libmp3lame -b:a "$($Bitrate)k" -ac 1 $mp3
    Remove-Item $wav; $final = $mp3
  }

  $dur = [math]::Round((New-Object -ComObject Shell.Application).
         Namespace((Resolve-Path $Out).Path).
         ParseName((Split-Path $final -Leaf)).ExtendedProperty("System.Media.Duration") / 1e7, 1)
  $total += $dur
  $kind = if ($it.Skip) { "不報讀" } else { "報讀" }
  $sum  = ($text -replace "`n","") ; if ($sum.Length -gt 24) { $sum = $sum.Substring(0,24) }
  $rows += [pscustomobject]@{ 軌號=$pad; 題號=$it.No; 類別=$kind; 內容摘要=$sum; 長度秒=$dur; 檔名=(Split-Path $final -Leaf) }
  Write-Host ("  {0}  {1,-6} {2,5}s  {3}" -f $pad, $kind, $dur, $sum)
}
$synth.Dispose()

# ── 曲目對照表 ─────────────────────────────────────
$rows | Export-Csv (Join-Path $Out "曲目對照表.csv") -NoTypeInformation -Encoding UTF8

$html = @"
<!DOCTYPE html><html lang="zh-Hant-TW"><head><meta charset="UTF-8">
<title>曲目對照表</title><style>
body{font-family:"Microsoft JhengHei","PingFang TC",sans-serif;font-size:18px;line-height:1.7;padding:2rem;max-width:44rem;margin:0 auto}
table{width:100%;border-collapse:collapse;margin-top:1rem}
th,td{border:1px solid #999;padding:.5rem .7rem;text-align:left}
th{background:#eee}td.skip{background:#fbe6de;font-weight:700}
@media print{body{padding:0}}</style></head><body>
<h1>報讀音檔曲目對照表</h1>
<p>共 $($rows.Count) 軌，其中 $skipped 題不報讀，總長度約 $([math]::Round($total/60)) 分鐘。</p>
<table><thead><tr><th>軌號</th><th>題號</th><th>類別</th><th>長度</th></tr></thead><tbody>
"@
foreach ($r in $rows) {
  $cls = if ($r.類別 -eq "不報讀") { ' class="skip"' } else { "" }
  $html += "<tr><td>$($r.軌號)</td><td>$($r.題號)</td><td$cls>$($r.類別)</td><td>$($r.長度秒) 秒</td></tr>`n"
}
$html += "</tbody></table>`n<p><strong>不報讀之題目請自行閱讀試題本。</strong></p></body></html>"
$html | Set-Content (Join-Path $Out "曲目對照表.html") -Encoding UTF8

Write-Host ""
Write-Host "完成：$($rows.Count) 軌（$skipped 題不報讀），總長約 $([math]::Round($total/60)) 分鐘"
Write-Host "輸出：$Out\"
Write-Host "語速 $Rate　輸出格式 .$Ext"
