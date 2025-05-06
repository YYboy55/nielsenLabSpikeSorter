% script for 1 file

%required: Steven's binary file
%if the sampling rate is other than 30k, then grab from .ns5 file

%% Add repository to path..

addpath(genpath('C:\Users\yhaile2\githubRepos\nielsenLabSpikeSorter'))
% copy binary file to appropriate folder, using below console command.. if 
% robocopy "Z:\fetschlab\data\lucio\lucio_neuro\20230127\lucio20230127_1" "C:\Users\YH\Documents\AcademicRelated\CODE_Projects\Data\SpikeSorting\nielsenLabSorting\lucio\lucio_u20230127_1" lucio_20230127_1.bin /Z /R:3

%% RUN MUA SCRIPT AS FUNCTION
% run MUA function

filepath='C:\Users\yhaile2\Documents\AcademicRelated\CODE_Projects\Data\SpikeSorting\nielsenLabSorting\';

% csvFilenames = 'C:\Users\fetschlab\Documents\WindowsPowerShell\MUAsess2sortFilenames.xlsx'; % stores filenamesList
% T = readtable(csvFilenames);
% filenameList = T.Sessions2Sort;
% filenameList = filenameList(~cellfun(@isempty, filenameList));  % remove empty entries

fieldnamesOfInt = {'lucio_u20230127_1', 'lucio_u20230127_1'};
sF = [3.5 4.0];

for sess = 1:length(fieldnamesOfInt)
    runMUApipeline(filepath,'filename',fieldnamesOfInt{sess},'scaleFactor',sF(sess))
    fprintf('%s MUA data sorted\n',fieldnamesOfInt{sess})
end


%% step 1: make a copy of binary file, rename it to look like
% animal_u<sessID>_<expId>_amplifier.dat, move into folder
% animal/animal_u<sessID>_<expId>

filepath='C:\Users\xx';
animal='lucio';
sessId='20230127';
expId='1';

filename=[animal '_u' sessId '_' expId];

%% step 2: make header file
%if change in sampling rate: run convertRippleIntan(<ns5file>,0,10);
%otherwise this will work:
sampleFreq=30000;

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

scaleFactor=4;

computeMUThreshold(filepath,animal,sessId,expId,1,[],scaleFactor,'YH',0);

%% step 5: extract spikes
%decision: how many jobs

Njobs=200;

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

%% YYY Step1 : Formatting spikeTimes into cell array            - YYY post processing step1
folderPath = [filepath animal '\' filename '\' ];
fileName = [filename '_p1_MUspkMerge'];
load([folderPath fileName])

% Extract data
spktimes = MUspkMerge.spktimes; % TODO --> these likely need to be divided by sample rate (30000) to get into appropriate units of time
detChSort = MUspkMerge.detChSort;

% Find group indices and group labels
[G, channelLabels] = findgroups(detChSort); % G == detChSort

% Group spike times into a cell array
spktimesByChannel = splitapply(@(x) {x}, spktimes, G);

%% Adding MUspikes as new field in dataStruct
% sessId = sessionDate
datastructPath = "C:\Users\yhaile2\Documents\AcademicRelated\CODE_Projects\Data\Lucio\Neural\NeuralDataStructs_Lucio\MKsorted_neuralDataStructs\lucio_" + sessId + "_3DMPData_MKsorted.mat";
load(datastructPath)
taskField = fieldnames(dataStruct_wMKsortUnits.data);
for f = 1:numel(taskField)
    dataStruct_wMKsortUnits.data.(taskField{f}).units.MUspikes = spktimesByChannel;
    dataStruct_wMKsortUnits.data.(taskField{f}).units.MUchList = channelLabels;
end

%%
% Save updated dataStruct
dataStruct = dataStruct_wMKsortUnits;

% Define filename and folderPath path
filename = [animal '_' sessId '_3DMPData_wMk_wMU.mat'];
folderPath = 'C:\Users\yhaile2\Documents\AcademicRelated\CODE_Projects\Data\Lucio\Neural\NeuralDataStructs_Lucio\MultiUnit_neuralDataStructs\individualSessionFiles';
fullFilePath = fullfile(folderPath, filename);

% Save with new variable name
save(fullFilePath, 'dataStruct');


%% compare MU with MKsorted units
% 1. load dataStruct
load C:\Users\yhaile2\Documents\AcademicRelated\CODE_Projects\Data\Lucio\Neural\NeuralDataStructs_Lucio\MultiUnit_neuralDataStructs\individualSessionFiles\lucio_20230127_3DMPData_wMk_wMU.mat
addpath(genpath('C:\Users\yhaile2\Documents\AcademicRelated\CODE_Projects\GitHubCodes\Fetschlab\preFLprojects\'))
% 2. analyze spikes
MKspikes = dataStruct.data.dots3DMP.units.spikeTimes_MK;
MKchList = dataStruct.data.dots3DMP.units.chList_MK;
MUchOfInt = unique(dataStruct.data.dots3DMP.units.chList_MK);
MUspikes = dataStruct.data.dots3DMP.units.MUspikes;

MUspikes{1}(1:150)
MUspikesUpdate{1}(10:11:1000)

dataStruct.data.dots3DMP.units.MUspikes = MUspikesUpdate;
MUspikesUpdate = cellfun(@(x) x(:) / 30000, MUspikes, 'UniformOutput', false);


un = 3;
currMU = MUspikes{MKchList(8)} / sampleFreq; % convert into time units rather than sample count units
curMKun = MKspikes{un}';
sum(ismember(currMU, curMKun)) % matched spiketimes ?
length(MKspikes{un})


% Check time alignment of MUspikes
dataPath = 'data.dots3DMP.events';
[trStart, goodtrial] = extract_dataStruct_fieldNameHandles(dataStruct,1,dataPath,{'trStart' 'goodtrial'},true,true);
preTime = -1; postTime = 2;
currentEventTimes = trStart(goodtrial);
allUn_spikeTimes = MUspikes(MUchOfInt);

un  = 2;
spikeTimes = allUn_spikeTimes{un};

currAxisSpikeTimes = [];
eachTrialSpikes = {};
for j = 1:numel(currentEventTimes) % Loop through all trials, find spikes occuring during trials of interest
    alignedSpikeTimes = spikeTimes(spikeTimes >= currentEventTimes(j) + preTime & ...
        spikeTimes <= currentEventTimes(j) + postTime) - ...
        currentEventTimes(j);
    currAxisSpikeTimes = [currAxisSpikeTimes; alignedSpikeTimes];  % all currAxis trial spikes stacked into single column vector
    eachTrialSpikes{j} = alignedSpikeTimes'; % store each trials spikeTimes, use cell since variable num spikes each trial
end






