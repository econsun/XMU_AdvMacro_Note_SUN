% Chapter 16: Persistent-shock policy IRFs
% This script compares discretion and commitment policy responses to a
% persistent cost-push shock.
%
% Model:
%   pi_t = beta E_t pi_{t+1} + kappa x_t + u_t
%   loss  = sum beta^t (pi_t^2 + alpha_x x_t^2)
%
% Notes:
%   1. The slide text says rho_u = 0.5 for the persistent shock, but the
%      plotted shock path is rho_u = 0.8 because u_12 is about 0.8^12.
%      The script therefore uses rho_u = 0.8 to match the plotted data.
%   2. The shock is normalized to 1, i.e. a 1 percent cost-push shock.

clear;
close all;
clc;

set(groot, 'defaultTextInterpreter', 'latex');
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter', 'latex');

%% Calibration
beta = 0.99;
epsilon = 6.00;
kappa = 0.1275;
alpha_x = kappa / epsilon;

T = 12;
t = (0:T)';
shock_size = 1.0;

script_dir = fileparts(mfilename('fullpath'));
asset_dir = fileparts(script_dir);
figure_dir = fullfile(asset_dir, 'figures');
persistent_png = fullfile(figure_dir, 'chapter-16-persistent-policy-irf.png');
if ~exist(figure_dir, 'dir')
    mkdir(figure_dir);
end

fprintf('Calibration:\n');
fprintf('  beta    = %.6f\n', beta);
fprintf('  epsilon = %.6f\n', epsilon);
fprintf('  kappa   = %.6f\n', kappa);
fprintf('  alpha_x = %.6f\n\n', alpha_x);

%% Persistent cost-push shock: discretion and commitment
rho_persistent = 0.8;

discretion_persistent = compute_discretion_irfs(beta, kappa, alpha_x, rho_persistent, shock_size, T);
commitment_persistent = compute_commitment_irfs(beta, kappa, alpha_x, rho_persistent, shock_size, T);

print_persistent_policy_table( ...
    'Persistent shock: discretion and commitment', ...
    t, discretion_persistent, commitment_persistent);

plot_persistent_policy_figure( ...
    t, discretion_persistent, commitment_persistent, ...
    'Persistent Shock IRFs', ...
    persistent_png, ...
    [-0.05, 1.10], [-6.5, 0.5], [-0.30, 1.10], [-0.05, 5.10]);
fprintf('Saved figure: %s\n', persistent_png);

write_persistent_policy_csv( ...
    fullfile(script_dir, 'chapter_16_irf_persistent_policy.csv'), ...
    t, discretion_persistent, commitment_persistent);

%% Local functions
function irf = compute_discretion_irfs(beta, kappa, alpha_x, rho_u, shock_size, T)
    t = (0:T)';
    u = shock_size * rho_u .^ t;
    if rho_u == 0
        u(2:end) = 0;
    end

    % Discretion:
    %   pi_t = alpha_x * Psi * u_t
    %   x_t  = -kappa * Psi * u_t
    Psi = 1 / (kappa^2 + alpha_x * (1 - beta * rho_u));
    pi_d = alpha_x * Psi * u;
    x_d = -kappa * Psi * u;
    p_d = cumsum(pi_d);

    irf = struct();
    irf.rho_u = rho_u;
    irf.Psi = Psi;
    irf.u = u;
    irf.x_discretion = x_d;
    irf.pi_discretion = pi_d;
    irf.p_discretion = p_d;
end

function irf = compute_commitment_irfs(beta, kappa, alpha_x, rho_u, shock_size, T)
    t = (0:T)';
    u = shock_size * rho_u .^ t;
    if rho_u == 0
        u(2:end) = 0;
    end

    % Commitment:
    %   p_tilde_t = delta p_tilde_{t-1}
    %               + delta / (1 - delta beta rho_u) * u_t
    %   x_t = -(kappa / alpha_x) p_tilde_t
    a = alpha_x / (kappa^2 + alpha_x * (1 + beta));
    delta = (1 - sqrt(1 - 4 * beta * a^2)) / (2 * a * beta);
    p_coeff = delta / (1 - delta * beta * rho_u);

    p_c = zeros(T + 1, 1);
    p_lag = 0.0;
    for idx = 1:(T + 1)
        p_c(idx) = delta * p_lag + p_coeff * u(idx);
        p_lag = p_c(idx);
    end
    pi_c = [p_c(1); diff(p_c)];
    x_c = -(kappa / alpha_x) * p_c;

    irf = struct();
    irf.rho_u = rho_u;
    irf.a = a;
    irf.delta = delta;
    irf.u = u;
    irf.x_commitment = x_c;
    irf.pi_commitment = pi_c;
    irf.p_commitment = p_c;
