% Chapter 10: saddle path in the (\hat{k}_{t-1}, \hat{c}_t) plane
% Uses the calibration in Chapter 10 and plots the linearized no-shock system.

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

%% Steady-state ratios and policy coefficients
xi = 1 - beta + beta * delta;
YK = xi / (alpha * beta);
CK = YK - delta;

gamma = 1 + 1 / beta + (xi * (1 - alpha) / sigma) * CK;
Vkk = gamma / 2 - sqrt((gamma / 2)^2 - 1 / beta);
Vck = (1 / beta - Vkk) / CK;

fprintf('Calibration summary:\n');
fprintf('  beta  = %.4f\n', beta);
fprintf('  alpha = %.4f\n', alpha);
fprintf('  sigma = %.4f\n', sigma);
fprintf('  delta = %.4f\n', delta);
fprintf('\n');
fprintf('Steady-state ratios:\n');
fprintf('  Y/K = %.6f\n', YK);
fprintf('  C/K = %.6f\n', CK);
fprintf('\n');
fprintf('Decision-rule coefficients:\n');
fprintf('  Vkk = %.6f\n', Vkk);
fprintf('  Vck = %.6f\n', Vck);

%% Linearized no-shock system
% \hat{k}_t     = (1/beta)\hat{k}_{t-1} - (C/K)\hat{c}_t
% \hat{c}_{t+1} = \hat{c}_t + xi(1-alpha)/sigma * \hat{k}_t
%
% In the (\hat{k}_{t-1}, \hat{c}_t) plane:
% 1) \Delta \hat{k}_t = 0  -> \hat{c}_t = ((1/beta)-1)/(C/K) * \hat{k}_{t-1}
% 2) \Delta \hat{c}_t = 0  -> \hat{k}_t = 0
%                         -> \hat{c}_t = (1/beta)/(C/K) * \hat{k}_{t-1}
% 3) Stable arm          -> \hat{c}_t = Vck * \hat{k}_{t-1}

kmin = -0.030;
kmax =  0.030;
cmin = -0.020;
cmax =  0.020;

k_grid = linspace(kmin, kmax, 400);
c_kdot0 = ((1 / beta) - 1) / CK * k_grid;
c_cdot0 = (1 / beta) / CK * k_grid;
c_stable = Vck * k_grid;

%% Direction field of x_{t+1} - x_t
% State vector x_t = [\hat{k}_{t-1}; \hat{c}_t]
A = [
    1 / beta,                           -CK;
    xi * (1 - alpha) / (sigma * beta),  1 - xi * (1 - alpha) * CK / sigma
];

[K, C] = meshgrid(linspace(kmin, kmax, 9), linspace(cmin, cmax, 9));
dK = zeros(size(K));
dC = zeros(size(C));

for idx = 1:numel(K)
    x_now = [K(idx); C(idx)];
    x_next = A * x_now;
    delta_x = x_next - x_now;
    speed = hypot(delta_x(1), delta_x(2));
    if speed > 1e-12
        delta_x = delta_x / speed;
        dK(idx) = delta_x(1) * 0.0042;
        dC(idx) = delta_x(2) * 0.0028;
    end
end

%% Plot
fig = figure('Color', 'w', 'Position', [120, 120, 1050, 760]);
hold on;
box on;

quiver(K, C, dK, dC, 0, ...
    'Color', [0.62, 0.62, 0.62], ...
    'LineWidth', 1.1, ...
    'MaxHeadSize', 1.4, ...
    'AutoScale', 'off');

plot(k_grid, c_kdot0, '-', 'LineWidth', 1.9, 'Color', [0.35, 0.35, 0.35]);
plot(k_grid, c_cdot0, '-', 'LineWidth', 1.9, 'Color', [0.35, 0.35, 0.35]);
plot(k_grid, c_stable, '-', 'LineWidth', 2.8, 'Color', [0.10, 0.10, 0.10]);

plot(0, 0, 'o', 'MarkerSize', 7, 'MarkerFaceColor', [0.75, 0.10, 0.18], ...
    'MarkerEdgeColor', [0.75, 0.10, 0.18]);

xline(0, '--', 'Color', [0.70, 0.70, 0.70], 'LineWidth', 1.0);
yline(0, '--', 'Color', [0.70, 0.70, 0.70], 'LineWidth', 1.0);

xlabel('$\hat{k}_{t-1}$', 'FontSize', 20);
ylabel('$\hat{c}_t$', 'FontSize', 20);
title('Saddle Path in the $(\hat{k}_{t-1},\hat{c}_t)$ Plane', 'FontSize', 20);

legend( ...
    '$x_{t+1}-x_t$', ...
    '$\Delta \hat{k}_t = 0$', ...
    '$\Delta \hat{c}_t = 0$', ...
    'stable arm: $\hat{c}_t = V_{ck}\hat{k}_{t-1}$', ...
    'steady state', ...
    'Location', 'northwest');

text(0.010, 0.0022, ...
    '$\hat{c}_t=\left(\beta^{-1}-1\right)\frac{\bar K}{\bar C}\hat{k}_{t-1}$', ...
    'FontSize', 17, 'Color', [0.20, 0.20, 0.20]);
text(0.006, 0.0165, ...
    '$\hat{c}_t=\frac{\bar K}{\beta\bar C}\hat{k}_{t-1}$', ...
    'FontSize', 17, 'Color', [0.20, 0.20, 0.20]);
text(0.014, 0.0105, 'stable arm', 'FontSize', 18, 'Color', [0.75, 0.10, 0.18]);
text(0.002, -0.0014, 'steady state', 'FontSize', 17, 'Color', [0.75, 0.10, 0.18]);

ax = gca;
ax.FontSize = 16;
ax.LineWidth = 1.0;
ax.XLim = [kmin, kmax];
ax.YLim = [cmin, cmax];
grid on;

exportgraphics(fig, '../figures/chapter-10-saddle-path.png', 'Resolution', 300);
exportgraphics(fig, '../figures/chapter-10-saddle-path.pdf', 'ContentType', 'vector');
