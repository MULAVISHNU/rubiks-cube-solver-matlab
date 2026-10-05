function rubiks_solver()
% RUBIKS_SOLVER  Photograph a scrambled 3x3 cube, detect colors, confirm, solve.
%
% Requirements
%   - MATLAB R2020b or newer with the Image Processing Toolbox
%   - Python 3 set up for MATLAB (run  pyenv  to check).
%   - MATLAB Support Package for USB Webcams (if using the live camera option).
%
% HOW TO HOLD THE CUBE FOR EACH PHOTO  (standard scheme)
%   Hold the cube with WHITE on top and GREEN facing you, then:
%     W (White)  : photo from above, GREEN edge at the BOTTOM of the photo
%     R (Red)    : turn so red faces you, WHITE edge at the top
%     G (Green)  : green faces you, WHITE edge at the top
%     Y (Yellow) : photo from below, GREEN edge at the TOP of the photo
%     O (Orange) : orange faces you, WHITE edge at the top
%     B (Blue)   : blue faces you, WHITE edge at the top

clc; close all;
faceOrder   = 'WRGYOB';          
colorLetter = 'WRGYOB';          
colorName   = {'White (Up)','Red (Right)','Green (Front)','Yellow (Down)','Orange (Left)','Blue (Back)'};
faceTitle   = { ...
    'UP    (White center)  - green edge at the BOTTOM of the photo', ...
    'RIGHT (Red center)    - white edge at the top', ...
    'FRONT (Green center)  - white edge at the top', ...
    'DOWN  (Yellow center) - green edge at the TOP of the photo', ...
    'LEFT  (Orange center) - white edge at the top', ...
    'BACK  (Blue center)   - white edge at the top'};

% PERFECT STANDARD COLORS FOR GUI AND 3D ANIMATION
standardRGB = [0.95 0.95 0.95; % W (White)
               0.80 0.10 0.10; % R (Red)
               0.10 0.80 0.10; % G (Green)
               0.90 0.90 0.10; % Y (Yellow)
               1.00 0.50 0.10; % O (Orange)
               0.10 0.10 0.80];% B (Blue)

%% ---------------- 0) check everything BEFORE asking for photos ----------------
solveFcn = preflight();          

%% ---------------- 1) Input Method (Camera, Photos, or Manual) ----------------
imgChoice = customQuestdlg('How do you want to input the cube?', 'Input Method', ...
    {'Use Camera', 'One photo', 'Six photos', 'Manual entry'}, ...
    {[0.6 0.3 0.8], [0.3 0.6 0.9], [0.9 0.6 0.2], [0.3 0.8 0.4]}); % Purple, Blue, Orange, Green

if isempty(imgChoice), disp('Cancelled.'); return; end

manualMode = strcmp(imgChoice, 'Manual entry');

if manualMode
    % Skip photos entirely. Pre-fill with a solved cube.
    labels = zeros(6,3,3);
    for f = 1:6
        labels(f,:,:) = f;
    end
    disp('Manual entry selected. Please use the GUI to build your scrambled cube.');
    
