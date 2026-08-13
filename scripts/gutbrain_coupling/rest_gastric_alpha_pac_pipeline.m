%% RESTING-STATE GASTRIC–ALPHA PAC PIPELINE
%
%
% This script documents:
%   1. Optional preprocessing + ICA from raw BioSemi BDF files
%   2. Manual ICA rejection
%   3. Gastric phase–alpha amplitude PAC analysis
%   4. Individual and group topoplots
%
% Raw BDF data are not required if you only want to reproduce the PAC
% analysis from the shared icafinal_rest files.
%
% IMPORTANT:
% - Update the USER CONFIGURATION section before running.
% - Channel assumptions:
%       1:64  = EEG
%       65:72 = EGG/EXG in the original raw recordings
%
% Developed with EEGLAB 2023.1.

clear; clc;

%% ========================================================================
%  USER CONFIGURATION
% =========================================================================

% Set this to true only if raw BDF files are available and you want to
% reproduce preprocessing + ICA.
RUN_PREPROCESSING = false;

% Set this to true if you want to perform manual ICA rejection.
% This requires ICA .set files created in the preprocessing stage.
RUN_MANUAL_ICA = false;

% Set this to true to compute PAC from final ICA-cleaned datasets.
RUN_PAC = true;

% -------------------------------------------------------------------------
% Software paths
% -------------------------------------------------------------------------

eeglab_path = 'PATH_TO_EEGLAB';

% Example:
% eeglab_path = 'C:\path\to\eeglab2023.1';

addpath(eeglab_path);
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab; %#ok<ASGLU>

% -------------------------------------------------------------------------
% Participant / visit selection
% -------------------------------------------------------------------------

participants = [ ...
   ];

visits = 1;

% -------------------------------------------------------------------------
% Data paths
% -------------------------------------------------------------------------

% Raw folders are only needed when RUN_PREPROCESSING = true.
raw_folders = { ...
    'PATH_TO_RAW_FOLDER_1'
    'PATH_TO_RAW_FOLDER_2'
};

% Directory containing / receiving ICA and final cleaned files.
preprocessed_path = fullfile(pwd, 'data', 'icafinal_rest');

% PAC output directory.
pac_path = fullfile(pwd, 'results', 'PAC');

% Gastric peak summary table.
% Only needed when RUN_PREPROCESSING = true.
summary_path = 'PATH_TO_GASTRIC_PEAK_SUMMARY.xlsx';

% EEGLAB channel-location files.
chanloc_lookup = fullfile( ...
    eeglab_path, 'plugins', 'dipfit', 'standard_BEM', ...
    'elec', 'standard_1005.elc');

chanloc_load = { ...
    'PATH_TO_BioSemi64.loc', ...
    'filetype', 'autodetect'};

if ~exist(preprocessed_path, 'dir')
    mkdir(preprocessed_path);
end

if ~exist(pac_path, 'dir')
    mkdir(pac_path);
end

% -------------------------------------------------------------------------
% Analysis parameters
% -------------------------------------------------------------------------

target_srate = 120;
alpha_band = [8 12];

% Participant-specific EGG band = gastric peak +/- egg_half_bw.
egg_half_bw = 0.015;

% Number of phase bins used for the Modulation Index.
nbin = 18;
position = -pi + (0:nbin-1) * (2*pi/nbin);

ica_rejection_mat = fullfile(preprocessed_path, 'ICA_rejection_log.mat');
ica_rejection_xlsx = fullfile(preprocessed_path, 'ICA_rejection_log.xlsx');

%% ========================================================================
%  LOAD GASTRIC PEAK TABLE, IF NEEDED
% =========================================================================

if RUN_PREPROCESSING
    if ~exist(summary_path, 'file')
        error('Gastric peak summary file not found: %s', summary_path);
    end
    T = readtable(summary_path);
else
    T = table();
end

%% ========================================================================
%  PHASE 1: OPTIONAL PREPROCESSING + ICA
% =========================================================================

