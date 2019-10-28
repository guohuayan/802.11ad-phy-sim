%% Script loads WIFI parameters for simulation and compute dependent parameters
%
% Authors:	Jiri Milos and Ladislav Polak, DREL FEEC BUT, 2018
%
warning('off')

%% load_wifi_params file for load parameters of simulation
% auxiliary parameters for debugging
useScrambling = true;
sendAllZeros = false;
sendAllOnes = false;
dataSymbolRotation = true;
showMapping = 0; % display of subcarriers mapping

% other parameters
wifi_params.general.standard = wifi_standard;
wifi_params.general.channel = channelType;

wifi_params.general.useScrambling = useScrambling;
wifi_params.general.showMapping = showMapping;

wifi_params.general.sendAllZeros = sendAllZeros;
wifi_params.general.sendAllOnes = sendAllOnes;

wifi_params.general.dataSymbolRotation = dataSymbolRotation;

disp('----------------------------------------------------------------')

if (wifi_params.general.sendAllZeros && wifi_params.general.sendAllOnes) == 1
    disp('Conflict: variables sendAllZeros and sendAllOnes are set to TRUE');
    disp('The transmitter will send all data bits as ones');
    disp('----------------------------------------------------------------')
    wifi_params.general.sendAllZeros = false;
    wifi_params.general.sendAllOnes = true;
end

if (wifi_params.general.sendAllZeros || wifi_params.general.sendAllOnes) == 1
    disp('Data scrambling is disabled');
    disp('----------------------------------------------------------------')
    wifi_params.general.useScrambling = false;
end
%% Colission detection:
switch wifi_standard
    case '802dot11ad'
        addpath('.\measured_channels');
    otherwise
        error('Unsupported type of IEEE 802.11 standard');
end

%% PHY layer - timing-related constants
switch wifi_standard
    case '802dot11ad'
        wifi_params.mapping.bandwidth = 2640e6;
        wifi_params.mapping.n_fft = 512; % FFT size
        wifi_params.mapping.N_GI = 64;
        wifi_params.mapping.N_SPB = 448;
        wifi_params.mapping.Fchip = 1760e6; % chip rate = 2/3*Fs
        wifi_params.mapping.Tchip = 1/wifi_params.mapping.Fchip; % chip time
        wifi_params.mapping.T_seq = 128*wifi_params.mapping.Tchip;
        wifi_params.mapping.T_STF = 17*wifi_params.mapping.T_seq; % detection sequence duration
        wifi_params.mapping.T_CE = 9*wifi_params.mapping.T_seq; % channel estimation sequence duration
        wifi_params.mapping.T_HEADER = 2*512*wifi_params.mapping.Tchip; % header duration
        wifi_params.mapping.F_CPP = 1760e6; % control mode chip rate
        wifi_params.mapping.T_CPP = 1/wifi_params.mapping.F_CPP; % control mode chip time
        wifi_params.mapping.T_STF_CP = 50*wifi_params.mapping.T_seq; % control mode short training field duration
        wifi_params.mapping.T_CE_CP = 9*wifi_params.mapping.T_seq; % control mode channel estimation field duration
        try
            %             wifi_params.mapping.N_BLKS = []; % see 20.6.3.2.3.3
            wifi_params.mapping.T_data = ((wifi_params.mapping.N_BLKS*512)+64)*wifi_params.mapping.Tchip;
        catch
            warning('N_BLKS undefined yet, see 20.6.3.2.3.3 - calculate after LDPC coding definition')
        end
    otherwise
        error('Unsupported type of IEEE 802.11 standard');
end
% parameters dependent
if strcmp(wifi_standard,'802dot11ad')
    % TBD
    wifi_params.mapping.n_tot = wifi_params.mapping.N_SPB;
else
    wifi_params.mapping.n_tot = wifi_params.mapping.n_data+wifi_params.mapping.n_pilot;
    wifi_params.mapping.df = wifi_params.mapping.bandwidth/wifi_params.mapping.n_fft;
    wifi_params.mapping.bw_real = wifi_params.mapping.n_tot*wifi_params.mapping.df;
    wifi_params.mapping.ir_all = -wifi_params.mapping.ir_highest_subc:wifi_params.mapping.ir_highest_subc;
