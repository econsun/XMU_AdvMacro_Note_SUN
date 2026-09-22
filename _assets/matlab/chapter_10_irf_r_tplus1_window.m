% Chapter 10: RBC impulse response for R_{t+1} over a user-selected window

clear;
close all;
clc;

set(groot, 'defaultTextInterpreter', 'latex');
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter', 'latex');

%% Calibration from Chapter 10
beta = 0.99;
alpha = 0.36;
sigma = 1.00;
delta = 0.025;
psi = 0.95;

T = 200;             % total number of periods to simulate
epsilon1 = 1.0;      % one-time shock at t = 1

%% Time window to display (edit these two numbers manually)
t_start = 10;
t_end = 80;

%% Steady-state ratios and decision-rule coefficients
xi = 1 - beta + beta * delta;
YK = xi / (alpha * beta);
CK = YK - delta;

gamma = 1 + 1 / beta + (xi * (1 - alpha) / sigma) * (YK - delta);
Vkk = gamma / 2 - sqrt((gamma / 2)^2 - 1 / beta);  % stable root
Vck = (1 / beta - Vkk) / CK;

numerator_vcz = (sigma * Vck + xi * (1 - alpha)) * YK - xi * psi;
denominator_vcz = sigma * (1 - psi) + CK * (sigma * Vck + xi * (1 - alpha));
Vcz = numerator_vcz / denominator_vcz;
Vkz = YK - CK * Vcz;

%% Shock path and IRF for R_{t+1}
t = (1:T)';
z_hat = zeros(T, 1);
k_hat = zeros(T, 1);
r_hat_lead = zeros(T, 1);  % \hat r_{t+1}, the log deviation of R_{t+1}

delta_tilde = 1 - beta * (1 - delta);

for idx = 1:T
    if idx == 1
        eps_t = epsilon1;
        k_lag = 0.0;
    else
        eps_t = 0.0;
        k_lag = k_hat(idx - 1);
    end

    if idx == 1
        z_hat(idx) = eps_t;
    else
        z_hat(idx) = psi * z_hat(idx - 1) + eps_t;
    end

    k_hat(idx) = Vkk * k_lag + Vkz * z_hat(idx);
end

for idx = 1:T
    if idx < T
        z_lead = z_hat(idx + 1);
    else
        z_lead = psi * z_hat(idx);
    end
    r_hat_lead(idx) = delta_tilde * (z_lead - (1 - alpha) * k_hat(idx));
end

%% Check window validity
if t_start < 1 || t_end > T || t_start >= t_end
    error('Invalid time window. Require 1 <= t_start < t_end <= T.');
end

window_idx = (t >= t_start) & (t <= t_end);
t_window = t(window_idx);
r_window = r_hat_lead(window_idx);

%% Print useful diagnostics
[r_min, r_min_idx_local] = min(r_window);
[r_max, r_max_idx_local] = max(r_window);
fprintf('Selected window for R_{t+1}: t = %d to %d\n', t_start, t_end);
fprintf('  Max within window: t = %d, value = %.6f\n', t_window(r_max_idx_local), r_max);
fprintf('  Min within window: t = %d, value = %.6f\n', t_window(r_min_idx_local), r_min);

%% Plot
figure('Color', 'w', 'Position', [100, 100, 900, 520]);
hold on;

yline(0, '--', 'Color', [0.45, 0.45, 0.45], 'LineWidth', 0.9);
plot(t_window, r_window, 'LineWidth', 2.0, 'Color', [0.10, 0.35, 0.70]);

grid on;
box on;
xlim([t_start, t_end]);
xticks([]);
yticks([]);

ax = gca;
ax.FontSize = 16;
title('log-deviation of $R_{t+1}$', 'Interpreter', 'latex', 'FontSize', 20);
