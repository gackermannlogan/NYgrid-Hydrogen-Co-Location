# Author: Gabriela Ackermann Logan, Cornell University
# Last modified: Novemember 2024

# Import Fundtions 
include("GroupData.jl")

using Glob, CSV, DataFrames, Plots, MAT, Dates, Statistics

# Define the directory where the plots will be saved
Scenario = 2

save_dir = "/Users/ga345/Desktop/Hydrogen Results/"
mkpath(save_dir2) # Create the directory if it doesn't exist

# Define the directory where the plots will be saved
save_dir2 = "/Users/ga345/Desktop/Hydrogen Results/Scenario$(Scenario)"
mkpath(save_dir2) # Create the directory if it doesn't exist

##################################################### LMP Comparison #####################################################
function AllScenariosLMP(save_directory)
    # need to make into a fucntion
    # First plot the baseline results 
    resultspath_base = "/Users/ga345/Desktop/NYgrid-main/Result_Baseline/2019/OPF/"
    all_baseline_results = glob("BaslineResults_date*.csv", resultspath_base)

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

    # Create the bar chart for all zones
    bar(1:length(group_data_baseline.Zone), group_data_baseline.Average_LMP,
        label="LMP(USD)",
        title= "LMP Across Zones",
        xlabel= "Zones", ylabel="LMP(USD)",
        xticks=(1:length(group_data_baseline.Zone), group_data_baseline.Zone),  # Use zone names for x-axis labels
        legend = :topright,
        color="#1E88E5", bar_width=0.8)
    savefig(joinpath(save_directory, "All_Zones_Baseline_LMP.png"))

    # Then go through the different Scenarios 
    resultspath_scenario1 = "/Users/ga345/Desktop/NYgrid-main/Result_Scenario1/2019/OPF/"
    resultspath_scenario2 = "/Users/ga345/Desktop/NYgrid-main/Result_Scenario2/2019/OPF/"
    resultspath_scenario3 = "/Users/ga345/Desktop/NYgrid-main/Result_Scenario3/2019/OPF/"
    all_result_scenario1 = glob("HydrogenResults_Scenario1_*.csv", resultspath_scenario1)
    all_result_scenario2 = glob("HydrogenResults_Scenario2_*.csv", resultspath_scenario2)
    all_result_scenario3 = glob("HydrogenResults_Scenario3_*.csv", resultspath_scenario3)

    all_scenario1_data = DataFrame()
    # Iterate through all files and ensure types are consistent
    for file in all_result_scenario1
        file_data = CSV.read(file, DataFrame)
        # Append the data
        append!(all_scenario1_data, file_data, promote=true)
    end

    all_scenario2_data = DataFrame()
    # Iterate through all files and ensure types are consistent
    for file in all_result_scenario2
        file_data = CSV.read(file, DataFrame)
        # Append the data
        append!(all_scenario2_data, file_data, promote=true)
    end

    all_scenario3_data = DataFrame()
    # Iterate through all files and ensure types are consistent
    for file in all_result_scenario3
        file_data = CSV.read(file, DataFrame)
        # Append the data
        append!(all_scenario3_data, file_data, promote=true)
    end

    group_data_scenario1 = combine(groupby(all_scenario1_data, [:Zone]), 
                                            :LMP => mean => :Average_LMP)
    
    group_data_scenario2 = combine(groupby(all_scenario2_data, [:Zone]), 
                                            :LMP => mean => :Average_LMP)

    group_data_scenario3 = combine(groupby(all_scenario3_data, [:Zone]), 
                                            :LMP => mean => :Average_LMP)    
                                            
    # Create a line chart to compare LMPs
    plot(group_data_baseline.Zone, group_data_baseline.Average_LMP, label = "Baseline", linewidth =2, color = "blue")
    plot!(group_data_scenario1.Zone, group_data_scenario1.Average_LMP, label = "Scenario 1",linewidth =2, color = "green")
    plot!(group_data_scenario2.Zone, group_data_scenario2.Average_LMP, label = "Scenario 2",linewidth =2, color = "purple")
    plot!(group_data_scenario3.Zone, group_data_scenario3.Average_LMP, label = "Scenario 3",linewidth =2, color = "orange")

    xlabel!("Zone")
    ylabel!("Average LMP (USD)")
    title!("Comparison of Average LMPs")
    savefig(joinpath(save_directory, "Compare_Zones_LMP.png"))
end

AllScenariosLMP(save_dir)

##################################################### LMP Calculations #####################################################
function calculate_LMPs(results_path, save_dir)
    # Initialize an empty DataFrame to store LMP results for all buses across all timestamps
    all_LMP_data = DataFrame(Timestamp = DateTime[], Bus = Int[], LMP = Float64[])

    # Filter for .mat files in the specified directory
    mat_files = filter(f -> endswith(f, ".mat"), readdir(results_path; join=true))

    for file_path in mat_files
        if occursin(r"resultOPF.*\.mat", file_path)  # Only process files that match the pattern
            # Extract the timestamp from the filename
            filename = basename(file_path)
            timestamp_str = match(r"\d{8}_\d{2}", filename).match  # Extract 'yyyymmdd_hh'
            timestamp = DateTime(timestamp_str, "yyyymmdd_HH")

            # Open the .mat file and read data
            file = matopen(file_path)
            data = read(file, "resultOPF")
            close(file)

            # Extract bus data
            bus_data = data["bus"]  # Assuming bus data has columns: [BUS_I, PD, LAM_P]

            # Initialize vector to store LMPs for this timestamp
            lmp_values = Float64[]

            # Calculate LMP for each bus
            for row in eachrow(bus_data)
                bus_id = row[1]
                load = row[3]
                price = row[4]

                # Weighted LMP calculation
                if load == 0
                    avg_price = mean(bus_data[:,14])  # Unweighted average if total load is zero
                else
                    avg_price = sum(bus_data[:,3] .* bus_data[:, 14]) / sum(bus_data[:,3])
                end

                # Append LMP data for this bus and timestamp
                push!(lmp_values, avg_price)
                append!(all_LMP_data, DataFrame(Timestamp = [timestamp], Bus = [bus_id], LMP = [avg_price]))
            end
        end
    end

    # Save the LMP data
    # CSV.write(joinpath(save_dir, "All_Buses_LMP.csv"), all_LMP_data)
    return all_LMP_data
