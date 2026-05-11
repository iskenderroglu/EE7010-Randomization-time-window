clc
clear all
close all

%% Randomization Time Window simulation
% Based on EPRI 3002008217 "Common Functions for Smart Inverters" 4th Ed.
%
% Per spec:
%   - Randomization Time Window (Tw): a time in seconds over which the DER
%     randomly delays before applying a new setting. Each DER picks a delay
%     uniformly in [0, Tw], so a broadcast command to N DERs avoids
%     simultaneous response.
%   - Ramp Time (Tr): after delay, the DER linearly transitions from the
%     previous setting to the new setting over Tr seconds.
%   - Reconnect (Sec 16): after voltage/frequency returns to nominal, the
%     DER waits TDelay + Rnd(TWindow) before reconnecting, then ramps over
%     TRamp.

%% ------------------------------------------------------------------
%% Parameters
%% ------------------------------------------------------------------
randomization_time_upperlimit = 60;   % Tw, seconds   (EPRI default-like)
ramp_time                     = 10;   % Tr, seconds
N_DER                         = 20;   % number of DERs receiving broadcast

t_broadcast = 5;                      % command issued at t = 5 s
P_old       = 100;                    % previous power setting [% of WMax]
P_new       = 40;                     % new power setting       [% of WMax]

dt   = 0.1;                           % simulation time step [s]
tEnd = t_broadcast + randomization_time_upperlimit + ramp_time + 10;
t    = 0:dt:tEnd;

rng('default');                       % reproducible

%% ------------------------------------------------------------------
%% 1) Single-DER randomization time window
%% ------------------------------------------------------------------
random_action_time = randi([0, randomization_time_upperlimit]);   % [0, Tw]
t_apply_single     = t_broadcast + random_action_time;
fprintf('Single DER: random delay = %d s, applies at t = %.1f s\n', ...
        random_action_time, t_apply_single);

P_single = P_old * ones(size(t));
for k = 1:length(t)
    if t(k) < t_apply_single
        P_single(k) = P_old;
    elseif t(k) < t_apply_single + ramp_time
        % linear ramp from P_old to P_new over ramp_time
        frac        = (t(k) - t_apply_single) / ramp_time;
        P_single(k) = P_old + frac * (P_new - P_old);
    else
        P_single(k) = P_new;
    end
end

%% ------------------------------------------------------------------
%% 2) Fleet of N DERs, each with its own random delay (broadcast case)
%% ------------------------------------------------------------------
delays  = randi([0, randomization_time_upperlimit], 1, N_DER);
P_fleet = zeros(N_DER, length(t));

for d = 1:N_DER
    t_apply = t_broadcast + delays(d);
    for k = 1:length(t)
        if t(k) < t_apply
            P_fleet(d,k) = P_old;
        elseif t(k) < t_apply + ramp_time
            frac          = (t(k) - t_apply) / ramp_time;
            P_fleet(d,k)  = P_old + frac * (P_new - P_old);
        else
            P_fleet(d,k) = P_new;
        end
    end
end

P_fleet_avg = mean(P_fleet, 1);     % aggregated fleet response

%% ------------------------------------------------------------------
%% 3) Reconnect-after-disturbance randomization (EPRI Sec 16)
%% ------------------------------------------------------------------
% Disturbance ends (voltage back in band) at t_clear.
% DER waits TDelayReconnect + Rnd(TWindowReconnect), then ramps over TRamp.
t_clear            = 2;
TDelayReconnect    = 5;     % fixed delay [s]
TWindowReconnect   = 30;    % randomization window [s]
TRampReconnect     = 8;     % reconnect ramp [s]
P_reconnect_final  = 100;   % full output after reconnect [%]

reconnect_random   = TDelayReconnect + rand()*TWindowReconnect;
t_reconnect_start  = t_clear + reconnect_random;
fprintf('Reconnect: TDelay=%d s, Rnd(Tw)=%.2f s, ramps in %d s.\n', ...
        TDelayReconnect, reconnect_random - TDelayReconnect, TRampReconnect);

P_reconnect = zeros(size(t));
for k = 1:length(t)
    if t(k) < t_reconnect_start
        P_reconnect(k) = 0;                       % still disconnected
    elseif t(k) < t_reconnect_start + TRampReconnect
        frac           = (t(k) - t_reconnect_start) / TRampReconnect;
        P_reconnect(k) = frac * P_reconnect_final;
    else
        P_reconnect(k) = P_reconnect_final;
    end
end

%% ------------------------------------------------------------------
%% Plots
%% ------------------------------------------------------------------
figure('Name','EPRI Randomization Time Window','Color','w');

subplot(3,1,1);
plot(t, P_single, 'LineWidth', 1.6);
xline(t_broadcast, '--k', 'broadcast');
xline(t_apply_single, '--r', sprintf('apply (+%d s)', random_action_time));
grid on; ylim([0 110]);
xlabel('Time [s]'); ylabel('Power setting [%]');
title(sprintf('Single DER: Tw = %d s, Ramp = %d s', ...
              randomization_time_upperlimit, ramp_time));

subplot(3,1,2);
plot(t, P_fleet', 'Color', [0.7 0.7 0.85]); hold on;
plot(t, P_fleet_avg, 'b', 'LineWidth', 2);
xline(t_broadcast, '--k', 'broadcast');
grid on; ylim([0 110]);
xlabel('Time [s]'); ylabel('Power [%]');
title(sprintf('Fleet of %d DERs (thin = each DER, thick = mean)', N_DER));
legend({'individual DERs','fleet average'}, 'Location','best');

subplot(3,1,3);
plot(t, P_reconnect, 'LineWidth', 1.6);
xline(t_clear, '--k', 'voltage clears');
xline(t_reconnect_start, '--r', 'reconnect start');
xline(t_reconnect_start + TRampReconnect, '--g', 'full output');
grid on; ylim([-5 110]);
xlabel('Time [s]'); ylabel('Power [%]');
title(sprintf(['Reconnect: TDelay=%d s + Rnd[0,%d] s + Ramp=%d s ' ...
               '(EPRI Sec 16)'], TDelayReconnect, TWindowReconnect, ...
               TRampReconnect));

%% ------------------------------------------------------------------
%% Histogram of fleet delays — shows uniform spread
%% ------------------------------------------------------------------
figure('Name','Fleet delay distribution','Color','w');
histogram(delays, 0:5:randomization_time_upperlimit);
xlabel('Random delay [s]'); ylabel('# DERs');
title(sprintf('Uniform random delays in [0, %d] s across %d DERs', ...
              randomization_time_upperlimit, N_DER));
grid on;
