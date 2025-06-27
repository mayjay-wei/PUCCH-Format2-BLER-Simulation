clear;
close all;
clc;


%% carrier setup
carrier = nrCarrierConfig;

carrier.NCellID = 0;
carrier.SubcarrierSpacing = 30;
carrier.NSizeGrid = 273;
carrier.NStartGrid = 0;
carrier.NSlot = 1;
disp(carrier);

%% fmt2 configure
pucch2 = nrPUCCH2Config;

pucch2.SymbolAllocation = [7 2];
pucch2.PRBSet = 40:45;
pucch2.FrequencyHopping = 'neither';
% pucch2.SecondHopStartPRB = 20;
pucch2.NID0 = 1005;


sym = nrPUCCHDMRS(carrier,pucch2);

sym_q15 = complex_to_q15(sym);

for i=1:length(sym_q15)
    fprintf('%d,%d,', real(sym_q15(i)), imag(sym_q15(i)));
end
fprintf("\n");
% 自定義轉換函數
function q15 = complex_to_q15(complex_data)
    % 分離實部和虛部
    real_part = real(complex_data);
    imag_part = imag(complex_data);
    
    
    % 轉換為 Q1.15
    real_q15 = int16(round(real_part * 32767));
    imag_q15 = int16(round(imag_part * 32767));
    
    % 確保不溢出
    real_q15 = max(-32768, min(32767, real_q15));
    imag_q15 = max(-32768, min(32767, imag_q15));

    % 合併實部和虛部
    q15 = complex(real_q15, imag_q15);
end