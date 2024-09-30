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

%% Run OPF
% mpopt = mpoption('opf.flow_lim','P');
mpopt = mpoption('model', 'DC');
mpcreduced = toggle_iflims(mpcreduced, 'on');
resultOPF = rundcopf(mpcreduced,mpopt);
fprintf("Finished solving optimal power flow!\n");

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% --------------------------------------------CHANGES MADE --------------------------------------------%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Read in Table with Generation to get hydrogen bus 
date = datestr(timeStamp);
resultTable_hydrogen = readtable("HydrogenResults_bus"+"_"+date+".csv");
all_hydrogen_bus = resultTable_hydrogen.Bus;

% Define the list of zones from A to K
%zones = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K"];

prices = NaN(length(all_hydrogen_bus),1);

for b = 1:length(all_hydrogen_bus)
    hydrogen_bus = all_hydrogen_bus(b);
    % actual_generation = sum(resultOPF.gen(resultOPF.gen(:, GEN_BUS) == hydrogen_bus, PG));

    % LMP Calculation 
    resultBus = resultOPF.bus;
    busM = resultBus(ismember(resultBus(:,BUS_I),hydrogen_bus),:);

    if isempty(busM)
        warning("Bus %d not found in resultOPF.bus", hydrogen_bus)
        continue;
    end

    totalLoad = sum(busM(:,PD)); %Total load at the hydrogen bus
    
    if totalLoad == 0
        warning("Bus %d has zero load. Using unweighted LMP")
        avgPrice = mean(busM(:,LAM_P));
    else 
        avgPrice = sum(busM(:,PD).*busM(:,LAM_P))/totalLoad;
    end

    prices(b) = avgPrice;

end

resultTable_hydrogen.LMP= prices;