end

wifi_params.general.LENGTH = LENGTH;
switch wifi_standard
    case '802dot11ah'
        wifi_params.mapping.service_length = 8;
    otherwise
        wifi_params.mapping.service_length = 16;
end

%% MODEM common params ====================================================
% BPSK --------------------------------------------------------------------
wifi_params.modulation(1).M = 1; % BPSK
wifi_params.modulation(1).k = 2.^wifi_params.modulation(1).M; % number of constellation points
wifi_params.modulation(1).hMod = comm.PSKModulator(...
    'ModulationOrder',wifi_params.modulation(1).k,...
    'PhaseOffset',pi,...
    'BitInput',true);
wifi_params.modulation(1).hDemod = comm.PSKDemodulator(...
    'ModulationOrder',wifi_params.modulation(1).k,...
    'PhaseOffset',pi,...
    'BitOutput',true,...
    'DecisionMethod','Hard decision');
wifi_params.modulation(1).hDemod_LLR = comm.PSKDemodulator(...
    'ModulationOrder',wifi_params.modulation(1).k,...
    'PhaseOffset',pi,...
    'BitOutput',true,...
    'DecisionMethod','Approximate log-likelihood ratio',... % Log-likelihood ratio
    'VarianceSource','Property');
wifi_params.modulation(1).hDemod_LLR.Variance = 1;
wifi_params.modulation(1).hMod_factor = 1;
wifi_params.modulation(1).hScalQuant = dsp.ScalarQuantizerEncoder('Partitioning','Unbounded');
wifi_params.modulation(1).bound_pts_wo_noiseVar = (-1.5:0.5:1.5)*wifi_params.modulation(1).hMod_factor;
% QPSK --------------------------------------------------------------------
wifi_params.modulation(2).M = 2; % QPSK
wifi_params.modulation(2).k = 2.^wifi_params.modulation(2).M; % number of constellation points
if strcmp(wifi_standard, '802dot11ad')
    wifi_params.modulation(2).hMod = comm.PSKModulator(...
        'ModulationOrder',wifi_params.modulation(2).k,...
        'PhaseOffset',0,...
        'BitInput',true,...
        'SymbolMapping','Custom',...
        'CustomSymbolMapping',[3 1 0 2]);
    wifi_params.modulation(2).hDemod = comm.PSKDemodulator(...
        'ModulationOrder',wifi_params.modulation(2).k,...
        'PhaseOffset',0,...
        'BitOutput',true,...
        'SymbolMapping','Custom',...
        'CustomSymbolMapping',[3 1 0 2],...
        'DecisionMethod','Hard decision');
    wifi_params.modulation(2).hDemod_LLR = comm.PSKDemodulator(...
        'ModulationOrder',wifi_params.modulation(2).k,...
        'PhaseOffset',0,...
        'BitOutput',true,...
        'SymbolMapping','Custom',...
        'CustomSymbolMapping',[3 1 0 2],...
        'DecisionMethod','Log-likelihood ratio',...
        'VarianceSource','Property'); %'Log-likelihood ratio');
    wifi_params.modulation(2).hDemod_LLR.Variance = 1;
else
    wifi_params.modulation(2).hMod = comm.PSKModulator(...
        'ModulationOrder',wifi_params.modulation(2).k,...
        'PhaseOffset',pi/4,...
        'BitInput',true,...
        'SymbolMapping','Custom',...
        'CustomSymbolMapping',[3 1 0 2]);
    wifi_params.modulation(2).hDemod = comm.PSKDemodulator(...
        'ModulationOrder',wifi_params.modulation(2).k,...
        'PhaseOffset',pi/4,...
        'BitOutput',true,...
        'SymbolMapping','Custom',...
        'CustomSymbolMapping',[3 1 0 2],...
        'DecisionMethod','Hard decision');
    wifi_params.modulation(2).hDemod_LLR = comm.PSKDemodulator(...
        'ModulationOrder',wifi_params.modulation(2).k,...
        'PhaseOffset',pi/4,...
        'BitOutput',true,...
        'SymbolMapping','Custom',...
        'CustomSymbolMapping',[3 1 0 2],...
        'DecisionMethod','Log-likelihood ratio',...
        'VarianceSource','Property'); %'Log-likelihood ratio');
    wifi_params.modulation(2).hDemod_LLR.Variance = 1;
