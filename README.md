# batchScratcher
Repository of functions that automate pushing data from your local machine to the scratch folder on a remote SLURM cluster with MATLAB Parallel Server installed, running remote 'batch' jobs, and retrieving the data.

## Overview

**batchScratcher** is a MATLAB-based project developed to provide a standalone, standardized, (hopefully) more intuitive framework for submitting 'batch' jobs to remote clusters running Matlab Parallel Server. This repository contains code that automates compressing a local copy of a project folder, pushing that project to the remote cluster, running a specified script as a 'batch' job, and retrieving the data back to your local machine.

## Dependencies

- Must be running either a Unix/Linux-based OS or macOS
- MATLAB R2021a or newer
- Required Toolbox(es):
  - MATLAB (base)
  - [MATLAB Parallel Computing Toolbox]('https://www.mathworks.com/products/parallel-computing.html')

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
% Open MATLAB and add the project to your path:
addpath(genpath('~/Documents/MATLAB/batchScratcher'));
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
| `submitBatchClstrJobMain.m`     | Primary script for submitting batch jobs. Effectively serves as a 'wrapper' for 'submitBatchClstrJob_v1.m'                 |
| `submitBatchClstrJob_v1.m`     | Main function called by 'submitBatchClstrJobMain.m' for preparing copies of a local project directory, pushing it to the cluster's scratch, and submitting scripts to run there remotely as batch jobs                 |
| `rxivMatlabPrjctDir4RemoteJob.m`     | Main function called by 'submitBatchClstrJob_v1.m' for compressing the local project directory. Effectively serves as a wrapper for the bash function 'rxivMatlabCode_v5.sh' which compresses subselections of data contained within the folder to tar.gz while maintaining the organizational structure of the project directory              |
| `mirror2cluster/`            | Sub-directory where other specified local project directories are copied an compressed prior to pushing to the remote cluster  |


## Acknowledgements


---