else
    %% ---------------- Image / Camera Processing ----------------
    rgbSamples = zeros(6,3,3,3);     
    capturedImages = cell(1,6);

    if strcmp(imgChoice, 'Use Camera')
        try
            cam = webcam;
        catch ME
            errordlg(['Could not connect to a webcam. Make sure the "MATLAB Support Package for USB Webcams" is installed and a camera is connected.' newline newline 'Error: ' ME.message], 'Camera Error');
            return;
        end
        
        % Create Live Camera Capture UI
        hCam = figure('Name', 'Live Camera Capture', 'NumberTitle', 'off', ...
                      'Position', [150 150 800 600], 'MenuBar', 'none', 'Color', [0.18 0.18 0.18]);
        axCam = axes('Parent', hCam, 'Position', [0.05 0.15 0.9 0.75]);
        btnCap = uicontrol('Parent', hCam, 'Style', 'pushbutton', 'String', 'Capture Face', ...
                           'Units', 'normalized', 'Position', [0.35 0.03 0.3 0.08], ...
                           'FontSize', 14, 'FontWeight', 'bold', 'BackgroundColor', [0.2 0.8 0.2]);
        
        for f = 1:6
            set(hCam, 'Name', ['Capture Face: ' faceOrder(f)]);
            set(btnCap, 'String', ['Capture ' colorLetter(f) ' Face']);
            set(btnCap, 'UserData', false);
            set(btnCap, 'Callback', @(s,e) set(s, 'UserData', true));
            
            % Initialize the frame image object for fast updating
            img = snapshot(cam);
            hImg = imshow(img, 'Parent', axCam);
            title(axCam, ['Hold ' faceTitle{f} ' to camera and click Capture'], 'FontSize', 14, 'Color', 'w');
            
            % Fast update loop
            while isgraphics(hCam) && ~get(btnCap, 'UserData')
                img = snapshot(cam);
                set(hImg, 'CData', img);
                drawnow limitrate;
            end
            
            if ~isgraphics(hCam)
                disp('Camera capture cancelled.');
                clear cam;
                return;
            end
            capturedImages{f} = img;
        end
        close(hCam);
        clear cam;
        
    elseif strcmp(imgChoice, 'One photo')
        [fn, fp] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff;*.heic','Images'}, ...
            'Select the SINGLE image containing all 6 faces');
        if isequal(fn,0), disp('Cancelled.'); return; end
        try
            masterImg = im2uint8(imread(fullfile(fp,fn)));
        catch ME
            errordlg(['Could not read that image: ' ME.message],'Image error'); return;
        end
    end

    % Process and Crop each of the 6 inputs
    for f = 1:6
        if strcmp(imgChoice, 'Six photos')
            [fn, fp] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff;*.heic','Images'}, ...
                ['Select photo of face ' faceOrder(f) ' : ' faceTitle{f}]);
            if isequal(fn,0), disp('Cancelled.'); return; end
            try
                img = im2uint8(imread(fullfile(fp,fn)));
            catch ME
                errordlg(['Could not read that image: ' ME.message],'Image error'); return;
            end
        elseif strcmp(imgChoice, 'One photo')
            img = masterImg;
        elseif strcmp(imgChoice, 'Use Camera')
            img = capturedImages{f};
        end
        
        if size(img,3) ~= 3
            errordlg('Please use a color (RGB) photo.','Image error'); return;
        end
        
        hf = figure('Name',['Crop face ' faceOrder(f)],'NumberTitle','off');
        imshow(img);
        title(['Face ' faceOrder(f) ': drag a box tightly around the 3x3 face, ' ...
               'then DOUBLE-CLICK inside it']);
        crop = imcrop;               
        if isvalid(hf), close(hf); end
        
        if isempty(crop) || min(size(crop,1),size(crop,2)) < 9
            errordlg(['No usable crop selected for face ' faceOrder(f) '. Please rerun.'], ...
                'Crop error');
            return;
        end
        
        [H, W, ~] = size(crop);
        rEdge = round(linspace(0, H, 4));
        cEdge = round(linspace(0, W, 4));
        for r = 1:3
            for c = 1:3
                r0 = rEdge(r); r1 = rEdge(r+1); c0 = cEdge(c); c1 = cEdge(c+1);
                dr = round(0.3*(r1-r0)); dc = round(0.3*(c1-c0));
                patch = crop(r0+dr+1 : r1-dr, c0+dc+1 : c1-dc, :);
                rgbSamples(f,r,c,:) = median(reshape(double(patch),[],3), 1);
            end
        end
    end

    %% ---------------- 2) identify the colors ----------------
    list = zeros(54,3); k = 0;
    for f = 1:6
        for r = 1:3
            for c = 1:3
                k = k + 1;
                list(k,:) = squeeze(rgbSamples(f,r,c,:))' / 255;
            end
        end
    end
    
    labList = rgb2lab(list);
    labCenter = rgb2lab(standardRGB);
    
    w = [0.1 1 1]; % Emphasize Hue, ignore lightness/glare                                  
    labels = zeros(6,3,3);                           
    k = 0;
    for f = 1:6
        for r = 1:3
            for c = 1:3
                k = k + 1;
                d = sum(((labCenter - labList(k,:)).*w).^2, 2);
                [~, labels(f,r,c)] = min(d);
            end
        end
    end
    for f = 1:6, labels(f,2,2) = f; end              
end % End of Input block