end

function print_discretion_comparison_table(title_text, t, irf_transitory, irf_persistent)
    fprintf('%s\n', title_text);
    fprintf('  transitory: rho_u = %.6f, Psi = %.6f\n', ...
        irf_transitory.rho_u, irf_transitory.Psi);
    fprintf('  persistent: rho_u = %.6f, Psi = %.6f\n', ...
        irf_persistent.rho_u, irf_persistent.Psi);

    data_table = table( ...
        t, ...
        irf_transitory.u, ...
        irf_persistent.u, ...
        irf_transitory.x_discretion, ...
        irf_persistent.x_discretion, ...
        irf_transitory.pi_discretion, ...
        irf_persistent.pi_discretion, ...
        irf_transitory.p_discretion, ...
        irf_persistent.p_discretion, ...
        'VariableNames', { ...
            't', ...
            'cost_push_shock_transitory', ...
            'cost_push_shock_persistent', ...
            'output_gap_discretion_transitory', ...
            'output_gap_discretion_persistent', ...
            'inflation_discretion_transitory', ...
            'inflation_discretion_persistent', ...
            'price_level_discretion_transitory', ...
            'price_level_discretion_persistent'});
    disp(data_table);
end

function write_discretion_comparison_csv(filename, t, irf_transitory, irf_persistent)
    data_table = table( ...
        t, ...
        irf_transitory.u, ...
        irf_persistent.u, ...
        irf_transitory.x_discretion, ...
        irf_persistent.x_discretion, ...
        irf_transitory.pi_discretion, ...
        irf_persistent.pi_discretion, ...
        irf_transitory.p_discretion, ...
        irf_persistent.p_discretion, ...
        'VariableNames', { ...
            't', ...
            'cost_push_shock_transitory', ...
            'cost_push_shock_persistent', ...
            'output_gap_discretion_transitory', ...
            'output_gap_discretion_persistent', ...
            'inflation_discretion_transitory', ...
            'inflation_discretion_persistent', ...
            'price_level_discretion_transitory', ...
            'price_level_discretion_persistent'});
    writetable(data_table, filename);
end

function print_commitment_comparison_table(title_text, t, irf_transitory, irf_persistent)
    fprintf('%s\n', title_text);
    fprintf('  transitory: rho_u = %.6f, delta = %.6f\n', ...
        irf_transitory.rho_u, irf_transitory.delta);
    fprintf('  persistent: rho_u = %.6f, delta = %.6f\n', ...
        irf_persistent.rho_u, irf_persistent.delta);

    data_table = table( ...
        t, ...
        irf_transitory.u, ...
        irf_persistent.u, ...
        irf_transitory.x_commitment, ...
        irf_persistent.x_commitment, ...
        irf_transitory.pi_commitment, ...
        irf_persistent.pi_commitment, ...
        irf_transitory.p_commitment, ...
        irf_persistent.p_commitment, ...
        'VariableNames', { ...
            't', ...
            'cost_push_shock_transitory', ...
            'cost_push_shock_persistent', ...
            'output_gap_commitment_transitory', ...
            'output_gap_commitment_persistent', ...
            'inflation_commitment_transitory', ...
            'inflation_commitment_persistent', ...
            'price_level_commitment_transitory', ...
            'price_level_commitment_persistent'});
    disp(data_table);
end

function write_commitment_comparison_csv(filename, t, irf_transitory, irf_persistent)
    data_table = table( ...
        t, ...
        irf_transitory.u, ...
        irf_persistent.u, ...
        irf_transitory.x_commitment, ...
        irf_persistent.x_commitment, ...
        irf_transitory.pi_commitment, ...
        irf_persistent.pi_commitment, ...
        irf_transitory.p_commitment, ...
        irf_persistent.p_commitment, ...
        'VariableNames', { ...
            't', ...
            'cost_push_shock_transitory', ...
            'cost_push_shock_persistent', ...
            'output_gap_commitment_transitory', ...
            'output_gap_commitment_persistent', ...
            'inflation_commitment_transitory', ...
            'inflation_commitment_persistent', ...
            'price_level_commitment_transitory', ...
            'price_level_commitment_persistent'});
    writetable(data_table, filename);
