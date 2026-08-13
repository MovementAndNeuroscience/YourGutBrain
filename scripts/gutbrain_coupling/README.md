# Gastric–Alpha Phase–Amplitude Coupling in Resting-State EEG

This repository contains the MATLAB/EEGLAB analysis pipeline used to investigate **phase–amplitude coupling (PAC) between the gastric rhythm and cortical alpha activity during resting-state recordings**.

The pipeline processes simultaneously recorded EEG and electrogastrography (EGG) data, performs ICA-based EEG artefact removal, and quantifies coupling between the **phase of the gastric rhythm** and the **amplitude of EEG alpha activity (8–12 Hz)** using the Modulation Index (MI).

ICA-cleaned resting-state datasets used for the PAC analysis are included in the repository. Raw `.bdf` recordings are not included.

---

## Overview

The analysis consists of two main stages:

1. **EEG/EGG preprocessing and ICA**
2. **Manual ICA rejection and gastric–alpha PAC analysis**

The overall workflow is:

```text
Raw resting-state EEG/EGG (.bdf)
        │
        ▼
Import into EEGLAB
        │
        ▼
Resample to 120 Hz
        │
        ├───────────────┐
        ▼               ▼
 EEG channels         EGG channels
   (1–64)              (65–72)
        │               │
        ▼               ▼
 Band-pass           Participant-specific
 filter 8–12 Hz      gastric band-pass
        │               │
        ▼               ▼
 Average              EGG
 reference           reference
        │               │
        └───────┬───────┘
                ▼
              ICA
                │
                ▼
             ICLabel
                │
                ▼
       Manual IC inspection
                │
                ▼
       Remove selected ICs
                │
                ▼
       ICA-cleaned dataset
                │
                ▼
    Gastric phase extraction
                +
    Alpha amplitude extraction
                │
                ▼
      Modulation Index (MI)
                │
        ┌───────┴────────┐
        ▼                ▼
 Individual PAC      Group PAC
  topographies       topographies
```

---

## Software requirements

The pipeline was developed in MATLAB using **EEGLAB 2023.1**.

The following software/toolboxes are required:

* MATLAB
* EEGLAB
* BIOSIG EEGLAB plugin
* ICLabel EEGLAB plugin
* DIPFIT / EEGLAB standard electrode locations
* MATLAB Signal Processing Toolbox

The Signal Processing Toolbox is required for functions including `hilbert`.

---

## Recording configuration

The pipeline was developed for BioSemi recordings containing simultaneously recorded EEG and EGG signals.

The original data structure is assumed to contain:

| Channels | Signal    |
| -------- | --------- |
| 1–64     | EEG       |
| 65–72    | EGG / EXG |

The code is specific to this recording configuration. Channel assignments and referencing should be checked and modified before applying the pipeline to data acquired using another system.

---

## Repository contents

The repository contains:

* MATLAB code for preprocessing and PAC analysis;
* ICA-cleaned resting-state datasets used as input to the PAC analysis; and
* code for generating individual and group-level PAC topographies.

Raw BioSemi `.bdf` recordings are **not included**.

Participant numbers appearing in filenames correspond to study-specific participant IDs.

---

# Analysis pipeline

## 1. Participant and visit selection

Participants and study visits are defined at the beginning of the analysis script.

For example:

```matlab
participants = [, , , ...];
visits = [1];
```

The script can therefore be run separately for different study visits.

For Visit 1, participants are additionally separated into **intervention** and **reference** groups for group-level visualization.

Later visits contain intervention participants only.

---

## 2. Raw data import

Raw recordings are expected to follow the naming convention:

```text
EEG_rest_visit<VISIT>_P<PARTICIPANT>.bdf
```

For example:

```text
EEG_rest_visit1_Pnumber.bdf
```

Raw recordings can be located in multiple directories.

The helper function:

```matlab
find_subject_file()
```

searches the specified raw-data directories and returns the location of the corresponding participant file.

The raw `.bdf` recordings themselves are not distributed with this repository.

---

## 3. Gastric peak frequency

The gastric frequency band is determined individually for each participant and visit.

Gastric peak-frequency estimation, EGG channel selection, and quality control were performed using a **modified and adapted version of the EGG analysis pipeline developed by Wolpert, Rebollo, and Tallon-Baudry**.

The resulting summary data contain:

