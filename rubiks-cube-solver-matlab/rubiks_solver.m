function rubiks_solver()
% RUBIKS_SOLVER  Photograph a scrambled 3x3 cube, detect colors, confirm, solve.
%
% Requirements
%   - MATLAB with Image Processing Toolbox (imcrop, rgb2lab)
%   - Python 3 configured in MATLAB (run  pyenv  to check) and the
%     "kociemba" package:   python -m pip install kociemba
%     (this script tries to install it automatically if it is missing)
%
% HOW TO HOLD THE CUBE FOR EACH PHOTO  (standard scheme)
%   Centers:  U=White  R=Red  F=Green  D=Yellow  L=Orange  B=Blue
%   Hold the cube with WHITE on top and GREEN facing you, then:
%     U (white)  : photo from above, GREEN edge at the BOTTOM of the photo
%     R (red)    : turn so red faces you, WHITE edge at the top
%     F (green)  : green faces you, WHITE edge at the top
%     D (yellow) : photo from below, GREEN edge at the TOP of the photo
%     L (orange) : orange faces you, WHITE edge at the top
%     B (blue)   : blue faces you, WHITE edge at the top
%
%   Keep the camera roughly square-on to the face, with even lighting.

clc; close all;
faceOrder   = 'URFDLB';          % Kociemba facelet order
colorLetter = 'WRGYOB';          % color of the CENTER of each face above
faceTitle   = { ...
    'UP    (white center)  - green edge at the BOTTOM of the photo', ...
    'RIGHT (red center)    - white edge at the top', ...
    'FRONT (green center)  - white edge at the top', ...
    'DOWN  (yellow center) - green edge at the TOP of the photo', ...
    'LEFT  (orange center) - white edge at the top', ...
    'BACK  (blue center)   - white edge at the top'};

%% ---------------- 1) ask for the image of each face ----------------
rgbSamples = zeros(6,3,3,3);     % face, row, col, rgb
for f = 1:6
    [fn, fp] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif','Images'}, ...
        ['Select photo of face ' faceOrder(f) ' : ' faceTitle{f}]);
    if isequal(fn,0), error('Cancelled by user.'); end
    img = im2uint8(imread(fullfile(fp,fn)));
    if size(img,3) ~= 3, error('Image must be a color (RGB) image.'); end

    hf = figure('Name',['Crop face ' faceOrder(f)],'NumberTitle','off');
    imshow(img);
    title(['Face ' faceOrder(f) ': drag a box tightly around the 3x3 face, ' ...
           'then DOUBLE-CLICK inside it']);
    crop = imcrop;               % interactive crop
    close(hf);
    if isempty(crop), error('No crop selected for face %s.', faceOrder(f)); end

    [H, W, ~] = size(crop);
    rEdge = round(linspace(0, H, 4));
    cEdge = round(linspace(0, W, 4));
    for r = 1:3
        for c = 1:3
            % sample only the middle 40% of each sticker (avoids borders/glare)
            r0 = rEdge(r); r1 = rEdge(r+1); c0 = cEdge(c); c1 = cEdge(c+1);
            dr = round(0.3*(r1-r0)); dc = round(0.3*(c1-c0));
            patch = crop(r0+dr+1 : r1-dr, c0+dc+1 : c1-dc, :);
            rgbSamples(f,r,c,:) = median(reshape(double(patch),[],3), 1);
        end
    end
end

%% ---------------- 2) identify the colors ----------------
% Each sticker is assigned to the nearest CENTER sticker (in Lab space),
% so lighting and camera differences matter much less.
list = zeros(54,3); k = 0;
for f = 1:6
    for r = 1:3
        for c = 1:3
            k = k + 1;
            list(k,:) = squeeze(rgbSamples(f,r,c,:))' / 255;
        end
    end
end
centerRGB = zeros(6,3);
for f = 1:6, centerRGB(f,:) = squeeze(rgbSamples(f,2,2,:))' / 255; end

labList   = rgb2lab(list);
labCenter = rgb2lab(centerRGB);
w = [0.6 1 1];                                   % de-emphasize lightness
labels = zeros(6,3,3);                           % values 1..6 (index in faceOrder)
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
for f = 1:6, labels(f,2,2) = f; end              % centers are known

