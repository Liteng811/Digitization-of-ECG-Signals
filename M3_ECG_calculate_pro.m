function [ECG,ECGori,ECG_head,ECG_data,ECG_strcell]=M3_ECG_calculate_pro(ECG_head,ECG_strcell,ECG1L,fs_ECGaft,PI,testmode_word)
ECG=struct;
ECGori=struct;
ECG_data=struct;
%ECG_head=struct;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%前言：确定模式，设定参数初始值%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%前置参数%%%%%%%%%%%
    i_want_check_ECG_pos_con=1;%1.检查；2.不检查是否有操作电极颠倒。
    there_are_pulse_pullution=1;%1.检查；2.不检查是否有脉冲污染
%%%%%%%%%前置参数%%%%%%%%%%%
%%%%算法测试模式testmode=1。
simplechoice_in_QrS_1_way=1;
testmode_word;
if ~exist('testmode_word','var')
    testmode=1;
elseif strcmp(testmode_word,'外部数据加载')
    testmode=0;
elseif strcmp(testmode_word,'独立运行调试')
    testmode=1;
end
if testmode==1       
    fs_ECGaft=250;
    [FileName,PathName,FilterIndex]=uigetfile({'*.*';'*.csv';'*.txt';'*.xlsx';'*.xls';'*.slx';'*.mat'},'File Selector');
    addpath(PathName);
    if FilterIndex==1
    end               
    loc=strfind(FileName,'.');
    loc=loc(end);
    [~,~,vtable]=find(strcmp(FileName(loc:end),{'.xlsx','.xls','.csv'}));
    [~,~,vtxt]=find(strcmp(FileName(loc:end),{'.txt','.dat'}));
    if ~isempty(vtable)
        ifopen=2;%xlsx格式的文件
        [num,~,~]=xlsread(FileName);
        ECG1L=reshape(num(:,2),1,[]);%ECG1L=num(:,2);        
    elseif ~isempty(vtxt)
        ifopen=3;%txt格式的文件
        pulsewave3 = importdata(FileName);
        size(pulsewave3);  
        ECG1L=reshape(pulsewave3(1,:),1,[]);                        
    end
    PI{1}=FileName(1:loc-1);%cell模式
    PI{2}='199912222125';    PI{3}='男';    PI{4}='170';    PI{5}='60';
    PI{6}='平原省炎黄市进阶区';PI{7}='410602198602120017';   PI{8}='13581671310';
    PI{9}='医学研究';    PI{10}='汉族';     PI{11}='1';
else
    FileName=PI{1};
end
%TIME_line=linspace(0,length(ECG1L)/fs_ECGaft,length(ECG1L));%时间序列
%%%%%%%%%%%%%%%%%%%%%ECG节律转音乐的原始参数设计%%%%%%%%%%%%%%%%
    basic_sound_fs=261.625*2;   %基础声音转换的频率设定523.25        
    sound_sample_fs=4000;%44100;录制声音的采样频率
    HRVmultime=2000; %HRV倍数扩展
    fftstartnum=15; %fft显示起点，大于1表示去掉低频分量
    startnum=15;    %起始位置
    musictype=3;    %1.7音，2.12音;3.5音
    tunestepmethod=2;  %声调 1-2,数据长一定选2
    soundmethod=4;  %发音方式1-4.
    Iwanthearit=0; %想听一下
    Basicfreqparameters=10;%考虑到心率本身对音调的影响。
    %%%%%%%%%%%%ECG节律转音乐的原始参数设计完成%%%%%%%%%%%%%%%%
    %%%%%%%%%ECG设计参数设置%%%%%%%%%%  
    head3length=100; 
    %fs_ECGaft=250;  %ECG 采样率
    selected_signal_row_num=1; %选择要分析的信号段数
    i2first=1;
    i3first=1;   %分段第几段1    
    figureshow=1;%寻找作图的位置，并管理是否显示figure。1为显示，其他不显示。
    removepulseway=1;%选择信号的滤波方案，关系到后面的分析与筛选方案
    filtermethod=0;
    HzinterECG_fft=0.45;  %设定ECGfft波的平滑曲线间隔参数0.45。
    fft_formant_distance=0.02; %求解共振峰所设定的频率间隔0.02。
    fft_formant_distance1=0.2; %0.2排除距离过近的两个共振峰,该值定为最小间隔数，小于此间隔的都算是一个共振峰之内。
    minimumRRnum=19;%一次样本最小的周期数19
    maxloopsec=50; %每次样本最大分割段数50
    %%%%%%%%%ECG设计参数设置完成%%%%%%%%%%  
    Q_S_overnum=round(fs_ECGaft/12.5);
    marklength=fs_ECGaft/4;%   预设计两两过近点的阈值   %后面用(mean(diffQrs)-std(diffQrs))/1.5代替;
    sect_deletable=1;%可以删除的片段
    strictrules=0;%更严格的筛选风格
    kmeans_secnum=3;
    Q_Rmindistance=8;%知道Q求R时，设定Q与R之间的最小距离。
    qrS_dis_recnum=ceil(fs_ECGaft/15);%附近低值的查找范围,基于采样率相对性计算
    signaltypesstr{selected_signal_row_num}='ECG';
    i2=1;
    DATAFILEmat{i2}=PI{1};
    
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%ECG设计参数设置完成%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%ECG基础分析-第一步：1.去掉空值，确定长度，匹配时间轴%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    ECG1L(isnan(ECG1L)) = [];%去掉空值
    ECG1L=reshape(ECG1L,1,[]);
    SAMPLES2READ=length(ECG1L);
    ECG.length=length(ECG1L);%1
    TIME_line=linspace(0,length(ECG1L)/fs_ECGaft,length(ECG1L));%时间序列
    ECG.name=PI{1};%DATAFILEmat{i2};
        ECG.PI_11=PI;
        ECG.TIME=length(ECG1L)/fs_ECGaft;  %ECG总样本持续时长        
        ECG.sample_sec_time=SAMPLES2READ/fs_ECGaft;%ECG分样本时长
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%ECG基础分析-第一步：2.判断导练是否正确，不对的要反转%%%%%%%%%%
    %%%%为了确认这一点，需要首先做一次QRS特征识别，然后分别观察其与均值之间的关系判断
    %%%%%然后对下方点高于上方点的样本进行翻转，保证二导联翻正，即最尖端在最高点处。%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%2.1寻找点位的纵坐标
    thres=0.3;
    rp=0.250;
    ws=round(0.5*SAMPLES2READ/fs_ECGaft);
    E_qRs_3_lists = wjqrs(ECG1L, fs_ECGaft, thres, rp, ws); %横排，要变纵列
    E_qrS_4_lists = qrs_adjust(ECG1L,E_qRs_3_lists,fs_ECGaft,-1,0.050,0);%横排
    %波形的正负极调整与归一化
    E_qRs_3_lists=reshape(E_qRs_3_lists,[],1);
    E_qrS_4_lists=reshape(E_qrS_4_lists,[],1);
    
    %%%%%%%%%%%已知R点最高，要判断另外一个点是前方更小的Q，还是后方更大的S%%%%%%%
    %%%3.1首先双列首发点位置对齐，qrS在后，y值低，位数大，qRs在前，y值高，位数小%%%%
    [E_qRs_3_lists,E_qrS_4_lists]=M3_ECG_c_subfunc_0(ECG1L,E_qRs_3_lists,E_qrS_4_lists);
    %%%%%%%%%%%进入附属1方程，目标，计算S-T阶段的校正后的特征并记录%%%%%%%
    %%%%%%%%%%%进入附属1方程，目标，计算S-T阶段的特征并为判断是否翻转提供依据%%%%%%%    
    t=1;    
    [ECG_data,ECG_head,ECG,E_qRs_3_lists,E_qrS_4_lists]=M3_ECG_c_subfunc_1(ECG_data,ECG_head,ECG,ECG1L,E_qRs_3_lists,E_qrS_4_lists,fs_ECGaft,t);
    
    %%%%%%%%%%%进入附属1方程，目标，计算S-T阶段的特征并判断是否翻转完成%%%%%%%
    %%%%%%%%%判断发生反转的条件，1.位于均值下方的极值点S绝对值乘2高于上方R点。%%%%%%%%
    %%%%%%%%%判断发生反转的条件，2.极值点S后应存在持续升高的T波，如果持续减低，则判定为应当翻转。%%
    if i_want_check_ECG_pos_con==1
        if ECG.qRs_mean_dis_1_ori<abs(ECG.qrS_mean_dis_1_ori)*2 && ECG.S_T_trend_1_mean<0
            ECG1L=-ECG1L+2*mean(ECG1L);
            ECG.oppositeflip=1; %2.1标记是否发生过翻转。1表示已经完成翻转，高点峰度最大。更像二导联，或者二导联校正
            E_qRs_3_lists = wjqrs(ECG1L, fs_ECGaft, thres, rp, ws); %横排，要变纵列
            E_qrS_4_lists = qrs_adjust(ECG1L,E_qRs_3_lists,fs_ECGaft,-1,0.050,0);%横排
            E_qRs_3_lists=reshape(E_qRs_3_lists,[],1);
            E_qrS_4_lists=reshape(E_qrS_4_lists,[],1);
            %%%%因为重新生成，所以需要重做一遍%%%%
            %%%3.1首先双列首发点位置对齐，qrS在后，数大，qRs在前，数小%%%%
            [E_qRs_3_lists,E_qrS_4_lists]=M3_ECG_c_subfunc_0(ECG1L,E_qRs_3_lists,E_qrS_4_lists);
            %%%%%%%%%%%进入附属1方程，目标，计算S-T阶段的校正后的特征并记录%%%%%%%
            t=2;
            [ECG_data,ECG_head,ECG,E_qRs_3_lists,E_qrS_4_lists]=M3_ECG_c_subfunc_1(ECG_data,ECG_head,ECG,ECG1L,E_qRs_3_lists,E_qrS_4_lists,fs_ECGaft,t);
            %%%%%%%%%%%进入附属1方程，目标，计算S-T阶段的校正后的特征并记录完成%%%%%%%
            if figureshow==1
                figure(10)
                %subplot(1,1,1)
                h_dot_ECG = plot(TIME_line,ECG1L,'k-');
                xlabel('Time / s'); ylabel('Voltage / mV');        
                title(strcat('2.Plotted QRS in fliped ECG--',signaltypesstr{selected_signal_row_num},FileName));  
                hold on
                h_dot_qRs_3 = plot(TIME_line(E_qRs_3_lists),ECG1L(E_qRs_3_lists),'m^');
                h_dot_qrS_4 = plot(TIME_line(E_qrS_4_lists),ECG1L(E_qrS_4_lists),'cx');
                hold off 
                legend([h_dot_ECG,h_dot_qRs_3,h_dot_qrS_4],'ECG line','ECG-qRs-3-lists','ECG-qrS-4-lists')
            end
        else
            ECG.oppositeflip=0;%2,如果是0，则表示信号表征未翻转
        end            
    else
        ECG.oppositeflip=-1;
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%ECG基础分析-第一步：3.要将定点设定为R点，S点统一放置于其后的第一个波谷中%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    %%%%初始点位对应关系确定计算前验证部分结束,建立了1.波形正常2.无异常翻转；3.标记点完全对应的标记原始ECG信号%%%%%%
    %%%%%%%%%ECG基础分析-第一步，到此完成,对原始波图的变化主要在与上下翻转的确认%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
   
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%ECG基础分析-第二步：1.由于自己采样的时候，图像中发现可能会有脉冲波干扰，
    %%%%因此对波图进行第二次优化，就是如果发现异常脉冲波，则对脉冲波进行过滤%%%%%%%%%%
    %%%%%%%基于20231130已考虑新加ECG实现质量评价与优化，我们发现该方法依然不完善，%%%%%%%%%%
    %%%为了确认是否存在脉冲，需要先对数据进行判断%%%%%
    %%%%%%%只有判断清楚脉冲波的存在，才能完成脉冲点的识别与清除。%%%%%%
    %%%%%%%于是20240707开始，进一步探讨如何自动识别并清除。%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%脉冲波过滤开始%%%%%%%%%%%%
    if there_are_pulse_pullution==1
        [ECG,ECGori,ECG_data,ECG_head,ECG1Ldone]=M3_ECG_c_subfilter_2(ECG,ECGori,ECG_data,ECG_head,ECG1L,E_qRs_3_lists,E_qrS_4_lists);
        %%%%%%%再走一遍关键点识别%%%%%%%%     
        thres=0.3;
        rp=0.250;
        ws=round(0.5*SAMPLES2READ/fs_ECGaft);
        E_qRs_3_lists = wjqrs(ECG1Ldone, fs_ECGaft, thres, rp, ws); %纵列
        E_qrS_4_lists = qrs_adjust(ECG1Ldone,E_qRs_3_lists,fs_ECGaft,-1,0.050,0);%横排
        %%%%对平滑过后的ECG1Lsecsmooth再次对齐%%%%
        [E_qRs_3_lists,E_qrS_4_lists]=M3_ECG_c_subfunc_0(ECG1Ldone,E_qRs_3_lists,E_qrS_4_lists);
        %%%%对平滑过后的ECG1Lsecsmooth再次对齐完成%%%%              
        %%%%%%%%%第三次开展纠错调试%%%%%%%%%
        t=2;
        [ECG_data,ECG_head,ECG,E_qRs_3_lists,E_qrS_4_lists]=M3_ECG_c_subfunc_1(ECG_data,ECG_head,ECG,ECG1Ldone,E_qRs_3_lists,E_qrS_4_lists,fs_ECGaft,t);
        %%%%%%%%%第三次开展纠错调试，完成后数据返回覆盖%%%%%%%%%
        if figureshow==1
         figure(11)
            cla; 
            plot(TIME_line,ECG1L,'k-');
            title(strcat('3.Pulse mark and remove in ECG--',signaltypesstr{selected_signal_row_num},FileName));
            hold on             
            distance_line=(ECG.qRs_mean_dis_2_ori-ECG.qrS_mean_dis_2_ori);
            plot(TIME_line,ECG1Ldone+distance_line*1.5,'c-');
            plot(TIME_line(ECGori.the_pulse_n_loc),ECG1Ldone(ECGori.the_pulse_n_loc),'k*');
            plot(TIME_line(ECGori.the_pulse_p_loc),ECG1Ldone(ECGori.the_pulse_p_loc),'c^');
            hold off
        end 
    else
        ECG1Ldone=ECG1L;
        ECGori.the_pulse_p_loc=1;
        ECGori.the_pulse_n_loc=1;
        ECG.pulse_pulluted_p=0;
        ECG.pulse_pulluted_n=0;
        ECG_data.c_subfilter_2=[ECG.pulse_pulluted_p,ECG.pulse_pulluted_n];
        ECG_head.c_subfilter_2={'正向干扰脉冲数','负向干扰脉冲数'};
    end
        %%%%%%%%%脉冲波过滤完成%%%%%%%%%%%%
        %%%%%%%%%%
        t=2;
        [ECG_data,ECG_head,ECG,E_qRs_3_lists,E_qrS_4_lists]=M3_ECG_c_subfunc_1(ECG_data,ECG_head,ECG,ECG1L,E_qRs_3_lists,E_qrS_4_lists,fs_ECGaft,t);
         %%%%%%%%%极端情况下，直接数据返回%%%%%%%%%
        if numel(E_qRs_3_lists)<=1 ||numel(E_qrS_4_lists)<=1 
            return
        elseif numel(E_qRs_3_lists)<(SAMPLES2READ/fs_ECGaft)*0.2 || numel(E_qRs_3_lists)>(SAMPLES2READ/fs_ECGaft)*5
            return       
        end        
        %%%%%%%%%极端情况下，直接数据返回%%%%%%%%%
        %%%%%%%%%diff_ECG波形的最大拐点求解完成%%%
        %%%%%%%%%%%%完成对ECG的质量评价%%%%%%%%%%
        [ECG,ECG_data,ECG_head]=M3_ECG_c_s_quality_3(ECG,ECG_data,ECG_head,ECG1Ldone,E_qRs_3_lists,E_qrS_4_lists);
        %%%%%%%%%%%%完成对ECG的质量评价%%%%%%%%%%                    
        %%%%%%%%滤波开始%%%%%%%%%
        w1_level=5;
        [ECG1Ldone_filted]=filter_ways(filtermethod,ECG1Ldone,fs_ECGaft,w1_level);
        %%%%%%%滤波完成%%%%%%%%%%          
        qRs_ori_num=numel(E_qRs_3_lists);
        qrS_ori_num=numel(E_qrS_4_lists);
        ECG.qRs_ori_num=qRs_ori_num;%16 原始qRs点数量
        ECG.qrS_ori_num=qrS_ori_num;%17 原始qrS点数量
        %}
        %%%%初始规范化描点数位部分结束（在ECG1Lsecsmooth重复了一遍）%%%%%%        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%ECG基础分析-第二步：1去除脉冲波干扰，滤波后完成对波形的定型。%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if figureshow==1
        figure(12)
        subplot(2,1,1)
        h_dot_ECG=plot(TIME_line,ECG1Ldone_filted,'k-');
        xlabel('Time / s'); ylabel('Voltage / mV');        
        title(strcat('4.Plotted R-S in final ECG--',signaltypesstr{selected_signal_row_num},FileName));  
        hold on
        h_dot_qRs_3=plot(TIME_line(E_qRs_3_lists),ECG1Ldone_filted(E_qRs_3_lists),'m^');
        h_dot_qrS_4=plot(TIME_line(E_qrS_4_lists),ECG1Ldone_filted(E_qrS_4_lists),'cx');
        hold off
        legend([h_dot_ECG,h_dot_qRs_3,h_dot_qrS_4],'ECG line','ECG-qRs-3-lists','ECG-qrS-4-lists');
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%ECG基础分析-第四步：PQRST五大关键点定位。%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    theway=1;
    find(isnan(ECG1Ldone_filted));