end
wifi_params.modulation(2).hMod_factor = 1;
wifi_params.modulation(2).hScalQuant = dsp.ScalarQuantizerEncoder('Partitioning','Unbounded');
wifi_params.modulation(2).bound_pts_wo_noiseVar = (-1.5:0.5:1.5)*wifi_params.modulation(2).hMod_factor;
% 16QAM
wifi_params.modulation(4).M = 4; % 16QAM
wifi_params.modulation(4).k = 2.^wifi_params.modulation(4).M; % number of constellation points
wifi_params.modulation(4).hMod = comm.RectangularQAMModulator(...
    'ModulationOrder',wifi_params.modulation(4).k,...
    'BitInput',true,...
    'SymbolMapping','Custom',...
    'CustomSymbolMapping',...
    [2 3 1 0 6 7 5 4 ...
    14 15 13 12 10 11 9 8]);
wifi_params.modulation(4).hDemod = comm.RectangularQAMDemodulator(...
    'ModulationOrder',wifi_params.modulation(4).k,...
    'BitOutput',true,...
    'SymbolMapping','Custom',...
    'CustomSymbolMapping',...
    [2 3 1 0 6 7 5 4 ...
    14 15 13 12 10 11 9 8],...
    'DecisionMethod','Hard decision');
wifi_params.modulation(4).hDemod_LLR = comm.RectangularQAMDemodulator(...
    'ModulationOrder',wifi_params.modulation(4).k,...
    'BitOutput',true,...
    'SymbolMapping','Custom',...
    'CustomSymbolMapping',...
    [2 3 1 0 6 7 5 4 ...
    14 15 13 12 10 11 9 8],...
    'DecisionMethod','Log-likelihood ratio',...
    'VarianceSource','Property');
wifi_params.modulation(4).hDemod_LLR.Variance = 1;
wifi_params.modulation(4).hMod_factor = 1/sqrt(10);
wifi_params.modulation(4).hScalQuant = dsp.ScalarQuantizerEncoder('Partitioning','Unbounded');
wifi_params.modulation(4).bound_pts_wo_noiseVar = (-3:1:3)*wifi_params.modulation(4).hMod_factor;
% 64QAM
wifi_params.modulation(6).M = 6; % 64QAM
wifi_params.modulation(6).k = 2.^wifi_params.modulation(6).M; % number of constellation points
wifi_params.modulation(6).hMod = comm.RectangularQAMModulator(...
    'ModulationOrder',wifi_params.modulation(6).k,...
    'BitInput',true,...
    'SymbolMapping','Custom',...
    'CustomSymbolMapping',...
    [4 5 7 6 2 3 1 0 ...
    12 13 15 14 10 11 9 8 ...
    28 29 31 30 26 27 25 24 ...
    20 21 23 22 18 19 17 16 ...
    52 53 55 54 50 51 49 48 ...
    60 61 63 62 58 59 57 56 ...
    44 45 47 46 42 43 41 40 ...
    36 37 39 38 34 35 33 32]);
wifi_params.modulation(6).hDemod = comm.RectangularQAMDemodulator(...
    'ModulationOrder',wifi_params.modulation(6).k,...
    'BitOutput',true,...
    'SymbolMapping','Custom',...
    'CustomSymbolMapping',...
    [4 5 7 6 2 3 1 0 ...
    12 13 15 14 10 11 9 8 ...
    28 29 31 30 26 27 25 24 ...
    20 21 23 22 18 19 17 16 ...
    52 53 55 54 50 51 49 48 ...
    60 61 63 62 58 59 57 56 ...
    44 45 47 46 42 43 41 40 ...
    36 37 39 38 34 35 33 32],...
    'DecisionMethod','Hard decision');
