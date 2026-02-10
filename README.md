# batchScratcher
Repository of functions that automate pushing data from your local machine to the scratch folder on a remote SLURM cluster with MATLAB Parallel Server installed, running remote 'batch' jobs in the cluster's scratch directory, retrieving the data, and cleaning up the remnants of the job in cluster's scratch when its done.

## Quick Links to Sections:

- [Overview](https://github.com/ejduwell/batchScratcher/blob/main/README.md#overview)
- [Dependencies](https://github.com/ejduwell/batchScratcher/blob/main/README.md#dependencies)
- [Installation](https://github.com/ejduwell/batchScratcher/blob/main/README.md#installation)
- [A brief list and overview of important files & folders](https://github.com/ejduwell/batchScratcher/blob/main/README.md#a-brief-list-and-overview-of-important-files--folders)
- [Usage](https://github.com/ejduwell/batchScratcher/blob/main/README.md#usage)
  
## Overview:

**batchScratcher** is a MATLAB-based project developed to provide a standalone, standardized, (hopefully) more intuitive framework for submitting 'batch' jobs to remote clusters running Matlab Parallel Server. This repository contains code that automates compressing a local copy of a project folder, pushing that project to the remote cluster's scratch, running a specified script as a 'batch' job, retrieving the data back to your local machine, and cleaning up the remnants of the job in cluster's scratch when its done.

## Dependencies:

- Must be running either a Unix/Linux-based OS or macOS
- Must have SSH installed and enabled
- Must have rsync installed
- Must have pigz installed for parallelized/accelerated compression features for compressing project directory.
- MATLAB (I developed this using R2025b)
- Required MATLAB Toolbox(es):
  - [MATLAB Parallel Computing Toolbox](https://www.mathworks.com/products/parallel-computing.html)
- Access to a remote SLURM cluster running [Matlab Parallel Server](https://www.mathworks.com/products/matlab-parallel-server.html)
  - For users at the Medical College of Wisconsin, instructions for setting up access to the Matlab Parallel Server on the HPC cluster can be found [HERE](https://docs.rcc.mcw.edu/software/matlab/)

## Installation:

### macOS and Linux

**(Step 00) If you are an MCW user, you must first set up access to MATLAB Parallel Server:**

(I presume a similar procedure will likely be in place at other institutions)
- If you have not done so already, follow the instructions provided [HERE](https://docs.rcc.mcw.edu/software/matlab/)
- Then proceed with the instructions below.

**(Step 01) Install batchScratcher and add to path:**

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

**(Step 02) Set up SSH keys:**

Open a terminal and run the following (replace email place-holder with your own):

```bash
ssh-keygen -t ed25519 -C "your_email@abc.edu"
```

You’ll see prompts like:

```bash
Enter file in which to save the key (/home/username/.ssh/id_ed25519):
```

Press Enter to accept the default.

Next you'll see something like this:

```bash
Enter passphrase (empty for no passphrase):
```

Simply press enter to proceed without a passphrase.
This allows for full automation of ssh/rsync pushing/pulling data to the remote cluster wihout needing to manualy provide a password every time.
However, public/private ssh key pairs will be generated to allow secure ssh access without a password.

It will result in the followng files:
```bash
~/.ssh/id_ed25519        (private key — keep secret)
~/.ssh/id_ed25519.pub    (public key — safe to share)
```

You now need to install your public key on the cluster (replace 'username' and 'login-hpc.cluster.hostname.edu' with your cluster username and cluster hostname):

```bash
ssh-copy-id username@login-hpc.cluster.hostname.edu
```

You’ll be prompted once for your password.

If successful, you’ll see something like:

```bash
Number of key(s) added: 1
```

To further test whether you were successful, try logging into the cluster via ssh:
```bash
ssh username@login-hpc.cluster.hostname.edu
```
If the ssh key setup above worked, you should now no longer be prompted for a password to login to the cluster.

**(Step 03) Create Directory in Remote Cluster Scratch for Running Batch Jobs:**

Open a terminal window, log into the remote cluster, and navigate to the location in /scratch where you want to run your batch jobs 
```bash
# Log into remote cluster
ssh username@login-hpc.cluster.hostname.edu
# Navigate to location in scratch where you want to create parent directory for running Matlab batch jobs
cd /scratch/path/to/desired/location
```

Create directory to house Matlab batch jobs running remotely on scratch
```bash
# Create directory
mkdir matlabBatchScratch
```
Copy the full path location of the directory you just created
```bash
# Enter the directory
cd matlabBatchScratch
# Run 'pwd' command to get the full path to matlabBatchScratch
pwd
# (copy the output)
```
Open 'submitBatchClstrJobMain.m' in Matlab and set 'jobIn.mainClusterPath' equal to the directory path just created/copied
```matlab
% set jobIn.mainClusterPath equal to the directory path just created
% (i.e. paste the pwd command output copied above)
jobIn.mainClusterPath="/scratch/dir/path/output/from/pwd/command/above";
```
Installation/setup is now complete and **batchScratcher** should be ready to use...


## A brief list and overview of important files & folders:

| File/Folder            | Description                                       |
|------------------------|---------------------------------------------------|
| `submitBatchClstrJobMain.m`     | Primary script for submitting batch jobs. Effectively serves as a 'wrapper' for 'submitBatchClstrJob_v1.m'                 |
| `submitBatchClstrJob_v1.m`     | Main function called by 'submitBatchClstrJobMain.m' for preparing copies of a local project directory, pushing it to the cluster's scratch, and submitting scripts to run there remotely as batch jobs                 |
| `rxivMatlabPrjctDir4RemoteJob.m`     | Main function called by 'submitBatchClstrJob_v1.m' for compressing the local project directory. Effectively serves as a wrapper for the bash function 'rxivMatlabCode_v5.sh' which compresses subselections of data contained within the folder to tar.gz while maintaining the organizational structure of the project directory              |
| `rxivMatlabCode_v5.sh`     | Bash function called by 'rxivMatlabPrjctDir4RemoteJob.m' for preparing compressed copies of a local project directory. Allows subselection of files in specific sub-directories and/or particular filetypes while maintaining overall directory structure                |
| `pushTarGzToCluster_v2.m`     | Matlab function that issues bash commands to push the compressed local copy of the project directory to the remote cluster's scratch.              |
| `pullRemoteDirTarSlurm_v1.m`     | Matlab wrapper function for 'pull_remote_dir_tar_slurm.sh' that compresses remote directory on cluster when job is done and pulls data back to local machine.              |
| `pull_remote_dir_tar_slurm.sh`     | Bash function called by 'pullRemoteDirTarSlurm_v1.m' for preparing and pulling compressed copies of a remote project directory on cluster, and cleaning up after the job is done.                |
| `mirror2cluster/`            | Sub-directory where other specified local project directories are copied an compressed prior to pushing to the remote cluster  |



## Usage:

To use this code:

1. Open MATLAB
2. Add the root project folder to your MATLAB path (if not already done)
3. Locate and run the main entry-point script(s) — found in the top level of the folder (e.g., `submitBatchClstrJobMain.m`).

### 1) Open 'submitBatchClstrJobMain.m' and update the parameters under the 'Set Pars' section:

```matlab
%% Set Pars

% auto-detect where the batchScratcher is installed on this machine
[projDirPath,~,~]=fileparts(which("submitBatchClstrJobMain.m"));

jobIn=struct; % intialize main struct..

% generate unique temp subdir for mirroring to cluster:
rng("shuffle");
tmpMirrorDir=strcat("jobTmpMirror_",num2str(randi(1000000000)));

% set pars for rxivMatlabPrjctDir4RemoteJob.m
%--------------------------------------------------------------------------
jobIn.prjctDirCpyPars=struct; % initialize
% set 'baseDir' (the local path to your project/program directory):
jobIn.prjctDirCpyPars.baseDir="/path/to/your/local/project/directory";
% set 'outDirBase' (path to where you want local compressed copy pushed to
% the cluster to be generated)
jobIn.prjctDirCpyPars.outDirBase=strcat(projDirPath,"/mirror2cluster/",tmpMirrorDir);
% make the output dir for mirroring prior to running job..
[statusTmp,msgTmp,msgIDtmp]=mkdir(jobIn.prjctDirCpyPars.outDirBase);
% specify set of extensions for filetypes you want to be included in the
% compressed copy of the project dir pushed to the cluster:
jobIn.prjctDirCpyPars.fileExtnz={".m",".sh",".lt",".1D"};
% specify individual files to include regardless of whether their extension 
% is specified in jobIn.prjctDirCpyPars.fileExtnz
jobIn.prjctDirCpyPars.indFiles={ ...
    "path/to/your/individalFileToInclude.ext", ...
    "path/to/another/individalFileToInclude.ext", ...
    };
% Specify 'dirs2Ignore' (set of subdirectories in your project directory to
% 'ignore'/not include in the compressed copy pushed to the cluster 
% regardless of whether their extensions are in the fileExtnz set.) 
% (Ethan added this functionality in the interest of efficiency. It allows 
% users to reduce the size of the project dir copy compressed and pushed to 
% the remote cluster and save time on compression/exporting files 
% not necessary for the job at hand)
jobIn.prjctDirCpyPars.dirs2Ignore={};
% Specify whether you want to compress the output directory copy
jobIn.prjctDirCpyPars.compress=1; % 1 or 0, (probably want 1 to compress..)
% auto-set 'programDirName' by extracting the directory name of the end of 
% the path specified as 'baseDir' above using 'fileparts' function:
[~,programDirName,~]=fileparts(jobIn.prjctDirCpyPars.baseDir);
jobIn.programDirName=programDirName;
%--------------------------------------------------------------------------

% pigz compression options:
%--------------------------------------------------------------------------
jobIn.prjctDirCpyPars.pigzPars=struct; % preallocate
jobIn.prjctDirCpyPars.pigzPars.usePigz=1; % use pigz to parallelize compression or no (1 or 0)
jobIn.prjctDirCpyPars.pigzPars.nCpus4Pigz=16; % set # of cpus for pigz to use
%--------------------------------------------------------------------------

% specify path to your "matlabBatchScratch" folder in scratch on the cluster
% (you need to make this there..)
jobIn.mainClusterPath="/scratch/g/agreenberg/eduwell/projects/matlabBatchScratch";

% Set cluster profile name for your cluster:
jobIn.clstrProfile="HPC Cluster"; % cluster profile name string (ie like "HPC Cluster")

% Specify additional SLURM headers
%--------------------------------------------------------------------------
jobIn.adnlArgs.timeInfo='--time=00-01:00:00'; % string describing time reserved for job in format : '--time=DD-HH:MM:SS';
jobIn.adnlArgs.memPerCpu='--mem-per-cpu=7gb'; % memory per cpu
jobIn.adnlArgs.ntasks='--ntasks=1'; % number of tasks
jobIn.adnlArgs.cpusPerTask="--cpus-per-task=32";  % number of cpus per task
%--------------------------------------------------------------------------

% specify cluster hostname/username info..
%--------------------------------------------------------------------------
jobIn.clusterHostname="login-hpc.rcc.yerCluster.edu";
jobIn.clusterUsername="yerUserName";
jobIn.clusterPIaccount="yerPIsAccountName";
%--------------------------------------------------------------------------

% specify function/script to run as a batch job along with input pdf and output vars
%--------------------------------------------------------------------------
jobIn.mainFcn.fname="yourScript2RunAsBatchJob";
% specify parameter descriptor file if your function/script uses one
% (otherwise feel free to ignore/comment out)
jobIn.mainFcn.inputPDF={};
jobIn.mainFcn.outVars={}; % output variables
jobIn.mainFcn.nFcnOutputs=0; % number of function inputs
%--------------------------------------------------------------------------

% parameters for pulling remote data on cluster back to local machine
% (Note: this final compression/data transfer back to the local machine
% is run as an additional sbatch slurm job at the end after running the matlab
% routine submitted to enable the ability to use pigz/multiple cpus to compress
% and make this run a lot faster...)
%--------------------------------------------------------------------------
jobIn.pullDownTimeStr="00-01:00:00"; % time alloted for compressing/pulling down
jobIn.pullDownCPUs=16; % number of cpus for compression/pulling down data
jobIn.pullDown.CleanRemoteTar=true; % if true, will clean up/remove the remote tar.gz copy after compression/transfer to local machine
jobIn.pullDown.CleanRemoteJob=true; % if true, will clean up temp directory generated remotely during compression
jobIn.pullDown.CleanLocalTar=true; % if true, will clean up/remove local tar.gz copy pulled down from remote cluster after extracting it's contents
jobIn.pullDown.rmRemoteDir=true; % if true, will completely remove the temporary subdirectory generated remotely in the cluster 
                                 % scratch for running this job after transfering it to the local machine
%--------------------------------------------------------------------------


```
### 2) Run submitBatchClstrJobMain.m to submit the job:

Either by running the following in the Matlab Command Window:
```matlab
submitBatchClstrJobMain
```

Or by hitting the green 'Run' button at the top of the Matlab editor window...

## Notes and Helpful Tips:

**1) Make sure that all code/data required to run your job are stored under a single parent project directory!**
- **batchScratcher** assumes implicitly that all of the code and data necessary to run the batch job is contained within a single parent directory on your local machine.
- This directory is the one you specify as "jobIn.prjctDirCpyPars.baseDir" in the parameter section of 'submitBatchClstrJobMain.m'
- If you're like me and tend to recycle code/functions from old projects, your project's code may intitially be distributed haphazardly across multiple directories all over your machine like Johnny Appleseed...
- If that is the case, you will need to copy/move all of the code necessary for your job to run under a single directory and point "jobIn.prjctDirCpyPars.baseDir" to that directory in 'submitBatchClstrJobMain.m' prior to submitting your job.
- Luckily, I also developed a Matlab package for doing just that called: [pipeCleaner](https://github.com/ejduwell/pipeCleaner)
- Click on the link above for full details, but in short, pipeCleaner automatically finds all of the Matlab code required to run a particular script/function and copies/organizes it neatly under a single project directory.

**2) batchScratcher automatically logs the specific options you use to generate the mirrored copy of your project directory in a file called README.txt**
- rxivMatlabCode_v5.sh, the bash function that ultimately handles creating the copy of your project directory mirrored to the cluster automatically saves the options used in a file called README.txt
- This logs the original local project folder being compressed, the specific filetypes included in the copy, and other parameters. Heres an example from my project below:
```
This directory was created by the bash script 'rxivMatlabCode_v5.sh' (written by E.J. Duwell, PhD).
It contains an archived copy of content from:
  /home/eduwell/SynologyDrive/projects/revCorrStimFMRI

Included file extensions:
  .m
  .sh
  .lt
  .1D

Additionally included individual files (relative to src_dir):
  matlab/fmriAnalysis/revCorrFMRI_Regrsrz_Take07_ERaves/046_revCorrFMRI_Regrsrz_Take07_ERaves.mat

Ignored subdirectories: (none)

Compression (--compress): 1
Use pigz (--pigz): 1
pigz CPUs (-p): 16

Created on:
  Tue Feb 10 01:13:15 PM CST 2026

```
- This is stored in the 'matlabCodeRxiv' directory which encloses the project directory on the cluster and in the local copy stored under batchScratcher/mirror2cluster


---
