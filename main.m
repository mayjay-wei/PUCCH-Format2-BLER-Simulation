clc, clear, close all;

%% Simulation Length and SNR Points

simParameters = struct;         % Create simParameters structure
simParameters.NFrames = 5;      % Number of 10 ms frames
simParameters.SNRIn = -14:2:-4; % SNR range (dB)

displaySimulationInformation = true;

%% Carrier and PUCCH Configuration

% Set carrier resource grid properties (15 kHz SCS and 10 MHz bandwidth)
carrier = nrCarrierConfig;
carrier.NCellID = 0;
carrier.SubcarrierSpacing = 30;
carrier.CyclicPrefix = "normal";
carrier.NSizeGrid = 273;
carrier.NStartGrid = 0;

% Set PUCCH format 3 properties
pucch = nrPUCCH2Config;
pucch.PRBSet = [0 1];
pucch.SymbolAllocation = [13 1];
pucch.FrequencyHopping = "neither";
pucch.NID = [];
pucch.RNTI = 1;

% Set number of transmit and receive antennas
simParameters.NTxAnts = 1;
simParameters.NRxAnts = 2;

%% UCI Configuration
simParameters.NumUCIBits = 16; % Number of UCI bits

%% UCI Configuration
perfectChannelEstimator = true;

%% Propagation Channel Model Configuration
% Set up TDL channel
channel = nrTDLChannel;
channel.DelayProfile = 'TDLC300';
channel.MaximumDopplerShift = 100; % in Hz
channel.MIMOCorrelation = 'low';
channel.TransmissionDirection = 'Uplink';
channel.NumTransmitAntennas = simParameters.NTxAnts;
channel.NumReceiveAntennas = simParameters.NRxAnts;

waveformInfo = nrOFDMInfo(carrier);
channel.SampleRate = waveformInfo.SampleRate;

%% Processing Loop and Results

% Obtain channel information
chInfo = info(channel);

% Specify array to store output(s) for all SNR points
blerUCI = zeros(length(simParameters.SNRIn),1);

% Assign temporary variables for parallel simulation
nTxAnts = simParameters.NTxAnts;
nRxAnts = simParameters.NRxAnts;
snrIn = simParameters.SNRIn;
nFrames = simParameters.NFrames;
ouci = simParameters.NumUCIBits;
nFFT = waveformInfo.Nfft;
symbolsPerSlot = carrier.SymbolsPerSlot;
slotsPerFrame = carrier.SlotsPerFrame;

% Validate number of frames
validateattributes(nFrames,{'double'},{'scalar','positive','integer'},'','simParameters.NFrames')

% Validate SNR range
validateattributes(snrIn,{'double'},{'real','vector','finite'},'','simParameters.SNRIn')

% Validate PUCCH configuration
classPUCCH = validatestring(class(pucch),{'nrPUCCH2Config','nrPUCCH3Config','nrPUCCH4Config'},'','class of PUCCH');
formatPUCCH = classPUCCH(8);

% The temporary variables carrier_init and pucch_init are used to
% create the temporary variables carrier and pucch in the SNR loop
% to create independent instances in case of parallel simulation.
carrier_init = carrier;
pucch_init = pucch;

