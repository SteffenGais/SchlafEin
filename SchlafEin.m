% SchlafEin.m 
% Simple help for sleep scoring
% 16.09.2021 Steffen Gais
% version 0.947 - initial version for GitHub

function SchlafEin
    global SED
    global SEversion
    SEversion = 0.946;
    horiversion = false;

    SE_update;    
    SE_initialize;
    SED.hori = horiversion;
    ok = false;
    while ~ok
        answer = questdlg('Open BrainVision or SchlafEin?','Select File','.vhdr','.sed','.sed');
        if strcmp(answer,'.vhdr')
            ok = SE_open; 
        else
            [fn, pn] = uigetfile({'*.sed','SchlafEin Data'},'Choose input file');
            if fn
                load(fullfile(pn, fn), 'SEDSAVE', '-MAT');
                SEDSAVE.objects = SED.objects;
                SED = SEDSAVE;
                ok = true;
                if ~isfield(SED, 'version')
                    SED.version = 0.1;
                end
                if SED.version < 0.2
                    SED.display.hiddenchans = zeros(SED.header.commoninfos.numberofchannels,1);
                    SED.display.windowsize = [0.1 0.1 0.8 0.8];
                    SED.display.hypwindowsize = [0.7 0.7 0.2 0.2];
                end
                if SED.version < 0.94
                    SED.hori = horiversion;
                    SED.score.hori = zeros(size(SED.score.stage,1),6);
                    SED.frqs = [0.3 1.2 2 8 12 16];
                end
                if SED.version < 0.942
                    SED.header.isecg = cellfun(@any,strfind([SED.header.channelinfos.labels],'ECG')) | cellfun(@any,strfind([SED.header.channelinfos.labels],'EKG'));
                    SED.header.iseeg = ~(SED.header.isemg | SED.header.iseog | SED.header.isecg);
                end
            end
        end
        if ~ok
            answer = questdlg('No file selected. Do you want to quit?','File Open Error.','Yes','No','No');
            if strcmp(answer, 'Yes')
                SE_close;
                return;
            end
        end
    end
    SE_create_window;
    SE_plot;
end

function SE_plot
    global SED
    plotcolor = SED.objects.axes(1).XColor;
    chns = find(~SED.display.hiddenchans);
    nch = length(chns);
    pos = round((SED.display.position * SED.header.commoninfos.samplingrate))+1;
    page = floor(SED.display.position/SED.display.epochlength)+1;
    len = round(SED.display.epochlength * SED.header.commoninfos.samplingrate);
    maxpage = floor(SED.header.commoninfos.datapoints/len);
    x = SED.display.position:SED.display.epochlength/len:SED.display.position+SED.display.epochlength;
    st = SED.header.commoninfos.starttime+SED.display.position/(24*60*60);
    horipos = x(1) + (2.5:5:27.5);
    
    for ch = 1:nch
%       mi = min(SED.data(chns(ch),pos:pos+len-1));     % this is useful if plots are not mean-centered
%       ma = max(SED.data(chns(ch),pos:pos+len-1));
%       if mi<-SED.display.ranges(chns(ch)) || ma>SED.display.ranges(chns(ch))
%           YLim = [mi ma];
%       else
%           YLim =  [-SED.display.ranges(chns(ch)) SED.display.ranges(chns(ch))];
%       end
        YLim =  [-SED.display.ranges(chns(ch)) SED.display.ranges(chns(ch))];
    
        hold(SED.objects.axes(ch), 'off');
        if SED.header.iseeg(chns(ch))
            [spec, t] = SE_calc_CWT(double(SED.data(chns(ch),pos:pos+len-1)),SED.header.commoninfos.samplingrate);
            imagesc(SED.objects.axes(ch), t+x(1), YLim(1)+(YLim(2)-YLim(1))/12:(YLim(2)-YLim(1))/6:YLim(2), spec, 'AlphaData', 0.5);
            hold(SED.objects.axes(ch), 'on');
            a = axis(SED.objects.axes(ch));
            axis(SED.objects.axes(ch),[x(1),x(end-1),a(3),a(4)]);
        end
        plot(SED.objects.axes(ch), x(1:end-1), SED.data(chns(ch),pos:pos+len-1)-mean(SED.data(chns(ch),pos:pos+len-1)), 'k');

        SED.objects.axes(ch).YLim = YLim;
%       if mi<-SED.display.ranges(chns(ch)) || ma>SED.display.ranges(chns(ch))
%           SED.objects.axes(ch).YColor = 'r';
%       else
%           SED.objects.axes(ch).YColor = plotcolor;
%       end
        SED.objects.axes(ch).Box = 'off';
        SED.objects.axes(ch).GridColorMode = 'manual';
        SED.objects.axes(ch).GridColor = [0 0 0];
        SED.objects.axes(ch).XGrid = 'on';
        SED.objects.axes(ch).YDir = 'normal';

        SED.objects.axes(ch).MinorGridColorMode = 'manual';
        SED.objects.axes(ch).MinorGridColor = plotcolor;
        SED.objects.axes(ch).XAxis.MinorTickValues = x(1):0.5:x(end-1);
        SED.objects.axes(ch).XMinorTick = 'off';
        SED.objects.axes(ch).XMinorGrid = 'on';
        SED.objects.axes(ch).MinorGridColor = [0 0 0];
        SED.objects.axes(ch).XAxis.Visible = 'off';
        SED.objects.axes(ch).YAxis.Label.String = SED.header.channelinfos(chns(ch)).labels{1};
        SED.objects.axes(ch).FontUnits = 'normalized';
        SED.objects.axes(ch).FontSize = 0.025/SED.objects.axes(ch).Position(4);
        if ch==1
            for i=1:6
                if SED.score.hori(page,i)
                    text(SED.objects.axes(ch), horipos(i), 0, -1, ['H' num2str(SED.score.hori(page,i))],'Color',[0.5 0.5 0.5],'FontUnits','normalized','FontSize',0.5,'HorizontalAlignment','center');
                end
            end
        end
        if SED.header.iseeg(chns(ch))
            frqb = {'SO','delta','theta','alpha','spindle'};
            y = double(YLim(1)+(YLim(2)-YLim(1))/10:(YLim(2)-YLim(1))/5:YLim(2));
            for i=1:5
                t = text(SED.objects.axes(ch), x(end)+0.1, y(i), frqb{i});
%               text(SED.objects.axes(ch), x(end)+0.1, y(i), [num2str(SED.frqs(i)) '-' num2str(SED.frqs(i+1))]);
                t.FontUnits = 'normalized';
                t.FontSize = 0.125;
            end
        end
    end
    SED.objects.axes(ch).XAxis.Visible = 'on';
    SED.objects.axes(ch).XAxis.Label.String = 'Time [s]';
    SED.objects.axes(ch).XTickLabel = x(1):5:x(end);
    SED.objects.axes(ch).TickLength = [0.001 0];
    
    if ~isfield(SED.objects, 'time') || isempty(SED.objects.time) || ~isvalid(SED.objects.time)
        SED.objects.time = annotation(SED.objects.window, 'textbox', [0.12 0 0.1 0.1], ... 
            'String', datestr(st, 'HH:MM:SS'), ...
            'FontUnits', 'normalized', 'FontSize', 0.025, 'EdgeColor', 'none', 'FitBoxToText','on');
        SED.objects.time.Position = [0.075 0 0.1 0.1];
    else
        SED.objects.time.String = datestr(st, 'HH:MM:SS');
    end
    
    if ~isfield(SED.objects, 'page') || isempty(SED.objects.page) || ~isvalid(SED.objects.page)
        SED.objects.page = annotation(SED.objects.window, 'textbox', [0.12 0 0.1 0.1], ... 
            'String', [num2str(page) '/' num2str(maxpage)], ...
            'FontUnits', 'normalized', 'FontSize', 0.025, 'EdgeColor', 'none', 'FitBoxToText','on');
        SED.objects.page.Position = [0.88 0 0.1 0.1];
    else
        SED.objects.page.String = [num2str(page) '/' num2str(maxpage)];
    end
    
    for i=1:length(SED.objects.freebuttons)
        SED.objects.freebuttons(i).Value = 0;
    end
    if SED.score.stage(page)
        SED.objects.freebuttons(SED.score.stage(page)).Value = 1;
    end
    if SED.score.movement(page)==1
        SED.objects.freebuttons(7).Value = 1;
    end
    SE_hypnogram;
end

