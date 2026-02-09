# batchScratcher
Repository of functions that automate pushing data from your local machine to the scratch folder on a remote SLURM cluster with MATLAB Parallel Server installed, running remote 'batch' jobs, and retrieving the data.

## Overview

**batchScratcher** is a MATLAB-based project developed to provide a standalone, standardized, (hopefully) more intuitive framework for submitting 'batch' jobs to remote clusters running Matlab Parallel Server. This repository contains code that automates compressing a local copy of a project folder, pushing that project to the remote cluster, running a specified script as a 'batch' job, and retrieving the data back to your local machine.

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
git clone https://github.com/ejduwell/batchScratcher.git
```

```matlab
# Open MATLAB and add the project to your path:
addpath(genpath('~/Documents/MATLAB/batchScratcher'));
savepath;
```

### Windows

1. Open MATLAB
2. In the Command Window, run:

```matlab
% Change directory to desired location
cd('C:\Users\YourName\Documents\MATLAB');

% Clone from GitHub (or download ZIP and unzip manually)
system('git clone https://github.com/ejduwell/batchScratcher.git');

% Add the project folder to your MATLAB path:
addpath(genpath('C:\Users\YourName\Documents\MATLAB\batchScratcher'));
savepath;
```

## Usage

To use this code:

1. Open MATLAB
2. Add the root project folder to your MATLAB path (if not already done)
3. Locate and run the main entry-point script(s) — found in the top level of the folder (e.g., `submitBatchClstrJobMain.m`).

### Common File Types

| File/Folder            | Description                                       |
|------------------------|---------------------------------------------------|
| `submitBatchClstrJobMain.m`     | Primary script to run the project                 |
| `miscFcns/`            | User-defined functions that did not match a tag  |
| `subFolderName/`       | Functions grouped based on original path tags     |
| `data/`, `figures/`    | Additional manually created folders if present    |


## Acknowledgements


---