| Variable      | Description                                      |
| ------------- | ------------------------------------------------ |
| `Participant` | Participant ID                                   |
| `Visit`       | Study visit                                      |
| `Max_Freq`    | Individual gastric peak frequency                |
| `Max_Chan`    | EGG channel containing the selected gastric peak |

The participant-specific gastric peak is subsequently used to define the EGG frequency band for the PAC analysis as:

```matlab id="7e6k7v"
egg_band = [max(0.005, f_peak - 0.015), ...
            f_peak + 0.015];
```

Thus, gastric phase is derived from an individually defined frequency band centred on each participant's gastric peak.

### EGG analysis reference

Wolpert N, Rebollo I, Tallon-Baudry C. *Electrogastrography for psychophysiological research: Practical considerations, analysis pipeline, and normative data in a large sample.* Psychophysiology. 2020;57:e13599.


The participant-specific gastric peak is used to define the EGG frequency band used in the PAC analysis.

---

## 4. Resampling

All recordings are resampled to:

```text
120 Hz
```

using EEGLAB's `pop_resample()` function.

Resampling is performed once before subsequent EEG and EGG filtering.

---

## 5. DC offset removal

The DC offset is removed using:

```matlab
EEG = pop_rmbase(EEG, []);
```

---

## 6. EEG filtering

EEG channels 1–64 are selected and band-pass filtered between:

```text
8–12 Hz
```

This frequency range represents the EEG **alpha band** used in the phase–amplitude coupling analysis.

The filtered alpha-band data are subsequently used to calculate the alpha amplitude envelope.

---

## 7. Participant-specific EGG filtering

EGG channels are filtered around the participant's individual gastric peak frequency.

The frequency range is defined as:

```matlab
egg_half_bw = 0.015;

egg_band = [max(0.005, f_peak - egg_half_bw), ...
            f_peak + egg_half_bw];
```

Thus, the EGG signal is filtered within:

```text
gastric peak ± 0.015 Hz
```

with the lower cutoff constrained to a minimum of 0.005 Hz.

For example, if the participant's gastric peak is:

```text
0.050 Hz
```

the corresponding EGG band is:

```text
0.035–0.065 Hz
```

This procedure provides a participant-specific estimate of the gastric rhythm used for phase extraction.

---

## 8. EEG referencing

EEG channels 1–64 are average referenced.

The average EEG signal is calculated across all 64 EEG electrodes at each time point and subtracted from each electrode.

---

## 9. EGG referencing

The EGG channels are referenced to **EXG2 / channel 65** according to the recording configuration used for this dataset.

Channels 66–72 are referenced as:

```matlab
EEG.data(ch,:) = EEG.data(ch,:) - EEG.data(65,:);
```

This step is specific to the acquisition setup used in the study and should be modified if a different EGG montage is used.

---

# Independent Component Analysis

## 10. ICA

Independent Component Analysis is performed on the **64 EEG channels only**.

The EGG channels are not included in the ICA decomposition.

ICA is performed using extended Infomax:

```matlab
EEG = pop_runica(EEG, ...
    'icatype', 'runica', ...
    'extended', 1, ...
    'chanind', 1:64, ...
    'pca', 63);
```

PCA reduction to 63 components is used because average referencing reduces the rank of the 64-channel EEG data.

---

## 11. ICLabel

Following ICA decomposition, components are classified using the EEGLAB **ICLabel** plugin:

```matlab
EEG = pop_iclabel(EEG, 'default');
```

ICLabel classifications are used to assist subsequent manual component inspection.

Components are **not automatically rejected based on ICLabel probabilities**.

---

## 12. Manual ICA component rejection

ICA components are displayed for manual inspection using:

```matlab
pop_selectcomps()
```

The user manually enters the component indices to reject.

For example:

```text
1,4,7
```

Pressing Enter without entering any component numbers retains all components.

Selected components are subsequently removed using:

```matlab
pop_subcomp()
```

---

## 13. ICA rejection log

Manual ICA decisions are recorded for each participant and visit.

The rejection log contains:

| Variable      | Description                             |
| ------------- | --------------------------------------- |
| `Participant` | Participant ID                          |
| `Visit`       | Study visit                             |
| `RejectedICs` | ICA components removed                  |
| `Timestamp`   | Time at which the decision was recorded |

The log is saved in both MATLAB and Excel formats:

```text
ICA_rejection_log.mat
ICA_rejection_log.xlsx
```

