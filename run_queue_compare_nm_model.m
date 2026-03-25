%% run_queue_compare_experiment.m
% Compare LyapOpt and MaxWeight on a queueing system
% LyapOpt / MaxWeight by exact enumeration over the feasible set.
%
% Required:
%   - Statistics and Machine Learning Toolbox (for gamrnd)
%   - export_fig (for saving PDF)

clear; clc; close all;

%% ============================================================
% 0. Housekeeping
% ============================================================
output_dir = 'results_queue_compare';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

%% ============================================================
% 1. Experiment parameters
% ============================================================
% -------------------------
% Model parameters: M-model
% -------------------------
lam = [1.3; 1; 3.99];

mu = [
    1 0 0;
    0 0 2;
    1 3 6
];

s = [1; 1; 1];

% Model parameters: N-model
% lam = [2; 3.6];
% mu = [
%     5 1;
%     0 3
% ];
% s = [1; 1];

[m, n] = size(mu);

% -------------------------
% Simulation parameters
% -------------------------
T = 500;                  % time horizon
num_rep = 1000;           % number of Monte Carlo replications
z_val = 1.96;             % 95% CI

%% ============================================================
% 2. Precompute all feasible schedules
% ============================================================
[X_list, D_list] = precompute_feasible_schedules(mu, s);
num_sched = size(X_list, 3);

fprintf('Number of feasible schedules precomputed: %d\n', num_sched);

%% ============================================================
% 3. Run simulations
% ============================================================
fprintf('Running LyapOpt simulation...\n');
[Q_paths_lyap, elapsed_lyap] = simulate_policy('lyapopt', num_rep, T, mu, lam, X_list, D_list);

fprintf('Running MaxWeight simulation...\n');
[Q_paths_max, elapsed_max] = simulate_policy('maxweight', num_rep, T, mu, lam, X_list, D_list);

%% ============================================================
% 4. Post-processing
% ============================================================
Q_total_lyap = sum(Q_paths_lyap, 3);   % size = (num_rep, T+1)
Q_total_max  = sum(Q_paths_max, 3);    % size = (num_rep, T+1)

[mean_lyap_total, hw_lyap_total] = mean_and_ci(Q_total_lyap, z_val);
[mean_max_total,  hw_max_total ] = mean_and_ci(Q_total_max,  z_val);

time_grid = 0:T;

mean_final_lyap = mean_lyap_total(end);
mean_final_max  = mean_max_total(end);

%% ============================================================
% 5. Print summary to command window
% ============================================================
fprintf('\nSimulation finished.\n');
fprintf('----------------------------------------\n');
fprintf('Number of replications : %d\n', num_rep);
fprintf('Time horizon           : 0 to %d\n', T);
fprintf('Number of queues       : %d\n', n);
fprintf('Number of servers      : %d\n', m);
fprintf('Number of feasible schedules : %d\n', num_sched);
fprintf('LyapOpt elapsed time   : %.4f seconds\n', elapsed_lyap);
fprintf('MaxWeight elapsed time : %.4f seconds\n', elapsed_max);
fprintf('Final mean total queue (LyapOpt)   : %.6f\n', mean_final_lyap);
fprintf('Final mean total queue (MaxWeight) : %.6f\n', mean_final_max);
fprintf('----------------------------------------\n');

%% ============================================================
% 6. Plot Total Queue Length
% ============================================================
x = time_grid;

fig2 = figure('Units','inches','Position',[1,1,6,4]);
set(fig2,'Color','w','InvertHardcopy','off');
axis tight
set(gca, 'Position', [0.13 0.15 0.75 0.75])
hold on;

% Draw shaded confidence intervals without legend entries
h3 = fill([x fliplr(x)], ...
    [mean_max_total + hw_max_total, fliplr(mean_max_total - hw_max_total)], ...
    [0 0.4470 0.7410], ...
    'EdgeColor','none', ...
    'FaceAlpha',0.3);
h3.HandleVisibility = 'off';

h4 = fill([x fliplr(x)], ...
    [mean_lyap_total + hw_lyap_total, fliplr(mean_lyap_total - hw_lyap_total)], ...
    [0.8500 0.3250 0.0980], ...
    'EdgeColor','none', ...
    'FaceAlpha',0.3);
h4.HandleVisibility = 'off';