wifi_params.modulation(6).hDemod_LLR = comm.RectangularQAMDemodulator(...
    'ModulationOrder',wifi_params.modulation(6).k,...
    'BitOutput',true,...
    'SymbolMapping','Custom',...
    'CustomSymbolMapping',...
    [4 5 7 6 2 3 1 0 ...
    12 13 15 14 10 11 9 8 ...
    28 29 31 30 26 27 25 24 ...
    20 21 23 22 18 19 17 16 ...
    52 53 55 54 50 51 49 48 ...
    60 61 63 62 58 59 57 56 ...
    44 45 47 46 42 43 41 40 ...
    36 37 39 38 34 35 33 32],...
    'DecisionMethod','Log-likelihood ratio',...
    'VarianceSource','Property');
wifi_params.modulation(6).hDemod_LLR.Variance = 1;
wifi_params.modulation(6).hMod_factor = 1/sqrt(42);
wifi_params.modulation(6).hScalQuant = dsp.ScalarQuantizerEncoder('Partitioning','Unbounded');
wifi_params.modulation(6).bound_pts_wo_noiseVar = (-7:1:7)*wifi_params.modulation(6).hMod_factor;
% 256QAM -- for 802dot11ac and ax only -- not defined correctly yet
wifi_params.modulation(8).M = 8; %
wifi_params.modulation(8).k = 2.^wifi_params.modulation(8).M; % number of constellation points
wifi_params.modulation(8).hMod = comm.RectangularQAMModulator(...
    'ModulationOrder',wifi_params.modulation(8).k,...
    'BitInput',true);
%             'SymbolMapping','Custom',...
%             'CustomSymbolMapping',...
%             [4 5 7 6 2 3 1 0 ...
%             12 13 15 14 10 11 9 8 ...
%             28 29 31 30 26 27 25 24 ...
%             20 21 23 22 18 19 17 16 ...
%             52 53 55 54 50 51 49 48 ...
%             60 61 63 62 58 59 57 56 ...
%             44 45 47 46 42 43 41 40 ...
%             36 37 39 38 34 35 33 32]);
wifi_params.modulation(8).hDemod = comm.RectangularQAMDemodulator(...
    'ModulationOrder',wifi_params.modulation(8).k,...
    'BitOutput',true,...
    'DecisionMethod','Hard decision');
wifi_params.modulation(8).hDemod_LLR = comm.RectangularQAMDemodulator(...
    'ModulationOrder',wifi_params.modulation(8).k,...
    'BitOutput',true,...
    'DecisionMethod','Log-likelihood ratio',...
    'VarianceSource','Property');
wifi_params.modulation(8).hDemod_LLR.Variance = 1;
%             'SymbolMapping','Custom',...
%             'CustomSymbolMapping',...
%             [4 5 7 6 2 3 1 0 ...
%             12 13 15 14 10 11 9 8 ...
%             28 29 31 30 26 27 25 24 ...
%             20 21 23 22 18 19 17 16 ...
%             52 53 55 54 50 51 49 48 ...
%             60 61 63 62 58 59 57 56 ...
%             44 45 47 46 42 43 41 40 ...
%             36 37 39 38 34 35 33 32],...
wifi_params.modulation(8).hMod_factor = 1/sqrt(170);
wifi_params.modulation(8).hScalQuant = dsp.ScalarQuantizerEncoder('Partitioning','Unbounded');
wifi_params.modulation(8).bound_pts_wo_noiseVar = (-15:1:15)*wifi_params.modulation(8).hMod_factor;
% 1024QAM -- for 802dot11ax only -- not defined correctly yet
wifi_params.modulation(10).M = 10; %
wifi_params.modulation(10).k = 2.^wifi_params.modulation(10).M; % number of constellation points
wifi_params.modulation(10).hMod = comm.RectangularQAMModulator(...
    'ModulationOrder',wifi_params.modulation(10).k,...
    'BitInput',true);
