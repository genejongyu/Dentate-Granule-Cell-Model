function aGC_currsteps(neuron,tree,params,targetfolder_data,ostruct)

if nargin < 5
    ostruct = struct();
end
if isfield(ostruct,'recordnode') && isnumeric(ostruct.recordnode) && numel(ostruct.recordnode) == numel(tree)
    recordnode = ostruct.recordnode;
else
    recordnode = ones(numel(tree),1);
end
if isfield(ostruct,'stimnode') && isnumeric(ostruct.stimnode) && numel(ostruct.stimnode) == numel(tree)
    stimnode = ostruct.stimnode;
else
    stimnode = ones(numel(tree),1);
end
if ~isfield(ostruct,'variabledt')
    ostruct.variabledt = 1;
end
if ~isfield(ostruct,'duration')
    ostruct.duration = 200;
end
if ~isfield(ostruct,'find_freq')
    ostruct.find_freq = 0;
end

if ~isfield(ostruct,'amp')
    ostruct.amp = 0:5:90;
end
cstepsSpiking = (0:5:120)*0.001;


if ~isfield(ostruct,'holding_voltage') || isnan(ostruct.holding_voltage)
    exp_iclamp = load_ephys(ostruct.dataset,'CClamp');
end
    params.accuracy = 1;  % for more nseg in axon and soma!

if isfield(ostruct,'coarse') && ostruct.coarse == 1
    params.nseg = 1;
    params.dt=0.1;  % does only count if cvode = 0
elseif isfield(ostruct,'coarse') && ostruct.coarse == 0.5
    params.dt=0.05;  % does only count if cvode = 0
else
    params.dt=0.025;  % does only count if cvode = 0
end
cstepsSpikingModel = ostruct.amp*0.001;  % 0:5:120


if isfield(ostruct,'variabledt') && ostruct.variabledt
    params.cvode = 1;
else
    params.cvode = 0;
end

params.v_init = -80-params.LJP;
params.tstop = 150+ostruct.duration;

if isfield(ostruct,'holding_voltage') && ~isnan(ostruct.holding_voltage)
    meanhvol = ostruct.holding_voltage;  % CAUTION! no LJP subtraction
else
    meanhvol = mean(mean(exp_iclamp(:,:,1))) - params.LJP;   % corrected!!
end
params.skiprun = 0; %!!!!!!!!!
if ~exist('hstep','var')
    hstep = [];
end
hstep = find_curr(params,neuron,tree,meanhvol,hstep,'-q-d');

if isnan(hstep)
    return
end
for t=1:numel(tree)
    neuron.APCount{t} = [1,-10];
end

nneuron = cell(numel(cstepsSpikingModel),1);
for s = 1:numel(cstepsSpikingModel)
    if s == 1
        nneuron{s} = neuron;
    end
    for t = 1:numel(tree)
        nneuron{s}.pp{t}.IClamp = struct('node',stimnode(t),'times',[-100,55.5,55.5+ostruct.duration],'amp', [hstep(t) hstep(t)+cstepsSpikingModel(s) hstep(t)]); %n,del,dur,amp
        nneuron{s}.record{t}.cell = struct('node',recordnode(t),'record','v');
    end
    nneuron{s} = t2n_as(1,nneuron{s});
end

if ostruct.find_freq
    amp = find_freq(params,nneuron{1},tree,ostruct.find_freq,'-q-d');
else
    amp = ostruct.amp;
end
for t = 1:numel(tree)
    nneuron{1}.pp{t}.IClamp.amp = [hstep(t) amp(t) hstep(t)]; %n,del,dur,amp  %WICHTIG! nur amp da hstep nicht abgezogen
end

out = t2n(tree,params,nneuron,'-q-d-w');



numspikes = zeros(numel(tree),numel(cstepsSpikingModel));
vol_new_curr_dend = cell(numel(tree),numel(cstepsSpikingModel));
tvol_new_curr_dend = vol_new_curr_dend;

for s = 1:numel(cstepsSpikingModel)
    for t = 1:numel(tree)
        if isfield(out{s},'error') && out{s}.error > 0
            vol_new_curr_dend{t,s} = [] ;
            tvol_new_curr_dend{t,s} = [];
            numspikes(t,s) = NaN;
        else
            vol_new_curr_dend{t,s} = out{s}.record{t}.cell.v{1} ;
            tvol_new_curr_dend{t,s} = out{s}.t;
            numspikes(t,s) = numel(out{s}.APCtimes{t}{1});
        end
    end
end
params.accuracy = 0;
str = '';
if numel(ostruct.amp)==1
   str = sprintf('%s_%dpA',str,ostruct.amp); 
end
if ~params.cvode
   str = strcat(str,'_fixed-dt'); 
end
save(fullfile(targetfolder_data,sprintf('Exp_Spiking_%s%s.mat',neuron.experiment,str)),'vol_new_curr_dend','tvol_new_curr_dend','numspikes','params','cstepsSpiking','cstepsSpikingModel','tree','nneuron')