end

function ScenarioLMP(scenario, save_dir)
    # Set the results path based on the scenario
    results_path = if Scenario == 0
        "/Users/ga345/Desktop/NYgrid-main/Result_Baseline/2019/OPF/"
    else
        "/Users/ga345/Desktop/NYgrid-main/Result_Scenario$(Scenario)/2019/OPF/"
    end

    # Calculate LMP data for the specified scenario
    LMP_data = calculate_LMPs(results_path, scenario_save_dir)

    # Process YearMonth and YearMonthDate columns for aggregation
    LMP_data.YearMonth = Dates.format.(LMP_data.Timestamp, "yyyy-mm-dd")
    LMP_data[!, :YearMonth] = Dates.Date.(LMP_data.YearMonth, "yyyy-mm-dd")
    LMP_data[!, :YearMonthDate] = Dates.format.(LMP_data.YearMonth, "yyyy-mm")

    # Group and aggregate data by YearMonthDate
    grouped_LMP_data = combine(groupby(LMP_data, [:YearMonthDate]), :LMP => mean => :AverageLMP)
    grouped_LMP_data[!, :YearMonth] = Dates.Date.(grouped_LMP_data.YearMonthDate, "yyyy-mm")
    month_abbreviations_LMP = Dates.format.(grouped_LMP_data.YearMonth, "UUU")  # Extract month abbreviations
    unique!(month_abbreviations_LMP)

    # Plot LMP across buses for the scenario
    bar(
        grouped_LMP_data.AverageLMP,
        label="Scenario $(Scenario) LMP", 
        xlabel="Month", ylabel="LMP (USD)", 
        xticks=(1:length(grouped_LMP_data.YearMonthDate), month_abbreviations_LMP),  # Use month abbreviations for x-axis labels
        title="Monthly LMP for 2019 Grid (Scenario $(Scenario))",
        legend=:topright, rotation=45,
    )
    savefig(joinpath(save_dir, "Monthly_LMP_Scenario$(Scenario).png"))
end

ScenarioLMP(1, save_dir2)  # Call this function with the desired scenario number


#------------------ Difference in LMP from Baseline ------------------# 
function LMPDifference(scenario, save_dir)
    if Scenario !== 0
        # Define paths for baseline and scenario data
        baseline_path = "/Users/ga345/Desktop/NYgrid-main/Result_Baseline/2019/OPF/"
        scenario_path = "/Users/ga345/Desktop/NYgrid-main/Result_Scenario$(Scenario)/2019/OPF/"
    
        # Calculate LMPs for baseline and scenario
        baseline_LMP_data = calculate_LMP_for_all_buses(baseline_path, save_dir)
        scenario_LMP_data = calculate_LMP_for_all_buses(scenario_path, save_dir)
    
        # Process YearMonthDate for both baseline and scenario data
        baseline_LMP_data.YearMonthDate = Dates.format.(baseline_LMP_data.Timestamp, "yyyy-mm")
        scenario_LMP_data.YearMonthDate = Dates.format.(scenario_LMP_data.Timestamp, "yyyy-mm")
    
        # Group and aggregate data by YearMonthDate to calculate average LMP per month
        grouped_baseline_LMP = combine(groupby(baseline_LMP_data, [:YearMonthDate]), :LMP => mean => :AverageLMP)
        grouped_scenario_LMP = combine(groupby(scenario_LMP_data, [:YearMonthDate]), :LMP => mean => :AverageLMP)
    
        # Join baseline and scenario data on YearMonthDate
        combined_LMP = innerjoin(grouped_baseline_LMP, grouped_scenario_LMP, on=:YearMonthDate, makeunique=true)
    
        # Rename columns for clarity
        rename!(combined_LMP, Dict("AverageLMP_1" => "Baseline_AverageLMP", "AverageLMP_2" => "Scenario_AverageLMP"))
    
        # Calculate LMP difference
        combined_LMP[!, :LMP_Difference] = combined_LMP.Scenario_AverageLMP .- combined_LMP.Baseline_AverageLMP
    
        # Convert YearMonthDate to Date for plotting
        combined_LMP[!, :YearMonth] = Dates.Date.(combined_LMP.YearMonthDate, "yyyy-mm")
        month_abbreviations_LMP = Dates.format.(combined_LMP.YearMonth, "UUU")
    
        # Plot the difference in LMP
        bar(
            combined_LMP.YearMonthDate, combined_LMP.LMP_Difference,
            label="LMP Difference (Scenario - Baseline)",
            xlabel="Month", ylabel="LMP Difference (USD)",
            xticks=(1:length(combined_LMP.YearMonthDate), month_abbreviations_LMP),
            title="Monthly LMP Difference from Baseline (Scenario $(Scenario))",
            legend=:topright, rotation=45
        )
        savefig(joinpath(save_dir, "Monthly_LMP_Difference.png"))
    end
end

# Example usage
LMPDifference(Scenario, save_dir2)  # Call this function with the desired scenario number

#=
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
=#
