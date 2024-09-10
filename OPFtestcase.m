function resultOPF = OPFtestcase(mpcreduced,timeStamp,savefig,savedata,addrenew)
%OPFTESTCASE Run optimal power flow at a specified timestamp and show results.
% 
%   Inputs:
%       mpcreduced - struct, reduced MATPOWER case
%       timeStamp - datetime, in "MM/dd/uuuu HH:mm:ss"
%       savefig - boolean, default to be true
%       savedata - boolean, default to be true
%       addrenew - boolean, default to false
%   Outputs:
%       resultOPF - struct, optimal power flow results

%   Created by Vivienne Liu, Cornell University
%   Last modified on April 9, 2022

%   Adapted by Gabriela Ackermann Logan, Cornell University 
%   Last modified 2024

%% Input parameters

% Read reduced MATPOWER case
if isempty(mpcreduced)
    mpcfilename = fullfile('Result',num2str(year(timeStamp)),'mpcreduced',...
        "mpcreduced_"+datestr(timeStamp,"yyyymmdd_hh")+".mat");
    mpcreduced = loadcase(mpcfilename);
end

% Save figure or not (default to save)
if isempty(savefig)
    savefig = true;
end

% Save OPF results or not (default to save)
if isempty(savedata)
    savedata = true;
end

% Add additional renewable or not (default to not)
if isempty(addrenew)
    addrenew = false;
end

%% Read operation condition for NYS

[fuelMix,interFlow,flowLimit,~,~,zonalPrice] = readOpCond(timeStamp);
busInfo = importBusInfo(fullfile("Data","npcc_new.csv"));

define_constants;

%% Create directory for store OPF results and plots

if addrenew
    resultDir = fullfile('Result_Renewable',num2str(year(timeStamp)),'OPF');
    figDir = fullfile('Result_Renewable',num2str(year(timeStamp)),'Figure','OPF');
else
    resultDir = fullfile('Result',num2str(year(timeStamp)),'OPF');
    figDir = fullfile('Result',num2str(year(timeStamp)),'Figure','OPF');
end

createDir(resultDir);
createDir(figDir);

% Run OPF

% mpopt = mpoption('opf.flow_lim','P');
mpopt = mpoption('model', 'DC');
mpcreduced = toggle_iflims(mpcreduced, 'on');
resultOPF = rundcopf(mpcreduced,mpopt);
fprintf("Finished solving optimal power flow!\n");

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% --------------------------------------------CHANGES MADE --------------------------------------------%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Calculate Shortfall for Hydrogen Plant
% Define the hydrogen plant demand
hydrogen_demand = 200;  % Demand in MW

%Define windf arm capacity 
wind_capacity = 250;    % Wind farm capacity in MW

% Define the list of zones from A to K
zones = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K"];

% Initialize an empty table to store the results
resultsTable = table();

