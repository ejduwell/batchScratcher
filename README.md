# batchScratcher
Repository of functions that automate pushing data from your local machine to the scratch folder on a remote SLURM cluster with MATLAB Parallel Server installed, running remote 'batch' jobs in the cluster's scratch directory, retrieving the data, and cleaning up the remnants of the job in the cluster's scratch when its done.

## Quick Links to Sections:

- [Overview](https://github.com/ejduwell/batchScratcher/blob/main/README.md#overview)
- [Key Functionalities](https://github.com/ejduwell/batchScratcher/blob/main/README.md#key-functionalities)
- [Dependencies](https://github.com/ejduwell/batchScratcher/blob/main/README.md#dependencies)
- [Installation](https://github.com/ejduwell/batchScratcher/blob/main/README.md#installation)
- [A brief list and overview of important files & folders](https://github.com/ejduwell/batchScratcher/blob/main/README.md#a-brief-list-and-overview-of-important-files--folders)
- [Usage](https://github.com/ejduwell/batchScratcher/blob/main/README.md#usage)
- [Notes and Helpful Tips](https://github.com/ejduwell/batchScratcher/blob/main/README.md#notes-and-helpful-tips)
  
## Overview:

**batchScratcher** is a MATLAB-based project developed to provide a general-purpose, standardized, (hopefully) more intuitive framework for submitting 'batch' jobs to remote clusters running Matlab Parallel Server. This repository contains code that automates compressing a local copy of a project folder, pushing that project to the remote cluster's scratch, running a specified script as a 'batch' job, retrieving the data back to your local machine, and cleaning up the remnants of the job in the cluster's scratch when its done.

## Key Functionalities:

**batchScratcher** is designed to make submitting *MATLAB remote batch jobs on a SLURM cluster* intuitive, flexible, and powerful — without requiring users to rewrite or restructure their existing project code. It automates many of the typical hassles of cluster workflows into clear, simple steps.

### 📦 Project Transfer Automation
- **Mirror entire local project directory to cluster scratch** before execution — including folder structure — rather than forcing users to manually specify every file and dependency. This avoids the fragile, error-prone process of individually listing required files for a batch job.
- Allows **sub-selection of files and folders** (e.g., by extension or ignore patterns) so only necessary code/data are transferred, reducing transfer time and overhead.

### 🚀 Remote Batch Submission with Intuitive SLURM Options
- Automates **SLURM header construction** by letting users specify resources like CPUs, memory, GPUs, and time limits through intuitive parameters — eliminating the need to manually concatenate header flags into one long space-separated string.
- Submits MATLAB batch jobs using a specified cluster profile while handling SSH and SLURM integration details under the hood.
- Makes it straightforward to request GPUs or multi-CPU resources for jobs that internally use `parpool`, `parfor`, or other parallel features.

### 🔄 Output Management and Retrieval
- Automatically **compresses output on the cluster**, transfers it back to the local machine, and **syncs results into the original project directory**, so outputs appear exactly where expected.
- Provides options to **clean up remote scratch directories** and temporary archives after job completion to maintain organized storage.

### 🧠 Intuitive Path and Dependency Handling
- Because the full project directory is mirrored before execution, users do not need to refactor code to accommodate remote execution.
- Existing paths, subfolders, and dependencies resolve on the cluster just as they do locally — minimizing debugging related to missing files.
- Enables users to run a local project pipeline on a remote cluster with minimal or no changes to existing code.

### 🧪 Debugging and Logging Enhancements
- Automatically captures and returns all Matlab Command Window output and error logs from the remote batch job into readable files within the project directory.
- Reduces the need to manually inspect SLURM output files or navigate remote scratch directories for debugging.

### 🔧 Power User Controls
For more experienced users, batchScratcher also provides:
- Fine-grained control over SLURM resource requests (e.g., task counts, memory per CPU, GPU flags, wall time).
- Flexible inclusion/exclusion filtering for complex project structures.
- The ability to integrate into advanced SLURM configurations while maintaining a clean, automated workflow.

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

#### (Step 00) If you are an MCW user, you must first set up access to MATLAB Parallel Server:

(I presume a similar procedure will likely be in place at other institutions)
- If you have not done so already, follow the instructions provided [HERE](https://docs.rcc.mcw.edu/software/matlab/)
- Then proceed with the instructions below.

#### (Step 01) Install batchScratcher and add to path:

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

#### (Step 02) Set up SSH keys:

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

#### (Step 03) Create Directory in Remote Cluster Scratch for Running Batch Jobs:

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
| `pull_remote_dir_tar_slurm.sh`     | Bash function called by 'pullRemoteDirTarSlurm_v1.m' for preparing and pulling compressed copies of a remote project directory on cluster, and cleaning up the remote scratch after the job is done.                |
| `syncDirCpy2MainDir.m`     | Matlab wrapper function for 'syncDirCpy2MainDir.sh' that syncs the output directory copy pulled down from the cluster to the temporary local folder in batchScratcher/mirror2cluster/ with the original project directory on the local machine and then cleans up the tempory local copy.              |
| `syncDirCpy2MainDir.sh`     | Bash function called by the syncDirCpy2MainDir.m Matlab wrapper function, that uses rsync commands to detect and sync any new files/folders in the temporary output directory copy from the cluster job with the original local project directory. Also cleans up the local copy in the temporary subdirectory in batchScratcher/mirror2cluster/ by either archiving it in specified location or deleting it if specified.              |
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
% Note: feel free to alter these to whatever is required for your
% particular job. You can also remove ones you don't need or add as many
% more SLURM headers as you want.
% ** Just make sure that they are specified as jobIn.adnlArgs.() subfields!**
% ** Any/All field strings in jobIn.adnlArgs will be interpreted as SLURM headers **
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

% parameters for archiving the compressed output directory copy pulled down
% from the cluster to your local machine after the job is finished.
%--------------------------------------------------------------------------
jobIn.rxivOutputTarCopy=1; % if 1, will save/archive the compressed copy of 
                        % the output directory from the cluster by moving 
                        % it (i.e. witn mv, not copy with cp) 
                        % to a location on the local machine specified 
                        % below by jobIn.rxivOutputCopyDir

% specify output subdirectory to save archived copys of the output data 
% when jobIn.rxivOutputTarCopy is on/1 (paths are assumed to be relative to 
% your main project folder specified above as 
% jobIn.prjctDirCpyPars.baseDir. If it doesn't exist it will be created):                        
jobIn.rxivOutputCopyDir="dataRxiv";

% NOTE: if jobIn.rxivOutputTarCopy==1, jobIn.pullDown.CleanLocalTar must be
% turned off (set to false) such that there is a compressed copy to
% save/archive. For this reason, the short routine below is in place to
% ensure that whenever jobIn.rxivOutputCopy==1 
% jobIn.pullDown.CleanLocalTar=false:
if jobIn.rxivOutputTarCopy==1
    jobIn.pullDown.CleanLocalTar=false;
end
%--------------------------------------------------------------------------

% parameters for syncing output copy of project directory pulled down from
% cluster to the local batchScratcher/mirror2cluster temporary folder with 
% the original project folder copy after running the job & removing the
% local job output copy after syncing
%--------------------------------------------------------------------------
jobIn.sync2origDir.syncOutCopy2Orig=1; % if 1, will detect and sync new 
                                       % and/or updated files present in 
                                       % the output directory copy to the 
                                       % original project directory on the 
                                       % local machine. (if 0, will not)

jobIn.sync2origDir.rmDirCopy=1;        % if 1, will remove the local output 
                                       % directory copy after syncing
                                       % (when/if syncing is turned on)
                                       % (if 0, will not)

jobIn.sync2origDir.dryRun=1;           % if 1, will do a "dry run" of the 
                                       % rsync and directory removal where 
                                       % the list of files/folders synced 
                                       % and removed will be reported on 
                                       % the commandline but the actual 
                                       % commands are not actually run.
                                       % (this feature is in places for
                                       % situations where the user may not
                                       % be sure if the settings are set to
                                       % their desired values/to make sure
                                       % directories/files they want to 
                                       % keep aren't destroyed by accident 
                                       % before running for real)
%--------------------------------------------------------------------------

```
### 2) Run submitBatchClstrJobMain.m to submit the job:

Either by running the following in the Matlab Command Window:
```matlab
submitBatchClstrJobMain
```

Or by hitting the green 'Run' button at the top of the Matlab editor window...

## Notes and Helpful Tips:

#### 1) Make sure that all code/data required to run your job are stored under a single parent project directory!
- **batchScratcher** assumes implicitly that all of the code and data necessary to run the batch job is contained within a single parent directory on your local machine.
- This directory is the one you specify as "jobIn.prjctDirCpyPars.baseDir" in the parameter section of 'submitBatchClstrJobMain.m'
- If you're like me and tend to recycle code/functions from old projects, your project's code may intitially be distributed haphazardly across multiple directories all over your machine like Johnny Appleseed...
- If that is the case, you will need to copy/move all of the code necessary for your job to run under a single directory and point "jobIn.prjctDirCpyPars.baseDir" to that directory in 'submitBatchClstrJobMain.m' prior to submitting your job.
- Luckily, I also developed a Matlab package for doing just that called: [pipeCleaner](https://github.com/ejduwell/pipeCleaner)
- Click on the link above for full details, but in short, pipeCleaner automatically finds all of the Matlab code required to run a particular script/function and copies/organizes it neatly under a single project directory.

#### 2) batchScratcher automatically logs the specific options you use to generate the mirrored copy of your project directory in a file called README.txt
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

#### 3) batchScratcher also automatically saves all Matlab Command Window output from the batch job in the uppermost level of the project directory copy
- It will be saved in a text file named with the following convention: matlabCodeRxiv_##-##-####-######_cmdWinLog
- The "##-##-####-######" numbers in the filename encode the date and time the job output directory was pushed back to your local machine to the second.
- The job start time, end time, and duration are also always included within this log file.
- This file can be very useful for debugging purposes. Its also a nice way to see whats going on while the job is still running remotely (it's updated in real time while the job runs...)
- If your job fails due to an error, **batchScratcher** captures the error and reports the full stack of error info including the files and line numbers that caused the errors.
- For example, here is the output from when I intentionally ran a bogus job script containing lines I knew would throw an error:
```
 
Job Start Time:
   10-Feb-2026 17:13:32

 
Path to this job's mirrored directory on cluster:
/scratch/g/agreenberg/eduwell/projects/matlabBatchScratch/matlabCodeRxiv_02-10-2026-170849/matlabCodeRxiv/revCorrStimFMRI
 
Running main batch job command:
testScript2MakeError
 
Sup Yo! Ima bout to run a function that doesn't exist with variables that don't exist to generate an error...
Here We Go!
 
!!!!YOUR JOB TERMINATED DUE TO AN ERROR!!!!
 
The error command line output is displayed below:
------------------------------------------------------------
Error Message:
Unrecognized function or variable 'bogus'.
Identifier:
MATLAB:UndefinedFunction
Full contents of error stack:
    file: '/scratch/g/agreenberg/eduwell/projects/matlabBatchScratch/matlabCodeRxiv_02-10-2026-170849/matlabCodeRxiv/revCorrStimFMRI/matlab/fmriAnalysis/testScript2MakeError.m'
    name: 'testScript2MakeError'
    line: 5

    file: '/tmp/tp46839862_1a0d_4a4d_859a_e3ebf1cfc588rp3695460/a/tpcc657d79_a16d_4209_8c21_007234be59a0/submitBatchClstrJob_v1.m'
    name: 'submitBatchClstrJob_v1/runAsBatchOnCluster'
    line: 195

    file: '/hpc/apps/matlab-parallel-server/R2025b/toolbox/parallel/cluster/+parallel/+internal/+cluster/executeFunction.m'
    name: 'executeFunction'
    line: 31

    file: '/hpc/apps/matlab-parallel-server/R2025b/toolbox/parallel/cluster/+parallel/+internal/+evaluator/evaluateWithNoErrors.m'
    name: 'evaluateWithNoErrors'
    line: 16

    file: '/hpc/apps/matlab-parallel-server/R2025b/toolbox/parallel/cluster/+parallel/+internal/+evaluator/CJSStreamingEvaluator.m'
    name: 'CJSStreamingEvaluator.evaluate'
    line: 28

    file: '/hpc/apps/matlab-parallel-server/R2025b/toolbox/parallel/parallel/private/dctEvaluateTask.m'
    name: 'iEvaluateTask/nEvaluateTask'
    line: 316

    file: '/hpc/apps/matlab-parallel-server/R2025b/toolbox/parallel/parallel/private/dctEvaluateTask.m'
    name: 'iEvaluateTask'
    line: 157

    file: '/hpc/apps/matlab-parallel-server/R2025b/toolbox/parallel/parallel/private/dctEvaluateTask.m'
    name: 'dctEvaluateTask'
    line: 83

    file: '/hpc/apps/matlab-parallel-server/R2025b/toolbox/parallel/parallel/distcomp_evaluate_filetask_core.m'
    name: 'iDoTask'
    line: 158

    file: '/hpc/apps/matlab-parallel-server/R2025b/toolbox/parallel/parallel/distcomp_evaluate_filetask_core.m'
    name: 'distcomp_evaluate_filetask_core'
    line: 52

    file: '/hpc/apps/matlab-parallel-server/R2025b/toolbox/parallel/parallel/distcomp_evaluate_filetask.m'
    name: 'distcomp_evaluate_filetask'
    line: 17

------------------------------------------------------------
Happy debugging...
 
 
Job End Time:
   10-Feb-2026 17:13:43

 
Total Job Duration:
   00:00:10
```
#### 4) There is nothing sacred about the original copy of submitBatchClstrJobMain.m Feel free to make copies for various projects/jobs etc..
- It may be useful to make copies of 'submitBatchClstrJobMain.m' for different projects/pipelines.
- That way you don't need to write over the parameters set for one pipeline to submit another one (which would be silly and annoying).
- Just make sure you give each a unique name like submitBatchClstrJobMain_coolProject1.m, submitBatchClstrJobMain_coolProject2.m, etc..

#### 5) Ethan's strong recommendation is to always make the main Matlab .m file submitted for the batch job (i.e. jobIn.mainFcn.fname="yourJobMfile") a 'script' with the 'function' syntax present but no input or output variables
- What on earth do I mean by this and why?:
  - It may sound like I'm delving into into minutia, but I promise this is relavant.. there are fine distinctions between 'scripts' and 'functions' in Matlab:
    - 'functions' begin with 'function [outputVariables]=yourJobMfile(inputVariables)' where yourJobMfile is the function's name and outputVariables/inputVariables are your input and output variables. They also end in 'end' to specify the end of the function.
    - 'scripts' do not begin with this syntax
    - The key/important difference here pertains to the 'scope' of variables created in a script vs. a function.
      - Variables set/defined in a function only exist within the scope of the function and do not persist in your workspace after the function is done except for those exported as output variables.
      - Variables set/defined in a script are simply dumped into the workspace and are available after the script is done until they are explicitly cleared.
    - Why does this matter here?: I've found that remote batch jobs in Matlab are **extremely** finicky about variables created in the job. If you create a variable in the workspace it will give you an error something to the effect of "can't create variable in a static workspace" and kill your job.
    - Simply surrounding the script with the empty function syntax without the input/output variables allows the thing to work just like a 'script' only the scope of variables is limited to within the function boundaries.
    - This means no new variables are ever created in the 'workspace' during the job and you avoid this major-league annoyance. 

#### 6) Related to (5) above: You may notice I included provisions to handle input/output variables in the parameters section. 
  *However, I still stand by what I recommend in (5)*
- I included the parameters to handle input/output variables for a batch job 'function'. However, my experience is that this (like many other aspects of 'batch' jobs in Matlab) is fraught with annoyances.
- To start, you need to specify each and every input and output variable, the total number of each that the job should create.
- In my experience, this is a doom-hole of wasted time and frustration full of random errors that are very difficult to chase down and debug.
- Conversely, a very straight-forward, scaleable, and easy alternative is to skip input/output variables all together and instead simply save any/all output variables to disk in a .mat (or whatever your preferred format) somewhere within the project directory at the end of the job script.
- This, in turn, will automatically get pulled down from the cluster to your local machine by the **batchScratcher** functions.

#### 7) For jobs to work running remotely, you need to avoid hard-coding paths in your main script and everywhere else in your code.
- *This is a big and important one.* I tried to make **batchScrather** manage/automate all of the path related aspects I could. However:
  - Nothing I can do will ever fix errors resulting from path variables within your job script submitted via **batchScratcher**
- If your job script references path/folder/file locations specific to your personal/local machine, **they will** fail on the remote cluster.
- Theres a *very easy* way around this using the 'fileparts' and 'which' functions in matlab that I use in almost all of my code:
  - A good example of this is the very first line under the "Set Pars" section of 'submitBatchClstrJobMain.m':
    ```matlab
    % auto-detect where the batchScratcher is installed on this machine
    [projDirPath,~,~]=fileparts(which("submitBatchClstrJobMain.m"));
    ```
  - 'which' finds the full path to 'submitBatchClstrJobMain.m' on whatever machine it's run and 'fileparts' splits off just the directory portion of the path/cuts off the filename and extension.
  - Because I stored 'submitBatchClstrJobMain.m' in the batchScratcher project directory, 'projDirPath' will therefore always give you the full path to where the project directory is installed no matter which computer its installed on and no matter where on that computer it is installed so long as it is somewhere on the path.
  - My strong recommendation is to use this trick at the top of your job script (specified as jobIn.mainFcn.fname) replacing 'submitBatchClstrJobMain.m' with whatever your script's file name happens to be.
  - Then, later in your script, set any and all path variables relative to your project root directory name using 'strcat' to concatenate 'projDirPath' on for the full path.
    - For Example:
      ```matlab
      path2File=strcat(projDirPath,"/someSubDirInsideYourProjectDir/filename.ext");
      ```
- This trick will allow you to avoid the path-related-error-hole-of-doom which is easy to fall into and waste hours of time while running/debugging jobs remotely.
- However, it is also a good habit to get into in any/all Matlab projects, even if you have no plans to run them remotely using **batchScratcher**.
- This effectively allows whatever Matlab code you write to be copied anywhere onto anyones computer and still run without having to update a bajillion path variables based on where it happened to be copied/installed...
---