% %% Calculate Shortfall for Hydrogen Plant
% hydrogen_demand = 200;  % Demand in MW
% wind_capacity = 400;    % Wind farm capacity in MW
% 
% % Define the list of zones from A to K
% zones = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K"];
% 
% % Initialize an empty table to store the results
% resultsTable = table();
% 
% renewableGen = importRenewableGen(fullfile("Data","RenewableGen.csv"));
% % Edit Renewable Gen table to change max to wind capacity
% for i = 1:height(renewableGen)
%    if renewableGen.PgWindCap(i) < wind_capacity
%        renewableGen.PgWindCap(i) = wind_capacity; % MW
%    end
% end
% % wind_buses = renewableGen.BusID(renewableGen.PgWindCap > 0);  % Get all buses with wind generation
% wind_buses = renewableGen.BusID;
% 
% % Loop through each zone
% for z = 1:length(zones)
%     zone = zones(z);  % Get the current zone
% 
%     % Filter the table to exclude rows where the zone is "NA"
%     busIdNY_hydro = busInfo(busInfo.zone ~= "NA", :);
% 
%     % Find all bus numbers within the specified zone in the filtered table
%     busNumbersInZone = busIdNY_hydro.idx(busIdNY_hydro.zone == zone);
% 
%     % Check if there are buses in this zone
%     if isempty(busNumbersInZone)
%         fprintf('No buses found in zone %s.\n', zone);
%         continue;  % Skip to the next iteration if no buses are found
%     end
% 
%     % Find the intersection of buses in the zone, wind generators, and OPF results
%     matchingBuses = intersect(intersect(resultOPF.gen(:, 1), wind_buses), busNumbersInZone);
% 
%     % Check if there are matching wind generator buses
%     if isempty(matchingBuses)
%         fprintf('No matching wind generator buses found in zone %s.\n', zone);
%         continue;  % Skip to the next iteration if no matches are found
%     end
% 
%     % Use the first matching bus with wind generation as the hydrogen plant bus
%     hydrogen_plant_bus = matchingBuses(1);
% 
%     % Get actual generation at the hydrogen plant bus
%     % actual_generation = sum(resultOPF.gen(resultOPF.gen(:, GEN_BUS) == hydrogen_plant_bus, PG));
% 
%     % Find all generation values at the hydrogen plant bus
%     gen_at_hydrogen_bus = resultOPF.gen(resultOPF.gen(:, GEN_BUS) == hydrogen_plant_bus, PG);
% 
%     % Initialize actual_generation
%     actual_generation = 0;
% 
%    % wind_cap_for_bus = renewableGen.PgWindCap(renewableGen.BusID == hydrogen_plant_bus);
% 
%     % Check if the bus has wind capacity information
%     %if isempty(wind_cap_for_bus)
%     if isempty(wind_capacity)
%         fprintf('No wind capacity found for hydrogen plant bus %d.\n', hydrogen_plant_bus);
%     else
%         % Loop through each generation value at the hydrogen plant bus
%         for i = 1:length(gen_at_hydrogen_bus)
%             % Check if the generation is less than or equal to the wind capacity for that bus
%             if gen_at_hydrogen_bus(i)>= 0 && gen_at_hydrogen_bus(i) <= wind_capacity
%                 actual_generation = actual_generation + gen_at_hydrogen_bus(i);  
%             end
%         end
%     end
% 
%     % Calculate shortfall (positive if the plant pulls from the grid)
%     shortfall = hydrogen_demand - actual_generation;    
% 
%     %% Determine when windfarm has 
%     if shortfall > 0
%         fprintf('At time %s, in zone %s, hydrogen plant at bus %d is pulling %.2f MW from the grid.\n', datestr(timeStamp), zone, hydrogen_plant_bus, shortfall);
% 
%         % Calculate Shortfall
%         MWFromGrid = shortfall;
%         MWFromWind = hydrogen_demand - MWFromGrid;
%         Windexcess = hydrogen_demand - (MWFromGrid + MWFromWind);  % No excess power when there's a shortfall
% 
%         % LMP Calculation for just bus with hydrogen plant 
%         resultBus = resultOPF.bus;
%         busM = resultBus(ismember(resultBus(:,BUS_I),hydrogen_plant_bus),:);
%         avgPrice = sum(busM(:,PD).*busM(:,LAM_P))/sum(busM(:,PD));
% 
%         % Append table with results 
%         newRow = {zone, hydrogen_plant_bus, timeStamp, MWFromGrid, MWFromWind, Windexcess, actual_generation, avgPrice}; % Append the results to the table
%         resultsTable = [resultsTable; newRow];
% 
%     else
%         fprintf('At time %s, in zone %s, hydrogen plant at bus %d is fully supplied by the wind farm.\n', datestr(timeStamp), zone, hydrogen_plant_bus);
% 
%         % Calculate Shortfall
%         MWFromGrid = 0;  % No grid power needed
%         MWFromWind = hydrogen_demand;
%         Windexcess = abs(actual_generation) - hydrogen_demand;  % Excess power from wind farm
% 
%         % LMP Calculation for just bus with hydrogen plant 
%         resultBus = resultOPF.bus;
%         busM = resultBus(ismember(resultBus(:,BUS_I),hydrogen_plant_bus),:);
%         avgPrice = sum(busM(:,PD).*busM(:,LAM_P))/sum(busM(:,PD));
% 
%         % Append table with results 
%         newRow = {zone, hydrogen_plant_bus, timeStamp, MWFromGrid, MWFromWind, Windexcess, actual_generation, avgPrice}; % Append the results to the table
%         resultsTable = [resultsTable; newRow];
% 
%     end
% 
%     % %% LMP Calculation for entire zone
%     % resultBus = resultOPF.bus;
%     % busMs = resultBus(ismember(resultBus(:, BUS_I), busNumbersInZone), :);
%     % avgPrice = sum(busMs(:, PD) .* busMs(:, LAM_P)) / sum(busMs(:, PD));
% 
%     % newRow = {zone, hydrogen_plant_bus, timeStamp, MWFromGrid, MWFromWind, Windexcess, avgPrice}; 
%     % resultsTable = [resultsTable; newRow];
% 
% end

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

% % Set the table column names
% resultsTable.Properties.VariableNames = {'Zone', 'Bus', 'Timestamp', 'MWFromGrid', 'MWFromWind', 'WindpowerSold', 'WindGen','LMP'};

%% Save the HydroResultsTable to a file 
date = datestr(timeStamp);
fullfilepath = fullfile(resultDir,"HydrogenResults_date"+date+".csv");
writetable(resultTable_hydrogen, fullfilepath)

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
% plotFuel(timeStamp, resultOPF, fuelMix, interFlow, type, savefig, figDir, addrenew);
% Plot price data and error
% plotPrice(timeStamp, resultOPF, zonalPrice, busInfo, type, savefig, figDir);

end