if theway==1
    ori_sig_struct.ECG1Ldone_filted=ECG1Ldone_filted;
    ori_sig_struct.E_qRs_3_lists=E_qRs_3_lists;
    ori_sig_struct.E_Qrs_2_lists=E_qrS_4_lists;
    mainparameters.line_choose=0;
    sig_m_path=pwd;
    ECG_4_ECG_mcode_folder=strcat(sig_m_path,'\M3_ECG_matcode');
    mainparameters.sig_m_path='';
mainparameters.ECG_4_ECG_mcode_folder=ECG_4_ECG_mcode_folder;
mainparameters.ECG_4_file_name='样本1';
mainparameters.sec_show=1;
mainparameters.figureshow=0;
mainparameters.BPR_3_fs_aft=250;%统一分析后的频率
mainparameters.line_choose=0;%选中哪一条滤波线进行后续的分析；
    [data_struct,data_t_struct,Signal_d,app]=M3_ECG_c_4_points_cal(ori_sig_struct,mainparameters);
ECG_data.c_PQRST_4=data_struct.c_PQRST_4;
ECG_head.c_PQRST_4=data_t_struct.c_PQRST_4;
E_Pqrs_1_lists=Signal_d.Pqrst_T_point_act;
E_Qrs_2_lists=Signal_d.pQrst_T_point_act;
E_qRs_3_lists=Signal_d.pqRst_T_point_act;
E_qrS_4_lists=Signal_d.pqrSt_T_point_act;
E_qrsT_5_lists=Signal_d.pqrsT_T_point_act;
ECGori.E_Pqrs_1_lists=E_Pqrs_1_lists;%1
        ECGori.E_Qrs_2_lists=E_Qrs_2_lists;%2
        ECGori.E_qRs_3_lists=E_qRs_3_lists;%3
        ECGori.E_qrS_4_lists=E_qrS_4_lists;%4
        ECGori.E_qrsT_5_lists=E_qrsT_5_lists;%5
        ECGori.qualitymark_lists=zeros(size(E_qrsT_5_lists));%qualitymark_lists;%6
        ECGori.P_loc_after_lines=Signal_d.pQrst_T_point_act;%2
        ECGori.P_loc_before_lines=Signal_d.v_Pqrst_T_point_act;%3
        ECGori.T_loc_before_lines=Signal_d.pqrSt_T_point_act;%4
        ECGori.T_loc_after_lines=Signal_d.pqrsT_T_point_act+floor(Signal_d.tool_pqrsT_pQrst_space./(Signal_d.tool_pqrsT_pQrst_valleynum+1));%5
end
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%ECG基础分析-第四步：PQRST五大关键点定位完成。%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    %%%%%原始计算序列特征加载完成，注意无法对齐，需要独立设计存储空间ECGori%%%%%
        if figureshow==0
            figure(13)
            cla
            h_dot_ECG=plot(TIME_line(1:length(ECG1Ldone_filted)),ECG1Ldone_filted,'k-');
            hold on
            E_Pqrs_1_lists;
            h_dot_Pqrs_1=plot(TIME_line(E_Pqrs_1_lists),ECG1Ldone_filted(E_Pqrs_1_lists),'ro');
            h_dot_Qrs_2=plot(TIME_line(E_Qrs_2_lists),ECG1Ldone_filted(E_Qrs_2_lists),'bv');
            h_dot_qRs_3=plot(TIME_line(E_qRs_3_lists),ECG1Ldone_filted(E_qRs_3_lists),'m^');
            h_dot_qrS_4=plot(TIME_line(E_qrS_4_lists),ECG1Ldone_filted(E_qrS_4_lists),'bx');%3.
            h_dot_qrsT_5=plot(TIME_line(E_qrsT_5_lists),ECG1Ldone_filted(E_qrsT_5_lists),'bp');
            hold off                                
            xlabel('Time / s'); ylabel('Voltage / mV');        
            title(deblank(strcat('PQRST rectified--',signaltypesstr{selected_signal_row_num},FileName)));  
            legend([h_dot_ECG,h_dot_Pqrs_1,h_dot_Qrs_2,h_dot_qRs_3,h_dot_qrS_4,h_dot_qrsT_5],...
                'ECG line','ECG-Pqrs-1-lists','ECG-Qrs-2-lists','ECG-qRs-3-lists','ECG-qrS-4-lists','ECG-qrsT-5-lists');
            
        end
    %距离法求解最优点，即选临1还是选隔2       
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%ECG基础分析-第五步：关系分析开始。%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

     [ECG,ECGori,ECG_data,ECG_head]...
    =M3_ECG_c_5(ECG,ECGori,ECG_data,ECG_head,ECG1Ldone_filted,E_Pqrs_1_lists,E_Qrs_2_lists,E_qRs_3_lists,E_qrS_4_lists,E_qrsT_5_lists,fs_ECGaft,Q_S_overnum);

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%ECG基础分析-第四步：关系分析完成。%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%ECG基础分析-第六步：呼吸特征edr分析开始。%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
    [ECG,ECGori,ECG_data,ECG_head]...
    =M3_ECG_c_breath_6(ECG,ECGori,ECG_data,ECG_head,ECG1Ldone_filted,E_qRs_3_lists,E_qrS_4_lists,fs_ECGaft,figureshow);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%ECG基础分析-第六步：呼吸特征edr分析完成。%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    TIME_line=linspace(0,length(ECG1Ldone_filted)/fs_ECGaft,length(ECG1Ldone_filted));%时间序列
        if figureshow==1
            figure(14)
            subplot(1,1,1)
            cla
            plot(ECGori.Timebreathline,ECGori.breathr);        
            hold on
            plot(TIME_line,ECG1Ldone_filted);
            hold off
        end
   
                       
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%ECG基础分析-第七步：多尺度熵计算开始%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
         
       [ECG,ECGori,ECG_data,ECG_head]...
    =M3_ECG_c_MSE_7(ECG,ECGori,ECG_data,ECG_head,ECG1Ldone_filted,fs_ECGaft,minimumRRnum,HRVmultime,E_qRs_3_lists);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%               
    %%%%%%%%%%%%%%%%%%%%ECG基础分析-第七步：多尺度熵计算完成%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %%%%%%%%%%%%%%%%%%%%梅尔mfcc多尺度熵计算开始%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   
  [ECG,ECGori,ECG_data,ECG_head]...
    =M3_ECG_c_mfcc_8(ECG,ECGori,ECG_data,ECG_head,ECG1Ldone_filted,fs_ECGaft,HzinterECG_fft,fft_formant_distance,fft_formant_distance1);
   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%梅尔mfcc多尺度熵计算完成%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
                
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%ECG基础分析-第九步：原始转乐开始%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        RRinterval=diff(TIME_line(E_qRs_3_lists)); %RR间期        
        RRinterval=reshape(RRinterval,1,[]);              
        HRVseries=-diff(RRinterval)*HRVmultime; %心率加快为正，心率减慢为负 10000
        HRmean=60/mean(RRinterval); 
        adjust_sound_fs=basic_sound_fs+(HRmean-70)*Basicfreqparameters;%心率的快慢决定基调音高
        ECG.basic_sound_fs=basic_sound_fs; %设定的HRV音频基调频率
        ECG.adjust_sound_fs=adjust_sound_fs;%考虑心率后的HRV音频基调频率
    [ECG,ECGori,ECG_data,ECG_head]...
    =M3_ECG_c_music_9(ECG,ECGori,ECG_data,ECG_head,ECG1Ldone_filted,E_qRs_3_lists,E_qrS_4_lists,TIME_line,HRVseries,RRinterval,musictype,adjust_sound_fs,tunestepmethod,sound_sample_fs,soundmethod,Iwanthearit);

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%ECG基础分析-第九步：ECG信号转写音乐开始完成%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%汇总数据%%%%%%%%%%%%%%      
        
end

function [E_qRs_3_lists,E_qrS_4_lists]=M3_ECG_c_subfunc_0(ECG1L,E_qRs_3_lists,E_qrS_4_lists)

        if (E_qRs_3_lists(1))<(E_qrS_4_lists(1))
            %P_qRs_2_list=P_qRs_2_list(1:length(P_Qrs_1_list));
        elseif (E_qRs_3_lists(1))>(E_qrS_4_lists(1))
            [val,maxloc_]=findpeaks(-ECG1L(1:E_qRs_3_lists(1)));
            %[~,maxloc_]=findpeaksreverse(val,maxloc_);
            if isempty(maxloc_)
                [~,E_qrS_4_lists_pre]=min(ECG1L(1:E_qRs_3_lists(1)));
            else
                E_qrS_4_lists_pre=maxloc_(end);
            end
            E_qrS_4_lists=cat(1,E_qrS_4_lists_pre,E_qrS_4_lists(1:end));
        end
        %%%3.2交替排列，不让其中出现异常穿插，然后unique去除重复点%%%%
        if numel(E_qRs_3_lists)~=numel(E_qrS_4_lists)
            for i=2:numel(E_qRs_3_lists)
                loc=find(E_qrS_4_lists>E_qRs_3_lists(i-1) & E_qrS_4_lists<E_qRs_3_lists(i));
                if numel(loc)>1
                    E_qrS_4_lists(loc(1:end-1))=[];
                end
            end            
        end
        E_qRs_3_lists=unique(E_qRs_3_lists); %再次独一化处理
        E_qrS_4_lists=unique(E_qrS_4_lists);
        %%%3.3 最后，让二者之间的数量保持一致，达成一一对应关系
        if numel(E_qRs_3_lists)>numel(E_qrS_4_lists)
            E_qRs_3_lists=E_qRs_3_lists(1:length(E_qrS_4_lists));
        elseif numel(E_qRs_3_lists)<numel(E_qrS_4_lists)
            E_qrS_4_lists=E_qrS_4_lists(1:length(E_qRs_3_lists));
        end
        
    lessthanzero=find(E_qRs_3_lists<0);
    if ~isempty(lessthanzero)
        E_qRs_3_lists=E_qRs_3_lists(numel(lessthanzero)+1:end);
        E_qrS_4_lists=E_qrS_4_lists(numel(lessthanzero)+1:end);
    end
    lessthanzero=find(E_qrS_4_lists<0);
    if ~isempty(lessthanzero)
        E_qRs_3_lists=E_qRs_3_lists(numel(lessthanzero)+1:end);
        E_qrS_4_lists=E_qrS_4_lists(numel(lessthanzero)+1:end);
    end
        
end

