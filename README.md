# YourGutBrain

This repository contains data, analysis code, and figures associated with the **YourGutBrain** study investigating relationships between gastrointestinal physiology, brain activity, and cognition.

## Abstract

**[ manuscript abstract ]**

The study examines gut–brain interactions using simultaneously acquired electrogastrography (EGG) and electroencephalography (EEG), including analyses of gastric activity, resting-state brain activity, and gastric–brain coupling.

---

## Summary of Repository

This repository contains the data and analysis materials required to reproduce the main analyses and figures presented in the associated manuscript.

### Data

The repository contains participant-level data used in the analyses, including:

* **EEG data** — preprocessed electrophysiological data used for the reported EEG analyses.
* **EGG data** — electrogastrography data and derived measures of gastric activity.
* **Gastric–brain coupling data** — data used to quantify coupling between gastric phase and EEG activity, including participant-specific gastric peak frequencies and phase–amplitude coupling measures.
* Faecal SCFA - [Link to metabolomics repo]
* **Cognitive performance data** — available upon reasonable request and following completion of an appropriate data-handling agreement.

Please see the documentation within the relevant data directories for information on file organization, variable definitions, preprocessing, and participant/visit identifiers.

### Scripts

Analysis scripts used to process the data, perform statistical analyses, and generate the results reported in the manuscript are provided in the `scripts/` directory.

The scripts include analyses of:

* EGG activity;
* EEG activity;
* gastric–brain coupling;
* gastric phase–EEG alpha amplitude phase–amplitude coupling (PAC);
* group and visit comparisons; and
* generation of manuscript figures.

Where applicable, individual analysis directories contain additional documentation describing software dependencies, input files, analysis parameters, and expected outputs.

### Figures

The `figures/` directory contains the figures associated with the manuscript.


---

## Paper & Preprint

The data and code in this repository accompany:

**[Authors]. [Manuscript title]. [Journal/year, if applicable].**

### Preprint

**[Insert preprint citation]**

[Link to preprint]

### Published article

**[Insert link/DOI when available]**

If you use the data or analysis code from this repository, please cite the associated manuscript.

---

## Figures

### Figure 1 — [Figure title]

**[Brief description of Figure 1.]**

Relevant data and analysis scripts:

* Data: `[insert path]`
* Script: `[insert path]`
* Figure: `[insert path]`

### Figure 2 — [Figure title]

**[Brief description of Figure 2.]**

Relevant data and analysis scripts:

* Data: `[insert path]`
* Script: `[insert path]`
* Figure: `[insert path]`

### Figure 3 — [Figure title]

**[Brief description of Figure 3.]**

Relevant data and analysis scripts:

* Data: `[insert path]`
* Script: `[insert path]`
* Figure: `[insert path]`

---

## Software Requirements

Analyses in this repository were performed primarily using **MATLAB**.

EEG/EGG analyses may require additional software and toolboxes, including:

* EEGLAB
* EEGLAB plugins specified in the relevant analysis scripts
* MATLAB Signal Processing Toolbox

Additional software requirements are documented alongside the corresponding analysis scripts.

---

## Data Availability

EEG, EGG, and derived gut–brain coupling data required for the analyses described in the repository are provided where permitted by the study's data-sharing framework.

Cognitive performance data are available upon reasonable request and subject to completion of an appropriate data-handling agreement.

Users of the shared participant-level data should comply with the applicable data-use conditions and should not attempt to identify individual participants.

---

## Reproducibility

The repository is organized to link the data, analysis scripts, and outputs associated with the manuscript.

Where raw data cannot be publicly distributed, processed data required to reproduce the corresponding analyses are provided when permitted. The analysis scripts document the preprocessing and analysis procedures used to generate these datasets and the results reported in the manuscript.

---