function SE_hypnogram
    global SED

    if ~SED.display.hypnogram
        return
    end

    if ~isfield(SED.objects, 'hypnowindow') || isempty(SED.objects.hypnowindow) || ~isvalid(SED.objects.hypnowindow)
        len = round(SED.display.epochlength * SED.header.commoninfos.samplingrate);
        maxpage = floor(SED.header.commoninfos.datapoints/len);
        SED.objects.hypnowindow = figure;
        set(SED.objects.hypnowindow, 'NumberTitle','off');
        set(SED.objects.hypnowindow, 'Name','SchlafEin Hypnogram');
        set(SED.objects.hypnowindow, 'Units', 'normalized', 'OuterPosition', SED.display.hypwindowsize);
        SED.objects.hypnoaxes = gobjects(2,1);
        SED.objects.hypnoaxes(1) = axes('Units','normalized', 'Position',[0.1 0.20 0.85 0.75]);
        SED.objects.hypnoaxes(2) = axes('Units','normalized', 'Position',[0.1 0.05 0.85 0.10]);
        SED.objects.hypnoaxes(1).FontUnits = 'normalized';
        SED.objects.hypnoaxes(1).FontSize = 0.075;
        SED.objects.hypnoaxes(2).FontUnits = 'normalized';
        SED.objects.hypnoaxes(2).FontSize = 0.35;
        SED.objects.hypnowindow.MenuBar = 'none';
        SED.objects.hypnowindow.ToolBar = 'none';
        SED.objects.hypnowindow.WindowKeyPressFcn = @SE_keypress;
        SED.objects.hypnowindow.WindowButtonDownFcn = @SE_hypclick;

        set(SED.objects.hypnowindow,'CloseRequestFcn','global SED; set(SED.objects.hypnowindow,"Visible","off"); SED.display.hypnogram = 0;');

        SED.objects.hypnoaxes(1).XAxis.Visible = 'off';
        SED.objects.hypnoaxes(1).Box = 'off';
        SED.objects.hypnoaxes(1).TickLength = [0 0];
        SED.objects.hypnoaxes(1).XLim = [1 maxpage];
        SED.objects.hypnoaxes(1).YLim = [0.5 5.5];
        SED.objects.hypnoaxes(1).YDir = 'reverse';
        SED.objects.hypnoaxes(1).YTick = [1 1.5 2 3 4 5];
        SED.objects.hypnoaxes(1).YTickLabel = {'W' 'REM' 'S1' 'S2' 'S3' 'S4'};

        SED.objects.hypnoaxes(2).Box = 'off';
        SED.objects.hypnoaxes(2).XLim = [1 maxpage];
        SED.objects.hypnoaxes(2).YLim = [0 2];
        SED.objects.hypnoaxes(2).TickLength = [0 0];
        SED.objects.hypnoaxes(2).YTick = [0.5 1.5];
        SED.objects.hypnoaxes(2).YTickLabel = {'MA' 'MT'};
        pause(0.2);
        SED.objects.hypnoaxes(1).YRuler.Axle.Visible = 'off';
        SED.objects.hypnoaxes(2).YRuler.Axle.Visible = 'off';
    else
        figure(SED.objects.hypnowindow);
    end
    warning('off', 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
    warning('off','MATLAB:ui:javaframe:PropertyToBeRemoved');
    jFrame = get(SED.objects.hypnowindow,'JavaFrame');
    jFrame.fHG2Client.getWindow.setAlwaysOnTop(true);

    cla(SED.objects.hypnoaxes(1));
    cla(SED.objects.hypnoaxes(2));
    plotcolor = SED.objects.hypnoaxes(2).XColor;
    stages = SED.score.stage;
    moves = SED.score.movement;
    if (stages(1)==8)
        stages(1) = 0;
    end
    stages(stages==6)=1.5;
    m = find(stages==8);
    while ~isempty(m)
        stages(m) = stages(m-1);
        m = find(stages==8);
    end

    line(SED.objects.hypnoaxes(1), [SED.display.position/SED.display.epochlength, SED.display.position/SED.display.epochlength], [0.5, 5.5], 'Color', [0.7 0.7 0.7]);
    s = find(stages(2:end) ~= stages(1:end-1));
    ox = 1;
    oy = stages(ox);
    for i=1:length(s)
        nx = s(i)+0.5;
        ny = stages(s(i)+1);
        if oy
            line(SED.objects.hypnoaxes(1), [ox nx], [oy oy], 'Color', plotcolor);
            if ny
                line(SED.objects.hypnoaxes(1), [nx nx], [oy ny], 'Color', plotcolor);
            end
        else
            if ny
                line(SED.objects.hypnoaxes(1), [nx nx], [ny ny], 'Color', plotcolor);
            end
        end
        ox = nx;
        oy = ny;
    end
    
    r = (stages==1.5);
    s = find(r(2:end)>r(1:end-1));
    if r(1)
        s = [1; s];
    end
    e = find(r(2:end)<r(1:end-1));
    if r(end)
        e = [e; length(r)];
    end
    e = e-s;
    for i=1:length(s)
        rectangle(SED.objects.hypnoaxes(1), 'Position',[s(i)+0.5 1.25 e(i) 0.5], 'EdgeColor', plotcolor, 'FaceColor', plotcolor);
    end
    
    x = repmat(find(moves),1,2);
    y = [zeros(sum(moves>0),1) moves(moves>0)];
    for i=1:size(x,1)
        line(SED.objects.hypnoaxes(2), x(i,:), y(i,:), 'Color', plotcolor);
    end
end

function SE_create_window
    global SED

    if ~isfield(SED.objects, 'window') || isempty(SED.objects.window) || ~isvalid(SED.objects.window)
        SED.objects.window = figure;
        set(SED.objects.window, 'NumberTitle','off');
        set(SED.objects.window, 'Name','SchlafEin');
        set(SED.objects.window, 'Units', 'normalized', 'OuterPosition', SED.display.windowsize);
        set(SED.objects.window,'CloseRequestFcn',@SE_close);
    else
        figure(SED.objects.window);
        return;
    end
    set(SED.objects.window,'Name',SED.filename);
    SED.objects.window.WindowKeyPressFcn = @SE_keypress;
    SED.objects.window.Pointer = 'crosshair';
    SED.objects.window.Units = 'normalized';
    SED.objects.window.MenuBar = 'none';
    SED.objects.window.ToolBar = 'none';

    nch = SED.header.commoninfos.numberofchannels;
    SED.objects.axes = gobjects(nch,1);
    SED.objects.selbuttons = gobjects(nch,1);
    height = 0.8/nch;
    for ch = 1:nch
        SED.objects.axes(ch) = axes('Units','normalized', 'Position',[0.075 1-(0.07+(ch*height)) 0.9 height-height/10]);
        SED.objects.selbuttons(ch) = uicontrol('Style','checkbox', 'Value', 1, ... 
            'Units','normalized', 'Position',[0 1-(0.10+(ch-1)*height) 0.025 0.035]);
    end

    SED.objects.freebuttons = gobjects([8,1]);
    SED.objects.freebuttons(1) = uicontrol('Style','togglebutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','W', ... 
        'Units','normalized', 'Position',[0.01 0.95 0.05 0.05]);
    SED.objects.freebuttons(1).Callback = @SE_buttonpush;
    SED.objects.freebuttons(2) = uicontrol('Style','togglebutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','1', ... 
        'Units','normalized', 'Position',[0.07 0.95 0.05 0.05]);
    SED.objects.freebuttons(2).Callback = @SE_buttonpush;
    SED.objects.freebuttons(3) = uicontrol('Style','togglebutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','2', ... 
        'Units','normalized', 'Position',[0.13 0.95 0.05 0.05]);
    SED.objects.freebuttons(3).Callback = @SE_buttonpush;
    SED.objects.freebuttons(4) = uicontrol('Style','togglebutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','3', ... 
        'Units','normalized', 'Position',[0.19 0.95 0.05 0.05]);
    SED.objects.freebuttons(4).Callback = @SE_buttonpush;
    SED.objects.freebuttons(5) = uicontrol('Style','togglebutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','4', ... 
        'Units','normalized', 'Position',[0.25 0.95 0.05 0.05]);
    SED.objects.freebuttons(5).Callback = @SE_buttonpush;    
    SED.objects.freebuttons(6) = uicontrol('Style','togglebutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','R', ... 
        'Units','normalized', 'Position',[0.31 0.95 0.05 0.05]);
    SED.objects.freebuttons(6).Callback = @SE_buttonpush;    
    SED.objects.freebuttons(7) = uicontrol('Style','togglebutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','MA', ... 
        'Units','normalized', 'Position',[0.47 0.95 0.05 0.05]);
    SED.objects.freebuttons(7).Callback = @SE_buttonpush;    
    SED.objects.freebuttons(8) = uicontrol('Style','togglebutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','MT', ... 
        'Units','normalized', 'Position',[0.37 0.95 0.05 0.05]);
    SED.objects.freebuttons(8).Callback = @SE_buttonpush;    

    if SED.hori
        SED.objects.hoributtons = gobjects([10,1]);
        SED.objects.hoributtons(1) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','H1', ... 
            'Units','normalized', 'Position',[0.01 0.9225 0.05 0.025]);
        SED.objects.hoributtons(1).Callback = @SE_buttonpush;
        SED.objects.hoributtons(2) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','H2', ... 
            'Units','normalized', 'Position',[0.07 0.9225 0.05 0.025]);
        SED.objects.hoributtons(2).Callback = @SE_buttonpush;
        SED.objects.hoributtons(3) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','H3', ... 
            'Units','normalized', 'Position',[0.13 0.9225 0.05 0.025]);
        SED.objects.hoributtons(3).Callback = @SE_buttonpush;
        SED.objects.hoributtons(4) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','H4', ... 
            'Units','normalized', 'Position',[0.19 0.9225 0.05 0.025]);
        SED.objects.hoributtons(4).Callback = @SE_buttonpush;
        SED.objects.hoributtons(5) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','H5', ... 
            'Units','normalized', 'Position',[0.25 0.9225 0.05 0.025]);
        SED.objects.hoributtons(5).Callback = @SE_buttonpush;    
        SED.objects.hoributtons(6) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','H6', ... 
            'Units','normalized', 'Position',[0.31 0.9225 0.05 0.025]);
        SED.objects.hoributtons(6).Callback = @SE_buttonpush;    
        SED.objects.hoributtons(7) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','H7', ... 
            'Units','normalized', 'Position',[0.37 0.9225 0.05 0.025]);
        SED.objects.hoributtons(7).Callback = @SE_buttonpush;    
        SED.objects.hoributtons(8) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','H8', ... 
            'Units','normalized', 'Position',[0.43 0.9225 0.05 0.025]);
        SED.objects.hoributtons(8).Callback = @SE_buttonpush;    
        SED.objects.hoributtons(9) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','H9', ... 
            'Units','normalized', 'Position',[0.49 0.9225 0.05 0.025]);
        SED.objects.hoributtons(9).Callback = @SE_buttonpush;    
        SED.objects.hoributtons(10) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','H0', ... 
            'Units','normalized', 'Position',[0.59 0.9225 0.05 0.025]);
        SED.objects.hoributtons(10).Callback = @SE_buttonpush;    
    end
    
    SED.objects.ctrlbuttons = gobjects([2,1]);
    SED.objects.ctrlbuttons(1) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','<<', 'TooltipString', 'Previous Page', ... 
        'Units','normalized', 'Position',[0.88 0 0.05 0.05]);
    SED.objects.ctrlbuttons(1).Callback = @SE_ctrlbuttonpush;    
    SED.objects.ctrlbuttons(2) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','>>', 'TooltipString', 'Next Page', ... 
        'Units','normalized', 'Position',[0.94 0 0.05 0.05]);
    SED.objects.ctrlbuttons(2).Callback = @SE_ctrlbuttonpush;    
    SED.objects.ctrlbuttons(3) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','HY', 'TooltipString', 'Hypnogram', ... 
        'Units','normalized', 'Position',[0.94 0.95 0.05 0.05]);
    SED.objects.ctrlbuttons(3).Callback = @SE_ctrlbuttonpush;    
    SED.objects.ctrlbuttons(4) = uicontrol('Style','togglebutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','L', 'TooltipString', 'Toggle 75µV Line', ... 
        'Units','normalized', 'Position',[0.88 0.95 0.05 0.05]);
    SED.objects.ctrlbuttons(4).Callback = @SE_ctrlbuttonpush;    
    SED.objects.ctrlbuttons(5) = uicontrol('Style','togglebutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','Z', 'TooltipString', 'Toggle Zoom', ... 
        'Units','normalized', 'Position',[0.82 0.95 0.05 0.05]);
    SED.objects.ctrlbuttons(5).Callback = @SE_ctrlbuttonpush;
    SED.objects.ctrlbuttons(6) = uicontrol('Style','togglebutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','C', 'TooltipString', 'Toggle Count', ... 
        'Units','normalized', 'Position',[0.76 0.95 0.05 0.05]);
    SED.objects.ctrlbuttons(6).Callback = @SE_ctrlbuttonpush;    
    SED.objects.ctrlbuttons(7) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','+', 'TooltipString', 'Increase Channels', ... 
        'Units','normalized', 'Position',[0.76 0 0.05 0.05]);
    SED.objects.ctrlbuttons(7).Callback = @SE_ctrlbuttonpush;    
    SED.objects.ctrlbuttons(8) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','-', 'TooltipString', 'Decrease Channels', ... 
        'Units','normalized', 'Position',[0.82 0 0.05 0.05]);
    SED.objects.ctrlbuttons(8).Callback = @SE_ctrlbuttonpush;    
    SED.objects.ctrlbuttons(9) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','O', 'TooltipString', 'Open File', ... 
        'Units','normalized', 'Position',[0.07 0 0.05 0.05]);
    SED.objects.ctrlbuttons(9).Callback = @SE_ctrlbuttonpush;    
    SED.objects.ctrlbuttons(10) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','S', 'TooltipString', 'Save File', ... 
        'Units','normalized', 'Position',[0.13 0 0.05 0.05]);
    SED.objects.ctrlbuttons(10).Callback = @SE_ctrlbuttonpush;    
    SED.objects.ctrlbuttons(11) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','I', 'TooltipString', 'Import Stages', ... 
        'Units','normalized', 'Position',[0.19 0 0.05 0.05]);
    SED.objects.ctrlbuttons(11).Callback = @SE_ctrlbuttonpush;    
    SED.objects.ctrlbuttons(12) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','E', 'TooltipString', 'Export Stages', ... 
        'Units','normalized', 'Position',[0.25 0 0.05 0.05]);
    SED.objects.ctrlbuttons(12).Callback = @SE_ctrlbuttonpush;    
    SED.objects.ctrlbuttons(13) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','H', 'TooltipString', 'Hide Channels', ... 
        'Units','normalized', 'Position',[0.35 0 0.05 0.05]);
    SED.objects.ctrlbuttons(13).Callback = @SE_ctrlbuttonpush;
    SED.objects.ctrlbuttons(14) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','U', 'TooltipString', 'Unhide Channels', ... 
        'Units','normalized', 'Position',[0.41 0 0.05 0.05]);
    SED.objects.ctrlbuttons(14).Callback = @SE_ctrlbuttonpush;
    SED.objects.ctrlbuttons(15) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','N', 'TooltipString', 'New File', ... 
        'Units','normalized', 'Position',[0.01 0 0.05 0.05]);
    SED.objects.ctrlbuttons(15).Callback = @SE_ctrlbuttonpush;    
    SED.objects.ctrlbuttons(16) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','RE', 'TooltipString', 'Results', ... 
        'Units','normalized', 'Position',[0.51 0 0.05 0.05]);
    SED.objects.ctrlbuttons(16).Callback = @SE_ctrlbuttonpush;    
    SED.objects.ctrlbuttons(17) = uicontrol('Style','pushbutton', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String','FB', 'TooltipString', 'Set Frequency Bands', ... 
        'Units','normalized', 'Position',[0.57 0 0.05 0.05]);
    SED.objects.ctrlbuttons(17).Callback = @SE_find_spectral_bands;    
