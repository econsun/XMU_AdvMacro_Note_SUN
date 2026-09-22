% Chapter 11: Hansen model phase diagram in the (\hat{k}_{t-1}, \hat{c}_t) plane
% This version classifies local stability from the full transition equation
% that includes labor:
%   x_t     = [\hat{k}_{t-1}; \hat{c}_t; \hat{n}_t]
%   x_{t+1} = [\hat{k}_t;    \hat{c}_{t+1}; \hat{n}_{t+1}]
%
% The figure is still drawn in the (\hat{k}_{t-1}, \hat{c}_t) plane, but
% the singularity type is determined by the eigenvalues of the full 3x3 map.

clear;
close all;
clc;

set(groot, 'defaultTextInterpreter', 'latex');
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter', 'latex');

%% Calibration
alpha = 0.36;
beta  = 0.99;
delta = 0.025;
A     = 2.00;
Zbar  = 1.00;

%% Steady state
Nbar = 1 / (1 + A / (1 - alpha) * (1 - alpha * beta * delta / (1 - beta * (1 - delta))));
Kbar = Nbar * (alpha * beta * Zbar / (1 - beta * (1 - delta)))^(1 / (1 - alpha));
Cbar = Nbar * Zbar^(1 / (1 - alpha)) * ...
    ((alpha * beta / (1 - beta * (1 - delta)))^(alpha / (1 - alpha)) ...
    - delta * (alpha * beta / (1 - beta * (1 - delta)))^(1 / (1 - alpha)));
Ybar = Zbar * Kbar^alpha * Nbar^(1 - alpha);

%% Corrected linearized no-shock system
% \hat{n}_t = B(\alpha \hat{k}_{t-1} - \hat{c}_t)
% \hat{k}_t = a \hat{k}_{t-1} + b \hat{n}_t - d \hat{c}_t
% \hat{c}_t = \hat{c}_{t+1} + xi \hat{k}_t - xi \hat{n}_{t+1}
td = 1 - beta * (1 - delta);           % \tilde{\delta}
B  = 1 / (alpha + Nbar / (1 - Nbar));
YK = Ybar / Kbar;
CK = Cbar / Kbar;
xi = td * (1 - alpha);

a = alpha * YK + 1 - delta;
b = (1 - alpha) * YK;
d = CK;

% Reduced formulas:
% \hat{c}_{t+1} = u \hat{k}_t + v \hat{c}_t
% \hat{n}_{t+1} = w \hat{k}_t + x \hat{c}_t
u = -xi * (1 - alpha * B) / (1 + xi * B);
v = 1 / (1 + xi * B);
w = B * (alpha + xi) / (1 + xi * B);
x = -B / (1 + xi * B);

%% Full transition matrix
% x_t     = [\hat{k}_{t-1}; \hat{c}_t; \hat{n}_t]
% x_{t+1} = [\hat{k}_t;    \hat{c}_{t+1}; \hat{n}_{t+1}]
A3 = [
    a,           -d,          b;
    u * a,  v - u * d,    u * b;
    w * a,  x - w * d,    w * b
];

[eigVec3, eigValMat3] = eig(A3);
eigVal3 = diag(eigValMat3);
eigMod3 = abs(eigVal3);
tol = 1e-8;

nStable = sum(eigMod3 < 1 - tol);
nUnstable = sum(eigMod3 > 1 + tol);
nStatic = sum(eigMod3 <= tol);

nonzeroEig = eigVal3(eigMod3 > tol);
nonzeroMod = abs(nonzeroEig);

if sum(nonzeroMod < 1 - tol) == 1 && sum(nonzeroMod > 1 + tol) == 1
    singularityType = 'saddle with one static root';
elseif all(abs(imag(nonzeroEig)) < tol) && all(nonzeroMod < 1 - tol)
    singularityType = 'stable node with one static root';
elseif all(abs(imag(nonzeroEig)) < tol) && all(nonzeroMod > 1 + tol)
    singularityType = 'unstable node with one static root';