if RUN_PREPROCESSING

    for pi = 1:numel(participants)
        for vi = 1:numel(visits)

            P = participants(pi);
            V = visits(vi);

            fprintf('\n====================================================\n');
            fprintf('PHASE 1: Preprocessing + ICA | P%d V%d\n', P, V);
            fprintf('====================================================\n');

            raw_filename = sprintf('EEG_rest_visit%d_P%d.bdf', V, P);
            raw_fullpath = find_subject_file(raw_filename, raw_folders);

            if isempty(raw_fullpath)
                warning('Raw file not found for P%d V%d: %s', P, V, raw_filename);
                continue;
            end

            row_idx = find(T.Participant == P & T.Visit == V, 1);

            if isempty(row_idx)
                warning('No gastric peak found for P%d V%d. Skipping.', P, V);
                continue;
            end

            f_peak = T.Max_Freq(row_idx);
            max_chan_label = get_table_string(T.Max_Chan, row_idx);

            egg_band = [ ...
                max(0.005, f_peak - egg_half_bw), ...
                f_peak + egg_half_bw];

            fprintf('Raw file: %s\n', raw_fullpath);
            fprintf(['Gastric peak: %.5f Hz | EGG band: %.5f-%.5f Hz | ' ...
                     'Max channel: %s\n'], ...
                    f_peak, egg_band(1), egg_band(2), max_chan_label);

            try
                EEG = pop_biosig(raw_fullpath);

                EEG = pop_chanedit(EEG, ...
                    'lookup', chanloc_lookup, ...
                    'rplurchanloc', 1);

                EEG = eeg_checkset(EEG);

                % Resample once.
                EEG = pop_resample(EEG, target_srate);
                EEG = eeg_checkset(EEG);

                % Remove DC offset.
                EEG = pop_rmbase(EEG, []);

                % EEG alpha-band filtering.
                EEG_alpha = pop_select(EEG, 'channel', 1:64);
                EEG_alpha = pop_eegfiltnew(EEG_alpha, ...
                    'locutoff', alpha_band(1), ...
                    'hicutoff', alpha_band(2));
                EEG.data(1:64, :) = EEG_alpha.data;

                % Participant-specific EGG filtering.
                EGG = pop_select(EEG, 'channel', 65:72);
                EGG = pop_eegfiltnew(EGG, ...
                    'locutoff', egg_band(1), ...
                    'hicutoff', egg_band(2));
                EEG.data(65:72, :) = EGG.data;

                % Average-reference EEG only.
                average_ref = mean(EEG.data(1:64, :), 1);
                EEG.data(1:64, :) = EEG.data(1:64, :) - average_ref;

                % Reference EGG to EXG2 / channel 65.
                ref_electrode = 65;
                for ch = 66:72
                    EEG.data(ch, :) = EEG.data(ch, :) - ...
                        EEG.data(ref_electrode, :);
                end

                % Store metadata.
                EEG.etc.participant = P;
                EEG.etc.visit = V;
                EEG.etc.f_peak = f_peak;
                EEG.etc.egg_band = egg_band;
                EEG.etc.max_chan_label = max_chan_label;
                EEG.etc.target_srate = target_srate;
                EEG.etc.alpha_band = alpha_band;

                % Clear any existing ICA fields.
                EEG.icaweights = [];
                EEG.icasphere = [];
                EEG.icawinv = [];
                EEG.icaact = [];

                % ICA only on EEG channels.
                EEG = pop_runica(EEG, ...
                    'icatype', 'runica', ...
                    'extended', 1, ...
                    'chanind', 1:64, ...
                    'pca', 63);

                EEG = pop_iclabel(EEG, 'default');

                ica_filename = sprintf('ica_rest_visit%d_P%d.set', V, P);

                EEG = pop_saveset(EEG, ...
                    'filename', ica_filename, ...
                    'filepath', preprocessed_path, ...
                    'savemode', 'onefile');

                fprintf('Saved ICA dataset: %s\n', ica_filename);

            catch ME
                warning('PHASE 1 failed for P%d V%d: %s', P, V, ME.message);
            end
        end
    end
end