% Plot performance lines with DisplayName for legend
plot(x, mean_max_total, 'b-', 'LineWidth', 1.5, 'DisplayName', 'MaxWeight');
plot(x, mean_lyap_total, 'r-', 'LineWidth', 1.5, 'DisplayName', 'LyapOpt');

xlabel('Time slot T');
ylabel('Total queue length');
title('Total queue length performance');
legend('show', 'Location', 'northwest');

% Show all box borders
box on;

set(findall(fig2, '-property', 'FontSize'), 'FontSize', 10);

%% ============================================================
% 7. Save figure
% ============================================================
fig_pdf_path = fullfile(output_dir, 'total_queue_length_performance.pdf');
export_fig(fig2, fig_pdf_path, '-pdf', '-nocrop');

%% ============================================================
% 8. Save raw results
% ============================================================
mat_path = fullfile(output_dir, 'simulation_results.mat');

save(mat_path, ...
    'lam', 'mu', 's', ...
    'T', 'num_rep', 'z_val', ...
    'Q_paths_lyap', 'Q_paths_max', ...
    'Q_total_lyap', 'Q_total_max', ...
    'mean_lyap_total', 'hw_lyap_total', ...
    'mean_max_total', 'hw_max_total', ...
    'elapsed_lyap', 'elapsed_max', ...
    'time_grid', 'x', 'X_list', 'D_list');

%% ============================================================
% 9. Save textual summary
% ============================================================
summary_path = fullfile(output_dir, 'summary.txt');
fid = fopen(summary_path, 'w');

fprintf(fid, 'Queueing experiment summary\n');
fprintf(fid, '========================================\n\n');

fprintf(fid, 'Model parameters\n');
fprintf(fid, '----------------------------------------\n');
fprintf(fid, 'lambda = \n');
fprintf_matrix(fid, lam);

fprintf(fid, '\nmu = \n');
fprintf_matrix(fid, mu);

fprintf(fid, '\ns = \n');
fprintf_matrix(fid, s);

fprintf(fid, '\nSimulation parameters\n');
fprintf(fid, '----------------------------------------\n');
fprintf(fid, 'Time horizon T            : %d\n', T);
fprintf(fid, 'Number of replications    : %d\n', num_rep);
fprintf(fid, 'z-value for confidence CI : %.2f\n', z_val);
fprintf(fid, 'Number of feasible schedules: %d\n', num_sched);

fprintf(fid, '\nResults\n');
fprintf(fid, '----------------------------------------\n');
fprintf(fid, 'LyapOpt elapsed time      : %.6f seconds\n', elapsed_lyap);
fprintf(fid, 'MaxWeight elapsed time    : %.6f seconds\n', elapsed_max);
fprintf(fid, 'Final mean total queue (LyapOpt)   : %.6f\n', mean_lyap_total(end));
fprintf(fid, 'Final mean total queue (MaxWeight) : %.6f\n', mean_max_total(end));

fclose(fid);

fprintf('\nSaved outputs to folder: %s\n', output_dir);
fprintf('Saved PDF figure       : %s\n', fig_pdf_path);
fprintf('Saved MAT results      : %s\n', mat_path);
fprintf('Saved TXT summary      : %s\n', summary_path);

%% ============================================================
% Local functions
% ============================================================

function [Q_paths, elapsed] = simulate_policy(policy_name, num_rep, T, mu, lam, X_list, D_list)
    [~, n] = size(mu);
    Q_paths = zeros(num_rep, T+1, n);

    tic;
    for rep = 1:num_rep
        Q = zeros(n, 1);
        Q_paths(rep, 1, :) = Q;

        for t = 1:T
            switch lower(policy_name)
                case 'lyapopt'
                    [~, d_plan] = solve_lyapopt_enum(Q, X_list, D_list);
                case 'maxweight'
                    [~, d_plan] = solve_maxweight_enum(Q, X_list, D_list);
                otherwise
                    error('Unknown policy: %s', policy_name);
            end

            D_real = gamma_mean_var1(d_plan);
            D_real = min(D_real, Q);

            A_next = gamma_mean_var1(lam);

            Q = max(Q - D_real, 0) + A_next;
            Q_paths(rep, t+1, :) = Q;
        end
    end
    elapsed = toc;
end