elseif any(abs(imag(nonzeroEig)) >= tol) && all(nonzeroMod < 1 - tol)
    singularityType = 'stable focus with one static root';
elseif any(abs(imag(nonzeroEig)) >= tol) && all(nonzeroMod > 1 + tol)
    singularityType = 'unstable focus with one static root';
else
    singularityType = 'nonhyperbolic / mixed case';
end

fprintf('Calibration summary:\n');
fprintf('  alpha = %.4f\n', alpha);
fprintf('  beta  = %.4f\n', beta);
fprintf('  delta = %.4f\n', delta);
fprintf('  A     = %.4f\n', A);
fprintf('\n');
fprintf('Steady state:\n');
fprintf('  Nbar = %.6f\n', Nbar);
fprintf('  Kbar = %.6f\n', Kbar);
fprintf('  Cbar = %.6f\n', Cbar);
fprintf('  Ybar = %.6f\n', Ybar);
fprintf('\n');
fprintf('Ratios and reduced-form coefficients:\n');
fprintf('  Y/K = %.6f\n', YK);
fprintf('  C/K = %.6f\n', CK);
fprintf('  B   = %.6f\n', B);
fprintf('  td  = %.6f\n', td);
fprintf('\n');
fprintf('Full transition matrix A3:\n');
disp(A3);
fprintf('Eigenvalues of A3:\n');
disp(eigVal3);
fprintf('Modulus of eigenvalues:\n');
disp(eigMod3);
fprintf('Stable roots   : %d\n', nStable);
fprintf('Unstable roots : %d\n', nUnstable);
fprintf('Static roots   : %d\n', nStatic);
fprintf('Local singularity type: %s\n', singularityType);

%% Zero-motion loci in the (\hat{k}_{t-1}, \hat{c}_t) plane
% Restrict to the static manifold \hat{n}_t = B(\alpha \hat{k}_{t-1} - \hat{c}_t).
p = a + alpha * b * B;
q = b * B + d;
r = alpha - 1 / B;

% 1) \hat{n}_t = 0
m_n = alpha;

% 2) \Delta \hat{k}_t = 0
m_k = (p - 1) / q;

% 3) \Delta \hat{c}_t = 0
m_c = (r * p) / (1 + r * q);

fprintf('Slopes in the (k,c) plane:\n');
fprintf('  n_t = 0          : %.6f\n', m_n);
fprintf('  Delta k_t = 0    : %.6f\n', m_k);
fprintf('  Delta c_t = 0    : %.6f\n', m_c);

%% Stable and unstable arms projected onto the (k,c) plane
stableSlope = NaN;
unstableSlope = NaN;

for j = 1:numel(eigVal3)
    if abs(eigVal3(j)) <= tol
        continue;
    end
    if abs(eigVec3(1, j)) <= tol
        continue;
    end
    slopeKC = real(eigVec3(2, j) / eigVec3(1, j));
    if abs(eigVal3(j)) < 1 - tol
        stableSlope = slopeKC;
    elseif abs(eigVal3(j)) > 1 + tol
        unstableSlope = slopeKC;
    end
end

%% Direction field in the (k,c) plane
% Each point is lifted to x_t = [k_{t-1}; c_t; n_t] with n_t satisfying
% the static labor equation, then updated by the full 3x3 matrix.
kmin = -0.12;
kmax =  0.12;
cmin = -0.12;
cmax =  0.12;

[K, C] = meshgrid(linspace(kmin, kmax, 17), linspace(cmin, cmax, 17));
dK = zeros(size(K));
dC = zeros(size(C));

for idx = 1:numel(K)
    nNow = B * (alpha * K(idx) - C(idx));
    xNow = [K(idx); C(idx); nNow];
    xNext = A3 * xNow;
    deltaX = xNext(1:2) - xNow(1:2);
    speed = hypot(deltaX(1), deltaX(2));
    if speed > 1e-12
        deltaX = deltaX / speed;
        dK(idx) = deltaX(1) * 0.018;
        dC(idx) = deltaX(2) * 0.018;
    end
end