function  [ECGdata,ECGhead,ECG,E_qRs_3_lists,E_qrS_4_lists]=M3_ECG_c_subfunc_1(ECGdata,ECGhead,ECG,ECG1L,E_qRs_3_lists,E_qrS_4_lists,fs_ECGaft,t)
        %size(E_qRs_3_lists)
        exam_timelength=numel(ECG1L)/fs_ECGaft;
        %any(E_qrS_4_lists)
        E_qRs_3_lists;
        ECG1L(E_qRs_3_lists);
        E_qrS_4_lists;
        ECG1L(E_qrS_4_lists);
        qRs_mean_dis_ori=mean(ECG1L(E_qRs_3_lists),2)-mean(ECG1L,2);
        qrS_mean_dis_ori=mean(ECG1L(E_qrS_4_lists),2)-mean(ECG1L,2);
        if qRs_mean_dis_ori<0
            [peakvalue,peakloc]=findpeaks(ECG1L);            
            for i=1:numel(E_qRs_3_lists)
                locnumback=find((peakloc-E_qRs_3_lists(i))>0,1,'first');
                locnumhead=find((peakloc-E_qRs_3_lists(i))<0,1,'last');
                %peakvalue(locnumback)
                %ECG1L(E_qRs_3_lists(i))
                %peakvalue(locnumhead)
                if peakvalue(locnumback)>peakvalue(locnumhead)  & peakvalue(locnumback)>ECG1L(E_qRs_3_lists(i))
                    E_qRs_3_lists(i)=peakloc(locnumback);
                elseif peakvalue(locnumback)<peakvalue(locnumhead)  & peakvalue(locnumhead)>ECG1L(E_qRs_3_lists(i))
                    E_qRs_3_lists(i)=peakloc(locnumhead);
                end
            end
        end
        if qrS_mean_dis_ori>0
            [valleyloc,peakvalue]=findpeaks(-ECG1L);
            valleyvalue=-peakvalue;
            for i=1:numel(E_qrS_4_lists)
                locnumback=find((valleyloc-E_qrS_4_lists(i))>0,1,'first');
                locnumhead=find((valleyloc-E_qrS_4_lists(i))<0,1,'last');
                if valleyvalue(locnumback)<valleyvalue(locnumhead)  & valleyvalue(locnumback)<ECG1L(E_qrS_4_lists(i))
                    E_qrS_4_lists(i)=valleyloc(locnumback);
                elseif valleyvalue(locnumback)>valleyvalue(locnumhead)  & valleyvalue(locnumhead)<ECG1L(E_qrS_4_lists(i))
                    if valleyloc(locnumhead)>E_qRs_3_lists(i)
                        E_qrS_4_lists(i)=valleyloc(locnumhead);%不能因为低点，就将与qRs相对位置调换。
                    end
                end
            end
        end            
        %E_qRs_3_lists=round(E_qRs_3_lists);
        ECG1L(E_qRs_3_lists);
        ECG1L(E_qrS_4_lists);
        lessthanzero=find(E_qRs_3_lists<0);
        if ~isempty(lessthanzero)
            E_qRs_3_lists=E_qRs_3_lists(numel(lessthanzero)+1:end);
            E_qrS_4_lists=E_qrS_4_lists(numel(lessthanzero)+1:end);
        end
   E_qRs_3_lists=reshape(E_qRs_3_lists,[],1);
   E_qrS_4_lists=reshape(E_qrS_4_lists,[],1);
        QnumLoc=find((E_qRs_3_lists-E_qrS_4_lists)>0);
        SnumLoc=find((E_qRs_3_lists-E_qrS_4_lists)<0);
        %%%%%%%%%%%已知R点最高，要判断另外一个点是前方更小的Q，还是后方更大的S%%%%%%%
        %%%%如果前方Q点多，意味着高点在后，需要将少数派翻转回来，让上述数据在对应性上一开始就保持一致%%%%%
        length_S_T=ceil(fs_ECGaft*0.15);%S-T段估计长度，含绝对变量值
        S_T_height=zeros(numel(QnumLoc),1);
        S_T_inter_height=zeros(numel(QnumLoc),1);
        S_T_trend=zeros(numel(QnumLoc),1);
        if numel(QnumLoc)>=2           
             for i01=1:numel(QnumLoc)-1 
                %寻找R博后面第一个极值点
                [~,loc]=findpeaks( -ECG1L(E_qRs_3_lists(QnumLoc(i01)):E_qRs_3_lists(QnumLoc(i01+1))) );
                
                S_T_sec=ECG1L(E_qRs_3_lists(QnumLoc(i01))+loc(1):E_qRs_3_lists(QnumLoc(i01))+loc(1)+length_S_T);
                P=polyfit((1:numel(S_T_sec)),S_T_sec,1);
                S_T_trend(QnumLoc(i01))=P(1);%将每一段的ST斜率放入S_T_trend。
                S_T_height(QnumLoc(i01))=mean(S_T_sec)-mean(ECG1L(E_qRs_3_lists(QnumLoc(i01)):E_qRs_3_lists(QnumLoc(i01)+1)));
                S_T_inter_height(QnumLoc(i01))=max(S_T_sec)-min(S_T_sec);
             end
        end
        if numel(SnumLoc)>=2           
             for i01=1:numel(SnumLoc)-1 
                %寻找S波后面的S-T段。并判断斜率
                S_T_sec= ECG1L(E_qRs_3_lists(SnumLoc(i01)):E_qRs_3_lists(SnumLoc(i01))+length_S_T)  ;
                P=polyfit((1:numel(S_T_sec)),S_T_sec,1);
                S_T_trend(SnumLoc(i01))=P(1);%将每一段的ST斜率放入S_T_trend。
                S_T_height(SnumLoc(i01))=mean(S_T_sec)-mean(ECG1L(E_qRs_3_lists(SnumLoc(i01)):E_qRs_3_lists(SnumLoc(i01)+1)));
                S_T_inter_height(SnumLoc(i01))=max(S_T_sec)-min(S_T_sec);
             end
        end
        QnumLoc_num=numel(QnumLoc);
        SnumLoc_num=numel(SnumLoc);
        S_T_trend_mean=mean(S_T_trend);
        S_T_trend_max=max(S_T_trend);
        S_T_trend_min=min(S_T_trend);
        S_T_height_mean=mean(S_T_height);
        S_T_height_max=max(S_T_height);
        S_T_height_min=min(S_T_height);
        
        S_T_inter_height_mean=mean(S_T_inter_height);
        S_T_inter_height_max=max(S_T_inter_height);
        S_T_inter_height_min=min(S_T_inter_height);
        

        
   
    if t==1
        ECG.qRs_mean_dis_1_ori=qRs_mean_dis_ori;%R点的相对海拔。
        ECG.qrS_mean_dis_1_ori=qrS_mean_dis_ori;%S点的相对海拔。判定条件1原始数据完成  
        ECG.QnumLoc_1_num=QnumLoc_num;%自动初始低点识别到Q点的数量
        ECG.SnumLoc_1_num=SnumLoc_num;%自动初始低点识别到S点的数量
        ECG.S_T_trend_1_mean=S_T_trend_mean;%S-T段曲线的斜率
        ECG.S_T_trend_1_max=S_T_trend_max;%S-T段曲线的斜率最大值
        ECG.S_T_trend_1_min=S_T_trend_min;%S-T段曲线的斜率最小值
        ECG.S_T_height_1_mean=S_T_height_mean;%S-T段曲线在本次心电周期中的高度均值
        ECG.S_T_height_1_max=S_T_height_max;%S-T段曲线在本次心电周期中的高度最大值
        ECG.S_T_height_1_min=S_T_height_min;%S-T段曲线在本次心电周期中的高度最小值
        ECG.S_T_inter_height_1_mean=S_T_inter_height_mean;%S-T段曲线的高度差均值
        ECG.S_T_inter_height_1_max=S_T_inter_height_max;%S-T段曲线的高度差最大值
        ECG.S_T_inter_height_1_min=S_T_inter_height_min;%S-T段曲线的高度差最小值
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        S_Tseris_1_1_13=[exam_timelength,qRs_mean_dis_ori,qrS_mean_dis_ori,...            
            QnumLoc_num,SnumLoc_num,S_T_trend_mean,...
            S_T_trend_max,S_T_trend_min,...
            S_T_height_mean,S_T_height_max,S_T_height_min,...       
            S_T_inter_height_mean,S_T_inter_height_max,S_T_inter_height_min];
        ECGdata.S_Tseris_1_1_13=S_Tseris_1_1_13;
        ECGhead.S_Tseris_1_1_13={'时长','原始qRs-均值高度差', '原始qrS-均值高度差',...        
        '自动初始识别的Q点数量','自动初始识别的S点数量','S-T段斜率均值',...
        'S-T段斜率最大值','S-T段斜率最小值',...
        'S-T段在本次心电的电压均值','S-T段在本次心电的电压最大值','S-T段在本次心电的电压最小值',...
        'S-T段的高差均值','S-T段的高差最大值','S-T段的高差最小值',...
        };
    elseif t==2
        ECG.oppositeflip;
        ECG.qRs_mean_dis_2_ori=qRs_mean_dis_ori;%R点的相对海拔
        ECG.qrS_mean_dis_2_ori=qrS_mean_dis_ori;%S点的相对海拔  
        ECG.QnumLoc_2_num=QnumLoc_num;%自动初始低点识别到Q点的数量
        ECG.SnumLoc_2_num=SnumLoc_num;%自动初始低点识别到S点的数量
        ECG.S_T_trend_2_mean=S_T_trend_mean;%S-T段曲线的斜率
        ECG.S_T_trend_2_max=S_T_trend_max;%S-T段曲线的斜率最大值
        ECG.S_T_trend_2_min=S_T_trend_min;%S-T段曲线的斜率最小值
        ECG.S_T_height_2_mean=S_T_height_mean;%S-T段曲线在本次心电周期中的高度均值
        ECG.S_T_height_2_max=S_T_height_max;%S-T段曲线在本次心电周期中的高度最大值
        ECG.S_T_height_2_min=S_T_height_min;%S-T段曲线在本次心电周期中的高度最小值
        ECG.S_T_inter_height_2_mean=S_T_inter_height_mean;%S-T段曲线的高度差均值
        ECG.S_T_inter_height_2_max=S_T_inter_height_max;%S-T段曲线的高度差最大值
        ECG.S_T_inter_height_2_min=S_T_inter_height_min;%S-T段曲线的高度差最小值
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        S_Tseris_1_2_14=[ECG.oppositeflip,qRs_mean_dis_ori,qrS_mean_dis_ori,...            
            QnumLoc_num,SnumLoc_num,S_T_trend_mean,...
            S_T_trend_max,S_T_trend_min,...
            S_T_height_mean,S_T_height_max,S_T_height_min,...       
            S_T_inter_height_mean,S_T_inter_height_max,S_T_inter_height_min];
        ECGdata.S_Tseris_1_2_14=S_Tseris_1_2_14;
    S_Tseris_1_2_14={'波图是否翻转','修正后qRs-均值高度差', '修正后qrS-均值高度差',...        
        '修正后自动识别的Q点数量','修正后自动识别的S点数量','修正后S-T段斜率均值',...
        '修正后S-T段斜率最大值','修正后S-T段斜率最小值',...
        '修正后S-T段在本次心电的电压均值','修正后S-T段在本次心电的电压最大值','修正后S-T段在本次心电的电压最小值',...
        '修正后S-T段的高差均值','修正后S-T段的高差最大值','修正后S-T段的高差最小值',...
        };
    ECGhead.S_Tseris_1_2_14=S_Tseris_1_2_14;
    end
end

function [ECG,ECGori,ECGdata,ECGhead,ECG1Ldone]=M3_ECG_c_subfilter_2(ECG,ECGori,ECGdata,ECGhead,ECG1L,E_qRs_3_lists,E_qrS_4_lists)
            
%%%%%%%%%%第二步，qRs再定位（1）寻找曲线拐点为高值点位是否有多余的错误的点%%%%%%%%%%%%%%%
[maxdifvalue___,maxloc__]=findpeaks([0,diff(diff(ECG1L))]);
%[maxdifvalue___,maxloc__]=findpeaksreverse(maxdifvalue___,maxloc__);
maxdifvalue___=reshape(maxdifvalue___,[],1);
%%%%%%%%%%%%%%最低点的diff2最大，即差值最大。%%%%%%%%%%55
kmeans_secnum=3;
[idx,C]=kmeans(maxdifvalue___,kmeans_secnum);             
[val_max,loc_max]=max(C);
[val_min,loc_min]=min(C);
val_max_num=numel(find(idx==loc_max));
val_min_num=numel(find(idx==loc_min));
C(loc_max)=val_min;       
[val_mid,loc_mid]=max(C);
val_mid_num=numel(find(idx==loc_mid));
numel(E_qRs_3_lists);        
%如果数量少，且与其他两项相比差值更高，则可以确认脉冲波，需要予以消除
if val_max_num<0.25*numel(E_qRs_3_lists) && val_max>mean(ECG1L(E_qRs_3_lists))*2
    %loc_in_ECGL1=find(idx==loc_max);
    %the_pulse_n_loc=maxloc__(loc_in_ECGL1);
    the_pulse_n_loc=maxloc__(idx==loc_max);
    for_disset=-10;
    later_disset=10;
    for i04=1:val_max_num                                  
        %%%%%由负值到正值的系列数字
        later_loc=find((E_qRs_3_lists-the_pulse_n_loc(i04))>0,1,'first');
        for_loc=find((E_qRs_3_lists-the_pulse_n_loc(i04))<0,1,'last');
        later_dis=E_qRs_3_lists(later_loc)-the_pulse_n_loc(i04);
        for_dis=E_qRs_3_lists(for_loc)-the_pulse_n_loc(i04);
        if isempty(later_dis)
            if numel(ECG1L)-the_pulse_n_loc(i04)>10
                later_disset=10;
            else
                later_disset=numel(ECG1L)-the_pulse_n_loc(i04);
            end
        end
        if isempty(for_dis)
            if the_pulse_n_loc(i04)>10
                for_disset=-10;
            else
                for_disset=-the_pulse_n_loc(i04);
            end
        end
        if ~isempty(for_dis) && ~isempty(later_dis)
            if for_dis>-10 &&  for_dis<-3
                for_disset=for_dis;
            end
            if  later_dis<10  && later_dis>3
                 later_disset=later_dis;
            end 
        end
        thenum=numel(ECG1L(the_pulse_n_loc(i04)+for_disset:the_pulse_n_loc(i04)+later_disset));
        line=linspace(ECG1L(the_pulse_n_loc(i04)+for_disset),ECG1L(the_pulse_n_loc(i04)+later_disset),thenum);
        ECG1L(the_pulse_n_loc(i04)+for_disset:the_pulse_n_loc(i04)+later_disset)=line;
    end
    pulse_pulluted_n=1;      
else
    pulse_pulluted_n=0;   
    the_pulse_n_loc=1;
end
%ECG1Ldone=ECG1L;
%%%%%%%%%%%%%%%%求反面%%%%%%%%%%%%%%
 %%%%%%%%%%第二步，寻找曲线拐点为高值点位是否有多余的错误的点%%%%%%%%%%%%%%%
[mindifvalue___,mindifloc___]=findpeaks([0,diff(diff(-ECG1L))]);
%[mindifvalue___,mindifloc___]=findpeaksreverse(mindifvalue___,mindifloc___);
mindifvalue___=reshape(mindifvalue___,[],1);
%%%%%%%%%%%%%%最低点的diff2最大，即差值最大。%%%%%%%%%%55
%%%%%%%%%%%%%%最低点的diff2最大，即差值最大。%%%%%%%%%%55
kmeans_secnum=3;
abs_mindifvalue___=abs(mindifvalue___);
[idx,C]=kmeans(abs_mindifvalue___,kmeans_secnum);  
C;
mean(ECG1L(E_qrS_4_lists));

[val_max,loc_max]=max(C);
[val_min,loc_min]=min(C);
val_max_num=numel(find(idx==loc_max));
val_min_num=numel(find(idx==loc_min));
C(loc_max)=val_min;       
[val_mid,loc_mid]=max(C);
val_mid_num=numel(find(idx==loc_mid));
numel(E_qrS_4_lists);
for_disset=-10;
later_disset=10;
%如果数量少，且与其他两项相比差值更高，则可以确认脉冲波，需要予以消除
if val_max_num<0.25*numel(E_qrS_4_lists) && val_max>abs(mean(ECG1L(E_qrS_4_lists)))*2
    %loc_in_ECGL1=find(idx==loc_max);
    %the_pulse_n_loc=maxloc__(loc_in_ECGL1);
    the_pulse_p_loc=mindifloc___(idx==loc_max);     
    for i04=1:val_max_num                                
        %%%%%由负值到正值的系列数字
        later_loc=find((E_qRs_3_lists-the_pulse_p_loc(i04))>0,1,'first');
        for_loc=find((E_qRs_3_lists-the_pulse_p_loc(i04))<0,1,'last');
        later_dis=E_qRs_3_lists(later_loc)-the_pulse_p_loc(i04);
        for_dis=E_qRs_3_lists(for_loc)-the_pulse_p_loc(i04);
        if isempty(later_dis)
            if numel(ECG1L)-the_pulse_p_loc(i04)>10
                later_disset=10;
            else
                later_disset=numel(ECG1L)-the_pulse_p_loc(i04);
            end
        end
        if isempty(for_dis)
            if the_pulse_p_loc(i04)>10
                for_disset=-10;
            else
                for_disset=-the_pulse_p_loc(i04);
            end
        end
        if ~isempty(for_dis) && ~isempty(later_dis)
            if for_dis>-10  &&  for_dis<-3
                for_disset=for_dis;
            end
            if  later_dis<10 &&  later_dis>3
                 later_disset=later_dis;
            end 
        end                                                
        thenum=numel(ECG1L(the_pulse_p_loc(i04)+for_disset:the_pulse_p_loc(i04)+later_disset));
        line=linspace(ECG1L(the_pulse_p_loc(i04)+for_disset),ECG1L(the_pulse_p_loc(i04)+later_disset),thenum);
        ECG1L(the_pulse_p_loc(i04)+for_disset:the_pulse_p_loc(i04)+later_disset)=line; 

    end
    pulse_pulluted_p=1;      
else
    pulse_pulluted_p=0;   
    the_pulse_p_loc=1;
end
%%%%%%写入数据，总结%%%%%%
ECG1Ldone=ECG1L;
ECG.pulse_pulluted_p=pulse_pulluted_p;
ECG.pulse_pulluted_n=pulse_pulluted_n;
ECGori.the_pulse_p_loc=the_pulse_p_loc;
ECGori.the_pulse_n_loc=the_pulse_n_loc;
%%%%%%写入数据，总结传递%%%%%%

ECGdata.c_subfilter_2=[ECG.pulse_pulluted_p,ECG.pulse_pulluted_n];
ECGhead.c_subfilter_2={'正向干扰脉冲数','负向干扰脉冲数'};



end


