function runMUApipeline(filepath, varargin)
% runMUApipeline - Processes MUA data from electrophysiology recordings.
%
% Usage:
%   runMUApipeline(filepath, 'filename', 'lucio_u20230127_1')
%   runMUApipeline(filepath, 'animal', 'lucio', 'sessId', '20230127', 'expId', '1')
%   Optional: 'scaleFactor', default = 3.5
%
% Inputs:
%   filepath      - Full root path to data directory
%   varargin      - Optional arguments:
%                   'filename' (string)       - Full base filename
%                   'animal', 'sessId', 'expId' - If filename not given
%                   'scaleFactor' (numeric)   - Spike detection threshold multiplier

% Parse inputs
p = inputParser;
addRequired(p, 'filepath', @ischar);

addParameter(p, 'filename', '', @ischar);
addParameter(p, 'animal', 'lucio', @ischar);
addParameter(p, 'sessId', '', @ischar);
addParameter(p, 'expId', '1', @ischar);
addParameter(p, 'scaleFactor', 3.4, @isnumeric);

parse(p, filepath, varargin{:});
opts = p.Results;

% Derive filename components
if ~isempty(opts.filename)
    tokens = regexp(opts.filename, '^(?<animal>\w+)_u(?<sessId>\d+)_(?<expId>\d+)$', 'names');
    if isempty(tokens)
        error('Filename format must be: animal_uYYYYMMDD_expId (e.g., lucio_u20230127_1)');
    end
    animal = tokens.animal;
    sessId = tokens.sessId;
    expId = tokens.expId;
    filename = opts.filename;
else
    if isempty(opts.animal) || isempty(opts.sessId) || isempty(opts.expId)
        error('If "filename" is not given, you must provide "animal", "sessId", and "expId".');
    end
    animal = opts.animal;
    sessId = opts.sessId;
    expId = opts.expId;
    filename = [animal '_u' sessId '_' expId];
end

if ~isempty(opts.expId) %allows explicit expId inptu to override filename expId
    expId = opts.expId;
end

scaleFactor = opts.scaleFactor;
sampleFreq = 30000;
Njobs = 200;

fprintf('Running pipeline for: %s | scaleFactor = %.2f\n', filename, scaleFactor);
addpath(genpath('C:\Users\yhaile2\githubRepos\nielsenLabSpikeSorter')); % YYY Laptop

%% step 2: make header file
%if change in sampling rate: run convertRippleIntan(<ns5file>,0,10);
%otherwise this will work:
% sampleFreq=30000;

hOut=fullfile(filepath,animal,filename,[filename '_info.rhd']);
fid = fopen(hOut, 'w');

%write magic number
magic_number= 0xC6912702;
fwrite(fid,magic_number,'uint32');

%fake file version
main_version=0;
second_version=0;
fwrite(fid,main_version,'int16');
fwrite(fid,second_version,'int16');

%sample rate
fwrite(fid,sampleFreq,'single');
fclose(fid);

%% step 3: generate id file
%this assumes 1 probe; update area as needed
%in files with 2 probes, this part will need to be modified

id=struct;
id.exptId=filename;

probewiring=probeConfig_Fetsch1;
probewiring=sortrows(probewiring);
id.probes.channels = probewiring(:,1);
id.probes.x = probewiring(:,2);
id.probes.y = probewiring(:,3);
id.probes.z = probewiring(:,4);
id.probes.shaft = probewiring(:,5);
id.probes.type = 'Fetsch1';

id.probes.area='MST';

id.probes.nChannels=size(probewiring,1);

id.sampleFreq=sampleFreq;

save(fullfile(filepath,animal,filename,[filename '_id.mat']),'id');

%% step 4: generate thresholds
%choice to make: scale factor for the threshold (4 or 5 recommended)
% scaleFactor=4;

computeMUThreshold(filepath,animal,sessId,expId,1,[],scaleFactor,'YH',0,num2str(scaleFactor));

%% step 5: extract spikes
%decision: how many jobs
% Njobs=200;

parfor i=0:Njobs-1
    extractSpikes(filepath,animal,sessId,expId,1,'YH',0,1,0,Njobs,i);
end

%% step 6: extract spike properties/assign duplicates
tic
parfor i=0:Njobs-1
    extractSpikeProps(filepath,animal,sessId,expId,1,'YH',0,1,i);
end
toc % 30mins
%% step 7: merge files
tic
mergeMUspkInfo(filepath,animal,sessId,expId,1,0,Njobs-1);
toc % ~50mins

end