function out = gamma_mean_var1(mean_vec)
    mean_vec = mean_vec(:);
    out = zeros(size(mean_vec));

    pos = mean_vec > 1e-12;
    if any(pos)
        shape = mean_vec(pos).^2;
        scale = 1 ./ mean_vec(pos);
        out(pos) = gamrnd(shape, scale);
    end
end

function [X_list, D_list] = precompute_feasible_schedules(mu, s)
    % Precompute all feasible integer scheduling matrices X
    % satisfying:
    %   x_ij >= 0 integer
    %   x_ij = 0 if mu_ij = 0
    %   sum_j x_ij <= s_i
    %
    % Output:
    %   X_list(:,:,k) = k-th feasible schedule matrix
    %   D_list(:,k)   = induced departure vector sum_i mu_ij x_ij

    [m, n] = size(mu);

    row_patterns = cell(m, 1);

    for i = 1:m
        allowed_cols = find(mu(i, :) > 0);
        row_patterns{i} = generate_row_patterns(n, allowed_cols, s(i));
    end

    num_per_row = cellfun(@(C) size(C, 1), row_patterns);
    total_sched = prod(num_per_row);

    X_list = zeros(m, n, total_sched);
    D_list = zeros(n, total_sched);

    idx_cell = cell(1, m);
    for i = 1:m
        idx_cell{i} = 1:num_per_row(i);
    end

    grids = cell(1, m);
    [grids{:}] = ndgrid(idx_cell{:});

    for k = 1:total_sched
        X = zeros(m, n);
        for i = 1:m
            pick = grids{i}(k);
            X(i, :) = row_patterns{i}(pick, :);
        end
        X_list(:, :, k) = X;
        D_list(:, k) = sum(mu .* X, 1)';
    end
end

function patterns = generate_row_patterns(n, allowed_cols, cap)
    % All integer row vectors x in R^n such that
    %   x_j = 0 for j not in allowed_cols
    %   x_j >= 0 integer
    %   sum_j x_j <= cap

    patterns = [];
    for total = 0:cap
        comp = weak_compositions(total, numel(allowed_cols));
        for r = 1:size(comp, 1)
            row = zeros(1, n);
            row(allowed_cols) = comp(r, :);
            patterns = [patterns; row];
        end
    end
end

function comps = weak_compositions(total, k)
    % All nonnegative integer vectors of length k summing to total
    if k == 1
        comps = total;
        return;
    end

    comps = [];
    for a = 0:total
        tail = weak_compositions(total - a, k - 1);
        comps = [comps; [a * ones(size(tail, 1), 1), tail]];
    end
end

function [x_sol_mat, d_plan] = solve_lyapopt_enum(Q, X_list, D_list)
    % LyapOpt:
    % min over all enumerated candidate service vectors d:
    %   sum_j (max(Q_j - d_j, 0))^2

    num_sched = size(X_list, 3);
    obj = zeros(num_sched, 1);

    for k = 1:num_sched
        d = D_list(:, k);
        r = max(Q - d, 0);
        obj(k) = sum(r.^2);
    end

    [~, best_idx] = min(obj);

    x_sol_mat = X_list(:, :, best_idx);
    d_plan = D_list(:, best_idx);
end

function [x_sol_mat, d_plan] = solve_maxweight_enum(Q, X_list, D_list)
    % MaxWeight:
    % max over all enumerated candidate service vectors d:
    %   Q' * d

    num_sched = size(X_list, 3);
    obj = zeros(num_sched, 1);

    for k = 1:num_sched
        d = D_list(:, k);
        obj(k) = Q' * d;
    end

    [~, best_idx] = max(obj);

    x_sol_mat = X_list(:, :, best_idx);
    d_plan = D_list(:, best_idx);
end

function [mean_val, half_width] = mean_and_ci(data, z)
    if nargin < 2
        z = 1.96;
    end

    mean_val = mean(data, 1);

    if size(data, 1) <= 1
        half_width = zeros(size(mean_val));
    else
        std_val = std(data, 0, 1);
        half_width = z * std_val / sqrt(size(data, 1));
    end
end

function fprintf_matrix(fid, A)
    [r, c] = size(A);
    for i = 1:r
        for j = 1:c
            fprintf(fid, '%.6f', A(i,j));
            if j < c
                fprintf(fid, '\t');
            end
        end
        fprintf(fid, '\n');
    end
end