end

function SE_buttonpush(src,~)
    global SED
    persistent horicounter
    if isempty(horicounter)
        horicounter = 1;
    end
    
    SED.unsaved = true;
    page = floor(SED.display.position/SED.display.epochlength)+1;

    if strcmp(src.String,'MA')
        if SED.score.movement(page) == 1
            SED.score.movement(page) = 0;
        else
            SED.score.movement(page) = 1;
            if SED.score.stage(page) == 8
                SED.objects.freebuttons(8).Value = 0;
                SED.score.stage(page) = 0;
            end
        end
        src.Value = SED.score.movement(page);
        SE_hypnogram;
    elseif src.String(1) == 'H'
        h = [];
        switch src.String
            case 'H1'
                h=1;
            case 'H2'
                h=2;
            case 'H3'
                h=3;
            case 'H4'
                h=4;
            case 'H5'
                h=5;
            case 'H6'
                h=6;
            case 'H7'
                h=7;
            case 'H8'
                h=8;
            case 'H9'
                h=9;
            case 'H0'
                h=0;
        end
        SED.score.hori(page,horicounter) = h;
        horicounter = mod(horicounter,6)+1;
        SE_plot;
    else
        switch src.String
            case 'W'
                r = 1;
            case '1'
                r = 2;
            case '2'
                r = 3;
            case '3'
                r = 4;
            case '4'
                r = 5;
            case 'R'
                r = 6;
            case 'MT'
                r = 8;
        end
        if SED.score.stage(page)
            SED.objects.freebuttons(SED.score.stage(page)).Value = 0;
        end
        if SED.score.stage(page) == r
            SED.score.stage(page) = 0;
            if r==8
                SED.score.movement(page) = 0;
            end
        else
            SED.score.stage(page) = r;
            SED.objects.freebuttons(r).Value = 1;
            if r==8
                SED.score.movement(page) = 2;
                SED.objects.freebuttons(7).Value = 0;
            end
            
            if ~SED.score.stage(page+1)
                SE_ctrlbuttonpush(SED.objects.ctrlbuttons(2),0);
            end
        end
        SE_hypnogram;
    end
end

