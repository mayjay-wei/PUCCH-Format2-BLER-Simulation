# PUCCH Format 2 BLER Performance Simulation

## 概述

本專案實現了 5G NR PUCCH (Physical Uplink Control Channel) Format 2 的區塊錯誤率 (BLER) 性能模擬與 DMRS (Demodulation Reference Signal) 產生器。該專案包含完整的 PUCCH Format 2 傳輸鏈路模擬，並提供硬體實現所需的固定點數值格式。

## 功能特點

- **PUCCH Format 2 模擬**：完整的 PUCCH Format 2 傳輸鏈路模擬
- **DMRS 產生器**：獨立的 PUCCH Format 2 DMRS 符號產生工具
- **固定點轉換**：將 DMRS 符號轉換為 Q1.15 格式，適用於硬體實現
- **C 語言輸出格式**：自動產生 C 語言 array 初始化程式碼
- **多天線支援**：支援 1x2 MIMO 配置 (1 傳輸天線，2 接收天線)
- **通道建模**：使用 TDL-C 300ns 延遲擴展通道模型
- **UCI 編碼/解碼**：完整的 UCI 編碼和解碼過程
- **性能評估**：在多個 SNR 點評估 BLER 性能
- **視覺化結果**：自動產生 BLER vs SNR 性能曲線

## 系統需求

- MATLAB R2020b 或更新版本
- 5G Toolbox
- Communications Toolbox

## 配置參數

### 載波配置
- **子載波間距**：30 kHz
- **循環前綴**：Normal
- **資源格數量**：273 (對應 10 MHz 頻寬)
- **細胞 ID**：0

### PUCCH 配置
- **格式**：PUCCH Format 2
- **PRB 配置**：[0 1] (2 個連續 PRB)
- **符號分配**：[13 1] (第 13 個符號，持續 1 個符號)
- **跳頻**：關閉
- **RNTI**：1

### 模擬參數
- **模擬幀數**：5 個 10ms 幀
- **SNR 範圍**：-14 到 -4 dB (步長 2 dB)
- **UCI 位元數**：16 位元
- **天線配置**：1 傳輸，2 接收

### 通道模型
- **延遲剖面**：TDL-C 300ns
- **最大多普勒頻移**：100 Hz
- **MIMO 相關性**：低相關性
- **傳輸方向**：上行鏈路

## 使用方法

### 主要 BLER 模擬
1. 確保已安裝所需的 MATLAB 工具箱
2. 開啟 MATLAB 並導航到專案目錄
3. 執行主程式：
   ```matlab
   main
   ```

### DMRS 產生與固定點轉換
1. 執行 DMRS 產生器：
   ```matlab
   dmrs_gen
   ```
2. 程式會自動：
   - 產生 PUCCH Format 2 DMRS 符號
   - 轉換為 Q1.15 固定點格式
   - 輸出 C 語言 array 初始化程式碼
   - 提供多種輸出格式（複數結構體、分離陣列、交錯格式、16進位格式）

## 程式結構

```
main.m                 % 主要模擬程式
├── 參數設定           % 載波、PUCCH、UCI 配置
├── 通道建模           % TDL 通道配置
├── 模擬迴圈           % SNR 掃描迴圈
│   ├── 時槽迴圈       % 每個時槽的處理
│   ├── UCI 編碼       % UCI 位元編碼
│   ├── PUCCH 調變     % PUCCH 符號調變
│   ├── OFDM 調變      % OFDM 波形產生
│   ├── 通道傳輸       % 通道模擬和雜訊添加
│   ├── 同步化         % 時間同步
│   ├── OFDM 解調變    % 接收信號解調變
│   ├── 通道估計       % 通道估計
│   ├── 等化           % MMSE 等化
│   ├── PUCCH 解調變   % PUCCH 符號解調變
│   └── UCI 解碼       % UCI 位元解碼
└── 結果視覺化         % BLER 性能曲線繪製

dmrs_gen.m             % DMRS 產生器與固定點轉換工具
├── 載波配置           % 5G NR 載波參數設定
├── PUCCH 配置         % Format 2 特定參數
├── DMRS 產生          % 使用 nrPUCCHDMRS 產生參考信號
├── 固定點轉換         % 轉換為 Q1.15 格式
├── C 語言輸出         % 產生硬體實現用的陣列
└── 多格式支援         % 複數結構體、分離陣列、交錯格式
```

## 輸出結果

### BLER 模擬結果
模擬完成後將顯示：
1. 每個 SNR 點的即時 BLER 結果
2. BLER vs SNR 性能曲線圖
3. 包含配置資訊的圖表標題

### DMRS 固定點輸出
DMRS 產生器提供多種 C 語言格式：

1. **複數結構體格式**：
   ```c
   typedef struct { int16_t real; int16_t imag; } complex_q15_t;
   complex_q15_t pucch2_dmrs[N] = {{real, imag}, ...};
   ```

2. **分離陣列格式**：
   ```c
   int16_t pucch2_dmrs_real[N] = {real1, real2, ...};
   int16_t pucch2_dmrs_imag[N] = {imag1, imag2, ...};
   ```

3. **交錯格式**：
   ```c
   int16_t pucch2_dmrs_interleaved[2*N] = {real1, imag1, real2, imag2, ...};
   ```

4. **16進位格式**：
   ```c
   uint16_t pucch2_dmrs_hex[2*N] = {0xXXXX, 0xYYYY, ...};
   ```

## 性能優化

- 支援平行運算：取消註解 `parfor` 迴圈以使用平行運算工具箱
- 可調整模擬幀數來平衡精度和運算時間
- 支援完美通道估計和實用通道估計模式

## 故障排除

### 常見錯誤

1. **nrUCIEncode 錯誤 "Expected E to be a scalar with value > 25"**
   - 原因：PUCCH 資源配置不足以支援指定的 UCI 位元數
   - 解決方案：增加 PRB 數量或符號數量，或減少 UCI 位元數

2. **通道估計錯誤**
   - 確保通道模型參數與載波配置一致
   - 檢查天線數量配置

3. **DMRS 產生錯誤**
   - 確認 PUCCH 配置參數有效性
   - 檢查 PRB 配置範圍是否在載波範圍內
   - 驗證符號分配是否符合時槽結構

4. **固定點精度問題**
   - Q1.15 格式數值範圍：-1 到 +0.999969482421875
   - 如需更高精度，考慮使用 Q1.31 或浮點數格式
   - 檢查溢出保護機制是否正常運作

## 授權

本專案僅供學術研究使用。

## 作者

建立日期：2025年6月26日

## 更新日誌

- **v1.1**：新增 DMRS 產生器與固定點轉換功能
  - 新增 `dmrs_gen.m` - PUCCH Format 2 DMRS 符號產生器
  - 實現 Q1.15 固定點數值轉換
  - 提供多種 C 語言輸出格式
  - 支援硬體實現的陣列初始化程式碼產生
- **v1.0**：初始版本，實現基本 PUCCH Format 2 BLER 模擬