%% ---------------- 3) confirm colors, validate, solve ----------------
sol = '';
while true
    labels = confirmColors(labels, standardRGB, colorLetter, faceOrder);
    close all;
    if isempty(labels), disp('Cancelled.'); return; end
    
    cubeStr = '';
    for f = 1:6
        for r = 1:3
            for c = 1:3
                cubeStr(end+1) = faceOrder(labels(f,r,c)); %#ok<AGROW>
            end
        end
    end
    
    counts = arrayfun(@(f) sum(cubeStr == faceOrder(f)), 1:6);
    if any(counts ~= 9)
        bad = find(counts ~= 9);
        msg = 'Each color must appear exactly 9 times, but:';
        for b = bad
            msg = [msg newline sprintf('   %s appears %d times', colorName{b}, counts(b))]; %#ok<AGROW>
        end
        msg = [msg newline newline 'Please fix the stickers in the Interactive Editor on the next screen.'];
        uiwait(warndlg(msg,'Sticker count problem','modal'));
        continue;
    end
    
    fprintf('Cube state (W R G Y O B order):\n  %s\n\n', cubeStr);
    
    % Translate custom format to strictly U R F D L B for the python backend
    solverMap = 'URFDLB';
    solverStr = cubeStr;
    for idx = 1:6
        solverStr(cubeStr == faceOrder(idx)) = solverMap(idx);
    end

    if isempty(solveFcn)
        showCubeStringOnly(cubeStr, solverStr); return;
    end
    
    try
        sol = solveFcn(solverStr);
        
        userSol = sol;
        for idx = 1:6
            userSol(sol == solverMap(idx)) = faceOrder(idx);
        end
        sol = userSol;
        
    catch ME
        uiwait(warndlg(['The solver says this cube is impossible:' newline newline ...
            ME.message newline newline ...
            'This almost always means one sticker was misread, or manually painted ' ...
            'incorrectly. Please check the colors again.'], ...
            'Cube rejected','modal'));
        continue;
    end
    break;
end

%% ---------------- 4) print each turn & animate ----------------
if isempty(sol)
    disp('The cube is already solved!'); return;
end
moves = strsplit(sol);
fprintf('Solution found: %d moves\n  %s\n\n', numel(moves), sol);
fprintf('Hold the cube WHITE on top, GREEN facing you.\n\n');

for i = 1:numel(moves)
    fprintf('%2d. %-3s  %s\n', i, moves{i}, describeMove(moves{i}));
end

% Styled prompt for 3D animation
animChoice = customQuestdlg('Step through the moves one at a time with 3D animation?', 'Solve', ...
    {'Yes', 'No'}, {[0.2 0.8 0.4], [0.9 0.3 0.3]}); % Green, Red

if strcmp(animChoice, 'Yes')
    hGraphic = figure('Name', '3D Move Visualization', 'NumberTitle', 'off', 'Color', [0.15 0.15 0.15], 'Position', [200, 200, 800, 700]);
    
    for i = 1:numel(moves)
        fprintf('\nMove %d/%d:  %s  -> %s\n', i, numel(moves), moves{i}, describeMove(moves{i}));
        
        [hPatches, hArrow] = showMoveGraphic3D(labels, standardRGB, moves{i}, hGraphic);
        
        if i <= numel(moves) 
            input('   Press Enter to animate move and continue...','s');
            animateTurn3D(hPatches, hArrow, moves{i});
            labels = applyMove(labels, moves{i});
        end
    end
    fprintf('\nCube Solved!\n');
    showMoveGraphic3D(labels, standardRGB, '', hGraphic);
end
disp('Done - the cube should now be solved.');
end

%% ======================= startup checks =======================
function solveFcn = preflight()
if isempty(which('imcrop')) || isempty(which('rgb2lab'))
    error('rubiks_solver:toolbox', ['This program needs the Image Processing Toolbox ' ...
        '(imcrop, rgb2lab).' newline 'Install it from the Home tab > Add-Ons.']);
end
if verLessThan('matlab','9.9')   
    warning('rubiks_solver:version', 'Tested on R2020b and newer; older versions may not work.');
end
disp('Checking solver setup...');
solveFcn = findSolver();
if isempty(solveFcn)
    choice = customQuestdlg(['No cube solver could be set up automatically.' newline newline ...
        'You can still continue: the program will read your cube and show the ' ...
        '54-letter cube string, which you can paste into any solver.'], ...
        'Solver not available', {'Continue without solver', 'Cancel'}, ...
        {[0.9 0.6 0.2], [0.9 0.3 0.3]}); % Orange, Red
        
    if ~strcmp(choice,'Continue without solver')
        error('rubiks_solver:cancelled','Cancelled by user.');
    end