Rejected component indices are also stored within the EEG structure:

```matlab
EEG.etc.rejected_ICs
```

This allows the manual cleaning decisions to be documented alongside the processed data.

---

# ICA-cleaned datasets

After manual ICA rejection, the participant-specific EGG channel identified during the gastric peak analysis is selected.

The original EGG channels are then removed from the final analysis structure, leaving the 64 EEG channels.

The selected EGG signal is duplicated 64 times so that every EEG electrode has a corresponding copy of the same gastric signal.

The final data structure therefore contains:

| Channels | Contents                                   |
| -------- | ------------------------------------------ |
| 1–64     | ICA-cleaned alpha-band EEG                 |
| 65–128   | Duplicated participant-specific EGG signal |

The correspondence is:

```text
EEG channel 1  ↔ EGG duplicate 65
EEG channel 2  ↔ EGG duplicate 66
EEG channel 3  ↔ EGG duplicate 67
...
EEG channel 64 ↔ EGG duplicate 128
```

All EGG duplicate channels contain the same participant-specific gastric signal.

This organization allows the same gastric phase signal to be paired with each of the 64 EEG electrodes during channel-wise PAC calculation.

The final datasets follow the naming convention:

```text
icafinal_rest_visit<VISIT>_P<PARTICIPANT>.mat
```

and, where applicable:

```text
icafinal_rest_visit<VISIT>_P<PARTICIPANT>.set
```

---

# Phase–amplitude coupling analysis

## 14. PAC definition

The analysis quantifies coupling between:

**Phase**

> Participant-specific gastric EGG rhythm

and

**Amplitude**

> EEG alpha activity (8–12 Hz)

PAC is calculated independently for each of the 64 EEG electrodes.

---

## 15. Hilbert transform

Because the EEG and EGG signals have already been filtered into their respective frequency ranges, the analytic signals are obtained directly using the Hilbert transform.

Alpha amplitude is calculated as:

```matlab
amp = abs(hilbert(alpha_signal));
```

Gastric phase is calculated as:

```matlab
phase = angle(hilbert(egg_signal));
```

The resulting gastric phase ranges from (-\pi) to (+\pi).

---

## 16. Phase binning

The gastric cycle is divided into **18 equally spaced phase bins**.

The phase-bin positions are defined as:

```matlab
nbin = 18;

position = -pi + (0:nbin-1) * (2*pi/nbin);
```

For each gastric phase bin, the mean alpha amplitude is calculated.

This produces a distribution of alpha amplitude as a function of gastric phase.

---

## 17. Modulation Index

Phase–amplitude coupling strength is quantified using an entropy-based **Modulation Index (MI)**.

The mean alpha amplitudes across phase bins are first normalized:

```matlab
P = MeanAmp ./ sum(MeanAmp);
```

The entropy of this distribution is then calculated:

```matlab
H = -sum(P .* log(P + eps));
```

Finally, MI is calculated as:

```matlab
MI = (log(nbin) - H) / log(nbin);
```

where:

```text
nbin = 18
```

If alpha amplitude is distributed uniformly across gastric phases, MI approaches zero.

Higher MI values indicate a stronger dependence of alpha amplitude on gastric phase.

---

## 18. Participant-level PAC

PAC is calculated separately for every EEG channel.

Each participant therefore produces a vector containing 64 MI values:

```text
MI_individual = 1 × 64
```

where each value represents gastric–alpha PAC at one EEG electrode.

The values are stored as:

```matlab
EEG.MI_individual
```

---

# Topographical visualization

## 19. Individual PAC topographies

Participant-level PAC values are visualized across the scalp using EEGLAB's:

```matlab
topoplot()
```

Each participant receives an individual topographical plot showing the spatial distribution of gastric–alpha MI across the 64 EEG electrodes.

Example output filename:

```text
PAC_topo_rest_visit1_Pnumber.png
```

---

## 20. Group-level PAC

Participant-level MI vectors are combined into:

```matlab
MI_all_subjects
```

with dimensions:

```text
number of participants × 64 EEG electrodes
```

Participant IDs are stored separately in:

```matlab
subject_ids
```

Files that cannot be successfully processed are recorded in:

```matlab
skipped_files
```

The group-level data are saved as:

```text
group_MI_all_subjects_visit<VISIT>.mat
```

---

## 21. Intervention and reference groups

For Visit 1, participants are separated into intervention and reference groups using predefined participant lists.

