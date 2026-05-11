clc
clear all
close all

%% Ramp Time / Ramp Rate simulation
% Based on EPRI 3002008217 "Common Functions for Smart Inverters" 4th Ed.
% Section 4 (WGra, Real Power Ramp Rate Settings) and Section 6/7/8
% (Ramp Time - Output/Input Inc/Dec).
%
% Intended for use as a power-setpoint signal source feeding a Simulink
% LV-network inverter model. Outputs a time-series of P [W] and Q [VAR]
% (Q optional) that can be exported via "From Workspace" / "Signal Editor"
% blocks or computed in real time by ramp_apply.m inside a MATLAB
% Function block.
%
% Two equivalent EPRI representations are supported:
%   1. Ramp Time  Tr [s]   -> seconds to reach full new setpoint
%   2. Ramp Rate  WGra [%/s] -> percent of WMax per second
%   Relationship: WGra = |P_new - P_old| / Tr           (if Tr known)
%                 Tr   = |P_new - P_old| / WGra         (if WGra known)
%
% Four EPRI ramp varieties:
%   - Output Increasing  (generating more, e.g. PV ramp-up)
%   - Output Decreasing  (curtailment, discharge slow-down)
%   - Input  Increasing  (storage absorbing more from grid)
%   - Input  Decreasing  (storage absorbing less)

%% ------------------------------------------------------------------
%% Inverter nameplate (LV scale: typical residential / small commercial)
%% ------------------------------------------------------------------
WMax        = 5000;        % rated apparent/active power [W]   (5 kW LV)
Vnom        = 230;         % LV phase voltage [V]
freq        = 50;          % Hz
dt          = 0.01;        % sim step [s]    (100 Hz, OK for slow ramps)
tEnd        = 120;         % total sim duration [s]
t           = (0:dt:tEnd).';

%% ------------------------------------------------------------------
%% Default ramp settings (EPRI Section 4 / Table 4-3)
%% ------------------------------------------------------------------
WGra_default       = 10;   % %/s, default if no specific Tr given
WGra_out_increase  = 20;   % %/s, Output Inc  (e.g. PV recovery)
WGra_out_decrease  = 40;   % %/s, Output Dec  (faster curtailment)
WGra_in_increase   = 15;   % %/s, Input  Inc  (storage absorbing)
WGra_in_decrease   = 30;   % %/s, Input  Dec

%% ------------------------------------------------------------------
%% Setpoint schedule (step changes to drive the ramps)
%% Sign convention: +P = output (export to grid)
%%                  -P = input  (import / charging)
%% ------------------------------------------------------------------
% time [s]   P_target [% WMax]   direction tag
schedule = [
    0      0     "init"
    5    100     "out_inc"      % cold start -> full export
    35    60     "out_dec"      % curtail to 60 %
    55   -80     "in_inc"       % switch to charging at 80 %
    80   -30     "in_dec"       % reduce charging
   100     0     "out_dec"      % settle to zero
];

%% ------------------------------------------------------------------
%% Build setpoint signal with EPRI-style ramps
%% ------------------------------------------------------------------
P_pct = zeros(size(t));    % output in % of WMax
P_cur = 0;                 % current applied setpoint
seg_start_idx = 1;

for s = 1:size(schedule,1)-1
    t_step   = double(schedule(s,1));
    P_target = double(schedule(s+1,2));
    P_from   = double(schedule(s  ,2));
    tag      = schedule(s+1,3);

    % pick ramp rate per EPRI direction
    WGra = pick_wgra(P_from, P_target, ...
                     WGra_out_increase, WGra_out_decrease, ...
                     WGra_in_increase,  WGra_in_decrease, ...
                     WGra_default);

    Tr = abs(P_target - P_from) / WGra;                    % ramp time [s]
    t_next = double(schedule(s+1,1));

    fprintf('Seg %d (%s): %+5.1f%% -> %+5.1f%% over Tr = %5.2f s (WGra = %4.1f %%/s)\n', ...
            s, tag, P_from, P_target, Tr, WGra);

    for k = 1:length(t)
        if t(k) < double(schedule(s,1)),   continue; end
        if t(k) > t_next,                  continue; end

        if t(k) < t_step + Tr
            frac     = (t(k) - t_step) / Tr;
            P_pct(k) = P_from + frac * (P_target - P_from);
        else
            P_pct(k) = P_target;
        end
    end
end
% hold final value
P_pct(t >= double(schedule(end,1))) = double(schedule(end,2));

%% ------------------------------------------------------------------
%% Convert to physical units for Simulink LV inverter
%% ------------------------------------------------------------------
P_watts = (P_pct/100) * WMax;     % [W]
Q_vars  = zeros(size(P_watts));   % [VAR] (extend later for volt-var)

% Pack into Simulink-friendly structures
P_signal.time         = t;
P_signal.signals.values = P_watts;
P_signal.signals.dimensions = 1;

Q_signal.time         = t;
Q_signal.signals.values = Q_vars;
Q_signal.signals.dimensions = 1;

% Save for "From File" / "From Workspace" Simulink blocks
save('ramp_setpoint.mat', 'P_signal', 'Q_signal', 't', 'P_watts', ...
     'Q_vars', 'WMax', 'Vnom', 'freq');

fprintf('\nSaved ramp_setpoint.mat for Simulink import.\n');
fprintf('  Use "From Workspace" block with variable: P_signal\n');

%% ------------------------------------------------------------------
%% Plot
%% ------------------------------------------------------------------
figure('Name','EPRI Ramp Time / Ramp Rate','Color','w');

subplot(2,1,1);
plot(t, P_pct, 'b', 'LineWidth', 1.8); hold on;
stairs(double(schedule(:,1)), double(schedule(:,2)), '--r', 'LineWidth', 1.0);
yline(0, ':k');
grid on; ylim([-110 110]);
xlabel('Time [s]'); ylabel('P [% of WMax]');
title('EPRI ramp-time response (blue = applied, red dashed = commanded step)');
legend({'applied (ramped)','commanded step'}, 'Location','best');

subplot(2,1,2);
plot(t, P_watts, 'b', 'LineWidth', 1.6);
grid on;
xlabel('Time [s]'); ylabel('P [W]');
title(sprintf('Physical setpoint for LV inverter (WMax = %d W)', WMax));

%% ==================================================================
%% local helper: choose WGra by EPRI direction
%% ==================================================================
function WGra = pick_wgra(P_from, P_to, wOutInc, wOutDec, wInInc, wInDec, wDef)
    if (P_to >= 0) && (P_from >= 0)
        % both output side
        if P_to >  P_from, WGra = wOutInc; return; end
        if P_to <  P_from, WGra = wOutDec; return; end
    elseif (P_to <= 0) && (P_from <= 0)
        % both input side (more negative = more charging)
        if P_to <  P_from, WGra = wInInc;  return; end
        if P_to >  P_from, WGra = wInDec;  return; end
    else
        % crossing zero: use the dominant side of the destination
        if P_to >= 0,  WGra = wOutInc;
        else,          WGra = wInInc;
        end
        return;
    end
    WGra = wDef;
end