function SE_ctrlbuttonpush(src,~)
    global SED
    switch src.String
        case '<<'
            SED.display.position = SED.display.position - SED.display.epochlength;
            if SED.display.position < 0
                SED.display.position = 0;
            end
            SED.objects.countperc = 0;
            for i=1:length(SED.objects.countlines)
                delete(SED.objects.countlines(i));
            end
            SED.objects.countlines = gobjects(0,0);
            if ~isempty(SED.objects.countannot)
                SED.objects.countannot.String = sprintf('%3.1f%%',SED.objects.countperc);
            end
            SE_plot;
        case '>>'
            if (SED.display.position+2*SED.display.epochlength) < floor(SED.header.commoninfos.datapoints/SED.header.commoninfos.samplingrate)
                SED.display.position = SED.display.position + SED.display.epochlength;
            end
            SED.objects.countperc = 0;
            for i=1:length(SED.objects.countlines)
                delete(SED.objects.countlines(i));
            end
            SED.objects.countlines = gobjects(0,0);
            if ~isempty(SED.objects.countannot)
                SED.objects.countannot.String = sprintf('%3.1f%%',SED.objects.countperc);
            end
            SE_plot;
        case '+'
            chns = find(~SED.display.hiddenchans);
            chns = chns(logical([SED.objects.selbuttons.Value]));
            if all((SED.display.ranges(chns) - SED.display.ranges(chns)./10) > 0)
                SED.display.ranges(chns) = SED.display.ranges(chns) - SED.display.ranges(chns)./10;
                SE_plot;
            end
        case '-'
            chns = find(~SED.display.hiddenchans);
            chns = chns(logical([SED.objects.selbuttons.Value]));
            SED.display.ranges(chns) = SED.display.ranges(chns) + SED.display.ranges(chns)./10;
            SE_plot;
        case 'HY'
            SED.display.hypnogram = 1;
            SE_hypnogram;
        case 'L'
            if SED.objects.ctrlbuttons(4).Value
                SED.objects.window.WindowButtonMotionFcn = @SE_mousemoveline;
                SED.objects.ctrlbuttons(5).Value = 0;
                SE_ctrlbuttonpush(SED.objects.ctrlbuttons(5));
            else
                if (SED.objects.ctrlbuttons(6).Value == 0) && strcmp(func2str(SED.objects.window.WindowButtonMotionFcn), func2str(@SE_mousemoveline))
                    SED.objects.window.WindowButtonMotionFcn = [];
                end
                if isfield(SED.objects, 'lines') && ~isempty(SED.objects.lines) && isgraphics(SED.objects.lines(1))
                    delete(SED.objects.lines(1));
                    delete(SED.objects.lines(2));
                end
            end
        case 'Z'
            if SED.objects.ctrlbuttons(5).Value
                SED.objects.window.WindowButtonMotionFcn = @SE_mousemovezoom;
                SED.objects.window.Pointer = 'custom';
                SED.objects.window.PointerShapeCData = NaN(16,16);
                SED.objects.ctrlbuttons(4).Value = 0;
                SE_ctrlbuttonpush(SED.objects.ctrlbuttons(4));
                SED.objects.ctrlbuttons(6).Value = 0;
                SE_ctrlbuttonpush(SED.objects.ctrlbuttons(6));
            else
                if strcmp(func2str(SED.objects.window.WindowButtonMotionFcn), func2str(@SE_mousemovezoom))
                    SED.objects.window.WindowButtonMotionFcn = [];
                end
                SED.objects.window.Pointer = 'crosshair';
                if isfield(SED.objects, 'zoomaxes') && ~isempty(SED.objects.zoomaxes) && isvalid(SED.objects.zoomaxes)
                    delete(SED.objects.zoomaxes);
                end
            end
        case 'C'
            if SED.objects.ctrlbuttons(6).Value
                SED.objects.window.WindowButtonMotionFcn = @SE_mousemoveline;
                SED.objects.window.WindowButtonDownFcn = @SE_linebuttondown;
                SED.objects.countannot = uicontrol(SED.objects.window, 'Style', 'text', 'FontUnits', 'normalized', 'FontSize', 0.5, 'String', '0%', ... 
                    'Units', 'normalized', 'Position', [0.6 0.94 .1 .05], 'ForegroundColor', [1 0 0]);

                SED.objects.ctrlbuttons(5).Value = 0;
                SE_ctrlbuttonpush(SED.objects.ctrlbuttons(5));
            else
                if (SED.objects.ctrlbuttons(4).Value == 0) && strcmp(func2str(SED.objects.window.WindowButtonMotionFcn), func2str(@SE_mousemoveline))
                    SED.objects.window.WindowButtonMotionFcn = [];
                end
                SED.objects.window.WindowButtonDownFcn = [];
                SED.objects.window.WindowButtonUpFcn = [];
                SED.objects.countpushed = 0;
                SED.objects.countperc = 0;
                for i=1:length(SED.objects.countlines)
                    delete(SED.objects.countlines(i));
                end
                SED.objects.countlines = gobjects(0,0);
                delete(SED.objects.countannot);
                SED.objects.countannot = [];
            end
        case 'N'
            if SED.unsaved
                answer = questdlg('Do you really want to quit?','Unsaved data.','Yes','No','No');
                if ~strcmp(answer, 'Yes')
                    return;
                end
            end
            SchlafEin;
        case 'O'
            [fn, pn] = uigetfile({'*.sed','SchlafEin Data'},'Choose input file');
            if ~fn
                return;
            end
            
            load(fullfile(pn, fn), 'SEDSAVE', '-MAT');
            SEDSAVE.objects = SED.objects;
            SED = SEDSAVE;
            SE_refreshax;
            SE_plot;
        case 'S'
            [fn, pn] = uiputfile({'*.sed','SchlafEin Data'},'Choose output file');
            if ~fn
                return
            end
            SED.unsaved = false;
            if isfield(SED.objects, 'hypnowindow') && ~isempty(SED.objects.hypnowindow) && isvalid(SED.objects.hypnowindow)
                SED.display.hypwindowsize = SED.objects.hypnowindow.OuterPosition;
            end
            SED.display.windowsize = SED.objects.window.OuterPosition;
            SEDSAVE = rmfield(SED, 'objects');
            save(fullfile(pn, fn), 'SEDSAVE', '-MAT');
        case 'I'
            [fn, pn] = uigetfile({'*.txt','SchlafEin Text Import'},'Select a File');
            if ~fn
                return;
            end
            [importfile, msg] = fopen(fullfile(pn, fn),'r');
            if importfile == -1
                errordlg(msg,'File Open Error');
                return;
            end
            t = fgetl(importfile);
            frewind(importfile);
            if sum(uint8(t)>=48) > 2
                s = fscanf(importfile, '%d\t%d\t\t%d\t%d\t%d\t%d\t%d\t%d\r\n', [8 Inf])';
            else
                s = fscanf(importfile, '%d\t%d\r\n', [2 Inf])';
            end
            len = size(s,1);
            if len ~= length(SED.score.stage)
                if len == length(SED.score.stage)-1
                    warndlg('File length one page too short','File Import Warning');
                else
                    errordlg('File length incorrect','File Import Error');
                    return;
                end
            end
            s(s(:,1)>=-1 & s(:,1)<=5,1) = s(s(:,1)>=-1 & s(:,1)<=5,1)+1;
            fclose(importfile);

            SED.score.stage(1:len) = s(:,1);
            SED.score.movement(1:len) = s(:,2);
            SED.score.hori(1:len,:) = s(:,3:8);
            if ~all((SED.score.movement==2) == (SED.score.stage==8))
                error('File format error: Movement Times not in identical places');
            end
            SE_hypnogram;
        case 'E'
            dt = strfind(SED.filename,'.');
            [fn, pn] = uiputfile({'*.txt','SchlafEin Text Export'},'Choose a filename',[SED.filename(1:dt(end)-1) '-export.txt']);
            if ~fn
                return;
            end
            [exportfile, msg] = fopen(fullfile(pn, fn),'w');
            if exportfile == -1
                errordlg(msg,'File Open Error');
                return;
            end
            stages = SED.score.stage;
            moves = SED.score.movement;
            stages(stages>=0 & stages<=6) = stages(stages>=0 & stages<=6)-1;
            fprintf(exportfile, '%1d\t%1d\t\t%1d\t%1d\t%1d\t%1d\t%1d\t%1d\r\n',[stages, moves, SED.score.hori(:,1:6)]');
            %fprintf('%1d\t%1d\n',[stages, moves]');
            fclose(exportfile);
        case 'H'
            chns = find(~SED.display.hiddenchans);
            chns = chns(~logical([SED.objects.selbuttons.Value]));
            SED.display.hiddenchans(chns) = true;
            SE_refreshax;
            SE_plot;
            uicontrol(SED.objects.selbuttons(1));
        case 'U'
            SED.display.hiddenchans(:) = false;
            SE_refreshax;
            SE_plot;
            uicontrol(SED.objects.selbuttons(1));
        case 'RE'
            dt = strfind(SED.filename,'.');
            
            stages = SED.score.stage;

            sonset = find(stages>=3 & stages<=6,1,'first');
            if isempty(sonset)
                fprintf('Warning: No sleep in this file.\r\n');
                return;
            end
            
            while(sonset>1 && stages(sonset-1)>=2 && stages(sonset-1)<=6)
                sonset = sonset-1;
            end
            
            soffset = find(stages>=2 & stages<=6,1,'last');
            sdur = (soffset-sonset+1)/2;
            
            ts1 = sum(stages(sonset:soffset)==2)/2;
            tts1 = sum(stages==2)/2;
            ts2 = sum(stages==3)/2;
            ts3 = sum(stages==4)/2;
            ts4 = sum(stages==5)/2;
            trem = sum(stages==6)/2;
            tsws = ts3+ts4;
            tmt = sum(stages(sonset:soffset)==8)/2;
            twaso = sum(stages(sonset:soffset)==1)/2;
            tst = ts1+ts2+tsws+trem;
            swslat = find(stages==4 | stages==5,1,'first');
            if ~isempty(swslat)
                swslat = (swslat-sonset)/2;
            end
            remlat = find(stages==6,1,'first');
            if ~isempty(remlat)
                remlat = (remlat-sonset)/2;
            end
            ps1 = ts1/sdur*100;
            ps2 = ts2/sdur*100;
            ps3 = ts3/sdur*100;
            ps4 = ts4/sdur*100;
            prem = trem/sdur*100;
            psws = tsws/sdur*100;
            pmt = tmt/sdur*100;
            pwaso = twaso/sdur*100;
            sonset = (sonset-1)/2;
            soffset = soffset/2;
 
            [fn, pn] = uiputfile({'*.txt','SchlafEin Results Text Output'},'Choose a filename',[SED.filename(1:dt(end)-1) '-results.txt']);
            if fn
                [resfile, msg] = fopen(fullfile(pn, fn),'w');
                if resfile == -1
                    errordlg(msg,'File Open Error');
                else
                    fprintf(resfile,'Filename: %s\r\n\r\n',SED.filename);
                    fprintf(resfile,'Times from sleep onset:\r\n');
                    fprintf(resfile,'WASO: \t%4.1f min\t\t%4.1f%%\r\n', twaso, pwaso);
                    fprintf(resfile,'S1: \t%4.1f min\t\t%4.1f%%\r\n', ts1, ps1);
                    fprintf(resfile,'S2: \t%4.1f min\t\t%4.1f%%\r\n', ts2, ps2);
                    fprintf(resfile,'S3: \t%4.1f min\t\t%4.1f%%\r\n', ts3, ps3);
                    fprintf(resfile,'S4: \t%4.1f min\t\t%4.1f%%\r\n', ts4, ps4);
                    fprintf(resfile,'SWS: \t%4.1f min\t\t%4.1f%%\r\n', tsws, psws);
                    fprintf(resfile,'REM: \t%4.1f min\t\t%4.1f%%\r\n', trem, prem);
                    fprintf(resfile,'MT: \t%4.1f min\t\t%4.1f%%\r\n\r\n', tmt, pmt);
                    fprintf(resfile,'Total S1: %4.1f min\r\n\r\n', tts1);
                    fprintf(resfile,'Sleep onset latency (first S1 followed by S2): \t%4.1f min\r\n',sonset);
                    fprintf(resfile,'Total Sleep Time (all sleep stages): \t\t%4.1f min\r\n',tst);
                    fprintf(resfile,'Sleep duration (onset to offset): \t\t%4.1f min\r\n',sdur);
                    fprintf(resfile,'SWS onset latency (sleep onset to SWS): \t');
                    if ~isempty(swslat)
                        fprintf(resfile,'%4.1f min\r\n',swslat);
                    else
                        fprintf(resfile,'none\r\n');
                    end
                    fprintf(resfile,'REM onset latency (sleep onset to REM): \t');
                    if ~isempty(remlat)
                        fprintf(resfile,'%4.1f min\r\n',remlat);
                    else
                        fprintf(resfile,'none\r\n');
                    end
                    fclose(resfile);
                end
            end
            [fn, pn] = uiputfile({'*.mat','SchlafEin Results Matlab Output'},'Choose a filename',[SED.filename(1:dt(end)-1) '-results.mat']);
            mfile = fullfile(pn, fn);
            save(mfile,'twaso','ts1','ts2','ts3','ts4','tsws','trem','tmt','tst','tts1','swslat','remlat','pwaso','ps1','ps2','ps3','ps4','psws','prem','pmt','sonset','soffset','sdur');
    end
end

function SE_mousemoveline(src, ~)
    global SED
    plotcolor = SED.objects.axes(1).XColor;
    pos = src.CurrentPoint;
    if isfield(SED.objects, 'lines') && ~isempty(SED.objects.lines) && isgraphics(SED.objects.lines(1))
        delete(SED.objects.lines(1));
        delete(SED.objects.lines(2));
    end

    if SED.objects.ctrlbuttons(4).Value 
        ax = SE_findax(pos);
        if ax
            Y = SED.objects.axes(ax).CurrentPoint(1,2);
            SED.objects.lines(1) = line(SED.objects.axes(ax), SED.objects.axes(ax).XLim, [Y Y],'LineStyle',':', 'Color', plotcolor);
            SED.objects.lines(2) = line(SED.objects.axes(ax), SED.objects.axes(ax).XLim, [Y+75 Y+75],'LineStyle',':', 'Color', plotcolor);
        end
    end
    if SED.objects.countpushed
        lastline = SED.objects.countlines(end);
        xlim = SED.objects.axes(SED.objects.countpushed).XLim;
        x = SED.objects.axes(SED.objects.countpushed).CurrentPoint(1,1);
        y = SED.objects.axes(SED.objects.countpushed).CurrentPoint(1,2);
        if x<xlim(1)
            x=xlim(1);
        end
        if x>xlim(2)
            x=xlim(2);
        end
        lastline.XData(2) = x;
        lastline.YData(2) = y;
        SED.objects.countperc = 0;
        for i=1:length(SED.objects.countlines)
            SED.objects.countperc = SED.objects.countperc + abs(SED.objects.countlines(i).XData(2)-SED.objects.countlines(i).XData(1));
        end
        SED.objects.countperc = SED.objects.countperc/SED.display.epochlength*100;
        SED.objects.countannot.String = sprintf('%3.1f%%',SED.objects.countperc);
    end
end

function SE_mousemovezoom(src, ~)
    global SED
    pos = src.CurrentPoint;
    siz = [0.2 0.2];
    ax = 0;
    chns = find(~SED.display.hiddenchans);
    
    if (pos(1) >= SED.objects.axes(1).Position(1)) && (pos(1) <= SED.objects.axes(1).Position(1) + SED.objects.axes(1).Position(3))
        for i=1:length(SED.objects.axes)
            if (pos(2) >= SED.objects.axes(i).Position(2)) && (pos(2) <= SED.objects.axes(i).Position(2) + SED.objects.axes(i).Position(4))
                ax = i;
                break
            end
        end
        if ax
            axpos = SED.objects.axes(ax).CurrentPoint;
            if isempty(SED.objects.zoomaxes) || ~isvalid(SED.objects.zoomaxes)
                figure(SED.objects.window);
                SED.objects.zoomaxes = axes('Units','normalized', 'Position',[pos(1)-siz(1)/2 pos(2)-siz(2)/2 siz(1) siz(2)]);
            else
                SED.objects.zoomaxes.Position = [pos(1)-siz(1)/2 pos(2)-siz(2)/2 siz(1) siz(2)];
            end
            eplen = 4;
            pos = round(((axpos(1)-(eplen/2))*SED.header.commoninfos.samplingrate)+1);
            if pos<1
                pos = 1;
            end
            len = round(eplen*SED.header.commoninfos.samplingrate);
            if (pos+len-1)>SED.header.commoninfos.datapoints
                pos = SED.header.commoninfos.datapoints-len+1;
            end
            x = axpos(1)-(eplen/2):eplen/len:axpos(1)+(eplen/2);
            x = x(1:end-1);
            plot(SED.objects.zoomaxes, x, SED.data(chns(ax), pos:pos+len-1));
            SED.objects.zoomaxes.XLim = [x(1) x(end)];
            SED.objects.zoomaxes.YLim =  [-SED.display.ranges(chns(ax)) SED.display.ranges(chns(ax))];
            SED.objects.zoomaxes.YTick = [];
            SED.objects.zoomaxes.YDir = 'normal';

            SED.objects.zoomaxes.XTick = x(1):1:x(end);
            SED.objects.zoomaxes.XTickLabel = [];
            SED.objects.zoomaxes.TickLength = [0 0];
            SED.objects.zoomaxes.GridColorMode = 'manual';
            SED.objects.zoomaxes.GridColor = [0 0 0];
            SED.objects.zoomaxes.XGrid = 'on';

            SED.objects.zoomaxes.MinorGridColorMode = 'manual';
            SED.objects.zoomaxes.MinorGridColor = SED.objects.zoomaxes.XColor;
            SED.objects.zoomaxes.XAxis.MinorTickValues = x(1):0.5:x(end);
            SED.objects.zoomaxes.XMinorTick = 'off';
            SED.objects.zoomaxes.XMinorGrid = 'on';
        end
    end
end

function SE_keypress(~, event)
    global SED
    switch event.Key
        case {'0', 'w'}
            SE_buttonpush(SED.objects.freebuttons(1),0);
        case '1'
            SE_buttonpush(SED.objects.freebuttons(2),0);
        case '2'
            SE_buttonpush(SED.objects.freebuttons(3),0);
        case '3'
            SE_buttonpush(SED.objects.freebuttons(4),0);
        case '4'
            SE_buttonpush(SED.objects.freebuttons(5),0);
        case '5'
            SE_buttonpush(SED.objects.freebuttons(6),0);
        case {'6', 'm'}
            SE_buttonpush(SED.objects.freebuttons(8),0);  % MT
        case {'7', 'a'}
            SE_buttonpush(SED.objects.freebuttons(7),0);  % MA
        case 'numpad1'
            if SED.hori
                SE_buttonpush(SED.objects.hoributtons(1),0);
            else
                SE_buttonpush(SED.objects.freebuttons(2),0);
            end
        case 'numpad2'
            if SED.hori
                SE_buttonpush(SED.objects.hoributtons(2),0);
            else
                SE_buttonpush(SED.objects.freebuttons(3),0);
            end
        case 'numpad3'
            if SED.hori
                SE_buttonpush(SED.objects.hoributtons(3),0);
            else
                SE_buttonpush(SED.objects.freebuttons(4),0);
            end
        case 'numpad4'
            if SED.hori
                SE_buttonpush(SED.objects.hoributtons(4),0);
            else
                SE_buttonpush(SED.objects.freebuttons(5),0);
            end
        case 'numpad5'
            if SED.hori
                SE_buttonpush(SED.objects.hoributtons(5),0);
            else
                SE_buttonpush(SED.objects.freebuttons(6),0);
            end
        case 'numpad6'
            if SED.hori
                SE_buttonpush(SED.objects.hoributtons(6),0);
            else
                SE_buttonpush(SED.objects.freebuttons(8),0);
            end
        case 'numpad7'
            if SED.hori
                SE_buttonpush(SED.objects.hoributtons(7),0);
            else
                SE_buttonpush(SED.objects.freebuttons(7),0);
            end
        case 'numpad8'
            SE_buttonpush(SED.objects.hoributtons(8),0);
        case 'numpad9'
            SE_buttonpush(SED.objects.hoributtons(9),0);
        case 'numpad0'
            if SED.hori
                SE_buttonpush(SED.objects.hoributtons(10),0);
            else
                SE_buttonpush(SED.objects.freebuttons(1),0);
            end
        case 'leftarrow'
            SE_ctrlbuttonpush(SED.objects.ctrlbuttons(1),0);
        case 'rightarrow'
            SE_ctrlbuttonpush(SED.objects.ctrlbuttons(2),0);
        case 'uparrow'
            SE_ctrlbuttonpush(SED.objects.ctrlbuttons(7),0);
        case 'downarrow'
            SE_ctrlbuttonpush(SED.objects.ctrlbuttons(8),0);
        case 'y'
            SE_ctrlbuttonpush(SED.objects.ctrlbuttons(3),0);
        case 'l'
            SED.objects.ctrlbuttons(4).Value = ~SED.objects.ctrlbuttons(4).Value;
            SE_ctrlbuttonpush(SED.objects.ctrlbuttons(4),0);
        case 'z'
            SED.objects.ctrlbuttons(5).Value = ~SED.objects.ctrlbuttons(5).Value;
            SE_ctrlbuttonpush(SED.objects.ctrlbuttons(5),0);
        case 'c'
            SED.objects.ctrlbuttons(6).Value = ~SED.objects.ctrlbuttons(6).Value;
            SE_ctrlbuttonpush(SED.objects.ctrlbuttons(6),0);
        case 'o'
            SE_ctrlbuttonpush(SED.objects.ctrlbuttons(9),0);
        case 's'
            SE_ctrlbuttonpush(SED.objects.ctrlbuttons(10),0);
        case 'i'
            SE_ctrlbuttonpush(SED.objects.ctrlbuttons(11),0);
        case 'e'
            SE_ctrlbuttonpush(SED.objects.ctrlbuttons(12),0);
        case 'h'
            SE_ctrlbuttonpush(SED.objects.ctrlbuttons(13),0);
        case 'u'
            SE_ctrlbuttonpush(SED.objects.ctrlbuttons(14),0);
        case 'n'
            SE_ctrlbuttonpush(SED.objects.ctrlbuttons(15),0);
    end
end

function SE_linebuttondown(src, ~)
    global SED
    pos = src.CurrentPoint;
    ax = SE_findax(pos);
    if ax
        src.WindowButtonUpFcn = @SE_linebuttonup;
        SED.objects.countpushed = ax;
        X = SED.objects.axes(ax).CurrentPoint(1,1);
        Y = SED.objects.axes(ax).CurrentPoint(1,2);
        SED.objects.countlines(length(SED.objects.countlines)+1) = line(SED.objects.axes(ax), [X X], [Y Y], 'Color', 'r');
    end
end

function SE_linebuttonup(src, ~)
    global SED
    src.WindowButtonUpFcn = [];
    SED.objects.countpushed = 0;
end

function SE_hypclick(~, ~)
    global SED
    len = round(SED.display.epochlength * SED.header.commoninfos.samplingrate);
    maxpage = floor(SED.header.commoninfos.datapoints/len);
    if (round(SED.objects.hypnoaxes(1).CurrentPoint(1)) >= 1) && (round(SED.objects.hypnoaxes(1).CurrentPoint(1)) <= SED.header.commoninfos.datapoints)
        SED.display.position = (round(SED.objects.hypnoaxes(1).CurrentPoint(1))-1)*SED.display.epochlength;
        if round(SED.objects.hypnoaxes(1).CurrentPoint(1)) > maxpage
            SED.display.position = (maxpage-1)*SED.display.epochlength;
        end
        if SED.objects.ctrlbuttons(6).Value
            SED.objects.countperc = 0;
            for i=1:length(SED.objects.countlines)
                delete(SED.objects.countlines(i));
            end
            SED.objects.countlines = gobjects(0,0);
            SED.objects.countannot.String = sprintf('%3.1f%%',SED.objects.countperc);
        end
    	SE_plot;
    end
end

function ok = SE_open
    global SED
    if isfield(SED,'unsaved') && SED.unsaved
        answer = questdlg('Do you really want to quit?','Unsaved data.','Yes','No','No');
        if ~strcmp(answer, 'Yes')
            return;
        end
    end
    [fn, pn] = uigetfile({'*.vhdr','BrainVision Header File'},'Select a File');
    
    if ~fn
        ok = false;
        return;
    end

    fprintf('Opening file ...');
    hdr = readbvconf(pn, fn);

    if ~strcmpi(hdr.commoninfos.dataformat, 'binary')
        errordlg('Data format must be BINARY','File Open Error');
        ok = false;
        return;
    end
    
    hdr.commoninfos.numberofchannels = str2double(hdr.commoninfos.numberofchannels);
    if(isfield(hdr.commoninfos, 'datapoints'))
        hdr.commoninfos.datapoints = str2double(hdr.commoninfos.datapoints);
    else
        hdr.commoninfos.datapoints = Inf;
    end
    hdr.commoninfos.samplinginterval = str2double(hdr.commoninfos.samplinginterval);
    hdr.commoninfos.samplingrate = 1000000 / hdr.commoninfos.samplinginterval;
    
    [datafile, msg] = fopen(fullfile(pn, hdr.commoninfos.datafile));
    if datafile == -1
        errordlg(msg,'File Open Error');
        ok = false;
        return;
    end
    
    switch lower(hdr.binaryinfos.binaryformat)
        case 'int_16'
            datformat = 'int16'; 
        case 'uint_16'
            datformat = 'uint16';
        case 'ieee_float_32'
            datformat = 'float32';
        otherwise
            errordlg('Unsupported data format','File Open Error');
            ok = false;
            return;
    end
    
    switch lower(hdr.commoninfos.dataorientation)
        case 'multiplexed'
            dat = fread(datafile, [hdr.commoninfos.numberofchannels, hdr.commoninfos.datapoints], [datformat '=>float32']);
            if isinf(hdr.commoninfos.datapoints)
                hdr.commoninfos.datapoints = size(dat,2);
            end
        case 'vectorized'
            if ~isinf(hdr.commoninfos.datapoints)
                dat = fread(datafile, [hdr.commoninfos.datapoints, hdr.commoninfos.numberofchannels], [datformat '=>float32'])';
            else
                dat = fread(datafile, Inf, [datformat '=>float32']);
                hdr.commoninfos.datapoints = length(dat)/hdr.commoninfos.numberofchannels;
                dat = reshape(dat,[hdr.commoninfos.datapoints, hdr.commoninfos.numberofchannels])';
            end
        otherwise
            error('Unexpected data orientation')
    end
    fclose(datafile);

    tci = struct;
    if isfield(hdr, 'channelinfos')
        for ch = 1:hdr.commoninfos.numberofchannels
            [tci(ch).labels, tci(ch).ref, tci(ch).scale, tci(ch).unit] = strread(hdr.channelinfos{ch}, '%s%s%s%s', 1, 'delimiter', ','); %#ok<DSTRRD>
            tci(ch).scale = str2double(tci(ch).scale);
            if ~isnan(tci(ch).scale)
                dat(ch, :) = dat(ch, :) * tci(ch).scale;
            end
        end
    end
    hdr.channelinfos = tci;

    if isfield(hdr.commoninfos, 'markerfile')
        mrk = readbvconf(pn, hdr.commoninfos.markerfile);
        [~, ~, ~, ~, ~, tim] = strread(mrk.markerinfos{1}, '%s%s%f%d%d%s', 'delimiter', ','); %#ok<DSTRRD>
    else
        tim = {'19700101000000'};
    end
    hdr.commoninfos.starttime = datenum(tim{1}(1:14),'yyyymmddHHMMSS');
    
    SED.filename = fn;
    SED.pathname = pn;
    SED.header = hdr;
    SED.data = dat;

    len = round(SED.display.epochlength * SED.header.commoninfos.samplingrate);
    maxpage = floor(SED.header.commoninfos.datapoints/len);
    SED.score.stage = zeros(maxpage,1);
    SED.score.movement = zeros(maxpage,1);
    SED.score.hori = zeros(maxpage,6);
    SED.header.isemg = cellfun(@any,strfind([SED.header.channelinfos.labels],'EMG')) | cellfun(@any,strfind([SED.header.channelinfos.labels],'MUS'));
    SED.header.iseog = cellfun(@any,strfind([SED.header.channelinfos.labels],'EOG'));
    SED.header.isecg = cellfun(@any,strfind([SED.header.channelinfos.labels],'ECG')) | cellfun(@any,strfind([SED.header.channelinfos.labels],'EKG'));
    SED.header.iseeg = ~(SED.header.isemg | SED.header.iseog | SED.header.isecg);
    SED.display.ranges(SED.header.isemg) = quantile(abs(SED.data(SED.header.isemg,:)),0.99,2);
    SED.display.ranges(SED.header.iseog) = quantile(abs(SED.data(SED.header.iseog,:)),0.99,2);
    SED.display.ranges(SED.header.isecg) = quantile(abs(SED.data(SED.header.isecg,:)),0.99,2);
    SED.display.ranges(SED.header.iseeg) = quantile(abs(reshape(SED.data(SED.header.iseeg,:),sum(SED.header.iseeg)*size(SED.data,2),1)),0.99,1);
    SED.display.hiddenchans = zeros(SED.header.commoninfos.numberofchannels,1);
    fprintf(' done.\n');
    cd(pn);
    ok = true;
end

function ax = SE_findax(pos)
    global SED
    ax = 0;
    if (pos(1) >= SED.objects.axes(1).Position(1)) && (pos(1) <= SED.objects.axes(1).Position(1) + SED.objects.axes(1).Position(3))
        for i=1:length(SED.objects.axes)
            if (pos(2) >= SED.objects.axes(i).Position(2)) && (pos(2) <= SED.objects.axes(i).Position(2) + SED.objects.axes(i).Position(4))
                ax = i;
                break
            end
        end
    end
end

function SE_refreshax
    global SED
    
    for ch=1:length(SED.objects.axes)
        delete(SED.objects.selbuttons(ch))
        delete(SED.objects.axes(ch))
    end
    figure(SED.objects.window);
    chns = find(~SED.display.hiddenchans);
    nch = length(chns);
    SED.objects.axes = gobjects(nch,1);
    SED.objects.selbuttons = gobjects(nch,1);
    height = 0.8/nch;
    for ch = 1:nch
        SED.objects.selbuttons(ch) = uicontrol('Style','checkbox', 'Value', 1, ... 
            'Units','normalized', 'Position',[0 1-(0.10+(ch-1)*height) 0.025 0.035]);
        SED.objects.axes(ch) = axes('Units','normalized', 'Position',[0.075 1-(0.07+(ch*height)) 0.9 height-height/10]);
    end
end

function SE_find_spectral_bands(~, ~)
    global SED
    srate = SED.header.commoninfos.samplingrate;
    %fftlen = 2^nextpow2(ndat/100);
    fftlen = srate*8;
    [psd,f] = pwelch(SED.data(SED.header.iseeg,:)', fftlen, fftlen/2, fftlen, srate);
    fr = f<40;
    frqb = {'SO','SO','delta','theta','alpha','spindle'};

    fig = figure;
    fig.Units = 'normalized';
    t1 = uicontrol(fig, 'Style','text');
    t1.String = 'Lower Limit';
    t1.Units = 'normalized';
    t1.Position = [0.85 0.86 0.1 0.05];
    t2 = uicontrol(fig, 'Style','text');
    t2.String = 'Upper Limit';
    t2.Units = 'normalized';
    t2.Position = [0.85 0.735 0.1 0.05];
    ax = axes('Position',[0.1 0.1 0.7 0.8]);
    semilogy(ax,f(fr),(psd(fr,:).*f(fr).^2)');
    frtext = gobjects(length(SED.frqs));
    frfield = gobjects(length(SED.frqs));
    for i=1:length(SED.frqs)
        frtext(i) = uicontrol(fig, 'Style','text');
        frtext(i).String = frqb(i);
        frtext(i).Units = 'normalized';
        frtext(i).Position = [0.85 0.83-(i-1)*0.125 0.1 0.05];

        frfield(i) = uicontrol(fig,'Style','edit');
        frfield(i).String = num2str(SED.frqs(i));
        frfield(i).Units = 'normalized';
        frfield(i).Position = [0.85 0.8-(i-1)*0.125 0.1 0.05];
    end
    fig.WindowStyle = 'modal';
    fig.CloseRequestFcn = @SE_find_spectral_bands_close;
end

function SE_find_spectral_bands_close(fig, ~)
    global SED

    frqb = {'SO','SO','delta','theta','alpha','spindle'};
    ncld = length(fig.Children);
    for i=1:length(SED.frqs)
        t = str2double(fig.Children(ncld-2-i*2).String);
        if ~isnan(t)
            SED.frqs(i) = t;
        end
        if i>1
            fprintf('%s: ]%2.1f - %2.1f] Hz\n', frqb{i}, SED.frqs(i-1), SED.frqs(i));
        end
    end
    delete(fig);
    SE_plot
end

function SE_initialize
    global SED
    global SEversion

    if isstruct(SED)
        if isfield(SED, 'objects')
            if isfield(SED.objects, 'window')
                delete(SED.objects.window);
            end
            if isfield(SED.objects, 'hypnowindow') && ~isempty(SED.objects.hypnowindow) && isvalid(SED.objects.hypnowindow)
                delete(SED.objects.hypnowindow);
            end
        end
    end
    
    SED = struct;
    SED.unsaved = false;
    SED.filename = '';
    SED.pathname = '';
    SED.header = [];
    SED.data = [];
    SED.objects.window = [];
    SED.objects.time = [];
    SED.objects.hypnoaxes = [];
    SED.objects.page = [];
    SED.objects.lines = gobjects(2,1);
    SED.objects.zoomaxes = [];
    SED.objects.countlines = gobjects(0,0);
    SED.objects.countpushed = 0;
    SED.objects.countperc = 0;
    SED.objects.countannot = [];
    SED.display.position = 0;
    SED.display.epochlength = 30;
    SED.display.hypnogram = 0;
    SED.display.hiddenchans = [];
    SED.display.windowsize = [0.05 0.05 0.9 0.85];
    SED.display.hypwindowsize = [0.6 0.1 0.3 0.2];
    SED.score.stage = [];
    SED.score.movement = [];
    SED.hori = false;
    SED.score.hori = [];
    SED.frqs = [0.3 1.2 4 8 12 16];
    SED.version = SEversion;
end

function SE_close(~,~)
    global SED; 

    if isstruct(SED)
        if isfield(SED,'unsaved') && SED.unsaved
            answer = questdlg('Do you really want to quit?','Unsaved data.','Yes','No','No');
            if ~strcmp(answer, 'Yes')
                return;
            end
        end
    
        if isfield(SED, 'objects')
            if isfield(SED.objects, 'window')
                delete(SED.objects.window);
            end
            if isfield(SED.objects, 'hypnowindow') && ~isempty(SED.objects.hypnowindow) && isvalid(SED.objects.hypnowindow)
                delete(SED.objects.hypnowindow);
            end
        end
        clear global SED
    end
end

function SE_update
    global SEversion
    try
        lines = splitlines(webread('https://raw.githubusercontent.com/SteffenGais/SchlafEin/main/SchlafEin.m'));
        v = 'notfound';
        for i = 1:length(lines)
            line = strip(lines{i});
            if isempty(line) || line(1)~='%'
                continue
            end
            if contains(lower(line), "version")
                v = regexp(line, '\d+\.?\d*', 'match');
                v = v{end};
                break
            end
        end
        if  strcmp(v, 'notfound')
            disp('Error while reading version number, no version number found. Check manually at https://github.com/SteffenGais/SchlafEin')
        elseif SEversion < str2double(v)
            a = input('There is a new version. Update (Y/N)? ','s');
            if lower(a(1))=='y'
                up = webread('https://raw.githubusercontent.com/SteffenGais/SchlafEin/main/SchlafEin.m',weboptions('ContentType','text'));
                fn = which('SchlafEin.m');
                copyfile(fn,[fn(1:end-2) '_' datestr(now,30) '.m']);
                f=fopen(fn,'w');
                fprintf(f,'%s',up);
                fclose(f);
            end
        else
            disp(['SchlafEin [v', num2str(SEversion), '] (no updates found, you are using the most recent version).'])
        end
    catch error
        disp(['Warning. Could not update: ', error.message]);
    end
end

function [spec,t] = SE_calc_CWT(x,sr)
    global SED
    if 1
        [tf,f] = cwt(x,'bump',sr);
        tf = (abs(tf).*repmat(f.^0.3,1,length(x)));
        t = (0:length(x)-1)/sr;
    else % for those without the wavelet toolbox - not optimized yet
        [tf,f,t] = mytimefreq(x,sr); %#ok<UNRCH>    
        t = t/1000;
        tf = (abs(tf).*repmat(f'.^1.5,1,length(t)));
    end
    %figure;s=pcolor(t, f, tf);s.EdgeColor='none';
    fSO = (f>SED.frqs(1) & f<=SED.frqs(2));
    fdelta = (f>SED.frqs(2) & f<=SED.frqs(3));
    ftheta = (f>SED.frqs(3) & f<=SED.frqs(4));
    falpha = (f>SED.frqs(4) & f<=SED.frqs(5));
    fspindle = (f>SED.frqs(5) & f<SED.frqs(6));
    pSO = mean(tf(fSO,:),1);
    pdelta = mean(tf(fdelta,:),1);
    ptheta = mean(tf(ftheta,:),1);
    palpha = mean(tf(falpha,:),1);
    pspindle = mean(tf(fspindle,:),1);
    spec = [pSO; pdelta; ptheta; palpha; pspindle];
end

% readbvconf() - read Brain Vision Data Exchange format configuration 
%                file
%
% Usage:
%   >> CONF = readbvconf(pathname, filename);
%
% Inputs:
%   pathname  - path to file
%   filename  - filename
%
% Outputs:
%   CONF      - structure configuration
%
% Author: Andreas Widmann, University of Leipzig, 2007

%123456789012345678901234567890123456789012345678901234567890123456789012

% Copyright (C) 2007 Andreas Widmann, University of Leipzig, widmann@uni-leipzig.de
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

% $Id: readbvconf.m 44 2009-11-12 02:00:56Z arnodelorme $

function CONF = readbvconf(pathname, filename)

    if nargin < 2
        error('Not enough input arguments');
    end

    % Open and read file
    [IN, ~] = fopen(fullfile(pathname, filename),'r','native','UTF-8');
    if IN == -1
        [IN, message] = fopen(fullfile(pathname, lower(filename)),'r','native','UTF-8');
        if IN == -1
            error(message)
        end
    end
    raw={};
    while ~feof(IN)
        raw = [raw; {fgetl(IN)}]; %#ok<AGROW>
    end
    fclose(IN);

    % Remove comments and empty lines
    raw(strmatch(';', raw)) = []; %#ok<MATCH2>
    raw(cellfun('isempty', raw) == true) = [];

    % Find sections
    sectionArray = [strmatch('[', raw)' length(raw) + 1]; %#ok<MATCH2>
    for iSection = 1:length(sectionArray) - 1

        % Convert section name
        fieldName = lower(char(strread(raw{sectionArray(iSection)}, '[%s', 'delimiter', ']'))); %#ok<DSTRRD>
        fieldName(isspace(fieldName) == true) = [];

        % Fill structure with parameter value pairs
        switch fieldName
            case {'commoninfos' 'binaryinfos'}
                for line = sectionArray(iSection) + 1:sectionArray(iSection + 1) - 1
                    splitArray = strfind(raw{line}, '=');
                    CONF.(fieldName).(lower(raw{line}(1:splitArray(1) - 1))) = raw{line}(splitArray(1) + 1:end);
                end
            case {'channelinfos' 'coordinates' 'markerinfos'}
                for line = sectionArray(iSection) + 1:sectionArray(iSection + 1) - 1
                    splitArray = strfind(raw{line}, '=');
                    CONF.(fieldName)(str2double(raw{line}(3:splitArray(1) - 1))) = {raw{line}(splitArray(1) + 1:end)};
                end
            case 'comment'
                CONF.(fieldName) = raw(sectionArray(iSection) + 1:sectionArray(iSection + 1) - 1);
        end
    end
end

% % 		        GNU GENERAL PUBLIC LICENSE
% % 		           Version 2, June 1991
% % 
% %  Copyright (C) 1989, 1991 Free Software Foundation, Inc.
% %                        59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
% %  Everyone is permitted to copy and distribute verbatim copies
% %  of this license document, but changing it is not allowed.
% % 
% % 		    GNU GENERAL PUBLIC LICENSE
% %    TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
% % 
% %   0. This License applies to any program or other work which contains
% % a notice placed by the copyright holder saying it may be distributed
% % under the terms of this General Public License.  The "Program", below,
% % refers to any such program or work, and a "work based on the Program"
% % means either the Program or any derivative work under copyright law:
% % that is to say, a work containing the Program or a portion of it,
% % either verbatim or with modifications and/or translated into another
% % language.  (Hereinafter, translation is included without limitation in
% % the term "modification".)  Each licensee is addressed as "you".
% % 
% % Activities other than copying, distribution and modification are not
% % covered by this License; they are outside its scope.  The act of
% % running the Program is not restricted, and the output from the Program
% % is covered only if its contents constitute a work based on the
% % Program (independent of having been made by running the Program).
% % Whether that is true depends on what the Program does.
% % 
% %   1. You may copy and distribute verbatim copies of the Program's
% % source code as you receive it, in any medium, provided that you
% % conspicuously and appropriately publish on each copy an appropriate
% % copyright notice and disclaimer of warranty; keep intact all the
% % notices that refer to this License and to the absence of any warranty;
% % and give any other recipients of the Program a copy of this License
% % along with the Program.
% % 
% % You may charge a fee for the physical act of transferring a copy, and
% % you may at your option offer warranty protection in exchange for a fee.
% % 
% %   2. You may modify your copy or copies of the Program or any portion
% % of it, thus forming a work based on the Program, and copy and
% % distribute such modifications or work under the terms of Section 1
% % above, provided that you also meet all of these conditions:
% % 
% %     a) You must cause the modified files to carry prominent notices
% %     stating that you changed the files and the date of any change.
% % 
% %     b) You must cause any work that you distribute or publish, that in
% %     whole or in part contains or is derived from the Program or any
% %     part thereof, to be licensed as a whole at no charge to all third
% %     parties under the terms of this License.
% % 
% %     c) If the modified program normally reads commands interactively
% %     when run, you must cause it, when started running for such
% %     interactive use in the most ordinary way, to print or display an
% %     announcement including an appropriate copyright notice and a
% %     notice that there is no warranty (or else, saying that you provide
% %     a warranty) and that users may redistribute the program under
% %     these conditions, and telling the user how to view a copy of this
% %     License.  (Exception: if the Program itself is interactive but
% %     does not normally print such an announcement, your work based on
% %     the Program is not required to print an announcement.)
% % 
% % These requirements apply to the modified work as a whole.  If
% % identifiable sections of that work are not derived from the Program,
% % and can be reasonably considered independent and separate works in
% % themselves, then this License, and its terms, do not apply to those
% % sections when you distribute them as separate works.  But when you
% % distribute the same sections as part of a whole which is a work based
% % on the Program, the distribution of the whole must be on the terms of
% % this License, whose permissions for other licensees extend to the
% % entire whole, and thus to each and every part regardless of who wrote it.
% % 
% % Thus, it is not the intent of this section to claim rights or contest
% % your rights to work written entirely by you; rather, the intent is to
% % exercise the right to control the distribution of derivative or
% % collective works based on the Program.
% % 
% % In addition, mere aggregation of another work not based on the Program
% % with the Program (or with a work based on the Program) on a volume of
% % a storage or distribution medium does not bring the other work under
% % the scope of this License.
% % 
% %   3. You may copy and distribute the Program (or a work based on it,
% % under Section 2) in object code or executable form under the terms of
% % Sections 1 and 2 above provided that you also do one of the following:
% % 
% %     a) Accompany it with the complete corresponding machine-readable
% %     source code, which must be distributed under the terms of Sections
% %     1 and 2 above on a medium customarily used for software interchange; or,
% % 
% %     b) Accompany it with a written offer, valid for at least three
% %     years, to give any third party, for a charge no more than your
% %     cost of physically performing source distribution, a complete
% %     machine-readable copy of the corresponding source code, to be
% %     distributed under the terms of Sections 1 and 2 above on a medium
% %     customarily used for software interchange; or,
% % 
% %     c) Accompany it with the information you received as to the offer
% %     to distribute corresponding source code.  (This alternative is
% %     allowed only for noncommercial distribution and only if you
% %     received the program in object code or executable form with such
% %     an offer, in accord with Subsection b above.)
% % 
% % The source code for a work means the preferred form of the work for
% % making modifications to it.  For an executable work, complete source
% % code means all the source code for all modules it contains, plus any
% % associated interface definition files, plus the scripts used to
% % control compilation and installation of the executable.  However, as a
% % special exception, the source code distributed need not include
% % anything that is normally distributed (in either source or binary
% % form) with the major components (compiler, kernel, and so on) of the
% % operating system on which the executable runs, unless that component
% % itself accompanies the executable.
% % 
% % If distribution of executable or object code is made by offering
% % access to copy from a designated place, then offering equivalent
% % access to copy the source code from the same place counts as
% % distribution of the source code, even though third parties are not
% % compelled to copy the source along with the object code.
% % 
% %   4. You may not copy, modify, sublicense, or distribute the Program
% % except as expressly provided under this License.  Any attempt
% % otherwise to copy, modify, sublicense or distribute the Program is
% % void, and will automatically terminate your rights under this License.
% % However, parties who have received copies, or rights, from you under
% % this License will not have their licenses terminated so long as such
% % parties remain in full compliance.
% % 
% %   5. You are not required to accept this License, since you have not
% % signed it.  However, nothing else grants you permission to modify or
% % distribute the Program or its derivative works.  These actions are
% % prohibited by law if you do not accept this License.  Therefore, by
% % modifying or distributing the Program (or any work based on the
% % Program), you indicate your acceptance of this License to do so, and
% % all its terms and conditions for copying, distributing or modifying
% % the Program or works based on it.
% % 
% %   6. Each time you redistribute the Program (or any work based on the
% % Program), the recipient automatically receives a license from the
% % original licensor to copy, distribute or modify the Program subject to
% % these terms and conditions.  You may not impose any further
% % restrictions on the recipients' exercise of the rights granted herein.
% % You are not responsible for enforcing compliance by third parties to
% % this License.
% % 
% %   7. If, as a consequence of a court judgment or allegation of patent
% % infringement or for any other reason (not limited to patent issues),
% % conditions are imposed on you (whether by court order, agreement or
% % otherwise) that contradict the conditions of this License, they do not
% % excuse you from the conditions of this License.  If you cannot
% % distribute so as to satisfy simultaneously your obligations under this
% % License and any other pertinent obligations, then as a consequence you
% % may not distribute the Program at all.  For example, if a patent
% % license would not permit royalty-free redistribution of the Program by
% % all those who receive copies directly or indirectly through you, then
% % the only way you could satisfy both it and this License would be to
% % refrain entirely from distribution of the Program.
% % 
% % If any portion of this section is held invalid or unenforceable under
% % any particular circumstance, the balance of the section is intended to
% % apply and the section as a whole is intended to apply in other
% % circumstances.
% % 
% % It is not the purpose of this section to induce you to infringe any
% % patents or other property right claims or to contest validity of any
% % such claims; this section has the sole purpose of protecting the
% % integrity of the free software distribution system, which is
% % implemented by public license practices.  Many people have made
% % generous contributions to the wide range of software distributed
% % through that system in reliance on consistent application of that
% % system; it is up to the author/donor to decide if he or she is willing
% % to distribute software through any other system and a licensee cannot
% % impose that choice.
% % 
% % This section is intended to make thoroughly clear what is believed to
% % be a consequence of the rest of this License.
% % 
% %   8. If the distribution and/or use of the Program is restricted in
% % certain countries either by patents or by copyrighted interfaces, the
% % original copyright holder who places the Program under this License
% % may add an explicit geographical distribution limitation excluding
% % those countries, so that distribution is permitted only in or among
% % countries not thus excluded.  In such case, this License incorporates
% % the limitation as if written in the body of this License.
% % 
% %   9. The Free Software Foundation may publish revised and/or new versions
% % of the General Public License from time to time.  Such new versions will
% % be similar in spirit to the present version, but may differ in detail to
% % address new problems or concerns.
% % 
% % Each version is given a distinguishing version number.  If the Program
% % specifies a version number of this License which applies to it and "any
% % later version", you have the option of following the terms and conditions
% % either of that version or of any later version published by the Free
% % Software Foundation.  If the Program does not specify a version number of
% % this License, you may choose any version ever published by the Free Software
% % Foundation.
% % 
% %   10. If you wish to incorporate parts of the Program into other free
% % programs whose distribution conditions are different, write to the author
% % to ask for permission.  For software which is copyrighted by the Free
% % Software Foundation, write to the Free Software Foundation; we sometimes
% % make exceptions for this.  Our decision will be guided by the two goals
% % of preserving the free status of all derivatives of our free software and
% % of promoting the sharing and reuse of software generally.
% % 
% % 			    NO WARRANTY
% % 
% %   11. BECAUSE THE PROGRAM IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
% % FOR THE PROGRAM, TO THE EXTENT PERMITTED BY APPLICABLE LAW.  EXCEPT WHEN
% % OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
% % PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED
% % OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
% % MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE ENTIRE RISK AS
% % TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU.  SHOULD THE
% % PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING,
% % REPAIR OR CORRECTION.
% % 
% %   12. IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
% % WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
% % REDISTRIBUTE THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES,
% % INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING
% % OUT OF THE USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED
% % TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY
% % YOU OR THIRD PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER
% % PROGRAMS), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE
% % POSSIBILITY OF SUCH DAMAGES.