%% ========================================================================
%  PHASE 2A: OPTIONAL MANUAL ICA REJECTION
% =========================================================================

if RUN_MANUAL_ICA

    ICA_log = table();

    if exist(ica_rejection_mat, 'file')
        S = load(ica_rejection_mat, 'ICA_log');
        ICA_log = S.ICA_log;
    end

    for pi = 1:numel(participants)
        for vi = 1:numel(visits)

            P = participants(pi);
            V = visits(vi);

            fprintf('\n====================================================\n');
            fprintf('PHASE 2A: Manual ICA rejection | P%d V%d\n', P, V);
            fprintf('====================================================\n');

            ica_filename = sprintf('ica_rest_visit%d_P%d.set', V, P);
            ica_fullpath = fullfile(preprocessed_path, ica_filename);

            if ~exist(ica_fullpath, 'file')
                warning('ICA file not found: %s', ica_fullpath);
                continue;
            end

            try
                EEG = pop_loadset( ...
                    'filename', ica_filename, ...
                    'filepath', preprocessed_path);

                pop_selectcomps(EEG, 1:size(EEG.icaweights, 1));

                fprintf('\nEnter rejected components for P%d V%d.\n', P, V);
                fprintf('Example: 1,4,7. Press ENTER for none.\n');

                comp_string = input('Rejected ICs: ', 's');
                comps_to_reject = parse_component_list(comp_string);

                newrow = table( ...
                    P, ...
                    V, ...
                    {comps_to_reject}, ...
                    {datestr(now)}, ...
                    'VariableNames', ...
                    {'Participant','Visit','RejectedICs','Timestamp'});

                ICA_log = remove_existing_log_row(ICA_log, P, V);
                ICA_log = [ICA_log; newrow]; %#ok<AGROW>

                save(ica_rejection_mat, 'ICA_log');
                writetable( ...
                    convert_log_for_excel(ICA_log), ...
                    ica_rejection_xlsx);

                fprintf('Saved rejected ICs for P%d V%d: %s\n', ...
                    P, V, mat2str(comps_to_reject));

                if ~isempty(comps_to_reject)
                    EEG = pop_subcomp(EEG, comps_to_reject, 0);
                    EEG = eeg_checkset(EEG);
                end

                EEG.etc.rejected_ICs = comps_to_reject;

                % Select the participant-specific EGG channel.
                max_chan_label = EEG.etc.max_chan_label;
                labels = {EEG.chanlocs.labels};
                egg_idx = find(strcmpi(labels, max_chan_label), 1);

                if isempty(egg_idx)
                    warning('EGG channel %s not found for P%d V%d.', ...
                        max_chan_label, P, V);
                    continue;
                end

                selected_egg = EEG.data(egg_idx, :, :);

                % Keep EEG channels only.
                EEG.data = EEG.data(1:64, :, :);
                EEG.nbchan = 64;
                EEG.chanlocs = EEG.chanlocs(1:64);

                % Duplicate the selected EGG signal into channels 65:128.
                EEG.data(128, :, :) = 0;

                template_chan = EEG.chanlocs(64);
                EEG.chanlocs(128) = template_chan;

                for ch = 65:128
                    EEG.data(ch, :, :) = selected_egg;
                    EEG.chanlocs(ch) = template_chan;
                    EEG.chanlocs(ch).labels = ...
                        sprintf('EGGdup%d', ch - 64);
                end

                EEG.nbchan = 128;
                EEG = eeg_checkset(EEG);

                final_setname = sprintf( ...
                    'icafinal_rest_visit%d_P%d.set', V, P);

                final_matname = sprintf( ...
                    'icafinal_rest_visit%d_P%d.mat', V, P);

                EEG = pop_saveset(EEG, ...
                    'filename', final_setname, ...
                    'filepath', preprocessed_path, ...
                    'savemode', 'onefile');

                save(fullfile(preprocessed_path, final_matname), ...
                    'EEG', '-v7.3');

                fprintf('Saved final ICA-cleaned dataset for P%d V%d.\n', P, V);

            catch ME
                warning('PHASE 2A failed for P%d V%d: %s', P, V, ME.message);
            end
        end
    end
