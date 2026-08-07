# ═══════════════════════════════════════════════════════════
# 資料儀表板繪圖程式
#
# 產生網站 assets/charts/ 之四張圖。資料為模擬產生，
# 欄位比照 backend.html 所列之參考欄位。
#
# 換成實際資料：將 d 改為自資料庫匯出之資料框即可，
# 欄位名稱維持不變，後續繪圖程式無須更動。
#
#   Rscript tools/dashboard.R
# ═══════════════════════════════════════════════════════════
library(ggplot2); library(showtext); library(sysfonts); library(ragg); library(dplyr)

# 中文字型（macOS）
pf <- list.files("/System/Library/AssetsV2", pattern="^PingFang\\.ttc$",
                 recursive=TRUE, full.names=TRUE)[1]
if (!is.na(pf)) sysfonts::font_add("pf", regular=pf) else sysfonts::font_add("pf", "STHeiti Light.ttc")
showtext_auto(TRUE)

OUT <- file.path(dirname(dirname(normalizePath(sys.frames()[[1]]$ofile %||% "."))), "assets", "charts")
if (!dir.exists(OUT)) OUT <- "assets/charts"
dir.create(OUT, recursive=TRUE, showWarnings=FALSE)

# ── 模擬資料 ───────────────────────────────────────
set.seed(20260811)
n <- 480; units <- paste0("U", sprintf("%02d", 1:6))
d <- data.frame(session_id=sprintf("S%03d",1:n),
                unit_code=sample(units,n,TRUE),
                path_chosen=sample(c("text","audio","diagram"),n,TRUE,prob=c(.46,.33,.21)))
diff_u <- c(U01=.0,U02=.15,U03=.55,U04=.05,U05=.35,U06=.10)
d$path_switch_count <- rpois(n, 0.4 + 2.6*diff_u[d$unit_code])
d$response_mode <- sample(c("typed","selected","spoken"),n,TRUE,prob=c(.42,.40,.18))
p <- plogis(0.85 - 1.5*diff_u[d$unit_code] +
            ifelse(d$path_chosen=="audio",.05,0) + ifelse(d$path_chosen=="diagram",-.03,0))
d$correct <- rbinom(n,1,p)
d$time_on_task <- round(pmax(8, rnorm(n, 42+14*diff_u[d$unit_code], 12)), 1)

# ── 樣式 ───────────────────────────────────────────
BRAND<-"#0A5A4B"; HOT<-"#C2371A"; GOLD<-"#B07E00"
PAPER<-"#FFFCF6"; INK<-"#15181C"; MUT<-"#5E5A54"
PAL <- c(text=BRAND, audio=GOLD, diagram=HOT)
LAB <- c(text="文字", audio="語音", diagram="圖解")
LM  <- c(typed="書寫", selected="點選", spoken="口述")
CAP <- "模擬資料，非實際施測結果。用於說明欄位可回答之問題。"
th <- theme_minimal(base_size=15, base_family="pf") +
  theme(plot.background=element_rect(fill=PAPER,colour=NA),
        panel.background=element_rect(fill=PAPER,colour=NA),
        panel.grid.minor=element_blank(),
        panel.grid.major=element_line(colour="#DED7C8",linewidth=.35),
        text=element_text(colour=INK), axis.text=element_text(colour=MUT,size=13),
        plot.title=element_text(face="bold",size=17,margin=margin(b=3)),
        plot.subtitle=element_text(colour=MUT,size=12.5,margin=margin(b=10)),
        plot.caption=element_text(colour=MUT,size=10.5,hjust=0),
        legend.position="none", plot.margin=margin(14,16,10,14))
png <- function(f,w=760,h=460) agg_png(file.path(OUT,f), width=w, height=h, res=110, background=PAPER)

# 圖一 使用比例
a <- d |> count(path_chosen) |> mutate(pct=n/sum(n),
        lab=factor(LAB[path_chosen], levels=LAB[c("text","audio","diagram")]))
png("path-usage.png"); print(
ggplot(a, aes(lab,pct,fill=path_chosen)) + geom_col(width=.62) +
  geom_text(aes(label=sprintf("%.0f%%（%d 人次）",pct*100,n)), vjust=-.5,
            family="pf", size=4.6, colour=INK, fontface="bold") +
  scale_fill_manual(values=PAL) +
  scale_y_continuous(labels=scales::percent, limits=c(0,.58), expand=c(0,0)) +
  labs(title="各取用路徑之實際使用比例", x=NULL, y="使用比例",
       subtitle="回答：語音與圖解路徑是否真的有人使用", caption=CAP) + th); dev.off()

