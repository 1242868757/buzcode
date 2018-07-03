function [  ] = bz_MultiLFPPlot( lfp,varargin )
%bz_MultiLFPPlot(lfp). This function plots multiple lfp channels from a 
%buzcode lfp structure with the channels appropriately spaced. 
%
%USAGE
%   figure
%       bz_MultiLFPPlot(lfp)
%
%INPUT
%   lfp         a buzcode lfp structure. channels are assumed to be ordered
%               from top to bottom
%   (optional)
%   'channels'  subset/ordering of channels to plot (0-index a la neuroscope)
%               default is to take the channels as ordered in lfp.channels
%   'timewin'   only plot a subwindow of time
%   'spikes'    a buzcode spikes struct to display spikes above the LFP
%   'sortmetric'metric by which to sort the cells in the raster (eg FR)
%   'cellgroups'{Ngroups} cell array of logical arrays of group members
%   'plotcells' list of cell UIDs to plot (not implemented. sad.)
%   'axhandle'  axes handle in which to put the plot
%   'scaleLFP'  multiplicative factor to scale the y range of LFP
%   'scalespikes' size of spike points (default:5)
%
%
%DLevenstein 2017
%% parse the inputs!
channelsValidation = @(x) assert(isnumeric(x) || strcmp(x,'all'),...
    'channels must be numeric or "all"');
spikedefault.spindices = [nan nan];

% parse args
p = inputParser;
addParameter(p,'channels','all',@isnumeric)
addParameter(p,'timewin',[0 Inf],@isnumeric)
addParameter(p,'spikes',[]) %should have iscellinfo function
addParameter(p,'sortmetric',[])
addParameter(p,'cellgroups',{})
addParameter(p,'axhandle',gca)
addParameter(p,'scaleLFP',1,@isnumeric)
addParameter(p,'scalespikes',5,@isnumeric)
addParameter(p,'plotcells',nan,@isnumeric)
parse(p,varargin{:})
timewin = p.Results.timewin;
channels = p.Results.channels;
spikes = p.Results.spikes;
sortmetric = p.Results.sortmetric;
cellgroups = p.Results.cellgroups;
plotcells = p.Results.plotcells;
ax = p.Results.axhandle;
scaleLFP = p.Results.scaleLFP;
scalespikes = p.Results.scalespikes;

if isempty(spikes)
    spikes = spikedefault;
else
    %Implement raster sorting 
    [~,cellsort] =sort(sortmetric);
    %Goups
    if ~isempty(cellgroups)
        for gg = 1:length(cellgroups)
            groupsort{gg} = intersect(cellsort,find(cellgroups{gg}),'stable');
        end
        cellsort = [groupsort{:}];
    end
    
    %Sort the raster
    [~,sortraster] = sort(cellsort);
    if isempty(sortraster)
        sortraster = 1:max(spikes.spindices(:,2));
    end
    
    if ~isnan(plotcells)
        temp = nan(size(sortraster));
        temp(plotcells) = sortraster(plotcells);
        sortraster = temp;
    end
    spikes.spindices(:,2) = sortraster(spikes.spindices(:,2));
    spikes.spindices(isnan(spikes.spindices(:,2)),:) = [];
end

%% Channel and time stuff
%Time Window
windex = lfp.timestamps>=timewin(1) & lfp.timestamps<=timewin(2);
%Channel to data array index mapping
if strcmp(channels,'all')
    chindex = 1:length(lfp.channels);
    channels = lfp.channels;
else
    [~,~,chindex] = intersect(lfp.channels,channels,'stable');
end

winspikes = spikes.spindices(:,1)>=timewin(1) & spikes.spindices(:,1)<=timewin(2);
%% Calculate and implement spacing between channels

%Space based on median absolute deviation over entire recording - robust to outliers.
channelrange = 10.*mad(single(lfp.data(:,chindex)),1);
lfpmidpoints = -cumsum(channelrange);
lfp.plotdata = (bsxfun(@(X,Y) X+Y,single(lfp.data(windex,chindex)).*scaleLFP,lfpmidpoints));

spikeplotrange = [1 -lfpmidpoints(1)];
spikes.plotdata = spikes.spindices(winspikes,:);
spikes.plotdata(:,2) = (spikes.plotdata(:,2)./max(spikes.spindices(:,2))).*(diff(spikeplotrange));

%% Do the plot
ywinrange = fliplr(lfpmidpoints([1 end])+1.*[1 -1].*max(channelrange));
if ~isnan(spikes.spindices)
    ywinrange(2) = ywinrange(2)+max([spikes.plotdata(:,2);0]);
end

plot(ax,lfp.timestamps(windex),lfp.plotdata,'k','linewidth',0.5)
hold on
plot(ax,spikes.plotdata(:,1),spikes.plotdata(:,2),'k.','markersize',scalespikes)
xlabel('t (s)')
ylabel('LFP Channel')
set(ax,'Ytick',fliplr(lfpmidpoints))
set(ax,'yticklabels',fliplr(channels))
ylim(ywinrange)
xlim(timewin)
box off


end

