
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

%% Run submitBatchClstrJob_v1 to submit batch job

jobOut = submitBatchClstrJob_v1(jobIn);

%% Clean up

clear;