end

%% ========================================================================
%  PHASE 2B: PAC FROM FINAL ICA-CLEANED FILES
% =========================================================================

MI_all_subjects = [];
subject_ids = [];
subject_visits = [];
skipped_files = {};

if RUN_PAC

    for pi = 1:numel(participants)
        for vi = 1:numel(visits)

            P = participants(pi);
            V = visits(vi);

            fprintf('\n====================================================\n');
            fprintf('PHASE 2B: PAC | P%d V%d\n', P, V);
            fprintf('====================================================\n');

            final_matname = sprintf( ...
                'icafinal_rest_visit%d_P%d.mat', V, P);

            final_matpath = fullfile(preprocessed_path, final_matname);

            if ~exist(final_matpath, 'file')
                warning('Final ICA-cleaned file not found: %s', final_matpath);
                skipped_files{end+1,1} = final_matname; %#ok<AGROW>
                continue;
            end

            try
                S = load(final_matpath, 'EEG');
                EEG = S.EEG;

                validate_final_dataset(EEG, P, V);

                MI_individual = zeros(1, 64);

                for ch = 1:64
                    alpha_signal = double(EEG.data(ch, :));
                    egg_signal = double(EEG.data(ch + 64, :));

                    [MI, ~] = compute_MI_from_prefiltered_signals( ...
                        alpha_signal, egg_signal, position);

                    MI_individual(ch) = MI;
                end

                if any(isnan(MI_individual)) || all(MI_individual == 0)
                    warning('Invalid MI vector for P%d V%d. Skipping.', P, V);
                    skipped_files{end+1,1} = final_matname; %#ok<AGROW>
                    continue;
                end

                % Save PAC separately from the shared input file.
                pac_result = struct();
                pac_result.Participant = P;
                pac_result.Visit = V;
                pac_result.MI_individual = MI_individual;
                pac_result.nbin = nbin;
                pac_result.alpha_band = alpha_band;

                if isfield(EEG, 'etc')
                    if isfield(EEG.etc, 'f_peak')
                        pac_result.f_peak = EEG.etc.f_peak;
                    end
                    if isfield(EEG.etc, 'egg_band')
                        pac_result.egg_band = EEG.etc.egg_band;
                    end
                end

                pac_filename = sprintf( ...
                    'PAC_rest_visit%d_P%d.mat', V, P);

                save(fullfile(pac_path, pac_filename), ...
                    'pac_result', '-v7.3');

                MI_all_subjects(end+1, :) = MI_individual; %#ok<AGROW>
                subject_ids(end+1, 1) = P; %#ok<AGROW>
                subject_visits(end+1, 1) = V; %#ok<AGROW>

                % Individual topoplot.
                EEG_clean = pop_select(EEG, 'channel', 1:64);

                EEG_clean = pop_chanedit(EEG_clean, ...
                    'lookup', chanloc_lookup, ...
                    'load', chanloc_load);

                EEG_clean = pop_chanedit(EEG_clean, ...
                    'eval', 'chans = pop_chancenter(chans, [], []);');

                fig = figure('Visible', 'off');

                clim = max(abs(MI_individual));
                if isempty(clim) || isnan(clim) || clim == 0
                    clim = 1;
                end

                topoplot(MI_individual, EEG_clean.chanlocs, ...
                    'maplimits', [0 clim], ...
                    'electrodes', 'on');

                colorbar;

                title(sprintf( ...
                    'PAC Gastric Phase -> Alpha Amplitude | P%d V%d', ...
                    P, V), ...
                    'Interpreter', 'none');

                exportgraphics(fig, ...
                    fullfile(pac_path, sprintf( ...
                    'PAC_topo_rest_visit%d_P%d.png', V, P)), ...
                    'Resolution', 300);

                close(fig);

                fprintf('PAC completed for P%d V%d\n', P, V);

            catch ME
                warning('PAC failed for P%d V%d: %s', P, V, ME.message);
                skipped_files{end+1,1} = final_matname; %#ok<AGROW>
            end
        end
    end

    % Save group PAC data for each requested visit.
    for vi = 1:numel(visits)
        V = visits(vi);
        visit_idx = subject_visits == V;

        if ~any(visit_idx)
            continue;
        end

        MI_visit = MI_all_subjects(visit_idx, :);
        IDs_visit = subject_ids(visit_idx);
        skipped_visit = skipped_files; %#ok<NASGU>

        group_file = sprintf( ...
            'group_MI_all_subjects_visit%d.mat', V);

        save(fullfile(pac_path, group_file), ...
            'MI_visit', 'IDs_visit', 'skipped_visit', '-v7.3');
    end