%% Plot
fig = figure('Color', 'w', 'Position', [120, 100, 1060, 790]);
hold on;
box on;

h = gobjects(0);
labels = {};

h(end + 1) = quiver(K, C, dK, dC, 0, ...
    'Color', [0.72, 0.72, 0.72], ...
    'LineWidth', 1.0, ...
    'MaxHeadSize', 1.25, ...
    'AutoScale', 'off');
labels{end + 1} = '$x_{t+1}-x_t$';

kGrid = linspace(kmin, kmax, 400);
h(end + 1) = plot(kGrid, m_k * kGrid, '-', 'LineWidth', 1.8, 'Color', [0.84, 0.22, 0.16]);
labels{end + 1} = '$\Delta \hat{k}_t = 0$';

h(end + 1) = plot(kGrid, m_c * kGrid, '-', 'LineWidth', 1.8, 'Color', [0.15, 0.45, 0.82]);
labels{end + 1} = '$\Delta \hat{c}_t = 0$';

h(end + 1) = plot(kGrid, m_n * kGrid, '--', 'LineWidth', 1.6, 'Color', [0.10, 0.10, 0.10]);
labels{end + 1} = '$\hat{n}_t = 0$';

if strcmp(singularityType, 'saddle with one static root') && isfinite(stableSlope)
    h(end + 1) = plot(kGrid, stableSlope * kGrid, '-', ...
        'LineWidth', 2.8, 'Color', [0.08, 0.08, 0.08]);
    labels{end + 1} = 'stable arm';
end

if strcmp(singularityType, 'saddle with one static root') && isfinite(unstableSlope)
    h(end + 1) = plot(kGrid, unstableSlope * kGrid, '--', ...
        'LineWidth', 1.4, 'Color', [0.35, 0.35, 0.35]);
    labels{end + 1} = 'unstable arm';
end

h(end + 1) = plot(0, 0, 'o', ...
    'MarkerSize', 6.5, ...
    'MarkerFaceColor', [0.10, 0.10, 0.10], ...
    'MarkerEdgeColor', [0.10, 0.10, 0.10]);
labels{end + 1} = 'steady state';

xline(0, '--', 'Color', [0.80, 0.80, 0.80], 'LineWidth', 1.0);
yline(0, '--', 'Color', [0.80, 0.80, 0.80], 'LineWidth', 1.0);

xlabel('$\hat{k}_{t-1}$', 'FontSize', 20);
ylabel('$\hat{c}_t$', 'FontSize', 20);
title(sprintf('Hansen Model: Phase Diagram (%s)', singularityType), 'FontSize', 20);

legend(h, labels, 'Location', 'northwest');

text(0.050, m_k * 0.050 + 0.006, '$\Delta \hat{k}_t = 0$', ...
    'FontSize', 16, 'Color', [0.84, 0.22, 0.16]);
text(-0.085, m_c * (-0.085) + 0.010, '$\Delta \hat{c}_t = 0$', ...
    'FontSize', 16, 'Color', [0.15, 0.45, 0.82]);
text(0.055, m_n * 0.055 - 0.012, '$\hat{n}_t = 0$', ...
    'FontSize', 16, 'Color', [0.10, 0.10, 0.10]);

if strcmp(singularityType, 'saddle with one static root') && isfinite(stableSlope)
    text(0.050, stableSlope * 0.050 + 0.010, 'stable arm', ...
        'FontSize', 15, 'Color', [0.08, 0.08, 0.08]);
end

text(0.004, -0.010, 'steady state', ...
    'FontSize', 15, 'Color', [0.10, 0.10, 0.10]);

ax = gca;
ax.FontSize = 15;
ax.LineWidth = 1.0;
ax.XLim = [kmin, kmax];
ax.YLim = [cmin, cmax];
grid on;

exportgraphics(fig, '../figures/chapter-11-hansen-phase-diagram.png', 'Resolution', 300);
exportgraphics(fig, '../figures/chapter-11-hansen-phase-diagram.pdf', 'ContentType', 'vector');