The mean MI at each electrode is calculated independently for the two groups.

Group topographies are then generated using a common colour scale to allow visual comparison between the intervention and reference groups.

Example output:

```text
PAC_Intervention_vs_Reference_Visit1.png
```

For subsequent visits, group-level topographies are generated for intervention participants.

---

# Output files

Depending on the stage of the analysis, the pipeline generates the following files.

### ICA datasets

```text
ica_rest_visit<VISIT>_P<PARTICIPANT>.set
```

These contain the preprocessed data and ICA decomposition prior to manual component rejection.

### ICA-cleaned datasets

```text
icafinal_rest_visit<VISIT>_P<PARTICIPANT>.set
icafinal_rest_visit<VISIT>_P<PARTICIPANT>.mat
```

### ICA rejection records

```text
ICA_rejection_log.mat
ICA_rejection_log.xlsx
```

### Participant PAC topographies

```text
PAC_topo_rest_visit<VISIT>_P<PARTICIPANT>.png
```

### Group PAC data

```text
group_MI_all_subjects_visit<VISIT>.mat
```

### Group PAC topographies

For Visit 1:

```text
PAC_Intervention_vs_Reference_Visit1.png
```

For intervention-only visits:

```text
PAC_Intervention_Visit<VISIT>_matched.png
```

---

# Data availability and reproducibility

This repository includes the **ICA-cleaned resting-state datasets used for the gastric–alpha PAC analysis**.

Raw `.bdf` recordings are not included.

Consequently, there are two different levels of reproducibility associated with this repository.

### Preprocessing and ICA

The supplied MATLAB code documents the preprocessing applied to the original recordings, including:

* resampling;
* EEG and EGG filtering;
* EEG and EGG referencing;
* ICA decomposition;
* ICLabel classification; and
* manual ICA component rejection.

Because the original raw `.bdf` recordings are not included, the complete preprocessing procedure cannot be rerun from the original recordings using this repository alone.

### PAC analysis

The included ICA-cleaned resting-state datasets provide the data used for the subsequent gastric–alpha PAC analysis.

These files can therefore be used to reproduce the participant-level MI calculations and subsequent group-level analyses without requiring access to the original raw recordings.

---

# Running the code

Before running the pipeline on a local computer, update the paths at the beginning of the MATLAB script.

For example:

```matlab
addpath('PATH_TO_EEGLAB');

raw_folders = {
    'PATH_TO_RAW_DATA'
};

preprocessed_path = 'PATH_TO_PREPROCESSED_DATA';
pac_path = 'PATH_TO_PAC_RESULTS';

summary_path = 'PATH_TO_GASTRIC_PEAK_SUMMARY.xlsx';

chanloc_lookup = 'PATH_TO_STANDARD_1005.elc';
```

The absolute paths used during the original analysis are computer-specific and should be replaced with paths appropriate for the local installation.

Users reproducing only the PAC analysis from the included ICA-cleaned files do not require the original raw `.bdf` recordings.

---

# Important methodological considerations

This code was developed for a specific simultaneous EEG/EGG recording configuration and should not be applied to another dataset without checking the relevant assumptions.

In particular, users should verify:

* EEG and EGG channel assignments;
* sampling rate;
* EEG rank before ICA;
* referencing scheme;
* EGG reference channel;
* electrode locations;
* participant-specific gastric frequency estimates;
* filtering parameters; and
* channel ordering.

ICA rejection in the original preprocessing pipeline is **manual**. ICLabel is used to support inspection but components are not automatically rejected according to ICLabel classifications.

The saved ICA-cleaned datasets should therefore be used when the objective is to reproduce the PAC analysis reported for this dataset.

---

# Notes on the shared data

Participant identifiers used in filenames are study-specific IDs.

Users of the shared data should comply with the conditions under which the dataset has been made available and should not attempt to identify individual participants.

Please refer to the associated study documentation and publication for further information regarding participant recruitment, data collection, ethics approval, and data-sharing conditions.

---

# Citation

If you use this code or the accompanying data in academic work, please cite the associated publication.

```text
Citation to be added upon publication.
```

If appropriate, please also cite EEGLAB and the methodological literature underlying the analysis, including the Modulation Index approach used to quantify phase–amplitude coupling.

---

# Contact

For questions regarding the analysis pipeline, implementation, or data included in this repository, please open an issue in the GitHub repository.
