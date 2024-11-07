# Author: Gabriela Ackermann Logan, Cornell University
# Last modified: October 2024

# Import Fundtions 
include("GroupData.jl")

# Define the directory where the plots will be saved
save_dir = "/Users/ga345/Desktop/Hydrogen Results/Scenario$(Scenario)"
mkpath(save_dir) # Create the directory if it doesn't exist

##################################################### LMP Comparison #####################################################
# Get the csv files for Hydrogen Results
all_baseline_results = glob("BaslineResults_date*.csv", resultspath_base) # Use Glob to find only Baseline Results 
all_result_scenario2 = glob("HydrogenResults_Scenario2_*.csv", resultspath)

# all__baseline_data will store all the results (combine all CSV files)
all_baseline_data = DataFrame()

# Iterate through all files and ensure types are consistent
for file in all_baseline_results
    base_data = CSV.read(file, DataFrame)
    # Append the data
    append!(all_baseline_data, base_data, promote=true)
end

group_data_baseline = combine(groupby(all_baseline_data, [:Zone]), 
                                    :LMP => mean => :Average_LMP)
group_data_baseline= group_data_baseline[1:11,:]

all_scenario2_data = DataFrame()
# Iterate through all files and ensure types are consistent
for file in all_result_scenario2
    file_data = CSV.read(file, DataFrame)
    # Append the data
    append!(all_scenario2_data, file_data, promote=true)
end

# Create the bar chart for all zones
bar(1:length(group_data_baseline.Zone), group_data_baseline.Average_LMP,
    label="LMP(USD)",
    title= "LMP Across Zones",
    xlabel= "Zones", ylabel="LMP(USD)",
    xticks=(1:length(group_data_baseline.Zone), group_data_baseline.Zone),  # Use zone names for x-axis labels
    legend = :topright,
    color="#1E88E5", bar_width=0.8)
savefig(joinpath(save_dir, "All_Zones_Baseline_LMP.png"))

group_data_scenario1 = combine(groupby(all_data, [:Zone]), 
                                        :LMP => mean => :Average_LMP)
 
 group_data_scenario2 = combine(groupby(all_scenario2_data, [:Zone]), 
                                        :LMP => mean => :Average_LMP)
# Create a line chart to compare LMPs
plot(group_data_baseline.Zone, group_data_baseline.Average_LMP, label = "Baseline", linewidth =2, color = "blue")
plot!(group_data_scenario1.Zone, group_data_scenario1.Average_LMP, label = "Scenario 1",linewidth =2, color = "green")
plot!(group_data_scenario2.Zone, group_data_scenario2.Average_LMP, label = "Scenario 2",linewidth =2, color = "purple")

xlabel!("Zone")
ylabel!("Average LMP (USD)")
title!("Comparison of Average LMPs")
savefig(joinpath(save_dir, "Compare_Zones_LMP.png"))

##################################################### Plotting for when power sold vs bought #####################################################
# Calculate total cost and revenue 
all_data.power_sold = all_data.WindpowerSold .* all_data.LMP
all_data.power_bought = all_data.MWFromGrid .* all_data.LMP

# Group by Zone 
group_data_sold = combine(groupby(all_data, :Zone),
                     :power_sold => mean => :Mean_Sold,
                     :power_bought => mean => :Mean_Bought)

group_data_sold.Mean_Bought = -group_data_sold.Mean_Bought 

# Create a bar chart for revenue and cost per zone
bar(1:length(group_data_sold.Zone), [group_data_sold.Mean_Sold group_data_sold.Mean_Bought],
    label=["Revenue" "Cost"],
    title="Net Market Participation: Revenue vs Cost by Zone",
    xlabel="Zone", ylabel= "Amount",
    xticks=(1:length(group_data_sold.Zone), group_data_sold.Zone),  # Zone labels on x-axis
    color=["#D81B60" "#1E88E5"], bar_width=0.8)
