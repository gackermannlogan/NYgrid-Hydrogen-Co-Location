# Author: Gabriela Ackermann Logan, Cornell University
# Last modified: Novemeber 2024

# Import Fundtions 
include("OpenDataHydrogen.jl")
include("GroupData.jl")

using MAT, DataFrames, Dates

# Define Scenario 
Scenario = 3

# Define the directory where the plots will be saved
save_dir = "/Users/ga345/Desktop/Hydrogen Results/Scenario$(Scenario)"
mkpath(save_dir) # Create the directory if it doesn't exist

if Scenario == 0 # This is the baseline scenario
    # Define the directory and pattern for .mat files
    results_path = "/Users/ga345/Desktop/NYgrid-main/Result_Baseline/2019/OPF/"
    Fuel_data = OpenBaseline(results_path)
    wind_data = filter(row -> row.fuel == "Wind", Fuel_data)
    if nrow(wind_data) >0
        # Create the bar chart for all zones
        bar(1:length(wind_data.zone), wind_data.Total_Power,
            label="Wind Generation (MWh)",
            title= "Wind Generation Across Zones",
            xlabel= "Zones", ylabel="Power (MWh)",
            xticks=(1:length(grouped_data_windgen.Zone), grouped_data_windgen.Zone),  # Use zone names for x-axis labels
            legend = :topright,
            color="#1E88E5", bar_width=0.8)
        savefig(joinpath(save_dir, "Wind_Generation_Baseline.png"))
    end
else
    resultspath = "/Users/ga345/Desktop/NYgrid-main/Result_Scenario$(Scenario)/2019/OPF"
    all_data = OpenDataScenario(resultspath, Scenario)

    grouped_data_windgen, grouped_data_demand, sorted_data_monthly, grouped_data_wind, sorted_monthly_wind = GroupData(all_data)

    ############################################# Figure generation for Total Wind Generation #############################################
    # Create the bar chart for all zones
    bar(1:length(grouped_data_windgen.Zone), grouped_data_windgen.Total_Wind,
    label="Wind Generation (MWh)",
    title= "Wind Generation Across Zones",
    xlabel= "Zones", ylabel="Power (MWh)",
    xticks=(1:length(grouped_data_windgen.Zone), grouped_data_windgen.Zone),  # Use zone names for x-axis labels
    legend = :topright,
    color="#1E88E5", bar_width=0.8,
    ylims=(0, 450))
    savefig(joinpath(save_dir, "All_Zones_Wind_Generation.png"))

    ############################################# Figure generation for Hydrogen Demand Met #############################################
    # Create the bar chart for all zones
    bar(1:length(grouped_data_demand.Zone), [grouped_data_demand.Total_Grid grouped_data_demand.Total_Wind],
    label=["Demand Not Met from Wind (MWh)" "Demand Met from Wind (MWh)"],
    title= "Hydrogen Demand met for Across Zones",
    xlabel= "Zones", ylabel="Power (MWh)",
    xticks=(1:length(grouped_data_demand.Zone), grouped_data_demand.Zone),  # Use zone names for x-axis labels
    legend = :topright,
    color=["#D81B60" "#1E88E5"], bar_width=0.8, 
    ylims=(-200, 200))
    savefig(joinpath(save_dir, "All_Zones_Hydrogen_Demand.png"))

    #-----------------------------------------------  Figure generation for Hydrogen Demand Met (Hourly)-----------------------------------------------#
    #=
    # Go through each zone and plot when demand is met from the wind farm vs when energy from the grid is needed (THIS IS HOURLY)
    zones = unique(all_data.Zone)

    for zone in zones
        zone_data = filter(row -> row[:Zone] == zone, all_data)
        demand_wind = [val for val in zone_data. MWFromWind]  # Power from Wind Farm is pos
        demand_grid = [-val for val in zone_data.MWFromGrid]  # Power from Grid is Neg 
        #hour_label = [string(i) for i in 1:length(zone_data.Timestamp)] # Convert Timestamp into hours 

        # Create the bar chart for each zone
        bar(1:length(zone_data.Timestamp), [demand_grid demand_wind],
            label=["Demand Not Met from Wind (MW)" "Demand Met from Wind (MW)"],
            title= "Hydrogen Demand met for Zone $zone",
            xlabel="Hours", ylabel="Power (MW)",
            legend = :topright,
            color=[:red :green], bar_width=0.8)
        savefig(joinpath(save_dir, "Zone_$(zone)_Hydrogen_Demand.png")) # Save the plot

    end

    # Check if Figure matches restults from output 
    # Filter the data to include only rows where the Zone is "A"
    # zone_a_data = filter(row -> row[:Zone] == "B", all_data)
    # display(zone_a_data)
    =#
end