function [ECG,ECGdata,ECGhead]=M3_ECG_c_s_quality_3(ECG,ECGdata,ECGhead,ECG1Ldone,E_qRs_3_lists,E_qrS_4_lists)

            kmeans_secnum=3;
            %diffECG1L=[mean(ECG1L,2),reshape(diff(ECG1L),1,[])];
            diff_qRs=[mean(diff(E_qRs_3_lists),1);reshape(diff(E_qRs_3_lists),[],1)];
            %diff_qRs=cat(1,diff_qRs,diff_qRs)
            [idx,~]=kmeans(diff_qRs,kmeans_secnum);
            static=tabulate(idx);%第一列是统计分组数，第二列是统计个数，第三列是占比，二与三都可以找数量上的最大值
            [~,locc]=max(static(:,2));
            thebest_qRs_by_RR_locs=find(idx==static(locc,1));
            R_R_dis_basic_mean=mean(E_qRs_3_lists(thebest_qRs_by_RR_locs));
            R_R_dis_basic_std=std(E_qRs_3_lists(thebest_qRs_by_RR_locs));%原始qrs位点最集中部分的均值与标准差
            thebest_qRs_by_RR_locs_num=numel(thebest_qRs_by_RR_locs);
            ECG.thebest_qRs_by_RR_locs_num=thebest_qRs_by_RR_locs_num;%5.RRstd原始统计数量
            ECG.R_R_dis_basic_mean=R_R_dis_basic_mean;%6.RR均值原始统计
            ECG.R_R_dis_basic_std=R_R_dis_basic_std;%7.RRstd原始统计
            
            %%%%此段为RR均值的初始参数部分统计数据%%%%%%
            %%%%%%%%%%%%高度差分析%%%%%%%%%%%%%%%%
            R_Q_height_dis_line=reshape(ECG1Ldone(E_qRs_3_lists)-ECG1Ldone(E_qrS_4_lists),[],1);
            [idx,~]=kmeans(R_Q_height_dis_line,kmeans_secnum);
            static=tabulate(idx);
            [~,locc]=max(static(:,2));
            thebest_qRs_by_RSheight_locs=find(idx==static(locc,1));
            thebest_qRs_by_RSheight_locsnum=numel(thebest_qRs_by_RSheight_locs);
            R_Q_height_dis_basic_mean=mean(R_Q_height_dis_line(thebest_qRs_by_RSheight_locs));
            R_Q_height_dis_basic_std=std(R_Q_height_dis_line(thebest_qRs_by_RSheight_locs));
            thebest_QRS_points_by2add=intersect(thebest_qRs_by_RR_locs,thebest_qRs_by_RSheight_locs);
            if isempty(thebest_QRS_points_by2add) && ~isempty(thebest_qRs_by_RR_locs)
                thebest_QRS_points_by2add=thebest_qRs_by_RR_locs;
            elseif isempty(thebest_QRS_points_by2add) && ~isempty(thebest_qRs_by_RSheight_locs)
                thebest_QRS_points_by2add=thebest_qRs_by_RSheight_locs;
            else
                thebest_QRS_points_by2add=1:numel(E_qRs_3_lists);
            end
            if thebest_QRS_points_by2add(end)==numel(E_qrS_4_lists)
                thebest_QRS_points_by2add=thebest_QRS_points_by2add(1:end-1);
            end
            if thebest_QRS_points_by2add(end)==numel(E_qrS_4_lists)
                thebest_QRS_points_by2add=thebest_QRS_points_by2add(1:end-1);
            end   
            thebest_QRS_points_by2addnum=numel(thebest_QRS_points_by2add);
            R_R_dis_best_2_basic_mean=mean(diff_qRs(thebest_QRS_points_by2add));
            R_R_dis_best_2_basic_std=std(diff_qRs(thebest_QRS_points_by2add));
            R_Q_height_best_2_basic_mean=mean(R_Q_height_dis_line(thebest_QRS_points_by2add));
            R_Q_best_2_basic_std=std(R_Q_height_dis_line(thebest_QRS_points_by2add));
            
         %%%%%%%%%%%%%%%最后基于参数评价心电质量%%%%%%%%%%%%%%
         qRs_ori_num=numel(E_qRs_3_lists);
        if ~isempty(thebest_qRs_by_RR_locs_num)
            if (thebest_qRs_by_RR_locs_num/qRs_ori_num)<0.1 
                quality=1;
            elseif (thebest_qRs_by_RR_locs_num/qRs_ori_num)>=0.1 && (thebest_qRs_by_RR_locs_num/qRs_ori_num)<0.3
                quality=2;
            elseif (thebest_qRs_by_RR_locs_num/qRs_ori_num)>=0.3 && (thebest_qRs_by_RR_locs_num/qRs_ori_num)<0.5
                quality=3;            
            elseif (thebest_qRs_by_RR_locs_num/qRs_ori_num)>=0.5 && (thebest_qRs_by_RR_locs_num/qRs_ori_num)<0.7
                quality=4; 
            elseif (thebest_qRs_by_RR_locs_num/qRs_ori_num)>=0.7 && (thebest_qRs_by_RR_locs_num/qRs_ori_num)<0.9
                quality=5;
            elseif (thebest_qRs_by_RR_locs_num/qRs_ori_num)>=0.9 
                quality=6;
            end

            thebest_QRS_points_by2add_num=numel(thebest_QRS_points_by2add);    
            if (thebest_QRS_points_by2add_num/qRs_ori_num)<0.1 
                quality1=1;
            elseif (thebest_QRS_points_by2add_num/qRs_ori_num)>=0.1 && (thebest_QRS_points_by2add_num/qRs_ori_num)<0.3
                quality1=2;
            elseif (thebest_QRS_points_by2add_num/qRs_ori_num)>=0.3 && (thebest_QRS_points_by2add_num/qRs_ori_num)<0.5
                quality1=3;            
            elseif (thebest_QRS_points_by2add_num/qRs_ori_num)>=0.5 && (thebest_QRS_points_by2add_num/qRs_ori_num)<0.7
                quality1=4; 
            elseif (thebest_QRS_points_by2add_num/qRs_ori_num)>=0.7 && (thebest_QRS_points_by2add_num/qRs_ori_num)<0.9
                quality1=5;
            elseif (thebest_QRS_points_by2add_num/qRs_ori_num)>=0.9 
                quality1=6;
            end
        else
            quality=99;
            quality1=99;
        end
        ECG.quality=quality;
        ECG.quality1=quality1;
        %%%%%%%%%%%%%%%最后基于参数评价心电质量%%%%%%%%%%%%%% 
        if numel(thebest_QRS_points_by2addnum)>1
            ECG.thebest_qRs_by_RR_locs_num=thebest_qRs_by_RR_locs_num;%5.RRstd原始统计数量
            ECG.R_R_dis_basic_mean=R_R_dis_basic_mean;%6.RR均值原始统计
            ECG.R_R_dis_basic_std=R_R_dis_basic_std;%7.RRstd原始统计
            
            ECG.thebest_qRs_by_RSheight_locsnum=thebest_qRs_by_RSheight_locsnum;%8高度差kmean3最大均值数量
            ECG.R_Q_height_dis_basic_mean=R_Q_height_dis_basic_mean;%9高度差kmean3最大数量均值
            ECG.R_Q_height_dis_basic_std=R_Q_height_dis_basic_std;%10高度差kmean3最大数量标准差
            
            ECG.thebest_QRS_points_by2addnum=thebest_QRS_points_by2addnum;%11  2者叠加最好的波形数量
            ECG.R_R_dis_best_2_basic_mean=R_R_dis_best_2_basic_mean;%12  2者叠加最好的波形RR均值
            ECG.R_R_dis_best_2_basic_std=R_R_dis_best_2_basic_std;%13  2者叠加最好的波形RR均值std
            ECG.R_Q_best_2_basic_mean=R_Q_height_best_2_basic_mean;%14  2者叠加最好的波形高度均值
            ECG.R_Q_best_2_basic_std=R_Q_best_2_basic_std;%15  2者叠加最好的波形高度均值
            %ECG1Lsecsmooth=sgolayfilt(ECG1L(1,:),2,15); 
        else
            %{
            ECG.thebest_qRs_by_RR_locs_num=numel(E_qRs_3_lists);%5.RRstd原始统计数量
            ECG.R_R_dis_basic_mean=mean(diff(E_qRs_3_lists));%6.RR均值原始统计
            ECG.R_R_dis_basic_std=std(diff(E_qRs_3_lists));%7.RRstd原始统计
                R_Q_height_dis_line=reshape(ECG1L(E_qRs_3_lists)-ECG1L(E_qrS_4_lists),[],1);
            ECG.thebest_qRs_by_RSheight_locsnum=numel(R_Q_height_dis_line);%8高度差kmean3最大均值数量
            ECG.R_Q_height_dis_basic_mean=mean(R_Q_height_dis_line);%9高度差kmean3最大数量均值
            ECG.R_Q_height_dis_basic_std=std(R_Q_height_dis_line);%10高度差kmean3最大数量标准差
            ECG.thebest_QRS_points_by2addnum=numel(R_Q_height_dis_line);%11  2者叠加最好的波形数量
            %}
            ECG.thebest_qRs_by_RR_locs_num=0;%5.RRstd原始统计数量
            ECG.R_R_dis_basic_mean=0;%6.RR均值原始统计
            ECG.R_R_dis_basic_std=0;%7.RRstd原始统计
                
            ECG.thebest_qRs_by_RSheight_locsnum=0;%8高度差kmean3最大均值数量
            ECG.R_Q_height_dis_basic_mean=0;%9高度差kmean3最大数量均值
            ECG.R_Q_height_dis_basic_std=0;%10高度差kmean3最大数量标准差
            
            ECG.thebest_QRS_points_by2addnum=0;%11  2者叠加最好的波形数量            
            ECG.R_R_dis_best_2_basic_mean=0;%12  2者叠加最好的波形RR均值
            ECG.R_R_dis_best_2_basic_std=0;%13  2者叠加最好的波形RR均值std
            ECG.R_Q_best_2_basic_mean=0;%14  2者叠加最好的波形高度均值
            ECG.R_Q_best_2_basic_std=0;%15  2者叠加最好的波形高度均值
        end
        ECGdata.s_quality_3=[ECG.quality,ECG.quality1,...
            ECG.thebest_qRs_by_RR_locs_num,ECG.R_R_dis_basic_mean,ECG.R_R_dis_basic_std,...
            ECG.thebest_qRs_by_RSheight_locsnum,ECG.R_Q_height_dis_basic_mean,ECG.R_Q_height_dis_basic_std,...
            ECG.thebest_QRS_points_by2addnum,...
            ECG.R_R_dis_best_2_basic_mean,ECG.R_R_dis_best_2_basic_std,...
            ECG.R_Q_best_2_basic_mean,ECG.R_Q_best_2_basic_std,...
            ];
        ECGhead.s_quality_3={'波形节律识别度','波形总质量（波高+节律kmeans=3分析）',...
            'R_R节律Kmeans下的最佳波形数','最佳节律均值','最佳节律标准差',...
                   'R_Q高度Kmeans下的最佳波形数','最佳高度均值','最佳高度标准差',...
                   'R_R节律合R_Q高度的共同最佳波形数',...
                   '最佳节律均值','最佳节律标准差',...
                   '最佳高度均值','最佳高度标准差',...
                   };
end
function [oridata_denoised]=filter_ways(filtermethod,ECG_data_final,fs,w1_level)

                oridata=ECG_data_final;
                if  filtermethod==0
                    oridata_denoised=oridata;%不滤波                 
                elseif filtermethod==1
                    % 小波函数降噪%%%%
                    % 设置小波函数和变换阶数
                    wname = 'db4';  % 选用 Daubechies 4 小波
                    %w1_level = 5;      % 小波变换的阶数                
                    [C, L] = wavedec(oridata, w1_level, wname); % 进行小波变换               
                    D = detcoef(C, L, w1_level); % 提取细节系数
                    % 对细节系数进行阈值处理
                    sigma = median(abs(D)) / 0.6745;  % 计算阈值
                    D = wthresh(D, 'h', sigma);       % 硬阈值处理
                    % 重构滤波信号
                    oridata_denoised = wrcoef('a', C, L, wname, w1_level);
                elseif filtermethod==2 % 带通滤波  
                    %fs_ori = 1000; % 采样频率  
                    f_band_low = 20; % 低通频率  
                    f_band_high = 200; % 高通频率  
                    % 生成一个包含不同频率成分的信号  
                    %speech_1_brife %= sin(2*pi*f1*t) + sin(2*pi*f2*t) + 0.5*sin(2*pi*50*t) + 0.5*sin(2*pi*300*t);  
                    % 设计带通滤波器参数  
                    Wn = [f_band_low/(fs/2) f_band_high/(fs/2)]; % 归一化频率
                    if Wn(2)>=1
                        Wn(2)=0.95;
                        if  Wn(1)> Wn(2)
                             Wn(1)=0.9;
                        end
                    end
                    Wn;
                    Rp = 1; % 通带最大衰减（以分贝为单位）  
                    Rs = 30; % 阻带最小衰减（以分贝为单位） 
                    % 使用butterworth滤波器设计带通滤波器  
                    [b,a] = butter(5,Wn,'bandpass');
                    % 应用滤波器  
                    oridata_denoised = filter(b,a,oridata);  
                    % 绘制原始信号和滤波后的信号
                elseif filtermethod==3 % 平均滤波
                    lvbochidu=0.01;
                    windowSize = ceil(numel(oridata)*lvbochidu);
                    b = (1/windowSize)*ones(1,windowSize);
                    a=1;
                    oridata_denoised = filter(b,a,oridata);  
                elseif filtermethod==4 % 平滑 
                    lvbochidu=0.01;
                    oridata_denoised = smooth(1:length(oridata),oridata,lvbochidu,'rloess');
                end
end

function   [data_struct,data_t_struct,Signal_d,app]=M3_ECG_c_4_points_cal(ori_sig_struct,mainparameters)
%{
dt=[1 2 3 -5 8 -9 5]'
dm=[8 9 14 -15 18 -29 15]'
cat(2,dt,dm)
sssss
%dt(dt>0)
%}

cut_it=1;
if ~exist("ori_sig_struct","var")
    sig_data_ori6=load("sig_data_ori6.mat");
    ori_sig_struct=sig_data_ori6.ori_sig_struct;
end
if ~exist("mainparameters","var")

    fullpath = mfilename('fullpath'); %本m文件所在位置全样本
        [ECG_4_ECG_mcode_folder,~,~]=fileparts(fullpath);%m算法文件夹   
        cd('..')
        sig_m_path=pwd;%父阶文件夹  
        ECG_4_file_name='sample';
        ECG_4_fs_ori=200;
        ECG_4_fs_aft=250;
        figureshow=0;
        sec_show=1;
        mainparameters.sig_m_path=sig_m_path;
        mainparameters.ECG_4_ECG_mcode_folder=ECG_4_ECG_mcode_folder;
        mainparameters.ECG_4_file_name=ECG_4_file_name;
        mainparameters.BPR_3_fs_ori=ECG_4_fs_ori;
        mainparameters.BPR_3_fs_aft=ECG_4_fs_aft;
        mainparameters.shall_we_send_all_details_to_Signal_d=0;%0别混淆结构。signal_d就是数据阵列。
        mainparameters.figureshow=figureshow;
        mainparameters.sec_show=sec_show;
        mainparameters.line_choose=3;%选择
end

%%%%参数预设%%%%
method_details_1=2; %1.用原波形找最大值；2.用各自的波形找最大值。
kmeans_secnum=2;
search_radius_para=5;%必须大于2，越小范围越大。BPR_3_fs_aft/search_radius_para
Q_range=0.2;%Q范围相比RR_dis的倍数
add_the_unnecessory=0;%0为不添加不必要的量。
tan_radical_threathhold=0.5;%Q点后方如果有波谷，二者位点形成的tan角度阈值，低于此阈值，就要向后移动一位。
save_data=1 ;%1.保存阶段性数据为本地文件mat；2.不保存
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%第一章：数据源标准点多重滤波优化确认方法开始%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%第一版块-原始信号获取kais%%%%%%%%%%%%
sig_m_path=mainparameters.sig_m_path;
ECG_4_ECG_mcode_folder=mainparameters.ECG_4_ECG_mcode_folder;
ECG_4_file_name=mainparameters.ECG_4_file_name;
sec_show=mainparameters.sec_show;
figureshow=mainparameters.figureshow;
ECG_4_fs_aft=mainparameters.BPR_3_fs_aft;%统一分析后的频率
%ECG_4_fs_aft=ECG_4_fs_aft
line_choose=mainparameters.line_choose;%选中哪一条滤波线进行后续的分析；
figureshow=1;%%%临时观察数据可靠性

if sec_show==1;disp('BPR_3_NIRS_cal_1');end
app.Text_process_statue_update.Value='BPR_3_NIRS_cal_1';
ECG1Ldone_filted=ori_sig_struct.ECG1Ldone_filted;
E_qRs_3_lists=ori_sig_struct.E_qRs_3_lists;
E_Qrs_2_lists=ori_sig_struct.E_Qrs_2_lists;
ECG_4_ECG_timeline=(1:numel(ECG1Ldone_filted))/ECG_4_fs_aft;
%BPR_3_NIRS_timeline=ori_sig_struct.BPR_3_NIRS_timeline;
%cd(BPR_3_NIRS_mcode_folder);

if cut_it==0
BPR_3_NIRS_data_xiaobo_filted=ori_sig_struct.BPR_3_NIRS_data_xiaobo_filted;
BPR_3_NIRS_data_daitong_filted=ori_sig_struct.BPR_3_NIRS_data_daitong_filted;
BPR_3_NIRS_data_pingjun_filted=ori_sig_struct.BPR_3_NIRS_data_pingjun_filted;
BPR_3_NIRS_data_pinghua_filted=ori_sig_struct.BPR_3_NIRS_data_pinghua_filted;
BPR_3_NIRS_data_butter_filted=ori_sig_struct.BPR_3_NIRS_data_butter_filted;
end
%%%%第一版块-原始信号获取完成%%%%%%%%%%%%
Signal_d.stepsign.t4='原始信号获取完成。信号波形进入分析阶段1.滤波并比较原始与滤波信号的特征，形成数据结构与信号质量评价依据1（4）';
%%%%第二板块-信号分析开始1比较原始与滤波信号的初始关键点特征，形成数据结构与信号质量评价依据1（4）
%1-1为了解决系统性的波形关键点识别问题，先建立精确的筛选调试方式。
[signal_bitnum,~]=size(ECG1Ldone_filted); %5022,7
ECG1Ldone_filted=reshape(ECG1Ldone_filted,1,[]);
SAMPLES2READ=numel(ECG1Ldone_filted);
thres=0.3;
rp=0.250;
ws=round(0.2*numel(ECG1Ldone_filted)/ECG_4_fs_aft);
E_qRs_3_lists = wjqrs(ECG1Ldone_filted, ECG_4_fs_aft, thres, rp, ws); %横排，要变纵列
E_qrS_4_lists = qrs_adjust(ECG1Ldone_filted,E_qRs_3_lists,ECG_4_fs_aft,-1,0.050,0);%横排
%E_qrS_4_lists=E_qrS_4_lists
%[E_qRs_3_lists, E_qrS_4_lists] = abd_beat_detector(ECG1Ldone_filted, ECG_4_fs_aft); 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%2.1多种滤波点位识别开始，目的，抓全所有关键点，防止遗漏%%%%%%
%%%%%%%%%%%%%%%%完成質量評價%%%%%%%%%%%%%%%%%%
%cd(ECG_4_ECG_mcode_folder);



