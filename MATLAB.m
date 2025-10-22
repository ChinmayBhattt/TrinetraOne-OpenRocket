% analyzeOpenRocket.m
% Load and analyze OpenRocket exported CSV (robust to different column names)
% Save: place 'flightData.csv' in current folder before running.
% Author: for Chinmay

%% ------------ Load file ------------
fname = 'flightData.csv';
if ~isfile(fname)
    error('File "%s" not found in current folder. Export CSV from OpenRocket and place it here.', fname);
end
T = readtable(fname);
cols = T.Properties.VariableNames;
fprintf('Loaded %s with %d columns.\n', fname, numel(cols));
disp(cols');

%% ------------ Helper: find column by keywords ------------
findCol = @(keywords) ...
    ( find( cellfun(@(c) any(contains(lower(c), lower(keywords))), cols), 1, 'first') );

% Common tries
iTime = findCol({'time','t_'});
iAlt  = findCol({'alt','altitude','height'});
iVel  = findCol({'vel','velocity','speed'});
iAcc  = findCol({'acc','acceleration'});
iCG   = findCol({'cg','center_of_gravity','center of gravity'});
iCP   = findCol({'cp','center_of_pressure','center of pressure'});

% If columns not found, show message
if isempty(iTime)
    error('Could not find a Time column. Columns found: %s', strjoin(cols,', '));
end

% Read vectors (use safe fallback if not present)
time = T{:, iTime};
if ~isempty(iAlt), alt = T{:, iAlt}; else alt = nan(size(time)); end
if ~isempty(iVel), vel = T{:, iVel}; else vel = nan(size(time)); end
if ~isempty(iAcc), acc = T{:, iAcc}; else acc = nan(size(time)); end
if ~isempty(iCG), cg = T{:, iCG}; else cg = []; end
if ~isempty(iCP), cp = T{:, iCP}; else cp = []; end

%% ------------ Basic plots ------------
% 1) Altitude vs Time
figure('Name','Altitude vs Time','Color','w');
if all(isnan(alt))
    text(0.5,0.5,'No altitude data found in CSV','HorizontalAlignment','center');
    title('Altitude vs Time (no data)');
else
    plot(time, alt, 'LineWidth', 1.8);
    xlabel('Time (s)'); ylabel('Altitude (m)');
    title('Altitude vs Time'); grid on;
end

% 2) Velocity and Acceleration
figure('Name','Velocity & Acceleration','Color','w');
subplot(2,1,1);
if all(isnan(vel))
    text(0.5,0.5,'No velocity data found','HorizontalAlignment','center');
    title('Velocity vs Time (no data)');
else
    plot(time, vel, 'LineWidth', 1.5); xlabel('Time (s)'); ylabel('Velocity (m/s)');
    title('Velocity vs Time'); grid on;
end
subplot(2,1,2);
if all(isnan(acc))
    text(0.5,0.5,'No acceleration data found','HorizontalAlignment','center');
    title('Acceleration vs Time (no data)');
else
    plot(time, acc, 'LineWidth', 1.5); xlabel('Time (s)'); ylabel('Acceleration (m/s^2)');
    title('Acceleration vs Time'); grid on;
end

%% ------------ Key metrics ------------
fprintf('\n---- Key Flight Metrics ----\n');
if ~all(isnan(alt))
    [maxAlt, idxAlt] = max(alt);
    fprintf('Peak altitude: %.2f m at t = %.2f s\n', maxAlt, time(idxAlt));
else
    fprintf('Peak altitude: N/A\n');
end
if ~all(isnan(vel))
    [maxVel, idxVel] = max(vel);
    fprintf('Max velocity: %.2f m/s at t = %.2f s\n', maxVel, time(idxVel));
else
    fprintf('Max velocity: N/A\n');
end
if ~all(isnan(acc))
    [maxAcc, idxAcc] = max(acc);
    fprintf('Peak acceleration: %.2f m/s^2 at t = %.2f s\n', maxAcc, time(idxAcc));
else
    fprintf('Peak acceleration: N/A\n');
end
fprintf('Total recorded time: %.2f s\n', time(end));

%% ------------ CG/CP and Static Margin (if available) ------------
if ~isempty(cg) && ~isempty(cp)
    figure('Name','CG & CP / Static margin','Color','w');
    subplot(2,1,1);
    plot(time, cg, '-','LineWidth',1.5); hold on;
    plot(time, cp, '--','LineWidth',1.5); hold off;
    legend('CG','CP'); xlabel('Time (s)'); ylabel('Position (m)');
    title('CG and CP vs Time'); grid on;
    
    % Static margin in calibers: need body diameter (ask user if not known)
    prompt = 'Enter body outer diameter in meters (e.g., 0.06): ';
    bodyD = input(prompt);
    static_margin = (cg - cp) ./ bodyD; % positive = CG ahead of CP
    subplot(2,1,2);
    plot(time, static_margin, 'LineWidth',1.5);
    xlabel('Time (s)'); ylabel('Static margin (calibers)');
    title('Static margin vs Time'); grid on;
    
    % print initial static margin
    fprintf('\nInitial static margin (at t=0): %.2f calibers\n', static_margin(1));
else
    fprintf('\nCG/CP data not found in CSV. Skipping static margin.\n');
end

%% ------------ Parachute sizing helper ------------
fprintf('\n---- Parachute sizing helper ----\n');
% Ask user for total mass if they want parachute calc
doPar = input('Do you want parachute diameter calc? (y/n): ','s');
if strcmpi(doPar,'y')
    m = input('Enter total descent mass in kg (rocket + recovery gear): ');
    Vdes = input('Desired descent speed in m/s (e.g., 5): ');
    Cd = input('Estimated parachute Cd (default 1.5): ');
    if isempty(Cd), Cd = 1.5; end
    g = 9.81; rho = 1.225;
    D = sqrt((8*m*g)/(rho*pi*Cd*Vdes^2));
    fprintf('Recommended parachute diameter: %.2f m (for V=%.2f m/s)\n', D, Vdes);
end

%% ------------ Save figures optionally ------------
saveOpt = input('Save generated figures as PNG? (y/n): ','s');
if strcmpi(saveOpt,'y')
    figs = findall(0,'Type','figure');
    for k = 1:numel(figs)
        fnameOut = sprintf('figure_%02d.png', k);
        saveas(figs(k), fnameOut);
        fprintf('Saved %s\n', fnameOut);
    end
end

fprintf('\nAnalysis complete.\n');
