# batchScratcher
Repository of functions that automate pushing data from your local machine to the scratch folder on a remote SLURM cluster with MATLAB Parallel Server installed, running remote 'batch' jobs, and retrieving the data.

## Overview

**batchScratcher** is a MATLAB-based project developed to provide a standalone, standardized, (hopefully) more intuitive framework for submitting 'batch' jobs to remote clusters running Matlab Parallel Server. This repository contains code that automates compressing a local copy of a project folder, pushing that project to the remote cluster, running a specified script as a 'batch' job, and retrieving the data back to your local machine.

## Dependencies

- Must be running either a Unix/Linux-based OS or macOS
- Must have SSH installed and enabled
- Must have rsync installed
- Must have pigz installed for parallelized/accelerated compression features for compressing project directory.
- MATLAB (I developed this using R2025b)
- Required MATLAB Toolbox(es):
  - [MATLAB Parallel Computing Toolbox](https://www.mathworks.com/products/parallel-computing.html)
- Access to a remote SLURM cluster running [Matlab Parallel Server](https://www.mathworks.com/products/matlab-parallel-server.html)
  - For users at the Medical College of Wisconsin, instructions for setting up access to the Matlab Parallel Server on the HPC cluster can be found [HERE](https://docs.rcc.mcw.edu/software/matlab/)

## Installation

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

## Usage

To use this code:

1. Open MATLAB
2. Add the root project folder to your MATLAB path (if not already done)
3. Locate and run the main entry-point script(s) — found in the top level of the folder (e.g., `submitBatchClstrJobMain.m`).

### Brief list and overview of important files & folders:

| File/Folder            | Description                                       |
|------------------------|---------------------------------------------------|
| `submitBatchClstrJobMain.m`     | Primary script for submitting batch jobs. Effectively serves as a 'wrapper' for 'submitBatchClstrJob_v1.m'                 |
| `submitBatchClstrJob_v1.m`     | Main function called by 'submitBatchClstrJobMain.m' for preparing copies of a local project directory, pushing it to the cluster's scratch, and submitting scripts to run there remotely as batch jobs                 |
| `rxivMatlabPrjctDir4RemoteJob.m`     | Main function called by 'submitBatchClstrJob_v1.m' for compressing the local project directory. Effectively serves as a wrapper for the bash function 'rxivMatlabCode_v5.sh' which compresses subselections of data contained within the folder to tar.gz while maintaining the organizational structure of the project directory              |
| `mirror2cluster/`            | Sub-directory where other specified local project directories are copied an compressed prior to pushing to the remote cluster  |


## Acknowledgements


---