%1-4.脉搏波的定点与起点计算程序%%%%%%%%%%%%%%%
if cut_it==0
if line_choose==-1
    [E_qRs_3_lists, E_qrS_4_lists] = abd_beat_detector(ECG1Ldone_filted, ECG_4_fs_aft); %脉搏波的定点与起点计算程序
    [peaks_xiaobo, onsets_xiaobo] = abd_beat_detector(BPR_3_NIRS_data_xiaobo_filted, ECG_4_fs_aft); %脉搏波的定点与起点计算程序
    [peaks_daitong, onsets_daitong] = abd_beat_detector(BPR_3_NIRS_data_daitong_filted, ECG_4_fs_aft); %脉搏波的定点与起点计算程序
    [peaks_pingjun, onsets_pingjun] = abd_beat_detector(BPR_3_NIRS_data_pingjun_filted, ECG_4_fs_aft); %脉搏波的定点与起点计算程序
    [peaks_pinghua, onsets_pinghua] = abd_beat_detector(BPR_3_NIRS_data_pinghua_filted, ECG_4_fs_aft); %脉搏波的定点与起点计算程序
    [peaks_butter, onsets_butter] = abd_beat_detector(BPR_3_NIRS_data_butter_filted, ECG_4_fs_aft); %脉搏波的定点与起点计算程序
elseif line_choose==0
    [E_qRs_3_lists, E_qrS_4_lists] = abd_beat_detector(ECG1Ldone_filted, ECG_4_fs_aft); 
    the_num=1;
    peaks_xiaobo=the_num;onsets_xiaobo=the_num;
    peaks_pingjun=the_num;onsets_pingjun=the_num;
    peaks_daitong=the_num;onsets_daitong=the_num;
    peaks_pinghua=the_num;onsets_pinghua=the_num;
    peaks_butter=the_num;onsets_butter=the_num;
elseif line_choose==1
    [peaks_xiaobo, onsets_xiaobo] = abd_beat_detector(BPR_3_NIRS_data_xiaobo_filted, ECG_4_fs_aft); %脉搏波的定点与起点计算程序
    the_num=1;
    E_qRs_3_lists=the_num;E_qrS_4_lists=the_num;
    peaks_pingjun=the_num;onsets_pingjun=the_num;
    peaks_daitong=the_num;onsets_daitong=the_num;
    peaks_pinghua=the_num;onsets_pinghua=the_num;
    peaks_butter=the_num;onsets_butter=the_num;
elseif line_choose==2
    [peaks_daitong, onsets_daitong] = abd_beat_detector(BPR_3_NIRS_data_daitong_filted, ECG_4_fs_aft); %脉搏波的定点与起点计算程序
    the_num=1;
    E_qRs_3_lists=the_num;E_qrS_4_lists=the_num;
    peaks_pingjun=the_num;onsets_pingjun=the_num;
    peaks_xiaobo=the_num;onsets_xiaobo=the_num;
    peaks_pinghua=the_num;onsets_pinghua=the_num;
    peaks_butter=the_num;onsets_butter=the_num;
elseif line_choose==3
    %[m,n]=size(BPR_3_NIRS_data_pingjun_filted);
    %if m>n
    %    BPR_3_NIRS_data_pingjun_filted=reshape(BPR_3_NIRS_data_pingjun_filted,1,[]);
    %end    
    [peaks_pingjun, onsets_pingjun] = abd_beat_detector(BPR_3_NIRS_data_pingjun_filted, ECG_4_fs_aft); %脉搏波的定点与起点计算程序
    the_num=1;
    E_qRs_3_lists=the_num;E_qrS_4_lists=the_num;
    peaks_xiaobo=the_num;onsets_xiaobo=the_num;
    peaks_daitong=the_num;onsets_daitong=the_num;
    peaks_pinghua=the_num;onsets_pinghua=the_num;
    peaks_butter=the_num;onsets_butter=the_num;
elseif line_choose==4
    [peaks_pinghua, onsets_pinghua] = abd_beat_detector(BPR_3_NIRS_data_pinghua_filted, ECG_4_fs_aft); %脉搏波的定点与起点计算程序
    the_num=1;
    E_qRs_3_lists=the_num;E_qrS_4_lists=the_num;
    peaks_xiaobo=the_num;onsets_xiaobo=the_num;
    peaks_daitong=the_num;onsets_daitong=the_num;
    peaks_pingjun=the_num;onsets_pingjun=the_num;
    peaks_butter=the_num;onsets_butter=the_num;
elseif  line_choose==5
        [peaks_butter, onsets_butter] = abd_beat_detector(BPR_3_NIRS_data_butter_filted, ECG_4_fs_aft); %脉搏波的定点与起点计算程序
    the_num=1;
    E_qRs_3_lists=the_num;E_qrS_4_lists=the_num;
    peaks_xiaobo=the_num;onsets_xiaobo=the_num;
    peaks_daitong=the_num;onsets_daitong=the_num;
    peaks_pingjun=the_num;onsets_pingjun=the_num;
    peaks_pinghua=the_num;onsets_pinghua=the_num;
end
if figureshow==1
    fig=figure(12);
    clf(fig, 'reset');    
    ax=subplot(6,1,1);
    plot(ax,ECG_4_ECG_timeline,ECG1Ldone_filted,'g-');
    %xlabel('Time / s'); ylabel('Voltage / mV');
    title(strcat('Original plotted signal--',ECG_4_file_name));
    hold on
    plot(ax,ECG_4_ECG_timeline(E_qRs_3_lists),ECG1Ldone_filted(E_qRs_3_lists),'b+');
    plot(ax,ECG_4_ECG_timeline(E_qrS_4_lists),ECG1Ldone_filted(E_qrS_4_lists),'ro');
    hold off
    ax=subplot(6,1,2);
    plot(ax,ECG_4_ECG_timeline,BPR_3_NIRS_data_xiaobo_filted,'g-');
    %xlabel('Time / s'); ylabel('Voltage / mV');
    %title(strcat('xiaobo filtered signal--',BPR_3_file_name));
    hold on
    plot(ax,ECG_4_ECG_timeline(peaks_xiaobo),BPR_3_NIRS_data_xiaobo_filted(peaks_xiaobo),'b+');
    plot(ax,ECG_4_ECG_timeline(onsets_xiaobo),BPR_3_NIRS_data_xiaobo_filted(onsets_xiaobo),'ro');
    hold off
    ax=subplot(6,1,3);
    plot(ax,ECG_4_ECG_timeline,BPR_3_NIRS_data_daitong_filted,'g-');
    %xlabel('Time / s'); ylabel('Voltage / mV');
    %title(strcat('daitong plotted signal--',BPR_3_file_name));
    hold on
    plot(ax,ECG_4_ECG_timeline(peaks_daitong),BPR_3_NIRS_data_daitong_filted(peaks_daitong),'b+');
    plot(ax,ECG_4_ECG_timeline(onsets_daitong),BPR_3_NIRS_data_daitong_filted(onsets_daitong),'ro');
    hold off
    ax=subplot(6,1,4);
    plot(ax,ECG_4_ECG_timeline,BPR_3_NIRS_data_pingjun_filted,'g-');
    %xlabel('Time / s'); ylabel('Voltage / mV');
    %title(strcat('pingjun plotted signal--',BPR_3_file_name));
    hold on
    plot(ax,ECG_4_ECG_timeline(peaks_pingjun),BPR_3_NIRS_data_pingjun_filted(peaks_pingjun),'b+');
    plot(ax,ECG_4_ECG_timeline(onsets_pingjun),BPR_3_NIRS_data_pingjun_filted(onsets_pingjun),'ro');
    hold off
    ax=subplot(6,1,5);
    plot(ax,ECG_4_ECG_timeline,BPR_3_NIRS_data_pinghua_filted,'g-');
    %xlabel('Time / s'); ylabel('Voltage / mV');
    %title(strcat('signal filtered pinghua--',BPR_3_file_name));
    hold on
    plot(ax,ECG_4_ECG_timeline(peaks_pinghua),BPR_3_NIRS_data_pinghua_filted(peaks_pinghua),'b+');
    plot(ax,ECG_4_ECG_timeline(onsets_pinghua),BPR_3_NIRS_data_pinghua_filted(onsets_pinghua),'ro');
    hold off
    ax=subplot(6,1,6);
    plot(ax,ECG_4_ECG_timeline,BPR_3_NIRS_data_butter_filted,'g-');
    %xlabel('Time / s'); ylabel('Voltage / mV');
    %title(strcat('butter plotted signal--',BPR_3_file_name));
    hold on
    plot(ax,ECG_4_ECG_timeline(peaks_butter),BPR_3_NIRS_data_butter_filted(peaks_butter),'b+');
    plot(ax,ECG_4_ECG_timeline(onsets_butter),BPR_3_NIRS_data_butter_filted(onsets_butter),'ro');
    hold off
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%2.1多种滤波点位识别完成，目的，抓全所有关键点，防止遗漏%%%%%%
%%%%%%%%%%%%%%%%完成質量評價%%%%%%%%%%%%%%%%%%
%%%%第二板块-信号分析开始1比较原始与滤波信号的初始关键点特征，形成数据结构与信号质量评价依据完成%%%%
if sec_show==1;disp('BPR_3_NIRS_cal_2_filted_done');end
Signal_d.stepsign.t5='信号滤波完成，比较原始信号基本特征，每秒特征及其滤波前后的预设识别点信号差异完成（5）';
app.Text_process_statue_update.Value=Signal_d.stepsign.t5;
%%%%第三板块-信号分析开始2.识别并确认pqRst关键点特征,并支撑后面引申出pQrst与pqrSt前后两个点。%%%%

%%%%1.通过观察信号描记质量，开始选择最优选的信号类型%%%%%
if line_choose==0
    ECG1Ldone_filted=ECG1Ldone_filted;
    
    pqRst_T_point_theory=E_qRs_3_lists;
    pQrst_T_point_theory=E_qrS_4_lists;
elseif line_choose==1
    ECG1Ldone_filted=BPR_3_NIRS_data_xiaobo_filted;
    pqRst_T_point_theory=peaks_xiaobo;
    pQrst_T_point_theory=onsets_xiaobo;
elseif line_choose==2
    ECG1Ldone_filted=BPR_3_NIRS_data_daitong_filted;
    pqRst_T_point_theory=peaks_daitong;
    pQrst_T_point_theory=onsets_daitong;
elseif line_choose==3
    ECG1Ldone_filted=BPR_3_NIRS_data_pingjun_filted;
    pqRst_T_point_theory=peaks_pingjun;
    pQrst_T_point_theory=onsets_pingjun;
elseif line_choose==4
    ECG1Ldone_filted=BPR_3_NIRS_data_pinghua_filted;
    pqRst_T_point_theory=peaks_pinghua;
    pQrst_T_point_theory=onsets_pinghua;
elseif line_choose==5
    ECG1Ldone_filted=BPR_3_NIRS_data_butter_filted;
    pqRst_T_point_theory=peaks_butter;
    pQrst_T_point_theory=onsets_butter;
end
ori_sig_struct.BPR_3_NIRS_final_fed_signal=ECG1Ldone_filted;
%%%%1.通过观察信号描记质量，开始选择最优选的信号类型完成,并单独存储。%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%2.2多种滤波点位识别完成，目的，抓全所有关键点，防止遗漏%%%%%%
%%%%%%%%%%%%%%%%完成質量評價%%%%%%%%%%%%%%%%%%
%%%%2.设计一个方程，确立并完成识别点中。
%%%2.合并群体的集群点，选择位置最高的，然后展示在原图中。
%paper title:a very simple way to identify QRS point in a very variance NIRS wave signals

if cut_it==0
%%%%集合所有滤波信号的识别点位%%%%
    whole_peaks_dis_assemble=cat(1,peaks_xiaobo,peaks_daitong, peaks_pingjun,peaks_pinghua,peaks_butter);
    whole_onsets_dis_assemble=cat(1,onsets_xiaobo,onsets_daitong, onsets_pingjun,onsets_pinghua,onsets_butter);
    %method_details_1=1;
    if method_details_1==1
        whole_peaks_height_assemble=cat(1,ECG1Ldone_filted(peaks_xiaobo),...
        ECG1Ldone_filted(peaks_daitong),...
        ECG1Ldone_filted(peaks_pingjun),...
        ECG1Ldone_filted(peaks_pinghua),...
        ECG1Ldone_filted(peaks_butter));
        whole_onsets_height_assemble=cat(1,ECG1Ldone_filted(onsets_xiaobo),...
        ECG1Ldone_filted(onsets_daitong),...
        ECG1Ldone_filted(onsets_pingjun),...
        ECG1Ldone_filted(onsets_pinghua),...
        ECG1Ldone_filted(onsets_butter));
    elseif method_details_1==2    
        whole_peaks_height_assemble=cat(1,BPR_3_NIRS_data_xiaobo_filted(peaks_xiaobo),...
        BPR_3_NIRS_data_daitong_filted(peaks_daitong),...
        BPR_3_NIRS_data_pingjun_filted(peaks_pingjun),...
        BPR_3_NIRS_data_pinghua_filted(peaks_pinghua),...
        BPR_3_NIRS_data_butter_filted(peaks_butter));
        whole_onsets_height_assemble=cat(1,BPR_3_NIRS_data_xiaobo_filted(onsets_xiaobo),...
        BPR_3_NIRS_data_daitong_filted(onsets_daitong),...
        BPR_3_NIRS_data_pingjun_filted(onsets_pingjun),...
        BPR_3_NIRS_data_pinghua_filted(onsets_pinghua),...
        BPR_3_NIRS_data_butter_filted(onsets_butter));
    end
    %%%%%开始对整合的peaks与onsets进行调优，条件是进行了多次%%%%%%
    whole_timesec_assemble=whole_peaks_dis_assemble/ECG_4_fs_aft;%由采样比特率变动到时间单位：秒
    wholes_time5_peaks5_2_ori=cat(2,whole_peaks_dis_assemble,whole_peaks_height_assemble);
    %%%%集合所有滤波信号的识别点位完成%%%%
    %%%%开展分析，如果是0，则二分类，如果是>0,则不分类跳过
    if line_choose==0
    %%%%对所有滤波信号的识别点位进行2分类分组%%%%
        [whols_2_sorted,~]=sortrows(wholes_time5_peaks5_2_ori,1,"ascend");%sort(whols_2_ori,1,"ascend")
        timeline_ascend_diff=cat(1,mean(diff(whols_2_sorted(:,1))), diff(whols_2_sorted(:,1)));
        [ind,C]=kmeans(timeline_ascend_diff,kmeans_secnum);%kmeans_secnum=2
        [~,loc]=max(C);
        [search_radius,~]=min(C);
        search_radius=max(ECG_4_fs_aft/search_radius_para,search_radius);
        start_point=find(ind==loc);
        %%%第一位可以不要%%%%
        theloc=zeros(numel(start_point,1));
        for i=1:numel(start_point)-1
            [~,theloc(i)]=max(whols_2_sorted(start_point(i):start_point(i+1)-1,2));
            theloc(i)=start_point(i)+theloc(i)-1;
        end
        %final_time=whols_2_sorted(theloc,1);
        pqRst_T_point_theory=round(whols_2_sorted(theloc,1));%实质性中心位。
        %%%%2.对所有滤波信号的识别点位进行2分类分组，最终得到理论最大值%%%%
        %%%%3.对所有滤波信号的识别点位进行微调理论最大值，形成对目标信号的实际最大值%%%%
        size(whole_timesec_assemble);
        size(whole_peaks_height_assemble);    
    else    
        pqRst_T_point_theory=peaks_pingjun;
        search_radius=ECG_4_fs_aft/search_radius_para;
    end
    %%%%%开始对整合的onsets，onsets进行调优，条件是进行了多次%%%%%%
    %
    wholes_time5_onsets5_2_ori=cat(2,whole_onsets_dis_assemble,whole_onsets_height_assemble);
    if line_choose==-1
    %%%%对所有滤波信号的识别点位进行2分类分组%%%%
        [whols_2_sorted,~]=sortrows(wholes_time5_onsets5_2_ori,1,"ascend");%sort(whols_2_ori,1,"ascend")
        timeline_ascend_diff=cat(1,mean(diff(whols_2_sorted(:,1))), diff(whols_2_sorted(:,1)));
        [ind,C]=kmeans(timeline_ascend_diff,kmeans_secnum);%kmeans_secnum=2
        [~,loc]=max(C);
        [search_radius,~]=min(C);
        search_radius=max(ECG_4_fs_aft/search_radius_para,search_radius);
        start_point=find(ind==loc);
        %%%第一位可以不要%%%%
        theloc=zeros(numel(start_point,1));
        for i=1:numel(start_point)-1
            [~,theloc(i)]=max(whols_2_sorted(start_point(i):start_point(i+1)-1,2));
            theloc(i)=start_point(i)+theloc(i)-1;
        end
        %final_time=whols_2_sorted(theloc,1);
        pQrst_T_point_theory=round(whols_2_sorted(theloc,1));%实质性中心位。
        %%%%2.对所有滤波信号的识别点位进行2分类分组，最终得到理论最大值%%%%
        %%%%3.对所有滤波信号的识别点位进行微调理论最大值，形成对目标信号的实际最大值%%%%
        size(whole_timesec_assemble);
        size(whole_peaks_height_assemble);    
    else
        pQrst_T_point_theory=onsets_pingjun;
        search_radius=ECG_4_fs_aft/search_radius_para;
    end
