# Author: Gabriela Ackermann Logan, Cornell University
# Last modified: October 2024

# Import Fundtions 
include("OpenDataHydrogen.jl")
include("GroupData.jl")

# Define the directory where the plots will be saved
save_dir = "/Users/ga345/Desktop/Hydrogen Results/Demand_$(demand)"
mkpath(save_dir) # Create the directory if it doesn't exist

################################################################### Fuel Mix ##########################################################################################
# Define the file path and find all matching files
resultspath2 = "/Users/ga345/Desktop/NYgrid-main/Result/2019/OPF"
FuelMix = OpenFuelData(resultspath2)

# Group the merged data by Zone and FuelCategory + sum the generation
grouped_fuel = combine(groupby(FuelMix, [:YearMonth, :FuelCategory]), :GenMW => mean => :Total_GenMW) 

# Pivot the data to make fuel categories the columns and zones the rows
pivot_data = unstack(grouped_fuel, :FuelCategory, :Total_GenMW)

dual_fuel = pivot_data[!, "Dual Fuel"]
hydro = pivot_data[!, "Hydro"]
natural_gas =  pivot_data[!, "Natural Gas"] 
nuclear = pivot_data[!, "Nuclear"]
other_fossil = pivot_data[!,"Other Fossil Fuels"]
other_renewables = pivot_data[!,"Other Renewables"]
wind_pivot = pivot_data[!,"Wind"]

groupedbar([dual_fuel hydro natural_gas nuclear other_fossil other_renewables wind_pivot],
    label= ["Dual Fuel" "Hydro" "Natural Gas" "Nuclear" "Other Fossil Fuels" "Other Renewables" "Wind"],
    bar_position = :stack,
    xlabel="Months", ylabel="Generation (MWh)",  
    xticks=(1:length(grouped_fuel.YearMonth), month_abbreviations_fuel),  # Use month abbreviations for x-axis labels
    title= "Fuel Mix Over Year",
    legend=:topright,
    rotation=45,
    color=["#648FFF" "#785EF0" "#DC267F" "#004D40" "#FE6100" "#FFB000" "#994F00"], bar_width=0.8)

# Save the stacked bar chart
savefig(joinpath(save_dir, "FuelMix_by_Zone_Stacked_Bar.png"))

#-------------------------------------------------------  Pie Chart for Fuel Mix per Zone-------------------------------------------------------#
#=
# Loop through each group of rows with the same timestamp to create pie charts with percentages
for group in grouped_fuel_data
    current_timestamp = group.TimeStamp[1]
    fuel_category = group.FuelCategory
    total_gen = sum(group.GenMW)  # Total generation for that timestamp
    percentages = (group.GenMW ./ total_gen) .* 100  # Calculate percentage for each fuel category
    # Create pie chart with percentages
    Plots.pie(fuel_category, percentages,
       title = "Fuel Mix (in %) for $current_timestamp",
       legend = true)
    savefig(joinpath(save_dir, "FuelMix_$current_timestamp.png"))
    
end
=#