% The section below is part of EEGLAB, see http://www.eeglab.org
% for the documentation and details.
%
% Copyright (C) 8/1/98  Arnaud Delorme, Sigurd Enghoff & Scott Makeig, SCCN/INC/UCSD
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are met:
%
% 1. Redistributions of source code must retain the above copyright notice,
% this list of conditions and the following disclaimer.
%
% 2. Redistributions in binary form must reproduce the above copyright notice,
% this list of conditions and the following disclaimer in the documentation
% and/or other materials provided with the distribution.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
% THE POSSIBILITY OF SUCH DAMAGE.
 
function [tmpall, freqs, timesout] = mytimefreq(data, srate) %#ok<DEFNU>
    frames = length(data);
    g.freqs     = [0.1 20];
    g.cycles    = [1 10];
    g.wletmethod = 'dftfilt3';
    g.freqscale = 'log';
    g.winsize   = srate;%2.^nextpow2(srate*4);%max(pow2(nextpow2(frames)-3),4);
    g.ntimesout = frames/srate*5;
    g.tlimits   = [0 frames/srate*1000];

    % finding frequency limits
    % ------------------------
    if g.cycles(1) ~= 0 && g.freqs(1) == 0
        g.freqs(1) = srate*g.cycles(1)/g.winsize;
    end

    % default number of freqs
    % -----------------------
    g.nfreqs = g.winsize/2+1;
    % adjust nfreqs depending on frequency range
    tmpfreqs = linspace(0, srate/2, g.nfreqs);
    tmpfreqs = tmpfreqs(2:end);  % remove DC (match the output of PSD)

    % adjust limits for FFT (only linear scale)
    if g.cycles(1) == 0 && ~strcmpi(g.freqscale, 'log')
        if ~any(tmpfreqs == g.freqs(1))
            [~, minind] = min(abs(tmpfreqs-g.freqs(1)));
            g.freqs(1)   = tmpfreqs(minind);
        end
        if ~any(tmpfreqs == g.freqs(2))
            [~, minind] = min(abs(tmpfreqs-g.freqs(2)));
            g.freqs(2)   = tmpfreqs(minind);
        end
    end

    % find number of frequencies
    % --------------------------
    g.nfreqs = length(tmpfreqs( intersect( find(tmpfreqs >= g.freqs(1)), find(tmpfreqs <= g.freqs(2)))));
    if g.freqs(1)==g.freqs(2), g.nfreqs = 1; end

    % find closest freqs for FFT
    % --------------------------
    if strcmpi(g.freqscale, 'log')
        g.freqs = linspace(log(g.freqs(1)), log(g.freqs(end)), g.nfreqs);
        g.freqs = exp(g.freqs);
    else
        g.freqs = linspace(g.freqs(1), g.freqs(2), g.nfreqs); % this should be OK for FFT
        % because of the limit adjustment
    end
    g.nfreqs = length(g.freqs);

    % function for time freq initialisation
    % -------------------------------------
    freqs = g.freqs;
    if length(g.cycles) == 2
        if g.cycles(2) < 1
            g.cycles = [ g.cycles(1) g.cycles(1)*g.freqs(end)/g.freqs(1)*(1-g.cycles(2))];
        end
    end
    if strcmp(g.wletmethod, 'dftfilt2')
        g.win    = dftfilt2(g.freqs,g.cycles,srate, g.freqscale); % uses Morlet taper by default
    elseif strcmp(g.wletmethod, 'dftfilt3')     % Default
        g.win    = dftfilt3(g.freqs,g.cycles,srate, 'cycleinc', g.freqscale); % uses Morlet taper by default
    end
    g.winsize = 0;
    for index = 1:length(g.win)
        g.winsize = max(g.winsize,length(g.win{index}));
    end

    % compute time vector
    % -------------------
    [ g.timesout, g.indexout ] = gettimes(frames, g.tlimits, g.winsize, g.ntimesout);

    % -------------------------------
    % compute time freq decomposition
    % -------------------------------
    % prepare wavelet filters
    % -----------------------
    for index = 1:length(g.win)
        g.win{index} = transpose(g.win{index});
    end

    % apply filters
    % -------------
    tmpall = zeros(length(g.win), length(g.indexout));
    for freqind = 1:length(g.win)
        wav = g.win{freqind};
        sizewav = size(wav,1)-1;
        for index = 1:length(g.indexout)
            tmpX = data((-sizewav/2:sizewav/2)+g.indexout(index))';
            tmpX = tmpX - mean(tmpX);
            tmpX = sum(wav .* tmpX);
            tmpall( freqind, index) = tmpX;
        end
    end

    zerovals = tmpall == 0;
    if any(reshape(zerovals, 1, numel(zerovals)))
        tmpall(zerovals) = Inf;
        minval = min(tmpall(:)); % remove bug
        tmpall(zerovals) = minval;
    end

    timesout = g.timesout;
