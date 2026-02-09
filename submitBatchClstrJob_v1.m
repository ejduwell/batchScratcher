function jobOut = submitBatchClstrJob_v1(jobIn)

%% Get initial start time

glblStart=datetime;

%% Initialize output struct

jobOut=struct;

%% Unpack jobIn struct pars

prjctDirCpyPars=jobIn.prjctDirCpyPars; % struct of pars for rxivMatlabPrjctDir4RemoteJob.m
clstrProfile=jobIn.clstrProfile; % cluster profile name string (ie like "HPC Cluster")

%% Build-out copy of project dir with necessary files to push to cluster

disp(" ");
disp("Starting to compress local project dir copy to push to cluster...");
strtTmp=datetime;
rxivMatlabPrjctDir4RemoteJob(prjctDirCpyPars.baseDir,prjctDirCpyPars.outDirBase, prjctDirCpyPars.fileExtnz,prjctDirCpyPars.dirs2Ignore,prjctDirCpyPars.indFiles,prjctDirCpyPars.compress,prjctDirCpyPars.pigzPars);
endTmp=datetime;
durTmp=endTmp-strtTmp;
disp("Compression finished in:")
disp(durTmp);

% extract just the dir name without the full path
localDir2Mir=prjctDirCpyPars.outDirBase;
localTarGzFile = getAllFileNamesTag(localDir2Mir,".tar.gz");
[tgzPath,tgzFname,tgzExt]=fileparts(localTarGzFile);
[~,tgzFname,~]=fileparts(tgzFname);

%% Push the copy of the project dir to the cluster

disp(" ");
disp("Starting to push local project dir copy to cluster...");
strtTmp=datetime;
mainClusterPath=jobIn.mainClusterPath;
pushTarOut = pushTarGzToCluster_v2(localTarGzFile, mainClusterPath, 'RemoteHost',jobIn.clusterHostname,'RemoteUser',jobIn.clusterUsername,'PromptForCredentials',false,'UseRsync', true);
endTmp=datetime;
durTmp=endTmp-strtTmp;
disp("Pushing project dir copy to cluster finished in:")
disp(durTmp);
% auto-set clstrMirPgrmDir string
clstrMirPgrmDir=strcat(jobIn.mainClusterPath,"/",tgzFname,"/matlabCodeRxiv/",jobIn.programDirName);

%% Build Main Function Command

fname=jobIn.mainFcn.fname;
fcnPDFin=jobIn.mainFcn.inputPDF;
nOutVars=length(jobIn.mainFcn.outVars);
% build command string flexibly based on input pars
if nOutVars==0
    if isempty(fcnPDFin)
        cmdStr=strcat(fname);
    else
        cmdStr=strcat(fname,"(","'",fcnPDFin,"'",")");
    end
else
    % grab output variables
    outVars=jobIn.mainFcn.outVars;
    % convert to string array
    outVars=string(cellstr(outVars));     
    % join them together into a single string separated by commas
    outVarsLst=strjoin(outVars,","); 
    % add output brackets and equal sign
    outputStr=strcat("[",outVarsLst,"]=");
    if isempty(fcnPDFin)
        % build command string with output vars incorporated
        cmdStr=strcat(outputStr,fname);
    else
        % build command string with output vars incorporated
        cmdStr=strcat(outputStr,fname,"(","'",fcnPDFin,"'",")");
    end
end


%% Set up parcluster

% open cluster profile
c = parcluster(clstrProfile);
% extract and add additional slurm args
adnlArgFlds=fieldnames(jobIn.adnlArgs);
adnlArgAry=cell(1,length(adnlArgFlds));
for ii=1:length(adnlArgFlds)
    adnlArgAry{1,ii}=jobIn.adnlArgs.(adnlArgFlds{ii,1});
end
adnlArgComb=strjoin(string(cellstr(adnlArgAry))," ");  
c.AdditionalProperties.AdditionalSubmitArgs=adnlArgComb;

%% Submit the job

