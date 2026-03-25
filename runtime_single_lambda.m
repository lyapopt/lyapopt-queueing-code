%% run_single_lambda_eval.m

% clear; clc;

%% Parameters
n = n;
m = n*10;
T = 1000;
runs = 100;
scenario = 'b_boundary';
sigma_A = 3 * ones(n,1);
sigma_D = 3 * ones(n,1);
epsilon = 0.1;
scalar = 10;
alpha = 0.05;  % 95% confidence

%% Generate D and facets
% [D, D_top, facets, goodIdx] = genDepartureSet(m, n, scalar, 42);

%% Generate one lambda
lambda = genLambda(D, D_top, facets, goodIdx, epsilon, [], scenario);

%% Preallocate metrics
Metric_max_sq = zeros(runs, T);
Metric_lyap_sq = zeros(runs, T);
Metric_max_total = zeros(runs, T);
Metric_lyap_total = zeros(runs, T);

%% Runtime accumulators
time_max_total = 0;
time_lyap_total = 0;

%% Run simulations
for run = 1:runs
    Q_max = zeros(n,1);
    Q_lyap = zeros(n,1);

    for t = 1:T
        %% MaxWeight decision timing
        t0 = tic;
        [~, idx_max] = max(D * Q_max);
        d_max = D(idx_max, :)';
        time_max_total = time_max_total + toc(t0);

        %% LyapOpt decision timing
        t0 = tic;
        lyap_costs = sum((max(Q_lyap' - D, 0)).^2, 2);
        [~, idx_lyap] = min(lyap_costs);
        d_lyap = D(idx_lyap, :)';
        time_lyap_total = time_lyap_total + toc(t0);

        %% Arrivals
        A_curr = zeros(n,1);
        for i = 1:n
            mu = lambda(i);
            v  = sigma_A(i)^2;

            if mu <= 0
                A_curr(i) = 0;
                continue;
            end

            if v < 0
                error('Negative variance detected for arrivals at i = %d.', i);
            elseif v == 0
                A_curr(i) = mu;
            else
                % Gamma(mean = mu, var = v)
                k     = mu^2 / v;   % shape
                theta = v / mu;     % scale
                A_curr(i) = gamrnd(k, theta);
            end
        end

        %% MaxWeight departures
        for i = 1:n
            if d_max(i) ~= 0
                mu = d_max(i);
                v  = sigma_D(i)^2;

                if mu <= 0
                    d_max(i) = 0;
                    continue;
                end

                if v < 0
                    error('Negative variance detected for MaxWeight departure at i = %d.', i);
                elseif v == 0
                    d_max(i) = mu;
                else
                    % Gamma(mean = mu, var = v)
                    k     = mu^2 / v;   % shape
                    theta = v / mu;     % scale
                    d_max(i) = gamrnd(k, theta);
                end
            end
        end

        %% LyapOpt departures
        for i = 1:n
            if d_lyap(i) ~= 0
                mu = d_lyap(i);
                v  = sigma_D(i)^2;

                if mu <= 0
                    d_lyap(i) = 0;
                    continue;
                end

                if v < 0
                    error('Negative variance detected for LyapOpt departure at i = %d.', i);
                elseif v == 0
                    d_lyap(i) = mu;
                else
                    % Gamma(mean = mu, var = v)
                    k     = mu^2 / v;   % shape
                    theta = v / mu;     % scale
                    d_lyap(i) = gamrnd(k, theta);
                end
            end
        end

        %% Queue update
        Q_max = max(Q_max - d_max, 0) + A_curr;
        Q_lyap = max(Q_lyap - d_lyap, 0) + A_curr;

        %% Record metrics
        Metric_max_sq(run, t)   = sum(Q_max.^2);
        Metric_lyap_sq(run, t)  = sum(Q_lyap.^2);
        Metric_max_total(run, t)  = sum(Q_max);
        Metric_lyap_total(run, t) = sum(Q_lyap);
    end
end

%% Post-processing
df = runs - 1;
tcrit = tinv(1 - alpha/2, df);
x = 1:T;

mean_max_sq = mean(Metric_max_sq, 1);
mean_lyap_sq = mean(Metric_lyap_sq, 1);
se_max_sq = std(Metric_max_sq, 0, 1) / sqrt(runs);
se_lyap_sq = std(Metric_lyap_sq, 0, 1) / sqrt(runs);
hw_max_sq = tcrit * se_max_sq;
hw_lyap_sq = tcrit * se_lyap_sq;

mean_max_total = mean(Metric_max_total, 1);
mean_lyap_total = mean(Metric_lyap_total, 1);
se_max_total = std(Metric_max_total, 0, 1) / sqrt(runs);
se_lyap_total = std(Metric_lyap_total, 0, 1) / sqrt(runs);
hw_max_total = tcrit * se_max_total;
hw_lyap_total = tcrit * se_lyap_total;

%% Plot Total Queue Length
fig2 = figure('Units','inches','Position',[1,1,6,4]);
set(fig2,'Color','w','InvertHardcopy','off');
axis tight
set(gca, 'Position', [0.13 0.15 0.75 0.75])
hold on;

% Draw shaded confidence intervals without legend entries
h3 = fill([x fliplr(x)], ...
          [mean_max_total + hw_max_total, fliplr(mean_max_total - hw_max_total)], ...
          [0 0.4470 0.7410], 'EdgeColor','none', 'FaceAlpha',0.3);
h3.HandleVisibility = 'off';

h4 = fill([x fliplr(x)], ...
          [mean_lyap_total + hw_lyap_total, fliplr(mean_lyap_total - hw_lyap_total)], ...
          [0.8500 0.3250 0.0980], 'EdgeColor','none', 'FaceAlpha',0.3);
h4.HandleVisibility = 'off';

% Plot mean curves
plot(x, mean_max_total, 'b-', 'LineWidth', 1.5, 'DisplayName', 'MaxWeight');
plot(x, mean_lyap_total, 'r-', 'LineWidth', 1.5, 'DisplayName', 'LyapOpt');

xlabel('Time slot T');
ylabel('Total queue length');
title('Total queue length performance');
legend('show', 'Location', 'northwest');
box on;

set(findall(fig2, '-property', 'FontSize'), 'FontSize', 10);
export_fig(fig2, 'total_n8.pdf', '-pdf', '-nocrop');

%% Runtime summary
num_steps = runs * T;

fprintf('\n===== Runtime Summary =====\n');
fprintf('Total MaxWeight runtime: %.6f seconds\n', time_max_total);
fprintf('Total LyapOpt runtime:   %.6f seconds\n', time_lyap_total);
fprintf('Average MaxWeight runtime per decision: %.6e seconds\n', time_max_total / num_steps);
fprintf('Average LyapOpt runtime per decision:   %.6e seconds\n', time_lyap_total / num_steps);
fprintf('Runtime ratio (LyapOpt / MaxWeight): %.4f\n', time_lyap_total / time_max_total);