else
    search_radius=ECG_4_fs_aft/search_radius_para;
    pqRst_T_point_theory=E_qRs_3_lists;
    pQrst_T_point_theory=E_qrS_4_lists;

end
%[pqRst_T_point_act, pQrst_T_point_act] = abd_beat_detector(BPR_3_NIRS_final_fed_signal, ECG_4_fs_aft); %脉搏波的定点与起点计算程序
thres=0.3;
rp=0.250;
ws=round(0.2*numel(ECG1Ldone_filted)/ECG_4_fs_aft);
pqRst_T_point_act = wjqrs(ECG1Ldone_filted, ECG_4_fs_aft, thres, rp, ws); %横排，要变纵列
pQrst_T_point_act = qrs_adjust(ECG1Ldone_filted,pqRst_T_point_act,ECG_4_fs_aft,-1,0.050,0);%横排
figure(14)
plot(ECG_4_ECG_timeline,ECG1Ldone_filted,'g-');
    hold on
    plot(ECG_4_ECG_timeline(pqRst_T_point_act),ECG1Ldone_filted(pqRst_T_point_act),'b+');
    plot(ECG_4_ECG_timeline(pQrst_T_point_act),ECG1Ldone_filted(pQrst_T_point_act),'ro');
    hold off

pqRst_T_point_theory=pqRst_T_point_act;
pQrst_T_point_theory=E_Qrs_2_lists;


%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%onsets只是辅助，后文重新分析。%%%%%%
numel(pqRst_T_point_theory);
numel(pQrst_T_point_theory);
minisec=min(numel(pqRst_T_point_theory),numel(pQrst_T_point_theory));
pqRst_T_point_theory=pqRst_T_point_theory(1:minisec);
pQrst_T_point_theory=pQrst_T_point_theory(1:minisec);

pqRst_T_point_act=zeros(length(pqRst_T_point_theory),1);%滤波后实际峰值
pqRst_T_point_oriact=zeros(length(pqRst_T_point_theory),1);%滤波前实际峰值
pQrst_T_point_act=zeros(length(pqRst_T_point_theory),1);%滤波后实际峰值
%pQrst_T_point_oriact=zeros(length(pqRst_T_point_theory),1);%滤波前实际峰值
%%%%pqRst_T_point_theory，R点理论值查询得到，小步前行，移动两次。
for i = 1:length(pqRst_T_point_theory)
    current_R_loc = pqRst_T_point_theory(i);        
    % 确定搜索范围（避免越界）
    left = floor(max(1, current_R_loc - search_radius));
    right = floor(min(length(ECG1Ldone_filted), current_R_loc + search_radius));        
    % 在邻域内找最大值
    [~, max_idx] = max(ECG1Ldone_filted(left:right));
    pqRst_T_point_act(i) = left + max_idx - 1; % 转换为全局索引
    [~, max_idx] = max(ECG1Ldone_filted(left:right));
    pqRst_T_point_oriact(i) = left + max_idx - 1; % 转换为全局索引
    %%%%%Q值分析
    current_Q_loc = pQrst_T_point_theory(i);        
    % 确定搜索范围（避免越界）
    left = floor(max(1, current_Q_loc - search_radius));
    right = floor(min(length(ECG1Ldone_filted), current_Q_loc + search_radius));        
    % 在邻域内找最大值
    [~, min_idx] = min(ECG1Ldone_filted(left:right));
    pQrst_T_point_act(i) = left + min_idx - 1; % 转换为全局索引  
end
%pqRst_T_point_act = unique(pqRst_T_point_act);
for i = 1:length(pqRst_T_point_act)
    current_R_loc = pqRst_T_point_act(i);        
    % 确定搜索范围（避免越界）
    left = floor(max(1, current_R_loc - search_radius));
    right = floor(min(length(ECG1Ldone_filted), current_R_loc + search_radius));        
    % 在邻域内找最大值
    [~, max_idx] = max(ECG1Ldone_filted(left:right));
    pqRst_T_point_act(i) = left + max_idx - 1; % 转换为全局索引
    [~, max_idx] = max(ECG1Ldone_filted(left:right));
    pqRst_T_point_oriact(i) = left + max_idx - 1; % 转换为全局索引
    %%%%%Q值分析
    current_Q_loc = pQrst_T_point_act(i);      %第二遍用实际值 确定搜索范围（避免越界）    
    left = floor(max(1, current_Q_loc - search_radius));
    right = floor(min(length(ECG1Ldone_filted), current_Q_loc + search_radius));        
    [~, min_idx] = min(ECG1Ldone_filted(left:right));
    pQrst_T_point_act(i) = left + min_idx - 1; % 转换为全局索引  
end
%pqRst_T_point_act = unique(pqRst_T_point_act);最后再做。
% 去重（如果多个峰值修正到同一位置。注意，只有pqRst_T_point_act执行此项）
%%%%两遍之后，即可确认pqRst% 峰值点位置所在。%%%%%
%%%%但是，这是防漏项设计的，两遍之后，不会有少的，但是可能会有多的，所以需要排查，将可能的重搏波排除掉，只保留最佳的波点位置。%%%%%
%%%%防漏设计结束，防多设计开始%%%%%%%
%%%%第一步，间距分组统计；

pqRst_T_point_act_diff=cat(1,mean(diff(pqRst_T_point_act)),diff(pqRst_T_point_act));
kmeans_secnum=3;
size(pqRst_T_point_act_diff)
%pqRst_T_point_act_diff=reshape(pqRst_T_point_act_diff,1,[]);
size(pqRst_T_point_act_diff)
[ind,C]=kmeans(pqRst_T_point_act_diff,kmeans_secnum);%kmeans_secnum=2
[dis,loc]=min(abs(C-ECG_4_fs_aft));%参数，按照秒级计算，差值最小的是对的，其余都是错的%%%%
the_right_place_dis=(find(ind==loc));
the_wrong_place_dis=(find(ind~=loc));
pqRst_T_point_act_diff_mean=mean(diff(pqRst_T_point_act));
%%%%第二步，QR高度分组统计；
QR_s_height=ECG1Ldone_filted(pqRst_T_point_act)-ECG1Ldone_filted(pQrst_T_point_act);
kmeans_secnum=3;
QR_s_height=reshape(QR_s_height,[],1);
[ind,C]=kmeans(QR_s_height,kmeans_secnum);%kmeans_secnum=2
%%%不统计数字，只管最低的那一组。
[dis,loc]=min(C);
the_wrong_place_height=(find(ind==loc));%最小的是错的
the_right_place_height=(find(ind~=loc));
%static=tabulate(ind); %第一列是统计分组数，第二列是统计个数，第三列是占比，二与三都可以找数量上的最大值
%[QR_s_height_kmeans3_num_list,QR_s_height_kmeans3_num_loc]=sort(static(:,2),"ascend"); %2与3均可
thewrongsec=intersect(the_wrong_place_height,the_wrong_place_dis);
if figureshow==1    
    fig=figure(13);
    clf(fig, 'reset');    
    ax=subplot(1,1,1);
    plot(ax,ECG_4_ECG_timeline,ECG1Ldone_filted,'k-');
    %xlabel('Time / s'); ylabel('Voltage / mV');
    title(strcat('Original plotted signal--',ECG_4_file_name));
    hold on
    plot(ax,ECG_4_ECG_timeline(pqRst_T_point_act),ECG1Ldone_filted(pqRst_T_point_act),'b+');
    plot(ax,ECG_4_ECG_timeline(pQrst_T_point_act),ECG1Ldone_filted(pQrst_T_point_act),'ro');
    plot(ax,ECG_4_ECG_timeline(pqRst_T_point_act(thewrongsec)),ECG1Ldone_filted(pqRst_T_point_act(thewrongsec)),'r*');
    hold off
end
%%%%展示完成后删除错误点，保留正确的点位。
%pqRst_T_point_act(thewrongsec) = [];
pqRst_T_point_act = round(unique(pqRst_T_point_act));%最后再做。

%pqRst_T_point_act_diff=cat(1,HR_bit_mean,diff(pqRst_T_point_act));
%%%%最后一次迭代循环，去掉所有临近点。后文采用动态阈值法，
ikl=1;
pqRst_T_point_act_1=pqRst_T_point_act;
for i=1:numel(pqRst_T_point_act) 
    HR_bit_mean=mean(diff(pqRst_T_point_act_1));%每次迭代完都会变化一点。
    pqRst_T_point_act_diff=cat(1,HR_bit_mean,diff(pqRst_T_point_act_1));
    [num,loc]=min(pqRst_T_point_act_diff);%loc不可能是1,1位置是均值    
    if num<ECG_4_fs_aft*0.5
        if ECG1Ldone_filted(pqRst_T_point_act_1(loc-1))>ECG1Ldone_filted(pqRst_T_point_act_1(loc))
            pqRst_T_point_act_1(loc)=[];
        else
            ikl=ikl+1;
            pqRst_T_point_act_1(loc-1)=[];
        end
    else
        break
    end
end
pqRst_T_point_act=pqRst_T_point_act_1;
pqRst_T_point_act = round(unique(pqRst_T_point_act));%最后再做。
HR_bit_mean=mean(diff(pqRst_T_point_act));
%Signal_d.stepsign.originpeaks=numel(peaks_pingjun);
Signal_d.stepsign.pqRst_T_point_theory_num=numel(pqRst_T_point_theory);
Signal_d.stepsign.pqRst_T_point_act_num=numel(pqRst_T_point_act);
Signal_d.stepsign.the_wrong_place_dis_num=numel(the_wrong_place_dis);
Signal_d.stepsign.the_wrong_place_height_num=numel(the_wrong_place_height);
Signal_d.stepsign.thewrongsec_num=numel(thewrongsec);
Signal_d.stepsign.lastminnum=ikl;
%%%%第一步，过滤过程记录分组统计完成；
%%%%第二步，高度分组统计完成；
%%%%第三步，统合分析统计完成；
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%2.4多种滤波点位识别完成，目的，抓全所有关键点，防止遗漏%%%%%%
%%%%%%%%%%%%%%%%完成質量評價%%%%%%%%%%%%%%%%%%
if sec_show==1;disp('BPR_3_NIRS_cal_3_pqRst_done');end
%%%%第三板块-信号分析2.识别并确认pqRst关键点位置完成。%%%    
Signal_d.stepsign.t6='信号识别NIRS波峰值点pqRst位置完成（6）';
app.Text_process_statue_update.Value=Signal_d.stepsign.t6;
%%%%第四板块-信号分析3.引申出pQrst与pqrSt前后两个点。%%%%
%%%%接下来开始,查找pQrst_T_point_act位置。第一步进入算法初赛。
search_pQrst_radius=ceil(HR_bit_mean*0.3);
EEG_4_EEG_data_grad = gradient(ECG1Ldone_filted);
min_slope = 0.5 * std(EEG_4_EEG_data_grad);  %梯度标准差的一半
%%%%这里引用了一个增加的pQrst_T_point_act算法%%%%%
%%%%%%%%%%pQrst_T_point_act重新来一遍%%%%%
pqRst_T_point_act;
search_radius=ceil(HR_bit_mean*Q_range);%重定义，以RR间距的名义
pQrst_T_point_act = pQrst_point_locs(ECG1Ldone_filted, pqRst_T_point_act, search_radius,min_slope);
%%%%这里引用了一个增加的pQrst_T_point_act算法完成%%%%%
pQrst_T_point_act=round(pQrst_T_point_act);%滤波后实际峰值

%%%%增加的pQrst_T_point_act算法完成%%%%%
%%%%全局峰值与谷值。这两组数值，与后面多组共享%%%%
%pqRst_T_point_oriact=zeros(length(pqRst_T_point_theory),1);%滤波前实际峰值
[~,loc_peak_1_max]=findpeaks(ECG1Ldone_filted);%所有峰值位置
[~,loc_valley_1_min]=findpeaks(-ECG1Ldone_filted);%所有谷值位置
%%%%全局峰值与谷值。这两组数值，与后面多组共享%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%pQrst_T_point_act，Q点初始值已经查询得到，按照常规，小步前行，移动两次。
    for i = 1:length(pQrst_T_point_act)
        current_Q_loc = pQrst_T_point_act(i);        
        % 确定搜索范围（避免越界）
        if i==1
            left = floor(max(1, current_Q_loc - search_radius));
        else
            left = floor(max(pqRst_T_point_act(i-1)+ceil(HR_bit_mean*0.5), current_Q_loc - search_radius));
        end        
        right = floor(min(pqRst_T_point_act(i), current_Q_loc + search_radius));        
        % 在邻域内找最大值              
        if right>pqRst_T_point_act(i)
            right=pqRst_T_point_act(i);
        end
        if left>right
            left=right-search_radius*2;
        end
        [~, min_idx] = min(ECG1Ldone_filted(left:right));
        pQrst_T_point_act(i) = left + min_idx - 1; % 转换为全局索引         
    end
    if add_the_unnecessory==1
        pQrst_T_point_act = unique(pQrst_T_point_act); 
    end
    %%%%pQrst_T_point_act，Q点值已经查询得到，小步前行，移动两次第一次完成。
