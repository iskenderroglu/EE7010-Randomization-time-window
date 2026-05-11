function P_out = ramp_apply(t, t_cmd, P_old, P_new, Tr)
%RAMP_APPLY  EPRI Ramp Time response (single setpoint change).
%   P_out = ramp_apply(t, t_cmd, P_old, P_new, Tr)
%
%   Inputs:
%     t      simulation time [s]            (scalar or vector)
%     t_cmd  time the new command arrives [s]
%     P_old  previous setpoint              (any unit: %, W, VAR, PF)
%     P_new  new setpoint                   (same unit as P_old)
%     Tr     ramp time [s] to traverse from P_old to P_new linearly
%
%   Behavior (EPRI 3002008217, §6/§7/§8):
%     - t  <  t_cmd          : P_out = P_old
%     - t_cmd <= t < t_cmd+Tr: P_out linearly interpolated
%     - t  >= t_cmd + Tr     : P_out = P_new
%
%   Tr = 0 -> instant step.
%
%   Designed for use inside a Simulink MATLAB Function block:
%     function P = setpoint(t)
%       P = ramp_apply(t, 5, 0, 5000, 2);  % example
%     end

    if Tr <= 0
        P_out = (t <  t_cmd) .* P_old + (t >= t_cmd) .* P_new;
        return;
    end

    frac  = max(0, min(1, (t - t_cmd) ./ Tr));
    P_out = P_old + frac .* (P_new - P_old);
    P_out(t < t_cmd) = P_old;
end
