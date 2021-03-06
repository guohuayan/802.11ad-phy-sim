function filename = load_filename(SNR, N, i_mcs, wifi_params, wifi_standard, ChannelBandwidth, coding_type, LENGTH, GuardInterval, decision_type)
% Code to generate the output filename
%
% Author:	Jiri Milos, DREL FEEC BUT, 2018--2019
%
the_date = clock;

SNRmin = SNR(1);
SNRmax = SNR(end);

if ~strcmp(wifi_standard, '802dot11ad')
    filename = sprintf('wifi_%s_BW%s_MHz_from%dto%d_dB_%s_%s_MCS%s_LENGTH%05d_%sCP_%d_repeat_%04d-%02d-%02d_%02d%02d%02d',...
        wifi_standard,...
        num2str(ChannelBandwidth),...
        SNRmin,...
        SNRmax,...
        coding_type,...
        decision_type,...
        num2str(i_mcs-1),...
        LENGTH,...
        GuardInterval,...
        N,...
        the_date(1),...      % Date: year
        the_date(2),...      % Date: month
        the_date(3),...      % Date: day
        the_date(4),...      % Date: hour
        the_date(5),...      % Date: minutes
        floor(the_date(6))); % Date: seconds)
else
    ad_MCS_vec = [1:9, 9.1, 10:12, 12.1:0.1:12.6].'; % for SC
    filename = sprintf('wifi_%s_BW%s_MHz_from%dto%d_dB_%s_%s_MCS%s_LENGTH%05d_%d_repeat_%04d-%02d-%02d_%02d%02d%02d',...
        wifi_standard,...
        num2str(ChannelBandwidth),...
        SNRmin,...
        SNRmax,...
        coding_type,...
        decision_type,...
        num2str(ad_MCS_vec(i_mcs-1)),...
        LENGTH,...
        N,...
        the_date(1),...      % Date: year
        the_date(2),...      % Date: month
        the_date(3),...      % Date: day
        the_date(4),...      % Date: hour
        the_date(5),...      % Date: minutes
        floor(the_date(6))); % Date: seconds)    
end

end