% Loop through each zone
for z = 1:length(zones)
    zone = zones(z);  % Get the current zone

    % Filter the table to exclude rows where the zone is "NA"
    busIdNY_hydro = busInfo(busInfo.zone ~= "NA", :);

    % Find all bus numbers within the specified zone in the filtered table
    busNumbersInZone = busIdNY_hydro.idx(busIdNY_hydro.zone == zone);

    % Check if there are buses in this zone
    if isempty(busNumbersInZone)
        fprintf('No buses found in zone %s.\n', zone);
        continue;  % Skip to the next iteration if no buses are found
    end

    % % Loop through each bus in the current zone
    % for b = 1:length(busNumbersInZone)
    %     hydrogen_plant_bus = busNumbersInZone(b);  % Current bus in the zone

    hydrogen_plant_bus = busNumbersInZone(1); % First bus in the zone

    % Get actual generation at the hydrogen plant bus
    actual_generation = sum(resultOPF.gen(resultOPF.gen(:, GEN_BUS) == hydrogen_plant_bus, PG));
        
    % Calculate shortfall (positive if the plant pulls from the grid)
    shortfall = hydrogen_demand - abs(actual_generation);
        
        
    %% Determine the amount of power pulled from the grid and from the wind farm
    if shortfall > 0
        fprintf('At time %s, in zone %s, hydrogen plant at bus %d is pulling %.2f MW from the grid.\n', datestr(timeStamp), zone, hydrogen_plant_bus, shortfall);
        
        % Calculate Shortfall
        MWFromGrid = shortfall;
        MWFromWind = hydrogen_demand - MWFromGrid;
        Windexcess = 0;  % No excess power when there's a shortfall

        % LMP Calculation for just bus with hydrogen plant 
        resultBus = resultOPF.bus;
        busM = resultBus(ismember(resultBus(:,BUS_I),hydrogen_plant_bus),:);
        avgPrice = sum(busM(:,PD).*busM(:,LAM_P))/sum(busM(:,PD));

        % Append table with results 
        newRow = {zone, hydrogen_plant_bus, timeStamp, MWFromGrid, MWFromWind, Windexcess, avgPrice}; % Append the results to the table
        resultsTable = [resultsTable; newRow];

    else
        fprintf('At time %s, in zone %s, hydrogen plant at bus %d is fully supplied by the wind farm.\n', datestr(timeStamp), zone, hydrogen_plant_bus);
        
        % Calculate Shortfall
        MWFromGrid = 0;  % No grid power needed
        MWFromWind = hydrogen_demand;
        Windexcess = abs(actual_generation) - hydrogen_demand;  % Excess power from wind farm

        % LMP Calculation for just bus with hydrogen plant 
        resultBus = resultOPF.bus;
        busM = resultBus(ismember(resultBus(:,BUS_I),hydrogen_plant_bus),:);
        avgPrice = sum(busM(:,PD).*busM(:,LAM_P))/sum(busM(:,PD));

        % Append table with results 
        newRow = {zone, hydrogen_plant_bus, timeStamp, MWFromGrid, MWFromWind, Windexcess, avgPrice}; % Append the results to the table
        resultsTable = [resultsTable; newRow];

    end

    % %% LMP Calculation for entire zone
    % resultBus = resultOPF.bus;
    % busMs = resultBus(ismember(resultBus(:, BUS_I), busNumbersInZone), :);
    % avgPrice = sum(busMs(:, PD) .* busMs(:, LAM_P)) / sum(busMs(:, PD));

    % newRow = {zone, hydrogen_plant_bus, timeStamp, MWFromGrid, MWFromWind, Windexcess, avgPrice}; 
    % resultsTable = [resultsTable; newRow];

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% ----------------------------------------END of CHANGES MADE -----------------------------------------%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
%% Save OPF results

if savedata
    timeStampStr = datestr(timeStamp,"yyyymmdd_hh");
    outfilename = fullfile(resultDir,"resultOPF_"+timeStampStr+".mat");
    save(outfilename,"resultOPF");
    fprintf("Saved optimal power flow results!\n");
end

% Set the table column names
resultsTable.Properties.VariableNames = {'Zone', 'Bus', 'Timestamp', 'MWFromGrid', 'MWFromWind', 'WindpowerSold', 'LMP'};

%% Save the HydroResultstable to a file 
date = datestr(timeStamp);
fullfilepath = fullfile(resultDir,"HydrogenResults_bus"+hydrogen_plant_bus+"_"+date+".csv");
writetable(resultsTable, fullfilepath)

%% Save Fuel Mix to a file 
fullfilepath2 = fullfile(resultDir,"HydrogenFuelMix_"+date+".csv");
writetable(fuelMix, fullfilepath2)

% % Create plots
% 
% type = "OPF";

% % Plot interface flow data and error
% plotFlow(timeStamp, resultOPF, interFlow, flowLimit, type, savefig, figDir);
% 
% Plot fuel mix data and error
%plotFuel(timeStamp, resultOPF, fuelMix, interFlow, type, savefig, figDir, addrenew);
% Plot price data and error
% plotPrice(timeStamp, resultOPF, zonalPrice, busInfo, type, savefig, figDir);

end


       