%             'SymbolMapping','Custom',...
%             'CustomSymbolMapping',...
%             [4 5 7 6 2 3 1 0 ...
%             12 13 15 14 10 11 9 8 ...
%             28 29 31 30 26 27 25 24 ...
%             20 21 23 22 18 19 17 16 ...
%             52 53 55 54 50 51 49 48 ...
%             60 61 63 62 58 59 57 56 ...
%             44 45 47 46 42 43 41 40 ...
%             36 37 39 38 34 35 33 32]);
wifi_params.modulation(10).hDemod = comm.RectangularQAMDemodulator(...
    'ModulationOrder',wifi_params.modulation(10).k,...
    'BitOutput',true,...
    'DecisionMethod','Hard decision');
wifi_params.modulation(10).hDemod_LLR = comm.RectangularQAMDemodulator(...
    'ModulationOrder',wifi_params.modulation(10).k,...
    'BitOutput',true,...
    'DecisionMethod','Log-likelihood ratio',...
    'VarianceSource','Property');
wifi_params.modulation(10).hDemod_LLR.Variance = 1;
%             'SymbolMapping','Custom',...
%             'CustomSymbolMapping',...
%             [4 5 7 6 2 3 1 0 ...
%             12 13 15 14 10 11 9 8 ...
%             28 29 31 30 26 27 25 24 ...
%             20 21 23 22 18 19 17 16 ...
%             52 53 55 54 50 51 49 48 ...
%             60 61 63 62 58 59 57 56 ...
%             44 45 47 46 42 43 41 40 ...
%             36 37 39 38 34 35 33 32],...
wifi_params.modulation(10).hMod_factor = 1/sqrt(682); % 1/sqrt(scf), where scf = 2/3*(M-1) for M-QAM modulations
wifi_params.modulation(10).hScalQuant = dsp.ScalarQuantizerEncoder('Partitioning','Unbounded');
wifi_params.modulation(10).bound_pts_wo_noiseVar = (-15:1:15)*wifi_params.modulation(10).hMod_factor;
%% Channel coding parameters
m_stbc = 1; % no STBC is used
wifi_params.coding = [];
switch coding_type
    case 'BCC'
        wifi_params.coding = BCC_params(wifi_params, m_stbc, i_mcs);
    case 'LDPC'
        wifi_params.coding = LDPC_params(wifi_params, m_stbc, i_mcs);
end

if ~strcmp(wifi_params.general.standard,'802dot11ad')
    wifi_params.mapping.n_data_symbols_per_frame = wifi_params.coding.N_sym; % N_SYM
else
    disp('TBD: at load_wifi_params.m, line 442');
end
wifi_params.coding.decision_type = decision_type;

%% Scrambling parameters
wifi_params.scrambling.scr_seed = randi([0 1],1,7); % 7-bit of length, seed selected in a pseudorandom fashion
% AD: see std. IEEE 802.11-2016, ch. 20.3.9, page 2451

%% Interleaving parameters
wifi_params.interleaving = Interleaving_params(coding_type,wifi_params,i_mcs);

%% Spreading (IEEE 802.11ad)
wifi_params.spreading.Golay_Seq = Spreading_params;

%% Mapping
switch wifi_params.general.PHYlayer
    case 'OFDM'
        % it will be necessary in case of change pilot subcarriers position
        % logical map of data
        wifi_params.mapping.map_data = false(wifi_params.mapping.n_tot+numel(wifi_params.mapping.i_DC),1);
        wifi_params.mapping.map_data(wifi_params.mapping.i_data) = true;
        wifi_params.mapping.map_data = repmat(wifi_params.mapping.map_data,1,wifi_params.mapping.n_data_symbols_per_frame);
        % logical map of pilots
        wifi_params.mapping.map_pilots = false(wifi_params.mapping.n_tot+numel(wifi_params.mapping.i_DC),1);
        wifi_params.mapping.map_pilots(wifi_params.mapping.i_pilots) = true;
        wifi_params.mapping.map_pilots = repmat(wifi_params.mapping.map_pilots,1,wifi_params.mapping.n_data_symbols_per_frame);
        % logical map of DC
        wifi_params.mapping.map_DC = false(wifi_params.mapping.n_tot+numel(wifi_params.mapping.i_DC),1);
        wifi_params.mapping.map_DC(wifi_params.mapping.i_DC) = true;
        wifi_params.mapping.map_DC = repmat(wifi_params.mapping.map_DC,1,wifi_params.mapping.n_data_symbols_per_frame);
        
        % logical phase shift mapping
        wifi_params.mapping.map_phase_rotation = false(size(wifi_params.mapping.map_data));
        wifi_params.mapping.map_phase_rotation(wifi_params.mapping.ir_phase_rotated_subc+wifi_params.mapping.ir_highest_subc+1,:) = true;
    case 'SC'
        
    case 'LPSC'
        
    otherwise
        error('Wrong physical layer type (unsupported by the simulator)');