else
    disp('Solver ready.');
end
end

function fcn = findSolver()
fcn = [];
try
    pe = pyenv;
    havePy = strlength(string(pe.Version)) > 0;
catch
    havePy = false;
end
if ~havePy
    fprintf(['No Python found by MATLAB. Install Python 3.9-3.12 from python.org, ' ...
             'then run  pyenv(''Version'',''<path to python.exe>'')\n']);
    return;
end
exe = pythonExe(pe);
if tryImport('kociemba'), fcn = @solveKociemba; return; end
if ~ispc
    fprintf('Installing "kociemba" (one time)...\n');
    if pipInstall(exe,'kociemba') && tryImport('kociemba')
        fcn = @solveKociemba; return;
    end
end
fprintf(['Loading pure-Python solver. The FIRST run builds lookup tables and can ' ...
         'take several minutes - please wait...\n']);
if ~tryImport('twophase.solver')
    fprintf('Installing "RubikTwoPhase" (one time, needs internet)...\n');
    pipInstall(exe,'RubikTwoPhase');
    try py.importlib.invalidate_caches(); catch, end
    tryImport('twophase.solver');
end
if tryImport('twophase.solver'), fcn = @solveTwoPhase; end
end

function ok = tryImport(name)
try
    py.importlib.import_module(name); ok = true;
catch
    ok = false;
end
end

function exe = pythonExe(pe)
exe = char(pe.Executable);
[folder, name, ext] = fileparts(exe);
if strcmpi(name,'pythonw')
    cand = fullfile(folder,['python' ext]);
    if isfile(cand), exe = cand; end
end
end

function ok = pipInstall(exe, pkg)
cmds = {sprintf('"%s" -m pip install %s', exe, pkg), ...
        sprintf('"%s" -m pip install --user %s', exe, pkg)};
ok = false;
for i = 1:numel(cmds)
    [st, ~] = system(cmds{i});          
    if st == 0, ok = true; return; end
end
end

%% ======================= solver back-ends =======================
function sol = solveKociemba(cubeStr)
sol = strtrim(char(py.kociemba.solve(cubeStr)));
if startsWith(sol,'Error')
    error('rubiks_solver:badcube','%s', sol);
end
end

function sol = solveTwoPhase(cubeStr)
m   = py.importlib.import_module('twophase.solver');
raw = strtrim(char(m.solve(cubeStr, 20, 5)));     
if startsWith(raw,'Error')
    error('rubiks_solver:badcube','%s', raw);