disp(" ");
disp("Submitting job to cluster...");
strtTmp=datetime;
job = batch(c, @runAsBatchOnCluster, jobIn.mainFcn.nFcnOutputs, {cmdStr,clstrMirPgrmDir,tgzFname}, ...
    "CurrentFolder",clstrMirPgrmDir, ...
    "AutoAddClientPath", false);

% wait until job finishes (or comment if you don't want to..)
disp(" ");
disp("Job submitted. Waiting while it runs on the cluster...");
wait(job);
endTmp=datetime;
durTmp=endTmp-strtTmp;
glblDur=endTmp-glblStart;
disp("Cluster job finished running in:")
disp(durTmp);
disp(" ")
disp("Job is finished. Total run time was:")
disp(glblDur);

%% Pull down the remote directory copy with data to local machine

% save start location
startDir=pwd;
% auto find batchScratch project directory
[batchScrathProjDir,~,~]=fileparts(which("pullRemoteDirTarSlurm_v1.m"));
% enter it
cd(batchScrathProjDir);
% make sure pull_remote_dir_tar_slurm.sh is executeable..
chmodCmd="chmod +x pull_remote_dir_tar_slurm.sh";
system(chmodCmd);
% return to start location
cd(startDir);
clear startDir;
% set bashFcnPath for 'pull_remote_dir_tar_slurm.sh'
bashFcnPath=strcat(batchScrathProjDir,"/pull_remote_dir_tar_slurm.sh");

disp(" ");
disp("Pulling data from remote cluster back to local machine...")
strtTmp=datetime;
[st,out,exdir,tar] = pullRemoteDirTarSlurm_v1( ...
  jobIn.clusterHostname, ...
  clstrMirPgrmDir, ...
  tgzPath, ...
  jobIn.clusterPIaccount, ...
  jobIn.pullDownTimeStr, ...
  jobIn.pullDownCPUs, ...
  'BashSourceFile',bashFcnPath, ...
  'CleanRemoteTar',jobIn.pullDown.CleanRemoteTar, ...
  'CleanRemoteJob',jobIn.pullDown.CleanRemoteJob, ...
  'CleanLocalTar',jobIn.pullDown.CleanLocalTar);

endTmp=datetime;
durTmp=endTmp-strtTmp;
disp("Finished pulling data from remote cluster back to local machine in:")
disp(durTmp);

disp(" ");
disp("Take care now! Bye Bye then!");
disp(" ");

%% General function handle for running things on cluster
    
    function runAsBatchOnCluster(cmdStr,clstrMirPgrmDir,tgzFname)                        
        
        % enter the mirrored program dir
        cd(clstrMirPgrmDir);

        % build command opening diary and naming it the same as the tarFile
        diaryFileName=strcat(tgzFname,"_cmdWinLog");
        diaryOnCmdStr=strcat("diary ",diaryFileName); 
        % evaluate the command to start the diary:
        eval(diaryOnCmdStr);

        % get the date/time at the start of the job and echo it out on the
        % command line to document in diary/log
        jobStartTime=datetime;
        disp(" ");
        disp("Job Start Time:")
        disp(jobStartTime);

        % grab and echo starting path on the cluster for
        % reference/debugging purposes:
        startDir=pwd;
        disp(" ");
        disp("Path to this job's mirrored directory on cluster:");
        disp(startDir);

        % make sure it/all subdirs are on path
        addpath(genpath(clstrMirPgrmDir));

        % echo primary job command onto commandline
        disp(" ");
        disp("Running main batch job command:")
        disp(cmdStr);
        
        % evaluate the command string for main function/script to run it
        eval(cmdStr);           

        % get the date/time at the end of the job and echo it out on the
        % command line to document in diary/log
        jobEndTime=datetime;
        disp(" ");
        disp("Job End Time:")
        disp(jobEndTime);

        % compute and echo the job duration for convenience/future
        % forcasting and planning purposes too:
        jobDuration=jobEndTime-jobStartTime;
        disp(" ")
        disp("Total Job Duration:")
        disp(jobDuration);

        % turn off diary at end of job
        diary off;
        
    end

end