end

if strcmp(wifi_params.general.standard,'802dot11ad')
    wifi_params.Fs = 2640e6;
else
    wifi_params.Fs = wifi_params.mapping.n_fft*wifi_params.mapping.df;
end

%% GUARD INTERVAL
switch wifi_standard %=====================================================
    case '802dot11g' %-----------------------------------------------------
        switch GuardInterval
            case 'normal'
                wifi_params.cprefix.t_cp = 800e-9;
            otherwise
                error('In IEEE 802.11g ''normal'' cyclic prefix length (800 ns) is valid only');
        end
    case {'802dot11n', '802dot11ac'} %-------------------------------------
        switch GuardInterval
            case 'short'
                wifi_params.cprefix.t_cp = 400e-9;
            case 'normal'
                wifi_params.cprefix.t_cp = 800e-9;
            otherwise
                error('In IEEE 802.11n/ac ''normal'' or ''short'' cyclic prefix length (800 ns or 400 ns) are valid only');
        end
    case '802dot11ax'%-----------------------------------------------------
        switch GuardInterval
            case 'normal'
                wifi_params.cprefix.t_cp = 800e-9;
            case 'doubled'
                wifi_params.cprefix.t_cp = 1600e-9;
            case 'enhanced'
                wifi_params.cprefix.t_cp = 3200e-9;
            otherwise
                error('In IEEE 802.11ax ''normal'', ''doubled'' or ''enhanced'' cyclic prefix length (800 ns, 1600 ns or 3200 ns) are valid only');
        end
    case '802dot11ah' %----------------------------------------------------
        switch GuardInterval
            case 'normal'
                wifi_params.cprefix.t_cp = 8e-6;
            case 'short'
                wifi_params.cprefix.t_cp = 4e-6;
            otherwise
                error('In IEEE 802.11ah ''normal'' or ''short'' cyclic prefix length (8 us or 4 us) are valid only');
        end
    case '802dot11ad'
        %         warning('AD: guard interval: TBD (see load_wifi_params.m, line 542)');
    otherwise
        error('Wrong or undefined standard');
end

if strcmp(wifi_params.general.PHYlayer,'OFDM')
    wifi_params.cprefix.n_cp = (wifi_params.cprefix.t_cp*wifi_params.Fs);
    wifi_params.cprefix.indices = wifi_params.mapping.n_fft-wifi_params.cprefix.n_cp+1:wifi_params.mapping.n_fft;
end
%% Framing