# Save figure
savefig(joinpath(save_dir, "Net_Market_Participation_Revenue_vs_Cost_by_Zone.png"))
#=
#------------------------------------------------------- Plotting by zone - net revenue vs cost -------------------------------------------------------#
# Group by Zone 
group_data_sold = combine(groupby(all_data, :Zone),
                     :WindpowerSold => mean => :Total_Surplus,
                     :MWFromGrid => mean => :Total_Demand,
                     :LMP => mean => :Avg_LMP)  # Use mean for LMP per zone                  
group_data_sold.Surplus_Sold = group_data_sold.Total_Surplus .* group_data_sold.Avg_LMP  # Revenue from selling power
group_data_sold.Power_Bought = group_data_sold.Total_Demand .* group_data_sold.Avg_LMP  # Cost from buying power

# Create a bar chart for revenue and cost per zone
bar(1:length(group_data_sold.Zone), [group_data_sold.Surplus_Sold group_data_sold.Power_Bought],
    label=["Revenue" "Cost"],
    title="Net Market Participation: Revenue vs Cost by Zone",
    xlabel="Zone", ylabel="Amount ",
    xticks=(1:length(group_data_sold.Zone), group_data_sold.Zone),  # Zone labels on x-axis
    color=["#D81B60" "#1E88E5"], bar_width=0.8)

# Save figure
savefig(joinpath(save_dir, "Net_Market_Participation_Revenue_vs_Cost_by_Zone.png"))


# #For each zone and plot when there is exess wind power that can be sold to the grid
all_data.Surplus_Sold = all_data.WindpowerSold .* all_data.LMP  # Revenue from selling power
all_data.Power_Bought = all_data.MWFromGrid .* all_data.LMP  # Cost from buying power
total_revenue = sum(all_data.Surplus_Sold)
total_cost = sum(all_data.Power_Bought)

# println("Total Revenue from selling power: $total_revenue")
# println("Total Cost from buying power: $total_cost")
profit = total_revenue - total_cost

# Create a bar chart for revenue and cost
bar(["Cost", "Revenue"], [total_cost, total_revenue],
    label=["Cost", "Revenue"],
    legend = false,
    title="Net Market Participation: Revenue vs Cost",
    xlabel="Market Activity", ylabel="Amount Of Money",
    color=[:gray, :green], bar_width=0.8)
# Save figure
savefig(joinpath(save_dir, "Net_Market_Participation_Revenue_vs_Cost.png"))
=#



############################################# Figure generation for When Wind can Sell Power #############################################
# Create the bar chart for all zones
groupedbar(1:length(grouped_data_wind.Zone), [grouped_data_wind.Wind_Used grouped_data_wind.Excess_Wind],
    bar_position = :stack,
    label=["Wind Used for Hydrogen" "Excess Wind (MWh)" ],
    title= "When Wind Sells Power Across Zones",
    xlabel= "Zones", ylabel="Power (MWh)",
    xticks=(1:length(grouped_data_wind.Zone), grouped_data_wind.Zone),  # Use zone names for x-axis labels
    legend = :topright,
    color=["#E1BE6A" "#1E88E5"], bar_width=0.8,
    ylims = (-200, 200))
savefig(joinpath(save_dir, "All_Zones_Wind_Power_Sell.png"))

#----------------------------------------------- Plotting for EACH zone - net surplus or demand (MONTHLY) -----------------------------------------------#
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
            color=["#D81B60" "#1E88E5"], bar_width=0.8,
            ylims = (-200, 200))
        
        # Save the plot for the current zone
        savefig(joinpath(save_dir, "Zone_$(zone)_Monthly_Hydrogen_Demand.png"))
    end

    zoneAdata = zonedata[1]
    zoneBdata = zonedata[2]
    zoneCdata = zonedata[3]
    zoneEdata = zonedata[5]
#----------------------------------------------- Plotting for EACH zone - net surplus or demand -----------------------------------------------#
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
        color=["#E1BE6A" "#1E88E5"], bar_width=0.8,
        ylims = (-200, 200))

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