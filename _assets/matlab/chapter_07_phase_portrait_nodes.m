% 相图分类示意
% 使用特征方程：lambda^2 + T lambda + D = 0
% 因而：
% 1) D < 0                -> 鞍点
% 2) D > 0, T^2 - 4D > 0  -> 结点
% 3) D > 0, T^2 - 4D = 0  -> 单向结点或星形结点
% 4) D > 0, T^2 - 4D < 0  -> 焦点
% 5) D > 0, T = 0         -> 中心点
% 在 2)-4) 中，T > 0 为稳定，T < 0 为不稳定。

clear;
close all;
clc;

fontName = "Songti SC";
titleColor = [0.10, 0.10, 0.10];

cases(1)  = struct("title", "稳定星形结点",     "subtitle", "两稳定实根相同", "A", [-1, 0; 0, -1], "kind", "star");
cases(2)  = struct("title", "不稳定星形结点",    "subtitle", "两不稳定实根相同", "A", [ 1, 0; 0,  1], "kind", "star");
cases(3)  = struct("title", "稳定单向结点",     "subtitle", "两稳定实根相同", "A", [-1, 1; 0, -1], "kind", "improper");
cases(4)  = struct("title", "不稳定单向结点",   "subtitle", "两不稳定实根相同", "A", [ 1, 1; 0,  1], "kind", "improper");
cases(5)  = struct("title", "稳定双向结点",     "subtitle", "两稳定实根", "A", [-1, 0; 0, -2], "kind", "node");
cases(6)  = struct("title", "不稳定双向结点",   "subtitle", "两不稳定实根", "A", [ 1, 0; 0,  2], "kind", "node");
cases(7)  = struct("title", "不稳定鞍点",       "subtitle", "稳定实根与不稳定实根异号", "A", [ 1, 0; 0, -1], "kind", "saddle");
cases(8)  = struct("title", "不稳定中心点",     "subtitle", "两虚根 ρ=1", "A", [ 0, -1; 1,  0], "kind", "center");
cases(9)  = struct("title", "稳定焦点",         "subtitle", "两虚根 ρ<1", "A", [-1, -2; 2, -1], "kind", "focus");
cases(10) = struct("title", "不稳定焦点",       "subtitle", "两虚根 ρ>1", "A", [ 1, -2; 2,  1], "kind", "focus");

figure("Color", "w", "Position", [60, 0, 1780, 800], ...
    "DefaultAxesFontName", fontName, ...
    "DefaultTextFontName", fontName);
t = tiledlayout(3, 4, "TileSpacing", "loose", "Padding", "compact");

for k = 1:numel(cases)
    labelText = sprintf("(%c)", char('a' + k - 1));

    if k <= 4
        nexttile(t, k);
    elseif k <= 7
        nexttile(t, 4 + (k - 4));
    else
        nexttile(t, 8 + (k - 7));
    end

    drawPhasePortrait(cases(k), labelText, fontName, titleColor);
end

function drawPhasePortrait(caseDef, labelText, fontName, titleColor)
    A = caseDef.A;
    xMin = -3;
    xMax = 3;
    yMin = -3;
    yMax = 3;

    [X, Y] = meshgrid(linspace(xMin, xMax, 17), linspace(yMin, yMax, 17));
    U = A(1, 1) * X + A(1, 2) * Y;
    V = A(2, 1) * X + A(2, 2) * Y;
    speed = hypot(U, V);
    speed(speed == 0) = 1;
    U = U ./ speed;
    V = V ./ speed;

    quiver(X, Y, U, V, 0.65, "Color", [0.72, 0.72, 0.72], "LineWidth", 1.0);
    hold on;

    initials = getInitialPoints(caseDef.kind);
    lineColor = [0.85, 0.33, 0.10];
    opts = odeset("RelTol", 1e-6, "AbsTol", 1e-8);

    if strcmp(caseDef.kind, "saddle")
        tForward = [0, 4];
        tBackward = [-4, 0];
    elseif any(strcmp(caseDef.kind, ["focus", "center"]))
        tForward = [0, 14];
        tBackward = [-14, 0];
    else
        tForward = [0, 8];
        tBackward = [-8, 0];
    end

    for i = 1:size(initials, 1)
        z0 = initials(i, :).';

        [~, z1] = ode45(@(t, z) A * z, tForward, z0, opts);
        plot(z1(:, 1), z1(:, 2), "Color", lineColor, "LineWidth", 1.0);

        [~, z2] = ode45(@(t, z) A * z, tBackward, z0, opts);
        plot(z2(:, 1), z2(:, 2), "Color", lineColor, "LineWidth", 1.0);
    end

    plot(0, 0, "ko", "MarkerFaceColor", "k", "MarkerSize", 5);

    axis equal;
    axis([xMin, xMax, yMin, yMax]);
    box on;
    grid on;
    ax = gca;
    set(ax, "XTick", [], "YTick", [], "FontName", fontName);
    ax.LooseInset = max(ax.TightInset, [0.02, 0.02, 0.02, 0.06]);

    title(sprintf("%s %s", labelText, caseDef.title), ...
        "FontSize", 11, ...
        "FontName", fontName, ...
        "FontWeight", "normal", ...
        "Color", titleColor, ...
        "Interpreter", "tex");
    subtitle(caseDef.subtitle, ...
        "Interpreter", "tex", ...
        "FontSize", 9.5, ...
        "FontName", fontName, ...
        "Color", titleColor, ...
        "FontWeight", "normal");
end

function initials = getInitialPoints(kind)
    switch kind
        case "saddle"
            initials = [
                -2.4, -1.2;
                -2.4,  1.2;
                -1.2, -2.2;
                -1.2,  2.2;
                 1.2, -2.2;
                 1.2,  2.2;
                 2.4, -1.2;
                 2.4,  1.2
            ];
        case "node"
            initials = [
                -2.2, -1.6;
                -2.2,  0.2;
                -2.2,  1.8;
                -0.8, -2.1;
                -0.8,  2.1;
                 0.8, -2.1;
                 0.8,  2.1;
                 2.2, -1.8;
                 2.2, -0.2;
                 2.2,  1.6
            ];
        case "improper"
            initials = [
                -2.2, -0.5;
                -2.0,  0.4;
                -1.6,  1.1;
                -1.2,  1.8;
                 1.2, -1.8;
                 1.6, -1.1;
                 2.0, -0.4;
                 2.2,  0.5
            ];
        case "star"
            initials = [
                -2.2,  0.0;
                 2.2,  0.0;
                 0.0,  2.2;
                 0.0, -2.2;
                 1.6,  1.6;
                -1.6,  1.6;
                 1.6, -1.6;
                -1.6, -1.6
            ];
        case "focus"
            initials = [
                -2.2, -0.8;
                -2.2,  0.8;
                -0.8,  2.2;
                 0.8,  2.2;
                 2.2,  0.8;
                 2.2, -0.8;
                 0.8, -2.2;
                -0.8, -2.2
            ];
        case "center"
            initials = [
                -2.0,  0.0;
                 2.0,  0.0;
                 0.0,  2.0;
                 0.0, -2.0;
                 1.5,  1.5;
                -1.5,  1.5;
                 1.5, -1.5;
                -1.5, -1.5
            ];
        otherwise
            initials = [
                -2, -1;
                -2,  1;
                 2, -1;
                 2,  1
            ];
    end
end
