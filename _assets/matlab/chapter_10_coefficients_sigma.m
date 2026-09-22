% Chapter 10: Relations between decision-rule coefficients and sigma

clear;
close all;
clc;

set(groot, 'defaultTextInterpreter', 'latex');
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter', 'latex');

%% Calibration
beta = 0.99;
alpha = 0.36;
delta = 0.025;
psi = 0.95;

%% Figure layout
left_margin = 0.08;
right_margin = 0.05;
bottom_margin = 0.08;
top_margin = 0.06;
horizontal_gap = 0.14;
vertical_gap = 0.13;

sigma_max = 40;
sigma_grid = linspace(1, sigma_max, 400);
n_sigma = numel(sigma_grid);

%% Steady-state ratios
xi = 1 - beta + beta * delta;
YK = xi / (alpha * beta);
CK = YK - delta;

%% Coefficients as functions of sigma
Vkk = zeros(n_sigma, 1);
Vkz = zeros(n_sigma, 1);
Vck = zeros(n_sigma, 1);
Vcz = zeros(n_sigma, 1);

for idx = 1:n_sigma
    sigma = sigma_grid(idx);

    gamma = 1 + 1 / beta + (xi * (1 - alpha) / sigma) * (YK - delta);
    Vkk(idx) = gamma / 2 - sqrt((gamma / 2)^2 - 1 / beta);
    Vck(idx) = (1 / beta - Vkk(idx)) / CK;

    numerator_vcz = (sigma * Vck(idx) + xi * (1 - alpha)) * YK - xi * psi;
    denominator_vcz = sigma * (1 - psi) + CK * (sigma * Vck(idx) + xi * (1 - alpha));
    Vcz(idx) = numerator_vcz / denominator_vcz;
    Vkz(idx) = YK - CK * Vcz(idx);
end

%% Plot
figure('Color', 'w', 'Position', [100, 100, 1280, 620]);

plot_specs = {
    Vkk, '$V_{kk}$', [0.96, 1.00];
    Vkz, '$V_{kz}$', [0.07, 0.08];
    Vck, '$V_{ck}$', [0.10, 0.70];
    Vcz, '$V_{cz}$', [0.24, 0.36]
};

tile_width = (1 - left_margin - right_margin - horizontal_gap) / 2;
tile_height = (1 - bottom_margin - top_margin - vertical_gap) / 2;

axes_positions = [
    left_margin,  bottom_margin + tile_height + vertical_gap, tile_width, tile_height;
    left_margin + tile_width + horizontal_gap, bottom_margin + tile_height + vertical_gap, tile_width, tile_height;
    left_margin,  bottom_margin, tile_width, tile_height;
    left_margin + tile_width + horizontal_gap, bottom_margin, tile_width, tile_height
];

for j = 1:size(plot_specs, 1)
    axes('Position', axes_positions(j, :));
    hold on;
    plot(sigma_grid, plot_specs{j, 1}, 'LineWidth', 2.0, 'Color', [0.10, 0.35, 0.70]);
    grid on;
    box on;
    xlim([1, sigma_max]);
    xticks([1, 10, 20, 30, 40]);
    ylim(plot_specs{j, 3});
    yticks(linspace(plot_specs{j, 3}(1), plot_specs{j, 3}(2), 5));
    ytickformat('%.3g');
    ax = gca;
    ax.FontSize = 16;
    title(plot_specs{j, 2}, 'Interpreter', 'latex', 'FontSize', 20);
end
