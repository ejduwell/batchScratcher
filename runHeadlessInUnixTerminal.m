%% Set Parameters

% auto-find batchScratcher script directly
runScriptPth = which("runHeadlessMatlabJob.sh");
if isempty(runScriptPth)
    error("Could not find runHeadlessMatlabJob.sh on the MATLAB path.");
end
% auto-find batchScratcher folder
batchScratchFldr = fileparts(runScriptPth); 

% Specify main MATLAB entrypoint job script (no .m)
matlabFile = "submitBatchClstrJobMain";

%% Run Job Headlessly in Seperate UNIX Terminal

cmdOut = runHeadlessMatlabJob_wrapper(runScriptPth, matlabFile, {batchScratchFldr});