end

function print_persistent_policy_table(title_text, t, irf_discretion, irf_commitment)
    fprintf('%s\n', title_text);
    fprintf('  rho_u = %.6f, Psi = %.6f, delta = %.6f\n', ...
        irf_discretion.rho_u, irf_discretion.Psi, irf_commitment.delta);

    data_table = table( ...
        t, ...
        irf_discretion.u, ...
        irf_discretion.x_discretion, ...
        irf_commitment.x_commitment, ...
        irf_discretion.pi_discretion, ...
        irf_commitment.pi_commitment, ...
        irf_discretion.p_discretion, ...
        irf_commitment.p_commitment, ...
        'VariableNames', { ...
            't', ...
            'cost_push_shock', ...
            'output_gap_discretion', ...
            'output_gap_commitment', ...
            'inflation_discretion', ...
            'inflation_commitment', ...
            'price_level_discretion', ...
            'price_level_commitment'});
    disp(data_table);
end

function write_persistent_policy_csv(filename, t, irf_discretion, irf_commitment)
    data_table = table( ...
        t, ...
        irf_discretion.u, ...
        irf_discretion.x_discretion, ...
        irf_commitment.x_commitment, ...
        irf_discretion.pi_discretion, ...
        irf_commitment.pi_commitment, ...
        irf_discretion.p_discretion, ...
        irf_commitment.p_commitment, ...
        'VariableNames', { ...
            't', ...
            'cost_push_shock', ...
            'output_gap_discretion', ...
            'output_gap_commitment', ...
            'inflation_discretion', ...
            'inflation_commitment', ...
            'price_level_discretion', ...
            'price_level_commitment'});
    writetable(data_table, filename);
end

function plot_discretion_comparison_figure( ...
    t, irf_transitory, irf_persistent, title_text, output_png, ...
    ylim_u, ylim_x, ylim_pi, ylim_p)
    fig = figure('Color', 'w', 'Name', title_text, 'Position', [100, 100, 980, 640]);
    tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    transitory_color = [0.10, 0.35, 0.70];
    persistent_color = [0.80, 0.25, 0.18];
    transitory_style = {'-', 'LineWidth', 2.0, 'Color', transitory_color};
    persistent_style = {'--', 'LineWidth', 2.0, 'Color', persistent_color};

    series = {
        irf_transitory.u,              irf_persistent.u,              'Cost Push Shock',   ylim_u;
        irf_transitory.x_discretion,   irf_persistent.x_discretion,   'Output Gap',        ylim_x;
        irf_transitory.pi_discretion,  irf_persistent.pi_discretion,  'Inflation',         ylim_pi;
        irf_transitory.p_discretion,   irf_persistent.p_discretion,   'Price Level',       ylim_p
    };

    for j = 1:size(series, 1)
        nexttile;
        hold on;
        yline(0, '--', 'Color', [0.45, 0.45, 0.45], 'LineWidth', 0.9);
        h1 = plot(t, series{j, 1}, transitory_style{:});
        h2 = plot(t, series{j, 2}, persistent_style{:});
        format_chapter_16_axes(t, series{j, 4});
        set_zero_including_yticks(j);
        title(series{j, 3}, 'Interpreter', 'latex', 'FontSize', 20);

        if j == 1
            legend( ...
                [h1, h2], ...
                {'transitory $(\rho_u=0)$', 'persistent $(\rho_u=0.8)$'}, ...
                'Location', 'northeast');
        end
    end

    exportgraphics(fig, output_png, 'Resolution', 600);
end

function plot_commitment_comparison_figure( ...
    t, irf_transitory, irf_persistent, title_text, output_png, ...
    ylim_u, ylim_x, ylim_pi, ylim_p)
    fig = figure('Color', 'w', 'Name', title_text, 'Position', [100, 100, 980, 640]);
    tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    transitory_color = [0.10, 0.35, 0.70];
    persistent_color = [0.80, 0.25, 0.18];
    transitory_style = {'-', 'LineWidth', 2.0, 'Color', transitory_color};
    persistent_style = {'--', 'LineWidth', 2.0, 'Color', persistent_color};

    series = {
        irf_transitory.u,              irf_persistent.u,              'Cost Push Shock',   ylim_u;
        irf_transitory.x_commitment,   irf_persistent.x_commitment,   'Output Gap',        ylim_x;
        irf_transitory.pi_commitment,  irf_persistent.pi_commitment,  'Inflation',         ylim_pi;
        irf_transitory.p_commitment,   irf_persistent.p_commitment,   'Price Level',       ylim_p
    };

    for j = 1:size(series, 1)
        nexttile;
        hold on;
        yline(0, '--', 'Color', [0.45, 0.45, 0.45], 'LineWidth', 0.9);
        h1 = plot(t, series{j, 1}, transitory_style{:});
        h2 = plot(t, series{j, 2}, persistent_style{:});
        format_chapter_16_axes(t, series{j, 4});
        set_commitment_zero_including_yticks(j);
        title(series{j, 3}, 'Interpreter', 'latex', 'FontSize', 20);

        if j == 1
            legend( ...
                [h1, h2], ...
                {'transitory $(\rho_u=0)$', 'persistent $(\rho_u=0.8)$'}, ...
                'Location', 'northeast');
        end
    end

    exportgraphics(fig, output_png, 'Resolution', 600);