end

% get time points
% ---------------
function [ timevals, timeindices ] = gettimes(frames, tlimits, winsize, ntimevar)
    timevect = linspace(tlimits(1), tlimits(2), frames);
    srate    = 1000*(frames-1)/(tlimits(2)-tlimits(1));

    if ntimevar(1) > 0
        % generate linearly space vector
        % ------------------------------
        if (ntimevar > frames-winsize)
            ntimevar = frames-winsize;
            if ntimevar < 0
                error('Not enough data points, reduce the window size or lowest frequency');
            end
        end
        npoints = ntimevar(1);
        wintime = 500*winsize/srate;
        timevals = linspace(tlimits(1)+wintime, tlimits(2)-wintime, npoints);
    else
        % subsample data
        % --------------
        nsub     = -ntimevar(1);
        timeindices = ceil(winsize/2+nsub/2):nsub:length(timevect)-ceil(winsize/2)-1;
        timevals    = timevect( timeindices ); % the conversion at line 741 leaves timeindices unchanged
    end

    % find closet points in data
    % --------------------------
    epoch_array = ones(1,length(timevals));
    timewin = tlimits*1E-3;
    pnts = (timewin(2)-timewin(1))*srate+1;
    timeindices  = round((timevals*1E-3-timewin(1))*srate+1 + (epoch_array-1)*pnts);

    if length(timeindices) < length(unique(timeindices))
        timeindices = unique_bc(timeindices);
    end
    timevals    = timevect(timeindices);
