# batchScratcher
Repository of functions that automate pushing data from your local machine to the scratch folder on a remote SLURM cluster with MATLAB Parallel Server installed, running remote 'batch' jobs, and retrieving the data.

## Overview

**batchScratcher** is a MATLAB-based project developed to provide a standalone, standardized, (hopefully) more intuitive framework for submitting 'batch' jobs to remote clusters running Matlab Parallel Server. This repository contains code that automates compressing a local copy of a project folder, pushing that project to the remote cluster, running a specified script as a 'batch' job, and retrieving the data back to your local machine.

This version of the repository was exported and cleaned using [`pipeCleaner`](https://github.com/ejduwell/pipeCleaner), which automatically finds and organizes all required dependencies into a single structured directory for sharing and archival.

## Dependencies

- MATLAB R2021a or newer
- Required Toolbox(es):
  - MATLAB (base)
  - [Add any additional toolboxes used]

## Installation

### macOS and Linux

Open a terminal and run:

```bash
# Navigate to desired install location
cd ~/Documents/MATLAB

# Clone the repository from GitHub
git clone https://github.com/yourGithubUsername/yourProjectRepoName.git

# Open MATLAB and add the project to your path:
addpath(genpath('~/Documents/MATLAB/yourProjectRepoName'))
savepath
```

### Windows

1. Open MATLAB
2. In the Command Window, run:

```matlab
% Change directory to desired location
cd('C:\Users\YourName\Documents\MATLAB')

% Clone from GitHub (or download ZIP and unzip manually)
system('git clone https://github.com/yourGithubUsername/yourProjectRepoName.git')

% Add the project folder to your MATLAB path:
addpath(genpath('C:\Users\YourName\Documents\MATLAB\yourProjectRepoName'))
savepath
```

## Usage

This project was exported using the `pipeCleaner` tool. The root directory and sub-directories within contain all required `.m` files needed to run the pipeline.

To use this code:

1. Open MATLAB
2. Add the root project folder to your MATLAB path (if not already done)
3. Locate and run the main entry-point script(s) — typically found in the top level of the folder (e.g., `yourMainScript.m`).

### Common File Types

| File/Folder            | Description                                       |
|------------------------|---------------------------------------------------|
| `yourMainScript.m`     | Primary script to run the project                 |
| `miscFcns/`            | User-defined functions that did not match a tag  |
| `subFolderName/`       | Functions grouped based on original path tags     |
| `data/`, `figures/`    | Additional manually created folders if present    |

## Tips for Reuse

- If you are adapting this repository for your own project, rename the folder and scripts as needed.
- If you wish to clean/export a new version, use `pipeCleaner` to regenerate a fresh copy with updated dependencies.
- If you make changes to file structure, be sure to re-test that your pipeline runs correctly.

## Acknowledgements

This project was cleaned and exported using the [pipeCleaner](https://github.com/ejduwell/pipeCleaner) tool, developed by Ethan Duwell, PhD (2025), with support from OpenAI’s GPT-4o model.

---