end

fprintf('\nFinished PAC pipeline.\n');
fprintf('Included participant-visits: %d\n', size(MI_all_subjects, 1));

%% ========================================================================
%  GROUP TOPOPLOTS
% =========================================================================

if RUN_PAC && ~isempty(subject_ids)

    participants_int = [ ...
       ];

    participants_ref = [ ...
        ];

    % Use the first available final dataset as the topoplot template.
    example_P = subject_ids(1);
    example_V = subject_visits(1);

    example_file = sprintf( ...
        'icafinal_rest_visit%d_P%d.mat', example_V, example_P);

    S = load(fullfile(preprocessed_path, example_file), 'EEG');
    EEG_template = pop_select(S.EEG, 'channel', 1:64);

    EEG_template = pop_chanedit(EEG_template, ...
        'lookup', chanloc_lookup, ...
        'load', chanloc_load);

    EEG_template = pop_chanedit(EEG_template, ...
        'eval', 'chans = pop_chancenter(chans, [], []);');

    for vi = 1:numel(visits)

        V = visits(vi);
        visit_idx = subject_visits == V;

        MI_visit = MI_all_subjects(visit_idx, :);
        IDs_visit = subject_ids(visit_idx);

        if isempty(MI_visit)
            continue;
        end

        if V == 1

            idx_int = ismember(IDs_visit, participants_int);
            idx_ref = ismember(IDs_visit, participants_ref);

            if ~any(idx_int) || ~any(idx_ref)
                warning(['Visit 1 group plot skipped because one or both ' ...
                         'groups contain no valid subjects.']);
                continue;
            end

            MI_int = mean(MI_visit(idx_int, :), 1, 'omitnan');
            MI_ref = mean(MI_visit(idx_ref, :), 1, 'omitnan');

            global_max = max(abs([MI_int, MI_ref]));

            if isempty(global_max) || isnan(global_max) || global_max == 0
                global_max = 1;
            end

            fig = figure( ...
                'Visible', 'off', ...
                'Position', [100 100 1200 500]);

            subplot(1,2,1);
            topoplot(MI_int, EEG_template.chanlocs, ...
                'maplimits', [0 global_max], ...
                'electrodes', 'on');
            colorbar;
            title(sprintf('Intervention (n=%d)', sum(idx_int)));

            subplot(1,2,2);
            topoplot(MI_ref, EEG_template.chanlocs, ...
                'maplimits', [0 global_max], ...
                'electrodes', 'on');
            colorbar;
            title(sprintf('Reference (n=%d)', sum(idx_ref)));

            exportgraphics(fig, ...
                fullfile(pac_path, sprintf( ...
                'PAC_Intervention_vs_Reference_Visit%d.png', V)), ...
                'Resolution', 300);

            close(fig);

        else

            MI_group = mean(MI_visit, 1, 'omitnan');

            % Fixed scale can be useful for direct visual comparison
            % between visits. Adjust if required for your study.
            CLIM_MAX = 0.0015;

            fig = figure('Visible', 'off');

            topoplot(MI_group, EEG_template.chanlocs, ...
                'maplimits', [0 CLIM_MAX], ...
                'electrodes', 'on');

            colorbar;
            caxis([0 CLIM_MAX]);

            title(sprintf( ...
                'Intervention Visit %d (n=%d)', ...
                V, size(MI_visit, 1)));

            exportgraphics(fig, ...
                fullfile(pac_path, sprintf( ...
                'PAC_Intervention_Visit%d_matched.png', V)), ...
                'Resolution', 300);

            close(fig);
        end
    end