end
raw = strtrim(regexprep(raw,'\(.*?\)',''));       
if isempty(raw), sol = ''; return; end
toks = strsplit(raw);
out  = cell(size(toks));
for i = 1:numel(toks)                              
    f = toks{i}(1); n = toks{i}(2);
    switch n
        case '1', out{i} = f;
        case '2', out{i} = [f '2'];
        case '3', out{i} = [f ''''];
        otherwise, error('rubiks_solver:badcube','Unexpected solver output: %s', raw);
    end
end
sol = strjoin(out,' ');
end

function showCubeStringOnly(cubeStr, solverStr)
try clipboard('copy', solverStr); catch, end %#ok<NOCOM>
fprintf(['\nNo solver is installed, so here is your standard URFDLB cube string (copied to the clipboard):\n' ...
         '  %s\n\nPaste it into any Kociemba-compatible solver.\n'], solverStr);
msgbox(['Standard URFDLB Cube string copied to clipboard:' newline solverStr], 'Cube read');
end

%% ======================= STYLED DIALOG HELPER =======================
function choice = customQuestdlg(prompt, titleStr, btnLabels, btnColors)
    % A sleek custom replacement for questdlg that dynamically fits N buttons
    hFig = figure('Name', titleStr, 'NumberTitle', 'off', ...
                  'Position', [400, 400, 550, 150], 'WindowStyle', 'modal', ...
                  'MenuBar', 'none', 'ToolBar', 'none', 'Color', [0.18 0.18 0.18]);
    
    uicontrol('Style', 'text', 'String', prompt, ...
        'Units', 'normalized', 'Position', [0.05 0.5 0.9 0.4], ...
        'FontSize', 12, 'ForegroundColor', [1 1 1], 'BackgroundColor', [0.18 0.18 0.18], ...
        'HorizontalAlignment', 'center');
    
    choice = '';
    numBtns = numel(btnLabels);
    
    % Dynamic button width and spacing calculations
    gap = 0.02;
    btnWidth = (0.9 - gap*(numBtns-1)) / numBtns;
    startX = 0.05;
    
    for i = 1:numBtns
        uicontrol('Style', 'pushbutton', 'String', btnLabels{i}, ...
            'Units', 'normalized', 'Position', [startX + (i-1)*(btnWidth+gap), 0.15, btnWidth, 0.3], ...
            'FontSize', 11, 'FontWeight', 'bold', 'BackgroundColor', btnColors{i}, ...
            'ForegroundColor', [0 0 0], 'Callback', @(s,e) setChoice(btnLabels{i}));
    end
    
    set(hFig, 'CloseRequestFcn', @(s,e) setChoice(''));
    uiwait(hFig);
    
    function setChoice(val)
        choice = val;
        uiresume(hFig);
        delete(hFig);
    end
end

%% ======================= INTERACTIVE UI HELPERS =======================
function labels = confirmColors(labels, standardRGB, colorLetter, faceOrder)
    hFig = figure('Name','Interactive Cube Editor', 'NumberTitle','off', ...
                  'Position',[150 150 850 600], 'WindowStyle','modal', 'MenuBar','none', 'Color', [0.18 0.18 0.18]);
              
    workLabels = labels;
    activeColor = 1; % Default to 'W'
    
    ax = axes('Position', [0.2 0.1 0.75 0.8]);
    axis equal off; hold on; set(gca,'YDir','reverse');
    xlim([-1 13]); ylim([-1 10]);
    
    title('Interactive Editor: Select a color on the left, then click a square to paint it.', ...
        'FontSize', 14, 'FontWeight', 'bold', 'Color', 'w', 'Units', 'normalized', 'Position', [0.5, 1.05, 0]);
    
    text(4, -1, 'UP (W)', 'HorizontalAlignment','center', 'FontWeight','bold', 'Color', 'w');
    text(7, 2, 'RIGHT (R)', 'HorizontalAlignment','center', 'FontWeight','bold', 'Color', 'w');
    text(4, 2, 'FRONT (G)', 'HorizontalAlignment','center', 'FontWeight','bold', 'Color', 'w');
    text(4, 9, 'DOWN (Y)', 'HorizontalAlignment','center', 'FontWeight','bold', 'Color', 'w');
    text(1, 2, 'LEFT (O)', 'HorizontalAlignment','center', 'FontWeight','bold', 'Color', 'w');
    text(10, 2, 'BACK (B)', 'HorizontalAlignment','center', 'FontWeight','bold', 'Color', 'w');
    
    bg = uibuttongroup('Position',[0.02 0.2 0.15 0.6], 'Title','Color Palette', ...
                       'SelectionChangedFcn',@colorSelected, 'FontSize', 12, 'FontWeight', 'bold', ...
                       'BackgroundColor', [0.18 0.18 0.18], 'ForegroundColor', 'w');
    
    for i = 1:6
        tc = [0 0 0]; 
        if mean(standardRGB(i,:)) < 0.5, tc = [1 1 1]; end
        
        uicontrol(bg, 'Style','radiobutton', 'String', [' ' colorLetter(i)], ...
            'Units','normalized', 'Position',[0.1, 1 - i*0.16, 0.8, 0.14], ...
            'BackgroundColor', standardRGB(i,:), 'ForegroundColor', tc, ...
            'UserData', i, 'FontSize', 14, 'FontWeight', 'bold');
    end
    
    origin = [3 0; 6 3; 3 3; 3 6; 0 3; 9 3]; 
    patchHandles = cell(6,3,3);
    textHandles = cell(6,3,3);
    
    for f = 1:6
        for r = 1:3
            for c = 1:3
                x = origin(f,1) + c - 1;
                y = origin(f,2) + r - 1;
                L = workLabels(f,r,c);
                
                % HitTest ON enables clicks on squares, PickableParts ALL ensures they register
                patchHandles{f,r,c} = patch([x x+1 x+1 x], [y y y+1 y+1], standardRGB(L,:), ...
                    'EdgeColor','k', 'LineWidth',1.5, 'HitTest', 'on', 'PickableParts', 'all', ...
                    'ButtonDownFcn', {@faceletClick, f, r, c});
                
                % HitTest OFF and PickableParts NONE makes text transparent to mouse clicks
                tc = [0 0 0]; if mean(standardRGB(L,:)) < 0.5, tc = [1 1 1]; end
                textHandles{f,r,c} = text(x+0.5, y+0.5, colorLetter(L), ...
                    'HorizontalAlignment','center', 'FontWeight','bold', 'FontSize',14, ...
                    'Color',tc, 'HitTest','off', 'PickableParts','none'); 
            end
        end
    end
    
    uicontrol('Style','pushbutton', 'String','Confirm & Solve', ...
        'Units','normalized', 'Position',[0.3 0.02 0.2 0.08], ...
        'FontSize', 12, 'FontWeight', 'bold', 'BackgroundColor', [0.2 0.8 0.2], ...
        'Callback', @(s,e) uiresume(hFig));
        
    uicontrol('Style','pushbutton', 'String','Cancel', ...
        'Units','normalized', 'Position',[0.6 0.02 0.2 0.08], ...
        'FontSize', 12, 'FontWeight', 'bold', 'BackgroundColor', [0.9 0.3 0.3], ...
        'Callback', @cancelCb);
        
    uiwait(hFig);
    
    if ~isvalid(hFig)
        labels = []; 
        return;
    end
    
    labels = workLabels;
    delete(hFig);
    
    function colorSelected(~, event)
        activeColor = event.NewValue.UserData;
    end
    
    function faceletClick(~, ~, f, r, c)
        if r == 2 && c == 2, return; end
        workLabels(f,r,c) = activeColor;
        set(patchHandles{f,r,c}, 'FaceColor', standardRGB(activeColor,:));
        tcNew = [0 0 0]; if mean(standardRGB(activeColor,:)) < 0.5, tcNew = [1 1 1]; end
        set(textHandles{f,r,c}, 'String', colorLetter(activeColor), 'Color', tcNew);
        drawnow; 
    end
    
    function cancelCb(~, ~)
        workLabels = [];
        uiresume(hFig);
        delete(hFig);
    end
end

function txt = describeMove(m)
names = containers.Map({'W','Y','O','R','G','B'}, ...
    {'UP (White)','DOWN (Yellow)','LEFT (Orange)','RIGHT (Red)','FRONT (Green)','BACK (Blue)'});
face = m(1);
if numel(m) == 1
    amt = '90 degrees clockwise (1/4 turn right)';
elseif m(2) == '2'
    amt = '180 degrees (a half turn)';
else
    amt = '90 degrees counter-clockwise (1/4 turn left)';
end
txt = sprintf('Turn the %s face %s.', names(face), amt);
end

%% ======================= 3D Graphical Helpers =======================
function [hPatches, hArrow] = showMoveGraphic3D(labels, standardRGB, move, hFig)
figure(hFig); clf; hold on; 
view(3); axis equal off;

e = [-1.5, -0.5, 0.5, 1.5];
er = [1.5, 0.5, -0.5, -1.5];

hPatches = gobjects(54, 1);
idx = 1;

for f = 1:6
    for r = 1:3
        for c = 1:3
            color = standardRGB(labels(f,r,c),:);
            switch f
                case 1 % W (Up)
                    X = [e(c) e(c+1) e(c+1) e(c)]; Y = [er(r) er(r) er(r+1) er(r+1)]; Z = [1.5 1.5 1.5 1.5];
                case 2 % R (Right)
                    X = [1.5 1.5 1.5 1.5]; Y = [e(c) e(c+1) e(c+1) e(c)]; Z = [er(r) er(r) er(r+1) er(r+1)];
                case 3 % G (Front)
                    X = [e(c) e(c+1) e(c+1) e(c)]; Y = [-1.5 -1.5 -1.5 -1.5]; Z = [er(r) er(r) er(r+1) er(r+1)];
                case 4 % Y (Down)
                    X = [e(c) e(c+1) e(c+1) e(c)]; Y = [e(r) e(r) e(r+1) e(r+1)]; Z = [-1.5 -1.5 -1.5 -1.5];
                case 5 % O (Left)
                    X = [-1.5 -1.5 -1.5 -1.5]; Y = [er(c) er(c+1) er(c+1) er(c)]; Z = [er(r) er(r) er(r+1) er(r+1)];
                case 6 % B (Back)
                    X = [er(c) er(c+1) er(c+1) er(c)]; Y = [1.5 1.5 1.5 1.5]; Z = [er(r) er(r) er(r+1) er(r+1)];
            end
            hPatches(idx) = patch(X, Y, Z, color, 'EdgeColor', 'k', 'LineWidth', 2);
            idx = idx + 1;
        end
    end
end

hArrow = gobjects(0);

if isempty(move)
    title('Cube Solved!', 'Color', 'w', 'FontSize', 18, 'FontWeight', 'bold');
    camtarget([0 0 0]); campos([10, -10, 8]); camva(25);
    drawnow; return;
end

faceChar = move(1);
moveType = 'cw';
if numel(move) > 1
    if move(2) == '2', moveType = '2'; end
    if move(2) == '''', moveType = 'ccw'; end
end

rArrow = 1.3;
if strcmp(moveType, 'cw')
    th = linspace(135, 45, 100) * pi/180;
elseif strcmp(moveType, 'ccw')
    th = linspace(45, 135, 100) * pi/180;
else
    th = linspace(180, 0, 150) * pi/180;
end

ax = rArrow * cos(th); ay = rArrow * sin(th); az = zeros(size(ax));

dx = ax(end) - ax(end-1); dy = ay(end) - ay(end-1);
L = norm([dx, dy]); dx = dx/L * 0.4; dy = dy/L * 0.4;
px = -dy * 0.5; py = dx * 0.5;
tipX = [ax(end)-dx+px, ax(end), ax(end)-dx-px];
tipY = [ay(end)-dy+py, ay(end), ay(end)-dy-py];
tipZ = [0 0 0];

switch faceChar
    case 'W', R = eye(3); T = [0; 0; 1.8]; cam_p = [7, -7, 10];
    case 'Y', R = [1 0 0; 0 -1 0; 0 0 -1]; T = [0; 0; -1.8]; cam_p = [7, -7, -10];
    case 'G', R = [1 0 0; 0 0 -1; 0 1 0]; T = [0; -1.8; 0]; cam_p = [5, -12, 6];
    case 'B', R = [-1 0 0; 0 0 1; 0 1 0]; T = [0; 1.8; 0]; cam_p = [-5, 12, 6];
    case 'R', R = [0 0 1; 1 0 0; 0 1 0]; T = [1.8; 0; 0]; cam_p = [12, 5, 6];
    case 'O', R = [0 0 -1; -1 0 0; 0 1 0]; T = [-1.8; 0; 0]; cam_p = [-12, -5, 6];
end

camtarget([0 0 0]); campos(cam_p); camva(25);

pts = R * [ax; ay; az] + T;
hArrow(1) = plot3(pts(1,:), pts(2,:), pts(3,:), 'k', 'LineWidth', 9);
hArrow(2) = plot3(pts(1,:), pts(2,:), pts(3,:), 'w', 'LineWidth', 4);

tipPts = R * [tipX; tipY; tipZ] + T;
hArrow(3) = fill3(tipPts(1,:), tipPts(2,:), tipPts(3,:), 'w', 'EdgeColor', 'k', 'LineWidth', 1.5);

title(['Step: Apply Move ' move], 'Color', 'w', 'FontSize', 16, 'FontWeight', 'bold');
drawnow;
end

function animateTurn3D(hPatches, hArrow, move)
    if ~isempty(hArrow) && any(isgraphics(hArrow))
        delete(hArrow(isgraphics(hArrow)));
    end

    faceChar = move(1);
    moveType = 'cw';
    if numel(move) > 1
        if move(2) == '2', moveType = '2'; end
        if move(2) == '''', moveType = 'ccw'; end
    end

    switch faceChar
        case 'W', ax = 'Z'; angDir = -90; sliceTest = @(c) c(3) > 0.5;
        case 'Y', ax = 'Z'; angDir = 90;  sliceTest = @(c) c(3) < -0.5;
        case 'R', ax = 'X'; angDir = 90;  sliceTest = @(c) c(1) > 0.5;
        case 'O', ax = 'X'; angDir = -90; sliceTest = @(c) c(1) < -0.5;
        case 'G', ax = 'Y'; angDir = 90;  sliceTest = @(c) c(2) < -0.5;
        case 'B', ax = 'Y'; angDir = -90; sliceTest = @(c) c(2) > 0.5;
    end

    if strcmp(moveType, 'ccw'), angDir = -angDir; end
    if strcmp(moveType, '2'), angDir = angDir * 2; end

    activePatches = [];
    for i = 1:numel(hPatches)
        p = hPatches(i);
        if ~isgraphics(p), continue; end
        centerPt = [mean(p.XData), mean(p.YData), mean(p.ZData)];
        if sliceTest(centerPt)
            activePatches = [activePatches, p]; %#ok<AGROW>
        end
    end

    frames = 30;
    if strcmp(moveType, '2'), frames = 45; end
    dTheta = (angDir / frames) * (pi / 180);

    switch ax
        case 'X', R = [1 0 0; 0 cos(dTheta) -sin(dTheta); 0 sin(dTheta) cos(dTheta)];
        case 'Y', R = [cos(dTheta) 0 sin(dTheta); 0 1 0; -sin(dTheta) 0 cos(dTheta)];
        case 'Z', R = [cos(dTheta) -sin(dTheta) 0; sin(dTheta) cos(dTheta) 0; 0 0 1];
    end

    for f = 1:frames
        for p = activePatches
            v = [p.XData(:)'; p.YData(:)'; p.ZData(:)'];
            v_new = R * v;
            p.XData = v_new(1, :)'; p.YData = v_new(2, :)'; p.ZData = v_new(3, :)';
        end
        drawnow limitrate;
    end
end

%% ======================= Cube State Permutation =======================
function labels = applyMove(labels, move)
    arr = zeros(1, 54);
    idx = 1;
    for f = 1:6
        for r = 1:3
            for c = 1:3
                arr(idx) = labels(f, r, c);
                idx = idx + 1;
            end
        end
    end

    faceChar = move(1);
    num = 1;
    if numel(move) > 1
        if move(2) == '2', num = 2; end
        if move(2) == '''', num = 3; end 
    end

    faceIdx = @(f) (f-1)*9 + (1:9);

    for rot = 1:num
        newArr = arr;
        switch faceChar
            case 'W' % U
                newArr(faceIdx(1)) = rotFace(arr(faceIdx(1)));
                newArr(10:12) = arr(46:48); newArr(46:48) = arr(37:39);
                newArr(37:39) = arr(19:21); newArr(19:21) = arr(10:12);
            case 'R' % R
                newArr(faceIdx(2)) = rotFace(arr(faceIdx(2)));
                u_idx=[9 6 3]; b_idx=[46 49 52]; d_idx=[36 33 30]; f_idx=[27 24 21];
                newArr(u_idx) = arr(f_idx); newArr(f_idx) = arr(d_idx);
                newArr(d_idx) = arr(b_idx); newArr(b_idx) = arr(u_idx);
            case 'G' % F
                newArr(faceIdx(3)) = rotFace(arr(faceIdx(3)));
                u_idx=[7 8 9]; r_idx=[10 13 16]; d_idx=[30 29 28]; l_idx=[45 42 39];
                newArr(u_idx) = arr(l_idx); newArr(l_idx) = arr(d_idx);
                newArr(d_idx) = arr(r_idx); newArr(r_idx) = arr(u_idx);
            case 'Y' % D
                newArr(faceIdx(4)) = rotFace(arr(faceIdx(4)));
                newArr(16:18) = arr(25:27); newArr(25:27) = arr(43:45);
                newArr(43:45) = arr(52:54); newArr(52:54) = arr(16:18);
            case 'O' % L
                newArr(faceIdx(5)) = rotFace(arr(faceIdx(5)));
                u_idx=[1 4 7]; f_idx=[19 22 25]; d_idx=[28 31 34]; b_idx=[54 51 48];
                newArr(u_idx) = arr(b_idx); newArr(b_idx) = arr(d_idx);
                newArr(d_idx) = arr(f_idx); newArr(f_idx) = arr(u_idx);
            case 'B' % B
                newArr(faceIdx(6)) = rotFace(arr(faceIdx(6)));
                u_idx=[3 2 1]; l_idx=[37 40 43]; d_idx=[34 35 36]; r_idx=[18 15 12];
                newArr(u_idx) = arr(r_idx); newArr(r_idx) = arr(d_idx);
                newArr(d_idx) = arr(l_idx); newArr(l_idx) = arr(u_idx);
        end
        arr = newArr;
    end

    idx = 1;
    for f = 1:6
        for r = 1:3
            for c = 1:3
                labels(f, r, c) = arr(idx);
                idx = idx + 1;
            end
        end
    end
end

function f = rotFace(f)
    f = f([7 4 1 8 5 2 9 6 3]);
end