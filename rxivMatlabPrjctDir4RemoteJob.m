function rxivMatlabPrjctDir4RemoteJob(baseDir,outDirBase, fileExtnz,dirs2Ignore,indFiles,compress,pigzPars)
 % matlab wrapper for E.J. Duwell's rxivMatlabCode_v4.sh bash function
 %
 % rxivMatlabCode_v5.sh finds and archives any/all code with a file 
 % extension matching one of those in the input extension list within
 % a specified directory. The original intended use case is for quickly 
 % packaging up and compressing a project folder to export to a remote 
 % cluster or other machine to run a job. This is intended to make it
 % easy/intuitive to package up everything required to run a job remotely. 
 % 
 % Input parameters:
 % baseDir    : should be the full path to the program base directory in
 %              which your matlab code resides ...
 % outDirBase : should be the full path to the output parent/base directory 
 %              where you want to save the archived code ...
 % fileExtnz  : a 1xN cell array of file extension strings for files you
 %              want included in the output archived directory. (Make sure
 %              this list includes all filetypes that will be required at
 %              the remote location)
 % dirs2Ignore: a 1xN cell array of path strings for sub directories you
 %              want to 'ignore'. Files within ignored directories with 
 %              extensions matching an entry fileExtnz are not included in
 %              the output archive. If dirs2Ignore=={}, no dirs ignored.
 % indFiles   : a 1xN cell array of path strings for individual files you
 %              want to include regardless of whether they match one of the
 %              extensions in fileExtnz. If indFiles=={}, no additional 
 %              individual files are copies into the output archivefiles 
 %              ignored.
 %
 % pigzPars   : struct containing parameters to indicate whether pigz
 %              should be used to parallelize compression to .tar.gz and if
 %              so, how many cpus should be used.
 %                  - pigzPars.usePigz : (required) 1 or 0. 
 %                    1=use pigz, 0=don't
 %                  - usePigz.nCpus4Pigz : (optional) integer, indicates
 %                    how many cpus to use. 
 
% Unpack/process pigzPars
%--------------------------------------------------------------------------
% get fields
pigzFlds=fieldnames(pigzPars);
% get value for usePigz subfield
usePigz=pigzPars.usePigz;
% if usePigz==1 set up pigz stuff for rxivMatlabCode_v5.sh :
if usePigz==1
    pigzStr=" --pigz";
    % check if 'nCpus4Pigz' is in the set of fields
    if any(strcmp(pigzFlds,'nCpus4Pigz'))
        % if it is, grab the value and convert to string
        nCpus4Pigz=num2str(pigzPars.nCpus4Pigz);
        % then concatenate it onto pigzStr
        pigzStr=strcat(pigzStr," ",nCpus4Pigz);        
        % *****************************************************************
        % (if it isn't, do nothing. pigz uses number of cpus.)    
        % *****************************************************************
    end
% if usePigz isn't 1, set pigz input pars to rxivMatlabCode_v5.sh to empty 
% strings such that pigz is not invoked in the system command :    
else
    pigzStr="";
end
%--------------------------------------------------------------------------

% Get path info on this machine..
pathToThisFile=which("rxivMatlabPrjctDir4RemoteJob.m");
currentDir = fileparts(pathToThisFile);

% ensure rxivMatlabCode.sh is executable..
chmodCmd=strcat("chmod +wrx ",currentDir,"/rxivMatlabCode_v4.sh ");
system(chmodCmd);

% extract/combine extension strings in fileExtnz into list for inclusion in
% rxivMatlabCode_v3 command string built below:
%--------------------------------------------------------------------------
% convert to string array
fileExtnz=string(cellstr(fileExtnz)); 
% add single quotes around each to ensure they are 
% interepreted as separate bash inputs..
fileExtnz2=strcat("'",fileExtnz(1,:),"'"); 
% join them together into a single string separated by spaces
fileExtLst=strjoin(fileExtnz2," "); 
%--------------------------------------------------------------------------

% do the same for dirs2Ignore:
%--------------------------------------------------------------------------
if isempty(dirs2Ignore)
    dirIgnrLst=""; % if dirs2Ignore is empty, set to empty string

% Otherwise: build the list of dirs to ignore 
% preceded by the input '-- ignore' tag:
else

    % convert to string array
    dirs2Ignore=string(cellstr(dirs2Ignore)); 
    % add single quotes around each to ensure they are 
    % interepreted as separate bash inputs..
    dirs2Ignore2=strcat("'",dirs2Ignore(1,:),"'"); 
    % join them together into a single string separated by spaces
    dirIgnrLst=strjoin(dirs2Ignore2," "); 
    dirIgnrLst=strcat(" --ignore ",dirIgnrLst); % add option tag in front
end
%--------------------------------------------------------------------------

% do the same for indFiles...
%--------------------------------------------------------------------------
if isempty(indFiles)
    indFileLst=""; % if dirs2Ignore is empty, set to empty string

% Otherwise: build the list of dirs to ignore 
% preceded by the input '-- ignore' tag:
else

    % convert to string array
    indFiles=string(cellstr(indFiles)); 
    % add single quotes around each to ensure they are 
    % interepreted as separate bash inputs..
    indFiles2=strcat("'",indFiles(1,:),"'"); 
    % join them together into a single string separated by spaces
    indFileLst=strjoin(indFiles2," "); 
    indFileLst=strcat(" --indFiles ",indFileLst); % add option tag in front
end
%--------------------------------------------------------------------------

% build/add compression option string
compressStr=strcat(" --compress ",num2str(compress));

% build bash command to call rxivMatlabCode.sh
%rxivCmd=strcat("bash ",currentDir,"/rxivMatlabCode_v4.sh ", "'",baseDir,"'"," ","'",outDirBase,"'"," --ext ",fileExtLst,dirIgnrLst,indFileLst,compressStr);
rxivCmd=strcat("bash ",currentDir,"/rxivMatlabCode_v5.sh ", "'",baseDir,"'"," ","'",outDirBase,"'"," --ext ",fileExtLst,dirIgnrLst,indFileLst,compressStr,pigzStr);

% run the command in the bash shell..
system(rxivCmd);

end