end

function wavelet = dftfilt2( freqs, cycles, srate, cycleinc, type)
    % compute number of cycles at each frequency
    % ------------------------------------------
    if length(cycles) == 1
        cycles = cycles*ones(size(freqs));
    elseif length(cycles) == 2
        if nargin == 4 && strcmpi(cycleinc, 'log') % cycleinc
            cycles = linspace(log(cycles(1)), log(cycles(2)), length(freqs));
            cycles = exp(cycles);
        else
            cycles = linspace(cycles(1), cycles(2), length(freqs));
        end
    end
    if nargin<5
        type = 'morlet';
    end

    % compute wavelet
    for index = 1:length(freqs)
        % number of cycles depend on window size
        % number of cycles automatically reduced if smaller window
        % note: as the number of cycle changes, the frequency shifts a little
        %       this has to be fixed

        winlen = cycles(index)*srate/freqs(index);
        winlenint = floor(winlen);
        if mod(winlenint,2) == 1, winlenint = winlenint+1; end
        winval = linspace(winlenint/2, -winlenint/2, winlenint+1);

        if strcmpi(type, 'sinus') % Hanning
            win = exp(2i*pi*freqs(index)*winval/srate);
            wavelet{index} = win .* hanning(length(winval))'; %#ok<AGROW>

        else % Morlet
            t = freqs(index)*winval/srate;
            p = 2*pi;
            s = cycles(index)/5;
            wavelet{index} = exp(1i*t*p)/sqrt(2*pi) .* ...
                (exp(-t.^2/(2*s^2))-sqrt(2)*exp(-t.^2/(s^2)-p^2*s^2/4)); %#ok<AGROW>
        end
    end
