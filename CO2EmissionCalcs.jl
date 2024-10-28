# Author: Gabriela Ackermann Logan, Cornell University
# Last modified: October 2024

# Import Fundtions 
include("GroupData.jl")

# Define the directory where the plots will be saved
save_dir = "/Users/ga345/Desktop/Hydrogen Results/Demand_$(demand)"
mkpath(save_dir) # Create the directory if it doesn't exist

##################################################### CO₂ Emissions Calculations by Technology #####################################################

# Extract generation data for each fuel category from pivot_data
dual_fuel_gen = pivot_data[!, "Dual Fuel"]          # MW from Dual Fuel
natural_gas_gen = pivot_data[!, "Natural Gas"]       # MW from Natural Gas
other_fossil_gen = pivot_data[!, "Other Fossil Fuels"]  # MW from Other Fossil Fuels

# Define the number of operating hours (e.g., assume 10 hours of operation or calculate from data if available)
operating_hours = 10  # Example: can be dynamic if available

# Heat rates (MMBtu/MWh)
heat_rate_dual_fuel = 12.9
heat_rate_natural_gas = 9.7
heat_rate_other_fossil = 12.5

# Carbon content (tons CO₂/MMBtu)
carbon_content_dual_fuel = 0.061
carbon_content_natural_gas = 0.059
carbon_content_other_fossil = 0.119

# Initialize arrays to store emissions for each month
emissions_dual_fuel = []
emissions_natural_gas = []
emissions_other_fossil = []

# Loop through each month to calculate emissions based on actual generation data
for i in 1:length(dual_fuel_gen)
    # Calculate CO₂ emissions for each technology
    emission_df = dual_fuel_gen[i] * operating_hours * heat_rate_dual_fuel * carbon_content_dual_fuel
    emission_ng = natural_gas_gen[i] * operating_hours * heat_rate_natural_gas * carbon_content_natural_gas
    emission_of = other_fossil_gen[i] * operating_hours * heat_rate_other_fossil * carbon_content_other_fossil

    # Append the results to each array
    push!(emissions_dual_fuel, emission_df)
    push!(emissions_natural_gas, emission_ng)
    push!(emissions_other_fossil, emission_of)
end

# Create a DataFrame to store the emissions results by month
emissions_data = DataFrame(
    Month = pivot_data[!, :YearMonth],
    Dual_Fuel_CO2_Emissions = emissions_dual_fuel,
    Natural_Gas_CO2_Emissions = emissions_natural_gas,
    Other_Fossil_CO2_Emissions = emissions_other_fossil
)

# Display the CO₂ emissions data
println("CO₂ Emissions by Technology and Month (tons):")
display(emissions_data)

# Optional: save the emissions data to a CSV file
CSV.write(joinpath(save_dir, "CO2_Emissions_By_Technology_Monthly.csv"), emissions_data)


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


