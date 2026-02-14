
%% Set Pars

clstrProfile="HPC Cluster"; % cluster profile name string (i.e. like "HPC Cluster")
localUserName="yourLocalUserName";

%% Run parcluster setup
c = parcluster(clstrProfile);
c.AdditionalProperties.AuthenticationMode = 'IdentityFile';
c = parcluster;  
c.AdditionalProperties.AuthenticationMode = 'IdentityFile';
c.AdditionalProperties.IdentityFile = strcat('/home/',localUserName,'/.ssh/id_ed25519');
c.AdditionalProperties.IdentityFileHasPassphrase = false;
saveProfile(c);

%% Clean Up

clear;