% disp(mat2str(wifi_params.cprefix.indices))
% disp('TBD: only for AD, see line: 597')
switch wifi_params.general.PHYlayer
    case 'SC'
        wifi_params.framing.Names = {...
            'STF';...
            'CEF';...
            'Header*';...
            'Data*';...
            'Beamforming Training'};
        wifi_params.framing.ChipLengths = [2176; 1152; (2*wifi_params.mapping.n_tot)+(2*wifi_params.mapping.N_GI); ((wifi_params.coding.N_blks*448)+((wifi_params.coding.N_blks+1)*wifi_params.mapping.N_GI)); 0]; % in case of Header, see 20.6.3.1.4 Header encoding and modulation
        ChipMapTmp = false(1, 2176+1152+((2*wifi_params.mapping.n_tot)+(2*wifi_params.mapping.N_GI))+((wifi_params.coding.N_blks*448)+((wifi_params.coding.N_blks+1)*wifi_params.mapping.N_GI)));
        % STF
        wifi_params.framing.ChipMap{1} = ChipMapTmp;
        wifi_params.framing.ChipMap{1}(1:2176) = true;
        % CEF
        wifi_params.framing.ChipMap{2} = ChipMapTmp;
        wifi_params.framing.ChipMap{2}(2176+1:2176+1152) = true;
        % Header
        wifi_params.framing.ChipMap{3} = ChipMapTmp;
        wifi_params.framing.ChipMap{3}(2176+1152+1:2176+1152+(2*wifi_params.mapping.n_tot)+(2*wifi_params.mapping.N_GI)) = true;
        % Data
        wifi_params.framing.ChipMap{4} = ChipMapTmp;
        wifi_params.framing.ChipMap{4}(2176+1152+(2*wifi_params.mapping.n_tot)+(2*wifi_params.mapping.N_GI)+1:2176+1152+(2*wifi_params.mapping.n_tot)+(2*wifi_params.mapping.N_GI)+((wifi_params.coding.N_blks*448)+((wifi_params.coding.N_blks+1)*wifi_params.mapping.N_GI))) = true;
        % Beamforming training
        wifi_params.framing.ChipMap{5} = ChipMapTmp;
        
        wifi_params.framing.Header.Items = {...
            'Scrambler Initialization';...
            'MCS';...
            'LENGTH';...
            'Additional PPDU';...
            'Packet Type';...
            'Training Length';...
            'Aggregation';...
            'Beam Tracking Request';...
            'Last RSSI';...
            'SIFS Response';...
            'Reserved';...
            'HCS'};
        wifi_params.framing.Header.ItemsBitLengths = [7, 5, 18, 1, 1, 5, 1, 1, 4, 1, 4, 16];
        wifi_params.framing.Header.ItemsBitLengthsAll = sum(wifi_params.framing.Header.ItemsBitLengths);
        wifi_params.framing.Header.ItemsOrder = 'LSB-first';
        wifi_params.framing.Header.coding = LDPC_params(wifi_params, 1, 5);
        wifi_params.framing.Header.hCRCgen = comm.CRCGenerator('Polynomial',[16 12 5 0]); %'InitialConditions',ones(1,16)); % not the same as in 15.3.3.7, page 2230
    case 'LPSC'
        
    case 'OFDM'
        
    otherwise
        error('Wrong type of physical layer')
end

%% Show data rates according to selected MCS
if strcmp(wifi_params.general.standard,'802dot11ad')
    user_data_rate_str = sprintf(' >>> User data rate: %2.2f Mbps ', ad_MCS_data_rates_vec(i_mcs-1)/1e6);
    wifi_params.data_rate = ad_MCS_data_rates_vec(i_mcs-1);
else
    wifi_params.data_rate = (wifi_params.MCS(i_mcs).N_ss*wifi_params.MCS(i_mcs).CR*wifi_params.mapping.n_data*log2(wifi_params.MCS(i_mcs).M))/((wifi_params.mapping.n_fft/wifi_params.Fs)+(wifi_params.cprefix.t_cp));
    wifi_params.data_rate_PSDU = ((LENGTH*8))/(wifi_params.coding.N_sym*((wifi_params.mapping.n_fft/wifi_params.Fs)+(wifi_params.cprefix.t_cp)));
    
    user_data_rate_str = sprintf(' >>> User data rate: %2.2f Mbps ', wifi_params.data_rate/1e6);
    PSDU_data_rate_str = sprintf(' >>> PSDU data rate: %2.2f Mbps ', wifi_params.data_rate_PSDU/1e6);
end
%% Create TX and RX object
txObj = transmitter(1,1,2412,wifi_params.MCS); % create transmitter object
rxObj = receiver(1,1,2412,wifi_params.MCS); % create receiver object

clear decType

%% channel definition
wifi_params.channel.type = channelType;
fadingType = 'block';
wifi_params.channel.fading = fadingType;
wifi_params.channel.powerdB = [0 -9.7]; % channel path relative power
wifi_params.channel.delayTime = [0 110]*10^(-9); % channel path delays

% clear channelType fadingType

%% other useful definitions
error_val = zeros(N_frames,length(SNR),length(MCSvec)); % initialize error values (rewrite in future)