%% ---------------- 3) confirm colors with the user ----------------
while true
    showNet(labels, centerRGB, colorLetter);
    ans1 = questdlg(['Do the colors in the unfolded cube match your real cube?' newline ...
        '(W=white R=red G=green Y=yellow O=orange B=blue)'], ...
        'Confirm colors','Yes, all correct','No, fix a face','Yes, all correct');
    if isempty(ans1), error('Cancelled by user.'); end
    if strcmp(ans1,'Yes, all correct'), break; end

    idx = listdlg('PromptString','Which face is wrong?', ...
        'ListString',cellstr(faceTitle(:)), 'SelectionMode','single', 'ListSize',[420 120]);
    if isempty(idx), continue; end
    cur = '';
    for r = 1:3, for c = 1:3, cur(end+1) = colorLetter(labels(idx,r,c)); end, end %#ok<AGROW>
    resp = inputdlg({['Enter the 9 stickers of face ' faceOrder(idx) ...
        ' row by row (left-to-right, top-to-bottom as in the photo), letters W R G Y O B:']}, ...
        'Fix face', 1, {cur});
    if isempty(resp), continue; end
    s = upper(strtrim(resp{1}));
    if numel(s) ~= 9 || any(~ismember(s, colorLetter))
        uiwait(msgbox('Need exactly 9 letters from W R G Y O B.','Invalid','modal'));
        continue;
    end
    n = 0;
    for r = 1:3, for c = 1:3, n = n + 1; labels(idx,r,c) = find(colorLetter == s(n)); end, end
end
close all;

%% ---------------- validate and build the cube string ----------------
cubeStr = '';
for f = 1:6
    for r = 1:3
        for c = 1:3
            cubeStr(end+1) = faceOrder(labels(f,r,c)); %#ok<AGROW>
        end
    end
end
for f = 1:6
    n = sum(cubeStr == faceOrder(f));
    if n ~= 9
        error(['Color %s appears %d times (must be 9). A sticker was misread - ' ...
               'rerun and correct it in the confirmation step.'], colorLetter(f), n);
    end
end
fprintf('Cube state (U R F D L B order):\n  %s\n\n', cubeStr);

%% ---------------- 4) solve and print each turn ----------------
ensureKociemba();
sol = strtrim(char(py.kociemba.solve(cubeStr)));
if startsWith(sol,'Error')
    error(['Solver rejected the cube (%s). This usually means a sticker is ' ...
           'misread or a face photo had the wrong orientation.'], sol);
end
if isempty(sol)
    disp('The cube is already solved!'); return;
end

moves = strsplit(sol);
fprintf('Solution found: %d moves\n  %s\n\n', numel(moves), sol);
fprintf('Hold the cube WHITE on top, GREEN facing you. Face turns are\n');
fprintf('clockwise when looking directly at that face.\n\n');
for i = 1:numel(moves)
    fprintf('%2d. %-3s  %s\n', i, moves{i}, describeMove(moves{i}));
end

if strcmp(questdlg('Step through the moves one at a time?','Solve','Yes','No','Yes'),'Yes')
    for i = 1:numel(moves)
        fprintf('\nMove %d/%d:  %s  -> %s\n', i, numel(moves), moves{i}, describeMove(moves{i}));
        if i < numel(moves), input('   Press Enter for the next move...','s'); end
    end
end
disp('Done - the cube should now be solved.');
end

%% ======================= helper functions =======================
function showNet(labels, centerRGB, colorLetter)
% Draw the unfolded cube using the measured center colors as the palette.
figure(1); clf; set(gcf,'Name','Detected colors','NumberTitle','off');
axis equal off; hold on; set(gca,'YDir','reverse');
origin = [3 0; 6 3; 3 3; 3 6; 0 3; 9 3];        % U R F D L B, [x y] in cells
for f = 1:6
    for r = 1:3
        for c = 1:3
            L = labels(f,r,c);
            rectangle('Position',[origin(f,1)+c-1, origin(f,2)+r-1, 1, 1], ...
                'FaceColor',centerRGB(L,:),'EdgeColor','k','LineWidth',1.5);
            text(origin(f,1)+c-0.5, origin(f,2)+r-0.5, colorLetter(L), ...
                'HorizontalAlignment','center','FontWeight','bold','FontSize',14, ...
                'Color',[0.5 0.5 0.5]);
        end
    end
end
title('Unfolded cube: U on top, then L F R B, then D');
xlim([-0.5 12.5]); ylim([-0.5 9.5]);
end

function txt = describeMove(m)
names = containers.Map({'U','D','L','R','F','B'}, ...
    {'UP (top)','DOWN (bottom)','LEFT','RIGHT','FRONT (facing you)','BACK (far side)'});
face = m(1);
if numel(m) == 1
    amt = '90 degrees clockwise';
elseif m(2) == '2'
    amt = '180 degrees (half turn)';
else
    amt = '90 degrees counter-clockwise';
end
txt = sprintf('Turn the %s face %s', names(face), amt);
end

function ensureKociemba()
pe = pyenv;
if strlength(string(pe.Version)) == 0
    error(['No Python found by MATLAB. Install Python 3, then run  ' ...
           'pyenv(''Version'',''<path to python>'')  and rerun.']);
end
try
    py.importlib.import_module('kociemba');
catch
    disp('Installing the Python "kociemba" package...');
    status = system(['"' char(pe.Executable) '" -m pip install kociemba']);
    if status ~= 0
        error(['Could not install kociemba. See the Troubleshooting section ' ...
               'of the README (Windows needs a prebuilt wheel or C++ Build Tools).']);
    end
    py.importlib.invalidate_caches();
    py.importlib.import_module('kociemba');
end
end