for snrIdx = 1:numel(snrIn) % Comment out for parallel computing
% parfor snrIdx = 1:numel(snrIn) % Uncomment for parallel computing
    % To reduce the total simulation time, you can execute this loop in
    % parallel by using Parallel Computing Toolbox features. Comment out the
    % for-loop statement and uncomment the parfor-loop statement. If
    % Parallel Computing Toolbox is not installed, parfor-loop defaults to
    % a for-loop statement. Because the parfor-loop iterations are executed
    % in parallel in a nondeterministic order, the simulation information
    % displayed for each SNR point can be intertwined. To switch off the
    % simulation information display, set the displaySimulationInformation
    % variable (defined earlier in this example) to false.

    % Reset the random number generator and channel so that each SNR point
    % experiences the same noise and channel realizations.
    rng(0,'twister')
    reset(channel)

    % Initialize variables for this SNR point (required when using
    % Parallel Computing Toolbox)
    carrier = carrier_init;
    pucch = pucch_init;
    pathFilters = [];

    % Get operating SNR value
    SNRdB = snrIn(snrIdx);

    % Get total number of slots in the simulation period
    NSlots = nFrames*slotsPerFrame;

    % Set timing offset, which is updated in every slot for perfect
    % synchronization and when correlation is strong for practical
    % synchronization
    offset = 0;

    % Set variable to store block errors for each SNR point with 0
    ucierr = 0;
    for nslot = 0:NSlots-1

        % Update carrier slot number to account for new slot transmission
        carrier.NSlot = nslot;

        % Get PUCCH resources
        [pucchIndices,pucchIndicesInfo] = nrPUCCHIndices(carrier,pucch);
        dmrsIndices = nrPUCCHDMRSIndices(carrier,pucch);
        dmrsSymbols = nrPUCCHDMRS(carrier,pucch);

        % Create random UCI bits
        uci = randi([0 1],ouci,1);

        % Perform UCI encoding
        codedUCI = nrUCIEncode(uci, pucchIndicesInfo.G);

        % Perform PUCCH modulation
        pucchSymbols = nrPUCCH(carrier,pucch,codedUCI);

        % Create resource grid associated with PUCCH transmission antennas
        pucchGrid = nrResourceGrid(carrier,nTxAnts);

        % Perform implementation-specific PUCCH MIMO precoding and mapping
        F = eye(1,nTxAnts);
        [~,pucchAntIndices] = nrExtractResources(pucchIndices,pucchGrid);
        pucchGrid(pucchAntIndices) = pucchSymbols*F;

        % Perform implementation-specific PUCCH DM-RS MIMO precoding and mapping
        [~,dmrsAntIndices] = nrExtractResources(dmrsIndices,pucchGrid);
        pucchGrid(dmrsAntIndices) = dmrsSymbols*F;

        % Perform OFDM modulation
        txWaveform = nrOFDMModulate(carrier,pucchGrid);

        % Pass data through the channel model. Append zeros at the end of
        % the transmitted waveform to flush the channel content. These
        % zeros take into account any delay introduced in the channel. This
        % delay is a combination of the multipath delay and implementation
        % delay. This value can change depending on the sampling rate,
        % delay profile, and delay spread.
        txWaveformChDelay = [txWaveform; zeros(chInfo.MaximumChannelDelay,size(txWaveform,2))];
        [rxWaveform,pathGains,sampleTimes] = channel(txWaveformChDelay);

        % Add AWGN to the received time domain waveform. Normalize the
        % noise power by the size of the inverse fast Fourier transform
        % (IFFT) used in OFDM modulation, because the OFDM modulator
        % applies this normalization to the transmitted waveform. Also,
        % normalize the noise power by the number of receive antennas,
        % because the default behavior of the channel model is to apply
        % this normalization to the received waveform.
        SNR = 10^(SNRdB/20);
        N0 = 1/(sqrt(2.0*nRxAnts*nFFT)*SNR);
        noise = N0*complex(randn(size(rxWaveform)),randn(size(rxWaveform)));
        rxWaveform = rxWaveform + noise;

        % Perform synchronization
        if perfectChannelEstimator == 1
            % For perfect synchronization, use the information provided by
            % the channel to find the strongest multipath component.
            pathFilters = getPathFilters(channel);
            [offset,mag] = nrPerfectTimingEstimate(pathGains,pathFilters);
        else
            % For practical synchronization, correlate the received
            % waveform with the PUCCH DM-RS to give timing offset estimate
            % t and correlation magnitude mag. The function hSkipWeakTimingOffset
            % is used to update the receiver timing offset. If the correlation
            % peak in mag is weak, the current timing estimate t is ignored
            % and the previous estimate offset is used.
            [t,mag] = nrTimingEstimate(carrier,rxWaveform,dmrsIndices,dmrsSymbols);
            offset = hSkipWeakTimingOffset(offset,t,mag);
            
            % Display a warning if the estimated timing offset exceeds the
            % maximum channel delay
            if offset > chInfo.MaximumChannelDelay
                warning(['Estimated timing offset (%d) is greater than the maximum channel delay (%d).' ...
                    ' This will result in a decoding failure. This may be caused by low SNR,' ...
                    ' or not enough DM-RS symbols to synchronize successfully.'],offset,chInfo.MaximumChannelDelay);
            end
        end
        rxWaveform = rxWaveform(1+offset:end,:);

        % Perform OFDM demodulation on the received data to recreate the
        % resource grid. Include zero padding in the event that practical
        % synchronization results in an incomplete slot being demodulated.
        rxGrid = nrOFDMDemodulate(carrier,rxWaveform);
        [K,L,R] = size(rxGrid);
        if (L < symbolsPerSlot)
            rxGrid = cat(2,rxGrid,zeros(K,symbolsPerSlot-L,R));
        end

        % Perform channel estimation
        if perfectChannelEstimator == 1
            % For perfect channel estimation, use the value of the path
            % gains provided by the channel.
            estChannelGrid = nrPerfectChannelEstimate(carrier,pathGains,pathFilters,offset,sampleTimes);

            % Get the perfect noise estimate (from the noise realization).
            noiseGrid = nrOFDMDemodulate(carrier,noise(1+offset:end,:));
            noiseEst = var(noiseGrid(:));

            % Apply MIMO deprecoding to estChannelGrid to give an
            % estimate per transmission layer.
            K = size(estChannelGrid,1);
            estChannelGrid = reshape(estChannelGrid,K*symbolsPerSlot*nRxAnts,nTxAnts);
            estChannelGrid = estChannelGrid*F.';
            estChannelGrid = reshape(estChannelGrid,K,symbolsPerSlot,nRxAnts,[]);
        else
            % For practical channel estimation, use PUCCH DM-RS.
            [estChannelGrid,noiseEst] = nrChannelEstimate(carrier,rxGrid,dmrsIndices,dmrsSymbols);
        end

        % Get PUCCH REs from received grid and estimated channel grid
        [pucchRx,pucchHest] = nrExtractResources(pucchIndices,rxGrid,estChannelGrid);

        % Perform equalization
        [pucchEq,csi] = nrEqualizeMMSE(pucchRx,pucchHest,noiseEst);

        % Decode PUCCH symbols
        [uciLLRs,rxSymbols] = nrPUCCHDecode(carrier,pucch,ouci,pucchEq,noiseEst);

        % Decode UCI
        decucibits = nrUCIDecode(uciLLRs{1},ouci);

        % Store values to calculate BLER
        ucierr = ucierr + (~isequal(decucibits,uci));

    end

    % Calculate UCI BLER for each SNR point
    blerUCI(snrIdx) = ucierr/NSlots;

    % Display results dynamically
    if displaySimulationInformation == 1
        fprintf(['UCI BLER of PUCCH format ' formatPUCCH ' for ' num2str(nFrames) ' frame(s) at SNR ' num2str(snrIn(snrIdx)) ' dB: ' num2str(blerUCI(snrIdx)) '\n'])
    end
end

% Plot results
figure
semilogy(snrIn,blerUCI,'-*')
grid on
xlabel('SNR (dB)')
ylabel('Block Error Rate')
title(sprintf('PUCCH Format = %s / NSizeGrid = %d / SCS = %d kHz / %dx%d',...
    formatPUCCH,carrier_init.NSizeGrid,carrier_init.SubcarrierSpacing,nTxAnts,nRxAnts))
