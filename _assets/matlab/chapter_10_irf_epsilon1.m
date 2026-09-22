% Chapter 10: RBC impulse responses for a one-time technology shock epsilon_1 = 1
% The script follows the notation in Chapter 10:
%   hat{k}_t = Vkk * hat{k}_{t-1} + Vkz * hat{z}_t
%   hat{c}_t = Vck * hat{k}_{t-1} + Vcz * hat{z}_t
%   hat{z}_t = psi * hat{z}_{t-1} + epsilon_t
%
% Note:
% hat{k}_t here is the end-of-period capital chosen at time t.
% The predetermined capital used in production at time t is hat{k}_{t-1}.

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

T = 35;              % number of periods to plot
epsilon1 = 1.0;      % one-time shock at t = 1

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

%% Shock path and IRFs
t = (1:T)';
z_hat = zeros(T, 1);
k_hat = zeros(T, 1);
c_hat = zeros(T, 1);
y_hat = zeros(T, 1);
i_hat = zeros(T, 1);
k_used_hat = zeros(T, 1);  % predetermined capital used in production, hat{k}_{t-1}
r_hat_lead = zeros(T, 1);  % \hat r_{t+1}, the log deviation of R_{t+1}
k_remaining_hat = zeros(T, 1);  % (1-delta) * hat{k}_{t-1}

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

    k_used_hat(idx) = k_lag;
    k_remaining_hat(idx) = (1 - delta) * k_lag;
    k_hat(idx) = Vkk * k_lag + Vkz * z_hat(idx);
    c_hat(idx) = Vck * k_lag + Vcz * z_hat(idx);
    y_hat(idx) = z_hat(idx) + alpha * k_lag;
    i_hat(idx) = (k_hat(idx) - (1 - delta) * k_lag) / delta;
end

for idx = 1:T
    if idx < T
        z_lead = z_hat(idx + 1);
    else
        z_lead = psi * z_hat(idx);
    end
    r_hat_lead(idx) = delta_tilde * (z_lead - (1 - alpha) * k_hat(idx));
end

%% Print key coefficients
fprintf('Decision-rule coefficients from Chapter 10:\n');
fprintf('  C/K = %.6f\n', CK);
fprintf('  Y/K = %.6f\n', YK);
fprintf('  Vkk = %.6f\n', Vkk);
fprintf('  Vkz = %.6f\n', Vkz);
fprintf('  Vck = %.6f\n', Vck);
fprintf('  Vcz = %.6f\n', Vcz);

[k_peak, k_peak_idx] = max(k_hat);
[k_used_peak, k_used_peak_idx] = max(k_used_hat);
fprintf('\nPeak capital in the simulated IRF:\n');
fprintf('  Peak of k_t occurs at t = %d, with k_t = %.6f and i_t = %.6f\n', ...
    k_peak_idx, k_peak, i_hat(k_peak_idx));
fprintf('  Peak of k_{t-1} occurs at t = %d, with k_{t-1} = %.6f and i_t = %.6f\n', ...
    k_used_peak_idx, k_used_peak, i_hat(k_used_peak_idx));
fprintf('  At t = %d, (1-delta)k_{t-1} = %.6f, i_t = %.6f, and their difference is %.6f\n', ...
    k_used_peak_idx, k_remaining_hat(k_used_peak_idx), i_hat(k_used_peak_idx), ...
    k_remaining_hat(k_used_peak_idx) - i_hat(k_used_peak_idx));

%% Plot
figure('Color', 'w', 'Position', [100, 100, 1280, 620]);
tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

series = {
    z_hat,      'log-deviation of ${Z_t}$';
    k_used_hat, 'log-deviation of ${K_{t-1}}$';
    c_hat,      'log-deviation of ${C_t}$';
    y_hat,      'log-deviation of ${Y_t}$';
    i_hat,      'log-deviation of ${i_t}$';
    r_hat_lead, 'log-deviation of $R_{t+1}$'
};

axis_limits = [
    0.0,   1.0;
    0.0,   0.7;
    0.25,  0.55;
    0.4,   1.0;
    0.0,   3.2;
   -0.01,  0.032
];

line_color = [0.10, 0.35, 0.70];

for j = 1:size(series, 1)
    nexttile;
    hold on;
    yline(0, '--', 'Color', [0.45, 0.45, 0.45], 'LineWidth', 0.9);
    plot(t, series{j, 1}, 'LineWidth', 2.0, 'Color', line_color);
    grid on;
    box on;
    xlim([0, T]);
    xticks(0:5:T);
    ylim(axis_limits(j, :));
    yl = ylim;
    yticks(linspace(yl(1), yl(2), 7));
    if j == 6
        ytickformat('%.3f');
    else
        ytickformat('%.2g');
    end
    ax = gca;
    ax.FontSize = 16;
    title(series{j, 2}, 'Interpreter', 'latex', 'FontSize', 20);
end