end

function [wavelet,cycles,freqresol,timeresol] = dftfilt3( freqs, cycles, srate, varargin)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Rey fixed all input parameter sorting. 
    varargin(1:2:end)=lower(varargin(1:2:end));
    numargin = numel(varargin);
    
    % Setting default parameter values.
    cycleinc='linear';
    winsize=[];
    timesupport=7;  % Setting default of 7 temporal standard deviations for wavelet's length.

    for n=1:2:numargin
        keyword=varargin{n};
        if strcmpi('cycleinc',keyword)
            cycleinc=varargin{n+1};
        elseif strcmpi('winsize',keyword)
            winsize=varargin{n+1};
            if ~mod(winsize,2)
                winsize=winsize+1; % Always set to odd length wavelets and hanning windows;
            end
        elseif strcmpi('timesupport',keyword)
            timesupport=varargin{n+1};     
        else
            error(['What is ' keyword '? The only legal keywords are: type, cycleinc, winsize, or timesupport.'])
        end
    end
    if isempty(winsize) && cycles(1)==0
        error('If you are using a Hanning tapered FFT, please supply the winsize input-pair.')
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % compute number of cycles at each frequency
    % ------------------------------------------
    type='morlet';
    if length(cycles) == 1 && cycles(1)~=0
        cycles = cycles*ones(size(freqs));
    elseif length(cycles) == 2
        if strcmpi(cycleinc, 'log') % cycleinc
             cycles = linspace(log(cycles(1)), log(cycles(2)), length(freqs));
             cycles = exp(cycles);
             %cycles=logspace(log10(cycles(1)),log10(cycles(2)),length(freqs)); %rey
        else
            cycles = linspace(cycles(1), cycles(2), length(freqs));
        end
    end
    if cycles==0
        type='sinus';
    end

    sp=1/srate; % Rey added this line (i.e., sampling period).
    % compute wavelet
    for index = 1:length(freqs)
        fk=freqs(index);
        if strcmpi(type, 'morlet') % Morlet.
            fk=fk/srate; % Normalize frequency for textbook equations as in TB97
            sigf=fk/cycles(index); % Computing time and frequency standard deviations, resolutions, and normalization constant. 
            sigt=1./(2*pi*sigf);
            A=1./sqrt(sigt*sqrt(pi));
            timeresol(index)=2*sigt/srate; %#ok<AGROW> % sec
            freqresol(index)=2*sigf*srate; %#ok<AGROW> % Hz
            if isempty(winsize) % bases will be a cell array.        
    %             tneg=[-sp:-sp:-sigt*timesupport/2];
    %             tpos=[0:sp:sigt*timesupport/2];
    %             t=[fliplr(tneg) tpos];
                t = (0:floor(sigt*timesupport/2)*2)-floor(sigt*timesupport/2); % Always odd; backward compatible
                psi=A.*(exp(-(t.^2)./(2*(sigt^2))).*exp(2i*pi*fk*t));
                wavelet{index}=psi;  %#ok<AGROW> % These are the wavelets with variable number of samples based on temporal standard deviations (sigt).
            else % bases will be a matrix.
    %             tneg=[-sp:-sp:-sp*winsize/2];
    %             tpos=[0:sp:sp*winsize/2];
    %             t=[fliplr(tneg) tpos];
                t = (0:floor(winsize/2)*2)-floor(winsize/2); % Always odd; backward compatible
                psi=A.*(exp(-(t.^2)./(2*(sigt^2))).*exp(2i*pi*fk*t));
                wavelet(index,:)=psi; %#ok<AGROW> % These are the wavelets with the same length.                                 
                % This is useful for doing time-frequency analysis as a matrix vector or matrix matrix multiplication.
            end
        elseif strcmpi(type, 'sinus') % Hanning
            tneg=-sp:-sp:-sp*winsize/2;
            tpos=0:sp:sp*winsize/2;
            t=[fliplr(tneg) tpos];
            win = exp(2i*pi*fk*t);
            wavelet(index,:) = win .* hanning(winsize)';  %#ok<AGROW>
            %wavelet{index} = win .* hanning(winsize)';
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    end
end

% syemtric hanning function
function w = hanning(n)
    if ~rem(n,2)
       w = .5*(1 - cos(2*pi*(1:n/2)'/(n+1)));
       w = [w; w(end:-1:1)];
    else
       w = .5*(1 - cos(2*pi*(1:(n+1)/2)'/(n+1)));
       w = [w; w(end-1:-1:1)];
    end
end
