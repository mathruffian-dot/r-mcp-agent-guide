# Palmer Penguins 端到端範例 —— 驗證 R 統計環境是否正常
# 用法：Rscript examples/penguins_demo.R
# 展現：R 原生抓網路資料 → 清理 → 含類別變數的多元迴歸 → ANOVA + Tukey → 出圖
# 全程僅用 base R，不需 tidyverse，開箱即用。

url <- "https://raw.githubusercontent.com/allisonhorst/palmerpenguins/main/inst/extdata/penguins.csv"
penguins <- read.csv(url, stringsAsFactors = TRUE)

cat("=== 1. 資料結構 ===\n")
cat("維度：", paste(dim(penguins), collapse = " x "), "\n")
print(table(penguins$species))
cat("缺失值：\n"); print(colSums(is.na(penguins)))

# 清理缺失值
df <- na.omit(penguins)
cat("\n清理後筆數：", nrow(df), "\n")

cat("\n=== 2. 分組敘述統計（體重平均/標準差）===\n")
print(aggregate(body_mass_g ~ species, df,
                FUN = function(x) round(c(平均 = mean(x), 標準差 = sd(x)), 1)))
cat("體重 vs 鰭長 相關係數 r =", round(cor(df$body_mass_g, df$flipper_length_mm), 3), "\n")

cat("\n=== 3. 多元迴歸：體重 ~ 鰭長 + 物種 ===\n")
m <- lm(body_mass_g ~ flipper_length_mm + species, data = df)
s <- summary(m)
print(round(s$coefficients, 3))
cat("R²=", round(s$r.squared, 3), " 調整後 R²=", round(s$adj.r.squared, 3),
    " F=", round(s$fstatistic[1], 1), "\n")

cat("\n=== 4. 單因子 ANOVA + Tukey 事後檢定 ===\n")
aov_fit <- aov(body_mass_g ~ species, data = df)
print(summary(aov_fit))
cat("Tukey 事後比較：\n")
print(round(TukeyHSD(aov_fit)$species, 2))

cat("\n=== 5. 出圖：體重 vs 鰭長（依物種，含迴歸線）===\n")
outfile <- file.path(tempdir(), "penguins_analysis.png")
cols <- c(Adelie = "#FF6B35", Chinstrap = "#A23B72", Gentoo = "#2A9D8F")
png(outfile, width = 1600, height = 1000, res = 180)
par(mar = c(5, 5, 4, 8))
plot(df$flipper_length_mm, df$body_mass_g,
     col = cols[as.character(df$species)], pch = 19, cex = 1.1,
     xlab = "Flipper length (mm)", ylab = "Body mass (g)",
     main = "Palmer Penguins: body mass vs flipper length")
for (sp in names(cols)) {
  abline(lm(body_mass_g ~ flipper_length_mm, data = df[df$species == sp, ]),
         col = cols[sp], lwd = 2.5)
}
legend(par("usr")[2], par("usr")[4], xpd = TRUE, bty = "n",
       legend = names(cols), col = cols, pch = 19, lwd = 2.5, title = "Species")
invisible(dev.off())
cat("圖已存：", outfile, "\n")

cat("\n✅ 驗證完成：若以上各步都正常輸出，代表 R 統計環境可用。\n")
