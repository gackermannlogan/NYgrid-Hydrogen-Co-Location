# Author: Gabriela Ackermann Logan, Cornell University
# Last modified: October 2024

# Import Fundtions 
include("GroupData.jl")

# Define the directory where the plots will be saved
save_dir = "/Users/ga345/Desktop/Hydrogen Results/Demand_$(demand)"
mkpath(save_dir) # Create the directory if it doesn't exist

##################################################### Figure generation for Total Wind Generation #####################################################
# Create the bar chart for all zones
bar(1:length(grouped_data_windgen.Zone), grouped_data_windgen.Total_Wind,
    label="Wind Generation (MWh)",
    title= "Wind Generation Across Zones",
    xlabel= "Zones", ylabel="Power (MWh)",
    xticks=(1:length(grouped_data_windgen.Zone), grouped_data_windgen.Zone),  # Use zone names for x-axis labels
    legend = :topright,
    color="#1E88E5", bar_width=0.8)
savefig(joinpath(save_dir, "All_Zones_Wind_Generation.png"))

##################################################### Figure generation for Hydrogen Demand Met #####################################################
# Create the bar chart for all zones
bar(1:length(grouped_data_demand.Zone), [grouped_data_demand.Total_Grid grouped_data_demand.Total_Wind],
    label=["Demand Not Met from Wind (MWh)" "Demand Met from Wind (MWh)"],
    title= "Hydrogen Demand met for Across Zones",
    xlabel= "Zones", ylabel="Power (MWh)",
    xticks=(1:length(grouped_data_demand.Zone), grouped_data_demand.Zone),  # Use zone names for x-axis labels
    legend = :topright,
    color=["#D81B60" "#1E88E5"], bar_width=0.8)
savefig(joinpath(save_dir, "All_Zones_Hydrogen_Demand.png"))

#------------------------------------------------------- Plotting for EACH zone - net surplus or demand (MONTHLY) -------------------------------------------------------#
# Go through each zone and plot when demand is met from the wind farm vs when energy from the grid is needed 
# Aggregated based on month - the chart will be power on y and month on x for the entire year 

zonedata = []
# Iterate over zones and plot data by sorted month
for zone in unique(sorted_data_monthly.Zone)
    # Filter sorted data for the current zone
    zone_data = filter(row -> row[:Zone] == zone, sorted_data_monthly)
    push!(zonedata,zone_data) #save to dataframe outside 

    # Convert the YearMonth string back into DateTime for this zone and get month abbreviations
    zone_data[!, :YearMonthDate] = Dates.Date.(zone_data.YearMonth, "yyyy-mm")
    month_abbreviations = Dates.format.(zone_data.YearMonthDate, "UUU")  # Extract month abbreviations

    demand_wind = [val for val in zone_data. Total_Wind]  # Power from Wind Farm is pos
    demand_grid = [-val for val in zone_data.Total_Grid]  # Power from Grid is Neg 

    # Create the bar chart for each zone, aggregated by month
    bar(1:length(zone_data.YearMonth),[demand_grid demand_wind],
        label=["Demand Not Met from Wind (MWh)" "Demand Met from Wind (MWh)"],
        title= "Hydrogen Demand met for Zone $zone",
        xlabel="Month", ylabel="Power (MWh)",
        xticks=(1:length(zone_data.YearMonth), month_abbreviations),  # Use month abbreviations for x-axis labels
        legend=:topright,
        rotation=45,
        color=["#D81B60" "#1E88E5"], bar_width=0.8)
    
    # Save the plot for the current zone
    savefig(joinpath(save_dir, "Zone_$(zone)_Monthly_Hydrogen_Demand.png"))
end

zoneAdata = zonedata[1]
zoneBdata = zonedata[2]
zoneCdata = zonedata[3]
zoneEdata = zonedata[5]

#-------------------------------------------------------  Figure generation for Hydrogen Demand Met (Hourly)-------------------------------------------------------#
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

##################################################### Figure generation for When Wind can Sell Power #####################################################
# Create the bar chart for all zones
groupedbar(1:length(grouped_data_wind.Zone), [grouped_data_wind.Wind_Used grouped_data_wind.Excess_Wind],
    bar_position = :stack,
    label=["Wind Used for Hydrogen" "Excess Wind (MWh)" ],
    title= "When Wind Sells Power Across Zones",
    xlabel= "Zones", ylabel="Power (MWh)",
    xticks=(1:length(grouped_data_wind.Zone), grouped_data_wind.Zone),  # Use zone names for x-axis labels
    legend = :topright,
    color=["#E1BE6A" "#1E88E5"], bar_width=0.8)
savefig(joinpath(save_dir, "All_Zones_Wind_Power_Sell.png"))

#------------------------------------------------------- Plotting for EACH zone - net surplus or demand -------------------------------------------------------#
# Go through each zone and plot when there is exess wind power that can be sold to the grid
for zone in unique(sorted_monthly_wind.Zone)
    # Filter sorted data for the current zone
    zone_data = filter(row -> row[:Zone] == zone, sorted_monthly_wind)

    # Convert the YearMonth string back into DateTime for this zone and get month abbreviations
    zone_data[!, :YearMonthDate] = Dates.Date.(zone_data.YearMonth, "yyyy-mm")
    month_abbreviations = Dates.format.(zone_data.YearMonthDate, "UUU")  # Extract month abbreviations

    excess_wind = [val for val in zone_data.Excess_Wind]
    total_wind = [val for val in zone_data.Total_Wind] 
    wind_used = [val for val in zone_data.Wind_Used]

    # Create the bar chart for each zone
    groupedbar(1:length(zone_data.YearMonth), [wind_used excess_wind],
        bar_position = :stack,
        label=["Wind Used for Hydrogen" "Excess Wind (MWh)" ],
        title= "When Wind Sells Power for $zone",
        xlabel="Month", ylabel="Power (MWh)",
        xticks=(1:length(zone_data.YearMonth), month_abbreviations),  # Use month abbreviations for x-axis labels
        legend = :topright,
        rotation=45,
        color=["#E1BE6A" "#1E88E5"], bar_width=0.8)
    savefig(joinpath(save_dir, "Zone_$(zone)_Wind_Sells.png")) # Save the plot
    #= 
    #-------------------- Plots including total wind generated, wind used and excess --------------------#
    # Create the bar chart for each zone
    bar(1:length(zone_data.YearMonth), [total_wind wind_used excess_wind],
        label=["Total Wind Generation(MW)" "Wind Used for Hydrogen" "Excess Wind (MW)" ],
        title= "When Wind Sells Power for $zone",
        xlabel="Hours", ylabel="Power (MW)",
        legend = :topright,
        color=[:gray :red :green], bar_width=0.8)
    savefig(joinpath(save_dir, "Zone_$(zone)_Wind_Sells.png")) # Save the plot
    =#

end

# Check if Figure matches restults from output 
# Filter the data to include only rows where the Zone is "A"
# zone_a_data = filter(row -> row[:Zone] == "K", all_data)
# display(zone_a_data)