end

function plot_persistent_policy_figure( ...
    t, irf_discretion, irf_commitment, title_text, output_png, ...
    ylim_u, ylim_x, ylim_pi, ylim_p)
    fig = figure('Color', 'w', 'Name', title_text, 'Position', [100, 100, 980, 640]);
    tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    smooth_t = linspace(t(1), t(end), 241)';
    shock_style = {'-', 'LineWidth', 2.0, 'Color', [0.20, 0.20, 0.20]};
    discretion_style = {'-', 'LineWidth', 2.0, 'Color', [0.10, 0.35, 0.70]};
    commitment_style = {'--', 'LineWidth', 2.0, 'Color', [0.80, 0.25, 0.18]};

    response_series = {
        irf_discretion.x_discretion,   irf_commitment.x_commitment,   'Output Gap',   ylim_x;
        irf_discretion.pi_discretion,  irf_commitment.pi_commitment,  'Inflation',    ylim_pi;
        irf_discretion.p_discretion,   irf_commitment.p_commitment,   'Price Level',  ylim_p
    };

    nexttile;
    hold on;
    yline(0, '--', 'Color', [0.45, 0.45, 0.45], 'LineWidth', 0.9);
    plot(smooth_t, interp1(t, irf_discretion.u, smooth_t, 'pchip'), shock_style{:});
    format_chapter_16_axes(t, ylim_u);
    yticks(0:0.2:1.0);
    title('Cost Push Shock', 'Interpreter', 'latex', 'FontSize', 20);

    for j = 1:size(response_series, 1)
        nexttile;
        hold on;
        yline(0, '--', 'Color', [0.45, 0.45, 0.45], 'LineWidth', 0.9);
        h1 = plot(smooth_t, interp1(t, response_series{j, 1}, smooth_t, 'pchip'), discretion_style{:});
        h2 = plot(smooth_t, interp1(t, response_series{j, 2}, smooth_t, 'pchip'), commitment_style{:});
        format_chapter_16_axes(t, response_series{j, 4});
        set_policy_zero_including_yticks(j);
        title(response_series{j, 3}, 'Interpreter', 'latex', 'FontSize', 20);

        if j == 1
            legend([h1, h2], {'discretion', 'commitment'}, 'Location', 'southeast');
        end
    end

    exportgraphics(fig, output_png, 'Resolution', 600);
end

function set_zero_including_yticks(panel_idx)
    switch panel_idx
        case 1
            yticks(0:0.2:1.0);
        case 2
            yticks(-6:1:0);
        case 3
            yticks(0:0.2:1.0);
        case 4
            yticks(0:1:5);
    end
end

function set_policy_zero_including_yticks(panel_idx)
    switch panel_idx
        case 1
            yticks(-6:1:0);
        case 2
            yticks(-0.2:0.2:1.0);
        case 3
            yticks(0:1:5);
    end
end

function set_commitment_zero_including_yticks(panel_idx)
    switch panel_idx
        case 1
            yticks(0:0.2:1.0);
        case 2
            yticks(-5:1:0);
        case 3
            yticks(-0.2:0.2:0.6);
        case 4
            yticks(0:0.2:0.8);
    end
end

function format_chapter_16_axes(t, y_limits)
    box on;
    grid on;
    xlim([t(1), t(end)]);
    ylim(y_limits);
    xticks(0:2:t(end));
    yl = ylim;
    yticks(linspace(yl(1), yl(2), 7));
    ytickformat('%.2g');
    ax = gca;
    ax.FontSize = 16;
    ax.Toolbar.Visible = 'off';
end