# 圖二 答對率
b <- d |> group_by(path_chosen) |>
  summarise(acc=mean(correct), n=n(), se=sqrt(acc*(1-acc)/n), .groups="drop") |>
  mutate(lab=factor(LAB[path_chosen], levels=LAB[c("text","audio","diagram")]))
png("path-accuracy.png"); print(
ggplot(b, aes(lab,acc,fill=path_chosen)) + geom_col(width=.62) +
  geom_errorbar(aes(ymin=acc-1.96*se, ymax=acc+1.96*se), width=.16, colour=INK, linewidth=.6) +
  geom_text(aes(y=acc-1.96*se, label=sprintf("%.1f%%",acc*100)), vjust=1.7,
            family="pf", size=4.6, colour=INK, fontface="bold") +
  scale_fill_manual(values=PAL) +
  scale_y_continuous(labels=scales::percent, limits=c(0,.82), expand=c(0,0)) +
  labs(title="各取用路徑之答對率", x=NULL, y="答對率",
       subtitle="三路徑之信賴區間重疊，表示內容深度一致，未因路徑而降低難度",
       caption=CAP) + th); dev.off()

# 圖三 單元切換次數
c3 <- d |> group_by(unit_code) |>
  summarise(m=mean(path_switch_count), n=n(), se=sd(path_switch_count)/sqrt(n), .groups="drop") |>
  arrange(desc(m)) |> mutate(unit_code=factor(unit_code, levels=unit_code), flag=m>=1.2)
png("unit-switch.png"); print(
ggplot(c3, aes(unit_code,m,fill=flag)) + geom_col(width=.62) +
  geom_errorbar(aes(ymin=pmax(0,m-1.96*se), ymax=m+1.96*se), width=.15, colour=INK, linewidth=.5) +
  geom_text(aes(label=sprintf("%.2f",m)), vjust=-1.5, family="pf", size=4.3,
            colour=INK, fontface="bold") +
  scale_fill_manual(values=c(`TRUE`=HOT,`FALSE`=BRAND)) +
  scale_y_continuous(limits=c(0,2.4), expand=c(0,0)) +
  annotate("text", x=6, y=2.15, label="＞1.2 者標為需檢視", family="pf",
           size=4.1, colour=HOT, fontface="bold", hjust=1) +
  labs(title="各單元之平均路徑切換次數", x="單元代碼", y="平均切換次數",
       subtitle="回答：哪些單元的既有設計存在障礙，使學生反覆更換取用方式",
       caption=CAP) + th); dev.off()

# 圖四 作答方式
c4 <- d |> group_by(response_mode) |>
  summarise(acc=mean(correct), n=n(), se=sqrt(acc*(1-acc)/n), .groups="drop") |>
  mutate(lab=factor(LM[response_mode], levels=LM[c("typed","selected","spoken")]))
png("response-mode.png", h=440); print(
ggplot(c4, aes(lab,acc)) +
  geom_hline(yintercept=mean(d$correct), linetype="22", colour=MUT, linewidth=.5) +
  geom_errorbar(aes(ymin=acc-1.96*se, ymax=acc+1.96*se), width=.13, colour=INK, linewidth=.6) +
  geom_point(size=5, colour=BRAND) +
  geom_text(aes(label=sprintf("%.1f%%（n=%d）",acc*100,n)), hjust=-.28,
            family="pf", size=4.4, colour=INK, fontface="bold") +
  annotate("text", x=.62, y=mean(d$correct)+.028, label="整體平均", family="pf",
           size=4, colour=MUT, hjust=0) +
  scale_y_continuous(labels=scales::percent, limits=c(.42,.86)) + coord_flip(clip="off") +
  labs(title="各作答方式之答對率", x=NULL, y="答對率",
       subtitle="回答：書寫、點選、口述三者是否等值；差距過大表示評分規準未對齊",
       caption=CAP) + th + theme(plot.margin=margin(14,64,10,14))); dev.off()

cat("四張圖已輸出至", OUT, "\n")
cat("\n注意：模擬資料的生成模型未設定作答方式效果，\n")
cat("      圖四所呈現之差異純屬抽樣變異（卡方檢定 p =",
    round(chisq.test(table(d$response_mode, d$correct))$p.value, 3), "）。\n")