pQrst_T_point_act_2_to_end = adjust_and_interleave(pqRst_T_point_act,pQrst_T_point_act(2:end) );
pQrst_T_point_act=cat(1,pQrst_T_point_act(1),pQrst_T_point_act_2_to_end(1:end-1));
loc=find((pqRst_T_point_act-pQrst_T_point_act)<5);
pQrst_T_point_act(loc)=pQrst_T_point_act(loc)-5;
pqRst_T_point_act-pQrst_T_point_act;
diff(pQrst_T_point_act)

    %%%%pQrst_T_point_act，Q点值已经查询得到，小步前行，移动两次第二次开始。
    %%%%开始添加pQ_rst_T_point_act，pqrSt_T_point_act与pqrsT_T_point_act。
    pqrSt_T_point_act=zeros(length(pQrst_T_point_act),1);%错误的标记位置，需查找
    pqrsT_T_point_act=zeros(length(pQrst_T_point_act),1);%错误的标记位置，需查找
    pQ_rst_T_point_act=zeros(length(pQrst_T_point_act),1);%辅助点，Q_R间加速度最大位。
    tool_Q_valley_tan_radical=zeros(length(pQrst_T_point_act),1);%线性梯度数值，测试用数据；
    
    tool_pQrst_pqRst_height_dis=zeros(length(pQrst_T_point_act),1);%辅助点，Q_R间高度差。
    tool_pQrst_pqRst_local_dis=zeros(length(pQrst_T_point_act),1);%辅助点，Q_R间距离位置差。

    tool_pQrst_pqRst_valleynum=zeros(length(pQrst_T_point_act),1);%辅助点，Q_R间是否还有波谷数量。
    tool_pQrst_pqRst_valleyheight=zeros(length(pQrst_T_point_act),1);%辅助点，Q_R间如果有波谷，波形深度。
    tool_pQrst_pqRst_valleyloc=zeros(length(pQrst_T_point_act),1);%辅助点，Q_R间如果有波谷，位置高度。
    tool_pQrst_valley_height=zeros(length(pQrst_T_point_act),1);%辅助点，Q_R间如果有波谷，其位置高度值。
    tool_pQrst_valley_pqRst_height_rate=zeros(length(pQrst_T_point_act),1);%辅助点，Q_R间如果有波谷，其位置高度在Q_R之间的比率关系。
    %%%%首先，调整到绝对最小值位置
    for i = 1:length(pQrst_T_point_act)
        current_Q_loc = pQrst_T_point_act(i);        
        % 确定搜索范围（避免越界）
        if i==1
            left = floor(max(1, current_Q_loc - search_radius));
        else
            left = floor(max(pqRst_T_point_act(i-1)+ceil(HR_bit_mean*0.5), current_Q_loc - search_radius));
        end        
        right = floor(min(pqRst_T_point_act(i), current_Q_loc + search_radius));        
        % 在邻域内找最小值              
        if right>pqRst_T_point_act(i)
            right=pqRst_T_point_act(i);
        end
        if left>right
            left=right-search_radius*2;
        end
        [~, min_idx] = min(ECG1Ldone_filted(left:right));
        pQrst_T_point_act(i) = left + min_idx - 1; % 转换为全局索引
        %%%额外增加项：进一步查找前一个谷值是否显著低于本值
        %%%标准点前半程区间内（更大范围内查找最低点），如果最小值低于pQrst_T_point_act(i)超过了pQrst_T_point_act(i)距离顶点的一半，则转移到最低点。
        if i==1
            left=floor(max(1, pqRst_T_point_act(i) - HR_bit_mean));%pqRst_T_point_act
        else
            left=floor(max(pqRst_T_point_act(i-1), 0.5*(pqRst_T_point_act(i-1) + pqRst_T_point_act(i))));%pqRst_T_point_act
        end               
        [~, min_sec] = min(ECG1Ldone_filted(left:pqRst_T_point_act(i)));
        min_sec=min_sec+left-1;
        %如果高于0.5倍的距离，直接引入最低点。
        higher_sec=ECG1Ldone_filted(pqRst_T_point_act(i))-ECG1Ldone_filted(pQrst_T_point_act(i));
        lower_sec=ECG1Ldone_filted(pQrst_T_point_act(i))-ECG1Ldone_filted(min_sec);
        if lower_sec>=higher_sec*0.3
            pQrst_T_point_act(i)=min_sec;
        end
        %%%%在往后倒腾一个值%%%%
        com_aft_loc_1=find((loc_valley_1_min-pQrst_T_point_act(i)) >0,1,"first");%再往后倒腾一下；
        if numel(com_aft_loc_1)>=1
        height_loss=ECG1Ldone_filted(pQrst_T_point_act(i))-ECG1Ldone_filted(loc_valley_1_min(com_aft_loc_1));
        dis_loss=pQrst_T_point_act(i)-loc_valley_1_min(com_aft_loc_1);
        height_loss;
        dis_loss;
        tan_radical=height_loss./dis_loss;
        tool_Q_valley_tan_radical(i)=tan_radical;
        else
            tan_radical=0;
            tool_Q_valley_tan_radical(i)=0;
        end

        if numel(com_aft_loc_1)>=1
        if tan_radical<tan_radical_threathhold% 预设值为0.5，意图在于观察 Q点后方。如果有波谷，二者位点形成的tan角度阈值，低于此阈值，就要向后移动一位。
            pQrst_T_point_act(i)=loc_valley_1_min(com_aft_loc_1(1));
        end
        EEG_4_EEG_data_grad(pQrst_T_point_act(i));
        EEG_4_EEG_data_grad(loc_valley_1_min(com_aft_loc_1(1)));
        end
        
        %%%%再加一个额外的辅助点，拐点pQ_rst_T_point_act。
        com_aft_loc_2=find((loc_peak_1_max-pQrst_T_point_act(i)) >0,1,"first");%再往后倒腾一下,求拐点；
        [value,loc]=max(EEG_4_EEG_data_grad(pQrst_T_point_act(i)+1:loc_peak_1_max(com_aft_loc_2)));
        if numel(loc)>=1
        pQ_rst_T_point_act(i)=pQrst_T_point_act(i)+loc;
        end
        %%%%正式标记点计算完成，确定了pQrst_T_point_act与pQ_rst_T_point_act
        % 接下来，进入辅助类信息求取阶段%
        %%%%建立Q_R间距与差的描述。%%%
        tool_pQrst_pqRst_height_dis(i)=ECG1Ldone_filted(pqRst_T_point_act(i))-ECG1Ldone_filted(pQrst_T_point_act(i)) ;%辅助点，Q_R间高度差。
        tool_pQrst_pqRst_local_dis(i)=pqRst_T_point_act(i)-pQrst_T_point_act(i);
        %%%完成Q_R间距与差的描述。%%%%
        %%%%求相关辅助性特征的数值，依然搭这个for的顺风车%%%%
        in_range =((loc_valley_1_min>pQrst_T_point_act(i)) & (loc_valley_1_min<pqRst_T_point_act(i)));
        loc_valley_pQ_Rst = find(in_range); % 对应的位置（索引）
        tool_pQrst_pqRst_valleynum(i)=numel(loc_valley_pQ_Rst);
        if numel(loc_valley_pQ_Rst)>=2
            in_range=(loc_peak_1_max>pQrst_T_point_act(i)) & (loc_peak_1_max<loc_valley_1_min(loc_valley_pQ_Rst(1)));
            %%%注意in_range数量可变，极端情况下可为0。
            loc_peak_pQ_Rst = find(in_range);%一定不多于loc_valley_pqrSt               
            if numel(loc_peak_pQ_Rst)>=1 & numel(loc_peak_pQ_Rst)<=numel(loc_valley_pQ_Rst)
                loc_valley_pQ_Rst=loc_valley_pQ_Rst(1:numel(loc_peak_pQ_Rst));
            end
            heightgain=ECG1Ldone_filted(loc_peak_1_max(loc_peak_pQ_Rst))-ECG1Ldone_filted(loc_valley_1_min(loc_valley_pQ_Rst));
            [val,loc]=max(heightgain);
            tool_pQrst_pqRst_valleyheight(i)=val;%最大的回弹高度;            
            tool_pQrst_pqRst_valleyloc(i)=loc_valley_1_min(loc_valley_pQ_Rst(loc));
            tool_pQrst_valley_height(i)=ECG1Ldone_filted(tool_pQrst_pqRst_valleyloc(i))-ECG1Ldone_filted(pQrst_T_point_act(i)) ;%辅助点，
            tool_pQrst_valley_pqRst_height_rate(i)=tool_pQrst_valley_height(i)/tool_pQrst_pqRst_height_dis(i);
            
        elseif isscalar(loc_valley_pQ_Rst)
            tool_pQrst_pqRst_valleyloc(i)=loc_valley_1_min(loc_valley_pQ_Rst(1));
            tool_pQrst_valley_height(i)=ECG1Ldone_filted(tool_pQrst_pqRst_valleyloc(i))-ECG1Ldone_filted(pQrst_T_point_act(i)) ;%辅助点，
            tool_pQrst_valley_pqRst_height_rate(i)=tool_pQrst_valley_height(i)/tool_pQrst_pqRst_height_dis(i);
            com_aft_loc_2=find((loc_peak_1_max-pQrst_T_point_act(i)) >0,1,"first");%再往后倒腾一下,求拐点；
            loc_peak_pQ_Rst=loc_peak_1_max(com_aft_loc_2);
            if  loc_peak_pQ_Rst >right
                loc_peak_pQ_Rst=right;%防止越界%%%再加约束条件，防止它跑得太靠后。
            end
            heightgain=ECG1Ldone_filted((loc_peak_pQ_Rst))-ECG1Ldone_filted(tool_pQrst_pqRst_valleyloc(i));
            %[heightgain,~]=max(heightgain);%无用了
            tool_pQrst_pqRst_valleyheight(i)=heightgain;%最大的回弹高度;    
                       
        elseif numel(loc_valley_pQ_Rst)==0
            %%%%就需要通过拐点识别，半程中前半段拐点最小与后半程拐点最大
           tool_pQrst_pqRst_valleyheight(i)=0;%最大的回弹高度;            
            tool_pQrst_pqRst_valleyloc(i)=0;
            tool_pQrst_valley_height(i)=0 ;%辅助点，
            tool_pQrst_valley_pqRst_height_rate(i)=0;%也是无用的
            %%%%这也是很异常且很极端的情况%%%%
        end
        %%%%最终额外的取得了关于是否升支过程出现回弹波的信息。
        tool_pQrst_pqRst_valleynum;%辅助点，辅助点，Q_R间是否还有波谷数量。
        tool_pQrst_pqRst_valleyloc;%辅助点，Q_R间如果有波谷，位置高度。
        tool_pQrst_pqRst_valleyheight;%Q_R间辅助点，Q_R间如果有波谷，波形深度。
        tool_pQrst_valley_height;
        tool_pQrst_valley_pqRst_height_rate;        
    end
    tool_Q_valley_tan_radical;%测试用数据；
    if add_the_unnecessory==1
        pQrst_T_point_act = unique(pQrst_T_point_act);
    end
    %%%%两遍之后，加上整体调整，即可确认峰值点位置所在。%%%%%
    %%%%第四板块-信号分析3.引申出pQrst点与pQ_rst_T_point_act完成。%%%%
    if sec_show==1;disp('BPR_3_NIRS_cal_4_pQrst_done');end
    Signal_d.stepsign.t7='信号点pQrst位置与pQ_rst_T_point_act完成（7）';
    app.Text_process_statue_update.Value=Signal_d.stepsign.t7;
    %%%%第五板块-信号分析4.引申出pqrSt点及其pqrsT开始。%%%%
    %%%%方法1.寻找后半程上升坡度最大的点位。定位重搏波。
    pqrSt_T_point_act=zeros(length(pqRst_T_point_act),1);%滤波后实际峰值
    pqrsT_T_point_act=zeros(length(pqRst_T_point_act),1);
    tool_pqRst_mid_space=zeros(length(pqRst_T_point_act),1);
    tool_pqRst_mid_valleynum=zeros(length(pqRst_T_point_act),1);
    for i = 1:length(pqRst_T_point_act)
        left = pqRst_T_point_act(i); %峰值点最靠后的位置是左侧     
        % 确定搜索范围（避免越界）
        %floor((pqRst_T_point_act(i)+pqRst_T_point_act(i+1))*0.5)
        if i<length(pqRst_T_point_act)
            right1 = floor((pqRst_T_point_act(i)+pQrst_T_point_act(i+1))*0.5);%中点
            right2 = floor(pqRst_T_point_act(i)+HR_bit_mean*0.2);%中点
            right=max([right1,right2]);
        else
            right = floor(min(length(ECG1Ldone_filted), pqRst_T_point_act(i) +HR_bit_mean*0.6));
        end      
        tool_pqRst_mid_space(i)=right-left;
        in_range =((loc_valley_1_min>left) & (loc_valley_1_min<right));
        loc_valley_pqrSt = find(in_range); % 对应的位置（索引）
        tool_pqRst_mid_valleynum(i)=numel(loc_valley_pqrSt);
        %max(loc_valley_1_min)
        %max(loc_peak_1_max)
        %(pqRst_T_point_act(end))
        %numel(loc_valley_pqrSt)
        %in_range=((loc_valley_1_min>left) & (loc_valley_1_min<right))
        if numel(loc_valley_pqrSt)>=2
            in_range=(loc_peak_1_max>loc_valley_1_min(loc_valley_pqrSt(1))) & (loc_peak_1_max<right);
            %%%注意in_range数量可变，极端情况下可为0。
            loc_peak_pqrSt = find(in_range);%一定不多于loc_valley_pqrSt
            if numel(loc_peak_pqrSt)<numel(loc_valley_pqrSt)
                loc_valley_pqrSt=loc_valley_pqrSt(1:numel(loc_peak_pqrSt));
            end
            heightgain=ECG1Ldone_filted(loc_peak_1_max(loc_peak_pqrSt))-ECG1Ldone_filted(loc_valley_1_min(loc_valley_pqrSt));
            [~,loc]=max(heightgain);
            pqrSt_T_point_act(i)=loc_valley_1_min(loc_valley_pqrSt(loc));
            pqrsT_T_point_act(i)=loc_peak_1_max(loc_peak_pqrSt(loc));
        elseif isscalar(loc_valley_pqrSt)
            pqrSt_T_point_act(i)=loc_valley_1_min(loc_valley_pqrSt(1));
            com_aft_loc_2=find((loc_peak_1_max-pqrSt_T_point_act(i)) >0,1,"first");%再往后倒腾一下,求拐点；
            if isempty(com_aft_loc_2)
                pqrsT_T_point_act(i)=min([pqrSt_T_point_act(i)+1,numel(ECG1Ldone_filted)]);
            else
                pqrsT_T_point_act(i)=loc_peak_1_max(com_aft_loc_2);
            end
            %%%再加约束条件，防止它跑得太靠后。
            if  pqrsT_T_point_act(i) >right
                pqrsT_T_point_act(i)=right;
            end
        elseif numel(loc_valley_pqrSt)==0
            %%%%就需要通过拐点识别，半程中前半段拐点最小与后半程拐点最大
            [val,loc]=max(EEG_4_EEG_data_grad(left:floor((left+right)*0.5)));
            left;
            right;
            pqrSt_T_point_act(i)=left+loc-1;
            [val,loc]=min(EEG_4_EEG_data_grad(ceil((left+right)*0.5):right));
            pqrsT_T_point_act(i)=ceil((left+right)*0.5)+loc-1;
            %%%%这也是很异常且很极端的情况%%%%
        end
    end
        % 提取符合条件的值和位置
    %%%%第五板块-信号分析4.引申出pqrSt点及其pqrsT完成。%%%%
if sec_show==1;disp('BPR_3_NIRS_cal_5_pqrSt_done');end
    Signal_d.stepsign.t8='信号识别NIRS波重搏波起点pqrSt点及其点pqrsT位置完成（8）';
app.Text_process_statue_update.Value=Signal_d.stepsign.t8;
    %%%%第六板块-信号分析5.最后识别引申出Pqrst点，并对对v_Pqrst点进行归位。%%%%
v_Pqrst_T_point_act=zeros(length(pqRst_T_point_act),1);%仿p波前的起始位置；
Pqrst_T_point_act=zeros(length(pqRst_T_point_act),1);%仿p波的峰值位置；
    tool_pqrsT_pQrst_space=zeros(length(pqRst_T_point_act),1);
    tool_pqrsT_pQrst_valleynum=zeros(length(pqRst_T_point_act),1);
    for i = 1:length(pqRst_T_point_act)
        if i==1
            left = max(1, pQrst_T_point_act(i)-floor(HR_bit_mean*0.6));%避免越界
        else
            left = pqrsT_T_point_act(i-1); %峰值点最靠后的位置是左侧  
        end        
        right = pQrst_T_point_act(i); %峰值点最靠后的位置是左侧  
        % 确定搜索范围（避免越界）
        %floor((pqRst_T_point_act(i)+pqRst_T_point_act(i+1))*0.5)
        tool_pqrsT_pQrst_space(i)=right-left;
        in_range =((loc_valley_1_min>left) & (loc_valley_1_min<right));
        loc_valley_pqrSt = find(in_range); % 对应的位置（索引）
        tool_pqrsT_pQrst_valleynum(i)=numel(loc_valley_pqrSt);
        if numel(loc_valley_pqrSt)>1
            in_range=(loc_peak_1_max>loc_valley_1_min(loc_valley_pqrSt(1))) & (loc_peak_1_max<right);
            %%%注意in_range数量可变，极端情况下可为0。
            loc_peak_pqrSt = find(in_range);%一定不多于loc_valley_pqrSt
            if numel(loc_peak_pqrSt)<numel(loc_valley_pqrSt)
                loc_valley_pqrSt=loc_valley_pqrSt(1:numel(loc_peak_pqrSt));
            end
            heightgain=ECG1Ldone_filted(loc_peak_1_max(loc_peak_pqrSt))-ECG1Ldone_filted(loc_valley_1_min(loc_valley_pqrSt));
            [~,loc]=max(heightgain);
            v_Pqrst_T_point_act(i)=loc_valley_1_min(loc_valley_pqrSt(loc));
            Pqrst_T_point_act(i)=loc_peak_1_max(loc_peak_pqrSt(loc));
        elseif isscalar(loc_valley_pqrSt)
            v_Pqrst_T_point_act(i)=loc_valley_1_min(loc_valley_pqrSt(1));
            com_aft_loc_2=find((loc_peak_1_max-v_Pqrst_T_point_act(i)) >0,1,"first");%再往后倒腾一下,求拐点；
            Pqrst_T_point_act(i)=loc_peak_1_max(com_aft_loc_2);
            %%%再加约束条件，防止它跑得太靠后。
            if  Pqrst_T_point_act(i) >=right
                Pqrst_T_point_act(i)=ceil((right+v_Pqrst_T_point_act(i))*0.5);
            end
        elseif numel(loc_valley_pqrSt)==0
            %%%%就需要通过拐点识别，半程中前半段拐点最小与后半程拐点最大
             if left>right
            right=left+1
            end
            [val,loc]=max(EEG_4_EEG_data_grad(left:floor((left+right)*0.5)));
            numel(ECG1Ldone_filted);
             numel(EEG_4_EEG_data_grad);
           
          
            v_Pqrst_T_point_act(i)=left+loc-1;
            [val,loc]=min(EEG_4_EEG_data_grad(ceil((left+right)*0.5):right));
            Pqrst_T_point_act(i)=ceil((left+right)*0.5)+loc-1;
            %%%%这也是很异常且很极端的情况%%%%
        end
    end