end

%% ========================================================================
%  LOCAL FUNCTIONS
% =========================================================================

function fullpath = find_subject_file(filename, folder_list)
%FIND_SUBJECT_FILE Search multiple directories for a file.

    fullpath = '';

    for k = 1:numel(folder_list)
        candidate = fullfile(folder_list{k}, filename);

        if exist(candidate, 'file')
            fullpath = candidate;
            return;
        end
    end
end

function value = get_table_string(variable, row_idx)
%GET_TABLE_STRING Return a table value as a trimmed character vector.

    if iscell(variable)
        value = strtrim(variable{row_idx});
    else
        value = char(strtrim(string(variable(row_idx))));
    end
end

function comps = parse_component_list(comp_string)
%PARSE_COMPONENT_LIST Convert "1,4,7" input to numeric component indices.

    if isempty(strtrim(comp_string))
        comps = [];
        return;
    end

    comps = str2double(strsplit(comp_string, ','));
    comps = comps(~isnan(comps));
    comps = unique(comps);
    comps = comps(comps >= 1);
end

function validate_final_dataset(EEG, P, V)
%VALIDATE_FINAL_DATASET Check assumptions required for PAC analysis.

    if ~isfield(EEG, 'data')
        error('EEG.data is missing for P%d V%d.', P, V);
    end

    if size(EEG.data, 1) < 128
        error(['Expected at least 128 channels for P%d V%d, but found %d. ' ...
               'The PAC stage expects 64 EEG + 64 duplicated EGG channels.'], ...
              P, V, size(EEG.data, 1));
    end

    if EEG.pnts < 2
        error('Dataset contains insufficient samples for P%d V%d.', P, V);
    end
end

function [MI, MeanAmp] = compute_MI_from_prefiltered_signals( ...
    alpha_signal, egg_signal, position)
%COMPUTE_MI_FROM_PREFILTERED_SIGNALS
% Calculate entropy-based Modulation Index from already filtered signals.
%
% alpha_signal : EEG filtered in the alpha band (8-12 Hz)
% egg_signal   : EGG filtered around the participant-specific gastric peak
% position     : phase-bin starting positions in radians

    alpha_signal = double(alpha_signal);
    egg_signal = double(egg_signal);

    amp = abs(hilbert(alpha_signal));
    phase = angle(hilbert(egg_signal));

    nbin = length(position);
    winsize = 2*pi / nbin;

    MeanAmp = zeros(1, nbin);

    for j = 1:nbin
        idx = phase >= position(j) & ...
              phase < position(j) + winsize;

        if any(idx)
            MeanAmp(j) = mean(amp(idx));
        else
            MeanAmp(j) = eps;
        end
    end

    total_amp = sum(MeanAmp);

    if total_amp <= 0 || ~isfinite(total_amp)
        MI = NaN;
        return;
    end

    P = MeanAmp ./ total_amp;
    H = -sum(P .* log(P + eps));

    MI = (log(nbin) - H) / log(nbin);
end

function ICA_log = remove_existing_log_row(ICA_log, P, V)
%REMOVE_EXISTING_LOG_ROW Replace previous manual ICA decision for P/V.

    if isempty(ICA_log)
        return;
    end

    rows_to_remove = ...
        ICA_log.Participant == P & ICA_log.Visit == V;

    ICA_log(rows_to_remove, :) = [];
end

function T_excel = convert_log_for_excel(ICA_log)
%CONVERT_LOG_FOR_EXCEL Convert rejected-component arrays to strings.

    T_excel = ICA_log;
    rejected_string = strings(height(ICA_log), 1);

    for i = 1:height(ICA_log)
        rejected_string(i) = ...
            string(mat2str(ICA_log.RejectedICs{i}));
    end

    T_excel.RejectedICs = rejected_string;
end