%%%%第六板块-信号分析5.最后识别引申出Pqrst点，并对v_Pqrst点进行归位完成。%%%%
if sec_show==1;disp('BPR_3_NIRS_cal_6_Pqrst_done');end
Signal_d.stepsign.t9='信号识别NIRS波最后引申出的Pqrst点与v_Pqrst位置完成（9）';
app.Text_process_statue_update.Value=Signal_d.stepsign.t9;
Signal_d.HR_bit_mean=HR_bit_mean;
%%%%将信号序列与相关的统计参数特征一同写入
Signal_d.v_Pqrst_T_point_act=v_Pqrst_T_point_act;
Signal_d.Pqrst_T_point_act=Pqrst_T_point_act;
Signal_d.pQrst_T_point_act=pQrst_T_point_act;
Signal_d. pQ_rst_T_point_act=pQ_rst_T_point_act;
Signal_d.pqRst_T_point_act=pqRst_T_point_act;
Signal_d.pqrSt_T_point_act=pqrSt_T_point_act;
Signal_d.pqrsT_T_point_act=pqrsT_T_point_act;

whole_mark_7=cat(2,v_Pqrst_T_point_act,Pqrst_T_point_act,pQrst_T_point_act,...
    pQ_rst_T_point_act,pqRst_T_point_act,pqrSt_T_point_act,pqrsT_T_point_act);

Signal_d.tool_pQrst_pqRst_height_dis=tool_pQrst_pqRst_height_dis;
Signal_d.tool_pQrst_pqRst_local_dis=tool_pQrst_pqRst_local_dis;
Signal_d.tool_pQrst_valley_height=tool_pQrst_valley_height;
Signal_d. tool_pQrst_valley_pqRst_height_rate=tool_pQrst_valley_pqRst_height_rate;
Signal_d.tool_pqRst_mid_space=tool_pqRst_mid_space;
Signal_d.tool_pqRst_mid_valleynum=tool_pqRst_mid_valleynum;
Signal_d.tool_pqrsT_pQrst_space=tool_pqrsT_pQrst_space;
Signal_d.tool_pqrsT_pQrst_valleynum=tool_pqrsT_pQrst_valleynum;
whole_toolrank_7=cat(2,tool_pQrst_pqRst_height_dis,tool_pQrst_pqRst_local_dis,...
        tool_pQrst_valley_height,tool_pQrst_valley_pqRst_height_rate,...
    tool_pqRst_mid_space,tool_pqRst_mid_valleynum,...
    tool_pqrsT_pQrst_space,tool_pqrsT_pQrst_valleynum);

if save_data==1
sig_data_rank_name='sig_data_ori6.mat';
save(sig_data_rank_name,"ori_sig_struct")
%sig_data_rank_name='sig_data_rank.mat';
%save(sig_data_rank_name,"Signal_d")
end
%%%%%绘图%%%%%
if figureshow==0
    fig=figure(13);
    clf(fig, 'reset');    
    ax=subplot(1,1,1);
    plot(ax,ECG_4_ECG_timeline,ECG1Ldone_filted,'b-');
    title(strcat('Original plotted signal--',ECG_4_file_name));
    hold on
    plot(ax,ECG_4_ECG_timeline(v_Pqrst_T_point_act),ECG1Ldone_filted(v_Pqrst_T_point_act),'ro');
    plot(ax,ECG_4_ECG_timeline(Pqrst_T_point_act),ECG1Ldone_filted(Pqrst_T_point_act),'bo');
    plot(ax,ECG_4_ECG_timeline(pQrst_T_point_act),ECG1Ldone_filted(pQrst_T_point_act),'k*');
    plot(ax,ECG_4_ECG_timeline(pQ_rst_T_point_act),ECG1Ldone_filted(pQ_rst_T_point_act),'y*');
    plot(ax,ECG_4_ECG_timeline(pqRst_T_point_act),ECG1Ldone_filted(pqRst_T_point_act),'c*');
    plot(ax,ECG_4_ECG_timeline(pqrSt_T_point_act),ECG1Ldone_filted(pqrSt_T_point_act),'go');
    plot(ax,ECG_4_ECG_timeline(pqrsT_T_point_act),ECG1Ldone_filted(pqrsT_T_point_act),'ko');
    hold off
end
%%%%%绘图完成%%
if sec_show==1;disp('BPR_3_NIRS_cal_7_ALL_points_list_done');end
app.Text_process_statue_update.Value='BPR_3_NIRS_cal_7_ALL_points_list_done';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%第一章：数据源标准点多重滤波优化确认方法完成%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
l1=numel(pqRst_T_point_act);
l2=mean(ECG1Ldone_filted(pqRst_T_point_act)-ECG1Ldone_filted(pQrst_T_point_act));
l3=std(ECG1Ldone_filted(pqRst_T_point_act)-ECG1Ldone_filted(pQrst_T_point_act));
%%%%%%%%%%1.1找到最大值最小值的所有点位%%%%%%%%
        [~,maxloc__]=findpeaks(ECG1Ldone_filted);
        %[maxvalue,maxloc__]=findpeaksreverse(maxvalue,maxloc__);
        [minvalue,minloc__]=findpeaks(-ECG1Ldone_filted);
        %[minvalue,minloc__]=findpeaksreverse(minvalue,minloc__);
        minvalue=-minvalue;
        if maxloc__(1)<minloc__(1)  %为首低值在前
            maxloc__=maxloc__(2:end);  %高值在后
        elseif maxloc__(end)<minloc__(end)  %为末低值在前
            minloc__=minloc__(1:end-1);  %高值在后，对齐
        end
        if length(maxloc__)>length(minloc__)
            maxloc__=maxloc__(1:length(minloc__));
        elseif length(maxloc__)<length(minloc__)
            minloc__=minloc__(1:length(maxloc__));  %对等化设计完毕             
        end    
        %首先计算最高点qRs的位置并调整到精确的位置上
        %%%%%1.2全波形参数特征分析%%%%%  
        %%%%%%%%%所有的波动的数量，均值，特点统计接着上面的位置继续%%%%%%%%%%%%
            min_max_ascend_dis_ECG_raw=(maxloc__-minloc__);%min在前，数值小；max在后，位置数大
            min_max_ascend_height_ECG_raw=ECG1Ldone_filted(maxloc__)-ECG1Ldone_filted(minloc__);
            if maxloc__(1)>minloc__(1)  %为首高值在前
                minloc__=minloc__(2:end);  %低值在后，对齐
                %maxloc__=maxloc__;
            elseif maxloc__(end)>minloc__(end)  %为末高值在前
                maxloc__=maxloc__(1:end-1);  %低值在后
                %minloc__=minloc__;
            end
            if length(maxloc__)>length(minloc__)
                maxloc__=maxloc__(1:length(minloc__));
            elseif length(maxloc__)<length(minloc__)
                minloc__=minloc__(1:length(maxloc__));               
            end
            max_min_descend_dis_ECG_raw=(maxloc__-minloc__);
            max_min_descend_height_ECG_raw=ECG1Ldone_filted(maxloc__)-ECG1Ldone_filted(minloc__);
            ECG.maxloc_num=numel(maxloc__);
            ECG.maxloc_dis_mean=mean(diff(maxloc__));
            ECG.maxloc_dis_std=std(diff(maxloc__));
            ECG.min_max_ascend_dis_ECG_mean=mean(min_max_ascend_dis_ECG_raw);%18
            ECG.min_max_ascend_dis_ECG_std=std(min_max_ascend_dis_ECG_raw);%19
            ECG.min_max_ascend_dis_ECG_max=max(min_max_ascend_dis_ECG_raw);%20
            ECG.min_max_ascend_dis_ECG_min=min(min_max_ascend_dis_ECG_raw);%21
            ECG.min_max_ascend_height_ECG_mean=mean(min_max_ascend_height_ECG_raw);%22
            ECG.min_max_ascend_height_ECG_std=std(min_max_ascend_height_ECG_raw);%23
            ECG.min_max_ascend_height_ECG_max=max(min_max_ascend_height_ECG_raw);%24
            ECG.min_max_ascend_height_ECG_min=min(min_max_ascend_height_ECG_raw);%25
                         %Q_R_height
            ECG.max_min_descend_dis_ECG_mean=mean(max_min_descend_dis_ECG_raw);%26
            ECG.max_min_descend_dis_ECG_std=std(max_min_descend_dis_ECG_raw);%27
            ECG.max_min_descend_dis_ECG_max=max(max_min_descend_dis_ECG_raw);%28
            ECG.max_min_descend_dis_ECG_min=min(max_min_descend_dis_ECG_raw);%29
            ECG.max_min_descend_height_ECG_mean=mean(max_min_descend_height_ECG_raw);%30
            ECG.max_min_descend_height_ECG_std=std(max_min_descend_height_ECG_raw);%31
            ECG.max_min_descend_height_ECG_max=max(abs(max_min_descend_height_ECG_raw));%32
            ECG.max_min_descend_height_ECG_min=min(abs(max_min_descend_height_ECG_raw));%33
       ECG.num_E_Pqrs_1_lists=numel(Pqrst_T_point_act);
       ECG.num_E_Qrs_2_lists=numel(pQrst_T_point_act);
       ECG.num_E_qRs_3_lists=numel(pqRst_T_point_act);
             ECG.num_E_qrS_4_lists=numel(pqrSt_T_point_act);
       ECG.num_E_qrsT_5_lists=numel(pqrsT_T_point_act);

RRintercrossrate=mean(diff(diff(pqRst_T_point_act)));%1diff是间期；2diff是间期差值，差值均值越大，交错感越强，折返特性越高；
        hrv_difvariance=std(diff(diff(pqRst_T_point_act))); %1diff是间期；2diff是间期差值，差值标准差越大，hrv越高
        
        RRmean_difstd=RRintercrossrate/hrv_difvariance;  %多判评价指标,越低，周期性单值间隔差节律性越强，幅度越大。
        ECG.RRintercrossrate=RRintercrossrate;%34 间期差值均值，差值均值越大，交错感越强，折返特性越高；
        ECG.hrv_difvariance=hrv_difvariance; %35 间期差值标准差，差值标准差越大，hrv越高
        ECG.RRmean_difstd=RRmean_difstd; %36 间期差值
          
data_t_struct.c_PQRST_4={'ECG总起伏个数','ECG总起伏波间距均值','ECG总起伏波间距标准差',...
                   '上升距离均值','上升距离标准差','上升距离最大值','上升距离最小值',...
                   '上升高度均值','上升高度标准差','上升高度最大值','上升高度最小值',...
                   '下降距离均值','下降距离标准差','下降距离最大值','下降距离最小值',...
                   '下降高度均值','下降高度标准差','下降高度最大值','下降高度最小值',...
                   '间隔交错均值（误识别程度）','间隔交错标准差','间隔交错均值/标准差',...
                   'P波数','Q波数','R波数','S波数','T波数',...
                   };

data_struct.c_PQRST_4=[ECG.maxloc_num,ECG.maxloc_dis_mean,ECG.maxloc_dis_std...
            ECG.min_max_ascend_dis_ECG_mean,ECG.min_max_ascend_dis_ECG_std,...
            ECG.min_max_ascend_dis_ECG_max,ECG.min_max_ascend_dis_ECG_min...
            ECG.min_max_ascend_height_ECG_mean,ECG.min_max_ascend_height_ECG_std,...
            ECG.min_max_ascend_height_ECG_max,ECG.min_max_ascend_height_ECG_min...            
            ECG.max_min_descend_dis_ECG_mean,ECG.max_min_descend_dis_ECG_std,...
            ECG.max_min_descend_dis_ECG_max,ECG.max_min_descend_dis_ECG_min...
            ECG.max_min_descend_height_ECG_mean,ECG.max_min_descend_height_ECG_std,...
            ECG.max_min_descend_height_ECG_max,ECG.max_min_descend_height_ECG_min,...
             ECG.RRintercrossrate,ECG.hrv_difvariance,ECG.RRmean_difstd,...
             ECG.num_E_Pqrs_1_lists,ECG.num_E_Qrs_2_lists,ECG.num_E_qRs_3_lists,...
             ECG.num_E_qrS_4_lists,ECG.num_E_qrsT_5_lists
            ];



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%第二章：数据源相关描述性参数提取开发方法开始%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if cut_it==0
[data_struct,data_t_struct,Signal_d]=BPR_3_NIRS_cal_data(Signal_d,ori_sig_struct,mainparameters);
app.Text_process_statue_update.Value='特征分析完成';
if save_data==1
    sig_data_rank_name='sig_data_ori6.mat';
    save(sig_data_rank_name,"ori_sig_struct")
    data_mat_name='data_struct.mat';
    save(data_mat_name,"data_struct","data_t_struct")
    data_mat_name='Signal_d_all.mat';
    save(data_mat_name,"Signal_d");
end
end
%data_struct_all=load('data_struct.mat')
%data_struct=data_struct_all.data_struct;
%data_t_struct=data_struct_all.data_t_struct;
%Signal_d=load('Signal_d.mat');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%第二章：数据源相关描述性参数提取开发方法完成%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%第二章：数据源相关描述性参数提取开发方法完成%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


    if add_the_unnecessory==1        
        pqRst_T_point_act%先是峰值点R求取
        pQrst_T_point_act  %然后是左侧谷底点Q求取
        pQ_rst_T_point_act %然后是左侧谷底点Q与R之间的最大拐点求取
        tool_pQrst_pqRst_height_dis%辅助点，Q_R间高度差。
        tool_pQrst_pqRst_local_dis%辅助点，Q_R间距离差。
        tool_pQrst_pqRst_valleynum;%辅助点，辅助点，Q_R间是否还有波谷数量。    
        tool_pQrst_pqRst_valleyheight;%Q_R间辅助点，Q_R间如果有波谷，波形深度。
        tool_pQrst_pqRst_valleyloc%辅助点，Q_R间如果有波谷，位置bit数。
        tool_pQrst_valley_height;%辅助点，Q_R间如果有波谷，其位置高度值。
        tool_pQrst_valley_pqRst_height_rate;%辅助点，Q_R间如果有波谷，其位置高度在Q_R之间的比率关系。
                pqrSt_T_point_act %然后是右侧谷底点S求取
        tool_pqRst_mid_space
        tool_pqRst_mid_valleynum
    %%%P值相关参数%%%
        v_Pqrst_T_point_act
        Pqrst_T_point_act
        tool_pqrsT_pQrst_space
        tool_pqrsT_pQrst_valleynum
        %最后制作一个整体的识别点相关参数矩阵
        whole_mark_7=cat(2,v_Pqrst_T_point_act,Pqrst_T_point_act,pQrst_T_point_act,...
            pQ_rst_T_point_act,pqRst_T_point_act,pqrSt_T_point_act,pqrsT_T_point_act);
    
        whole_toolrank_7=cat(2,tool_pQrst_pqRst_height_dis,tool_pQrst_pqRst_local_dis,...
            tool_pQrst_valley_height,tool_pQrst_valley_pqRst_height_rate,...
            tool_pqRst_mid_space,tool_pqRst_mid_valleynum,...
            tool_pqrsT_pQrst_space,tool_pqrsT_pQrst_valleynum);    
    end


%%%pqRst_T_point_theory,信号点R的理论最大值（整体势头最大值）评估完成。%%%%%%%%%%
%%%pqRst_T_point_oriact, 信号点R的实际最大值（滤波前的波形最大值）评估完成
%%%pqRst_T_point_act, 信号点R的实际最大值（滤波后的波形最大值）评估完成
%%%%第二板块-信号分析-初始节律的峰值关键点R特征建立完成%%%%%%%%%%

%%%%第三板块-信号分析-初始节律的峰值R关键点前后Q与S实际点位特征建立开始%%%%%%%%%%




















%%%%%%%%%%%%%%%%%%%%%%去掉下面的一些重复的工作
%%%%%%%%%%%%%%顺序排好,个数先不考虑相等，满足基本条件，是onsets(1)在前，peaks(1)在后%%%%%%%%%%%%%%%



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%第一章：数据源输入完成%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%以下开始，优化QRS识别问题，首先克服最低点Q问题。%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%第二章：校正Qrs与qRs之间的匹配性%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%第一节.校正第一个Qrs位置到第一个脉搏波qRs起点的后方%%%%%%%%%%
%要求：qRs与Qrs之间的对应性保证,Qrs起点在前，qRs高点在后


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%关键点识别完成%%%%%%%%%%%%%
%%%%%%%%%%关键点识别完成%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%第二章：校正Qrs与qRs之间的匹配性***完成***%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end