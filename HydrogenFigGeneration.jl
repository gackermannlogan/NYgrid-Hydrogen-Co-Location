
# Author: Gabriela Ackermann Logan, Cornell University
# Last modified: September 2024

# Import relevant packages
using DataFrames, CSV, Glob, Dates, Plots, Statistics

# Get the csv files for Hydrogen Results
resultspath = "/Users/ga345/Desktop/NYgrid-main/Result/2019/OPF"
all_result_files = glob("HydrogenResults_date*.csv", resultspath) # Use Glob to find only Hydrogen Results 

# all_data will store all the results (combine all CSV files)
all_data = DataFrame()
# Iterate through all files and ensure types are consistent
for file in all_result_files
    data = CSV.read(file, DataFrame)
    
    # Ensure that 'MWFromGrid' column is Float64 in each file
    if "MWFromGrid" in names(data)
        data[!, :MWFromGrid] = convert(Vector{Float64}, data[!, :MWFromGrid])
    end
    
    # Append the data
    append!(all_data, data, promote=true)
end

# Calculate demand 
demand = round(sum(all_data.MWFromGrid[1] + all_data.MWFromWind[1]), digits = 2)

# Define the directory where the plots will be saved
save_dir = "/Users/ga345/Desktop/Hydrogen Results/Demand_$(demand)"
mkpath(save_dir) # Create the directory if it doesn't exist

# Create a dictionary to map month abbreviations to numeric values
month_mapping = Dict("Jan" => "01", "Feb" => "02", "Mar" => "03", "Apr" => "04", 
                     "May" => "05", "Jun" => "06", "Jul" => "07", "Aug" => "08", 
                     "Sep" => "09", "Oct" => "10", "Nov" => "11", "Dec" => "12")

# Function to replace the month abbreviation with numeric value
function replace_month(ts::String)
    for (abbr, num) in month_mapping
        if occursin(abbr, ts)
            return replace(ts, abbr => num)
        end
    end
    return ts  # Return the timestamp if no replacement is needed
end

# Function to fix timestamps and add missing 24:00:00 hour label
function fix_timestamp(timestamp::String)
   # Check if the timestamp is missing the hour component
   if occursin(r"\d{2}-\w{3}-\d{4}$", timestamp)
       # If the timestamp ends with just the date (no time), append " 24:00:00"
       return timestamp * " 24:00:00"
   else
       # Otherwise, return the timestamp as is
       return timestamp
   end
end

all_data[!, :Timestamp] = fix_timestamp.(String.(all_data.Timestamp))
all_data[!, :Timestamp] = replace_month.(all_data.Timestamp)  # Replace month abbreviations

# Convert the Timestamp column to datetime for easier grouping by months
try
    all_data[!, :Timestamp] = Dates.DateTime.(all_data.Timestamp, "dd-mm-yyyy HH:MM:SS")
    println("Successfully converted all timestamps to DateTime.")
catch e
    println("Error converting timestamps: ", e)
end

# Check output
# println(first(all_data, 5))  # Print the first 5 rows to verify the conversion

##################################################### Figure generation for Total Wind Generation #####################################################
# Group by zone and the total generation from the wind farm 
grouped_data = combine(groupby(all_data, :Zone),
                       :WindGen => mean => :Total_Wind)

# Create the bar chart for all zones
bar(1:length(grouped_data.Zone), grouped_data.Total_Wind,
    label="Wind Generation (MWh)",
    title= "Wind Generation Across Zones",
    xlabel= "Zones", ylabel="Power (MWh)",
    xticks=(1:length(grouped_data.Zone), grouped_data.Zone),  # Use zone names for x-axis labels
    legend = :topright,
    color="#1E88E5", bar_width=0.8)
savefig(joinpath(save_dir, "All_Zones_Wind_Generation.png"))

##################################################### Figure generation for Hydrogen Demand Met #####################################################
# Group by zone and see when demand is met from the wind farm vs when energy from the grid is needed 
grouped_data = combine(groupby(all_data, :Zone),
                       :MWFromWind => mean => :Total_Wind,
                       :MWFromGrid => mean => :Total_Grid)

grouped_data.Total_Grid = -grouped_data.Total_Grid # Ensure that demand is negative for plotting 

# Create the bar chart for all zones
bar(1:length(grouped_data.Zone), [grouped_data.Total_Grid grouped_data.Total_Wind],
    label=["Demand Not Met from Wind (MW)" "Demand Met from Wind (MWh)"],
    title= "Hydrogen Demand met for Across Zones",
    xlabel= "Zones", ylabel="Power (MWh)",
    xticks=(1:length(grouped_data.Zone), grouped_data.Zone),  # Use zone names for x-axis labels
    legend = :topright,
    color=["#D81B60" "#1E88E5"], bar_width=0.8)
savefig(joinpath(save_dir, "All_Zones_Hydrogen_Demand.png"))

#------------------------------------------------------- Plotting for EACH zone - net surplus or demand (MONTHLY) -------------------------------------------------------#
# Go through each zone and plot when demand is met from the wind farm vs when energy from the grid is needed 
# Aggregated based on month - the chart will be power on y and month on x for the entire year 

# Convert the timestamp to a "Year-Month" string for grouping
all_data[!, :YearMonth] = Dates.format.(all_data.Timestamp, "yyyy-mm")
all_data[!, :YearMonthDate] = Dates.Date.(all_data.YearMonth, "yyyy-mm") # Convert 'YearMonth' string back into a DateTime

# Group by zone and YearMonth and mean the relevant columns
grouped_data_monthly = combine(groupby(all_data, [:Zone, :YearMonth]),
                             :MWFromWind => mean => :Total_Wind,
                             :MWFromGrid => mean => :Total_Grid)
# Sort the 'grouped_data_monthly' by YearMonth
sorted_data_monthly1 = sort(grouped_data_monthly, :YearMonth)
sorted_data_monthly = filter(row ->row.YearMonth !="2020-01",sorted_data_monthly1)

# println("First 5 rows after sorting by YearMonth:")
# println(first(sorted_data_monthly, 105))

# Iterate over zones and plot data by sorted month
for zone in unique(sorted_data_monthly.Zone)
    # Filter sorted data for the current zone
    zone_data = filter(row -> row[:Zone] == zone, sorted_data_monthly)
    
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

#=
#-------------------------------------------------------  Figure generation for Hydrogen Demand Met (Hourly)-------------------------------------------------------#
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
# Group by zone and see when demand is met from the wind farm vs when energy from the grid is needed 
grouped_data_wind = combine(groupby(all_data, :Zone),
                       :MWFromWind => mean => :Wind_Used,
                       :WindGen => mean => :Total_Wind,
                       :WindpowerSold=> mean => :Excess_Wind)

# Create the bar chart for all zones
bar(1:length(grouped_data_wind.Zone), [grouped_data_wind.Wind_Used grouped_data_wind.Excess_Wind],
    label=["Wind Used for Hydrogen" "Excess Wind (MWh)" ],
    title= "When Wind Sells Power Across Zones",
    xlabel= "Zones", ylabel="Power (MWh)",
    xticks=(1:length(grouped_data_wind.Zone), grouped_data_wind.Zone),  # Use zone names for x-axis labels
    legend = :topright,
    color=["#E1BE6A" "#1E88E5"], bar_width=0.8)
savefig(joinpath(save_dir, "All_Zones_Wind_Power_Sell.png"))

#------------------------------------------------------- Plotting for EACH zone - net surplus or demand -------------------------------------------------------#
# Go through each zone and plot when demand is met from the wind farm vs when energy from the grid is needed 
# Aggregated based on month - the chart will be power on y and month on x for the entire year 

grouped_data_wind_monthly = combine(groupby(all_data, [:Zone, :YearMonth]),
                       :MWFromWind => mean => :Wind_Used,
                       :WindGen => mean => :Total_Wind,
                       :WindpowerSold=> mean => :Excess_Wind)
# Sort the 'grouped_data_monthly' by YearMonth
sorted_monthly_wind1 = sort(grouped_data_wind_monthly, :YearMonth)
sorted_monthly_wind = filter(row ->row.YearMonth !="2020-01",sorted_monthly_wind1)


# Go through each zone and plot when there is exess wind power that can be sold to the grid
for zone in unique(sorted_monthly_wind.Zone)
    # Filter sorted data for the current zone
    zone_data = filter(row -> row[:Zone] == zone, sorted_monthly_wind )

    # Convert the YearMonth string back into DateTime for this zone and get month abbreviations
    zone_data[!, :YearMonthDate] = Dates.Date.(zone_data.YearMonth, "yyyy-mm")
    month_abbreviations = Dates.format.(zone_data.YearMonthDate, "UUU")  # Extract month abbreviations

    excess_wind = [val for val in zone_data.Excess_Wind]
    total_wind = [val for val in zone_data.Total_Wind] 
    wind_used = [val for val in zone_data.Wind_Used]

    # Create the bar chart for each zone
    bar(1:length(zone_data.YearMonth), [wind_used excess_wind],
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
#=
################################################################### Fuel Mix ##########################################################################################
# Define the file path and find all matching files
resultspath = "/Users/ga345/Desktop/NYgrid-main/Result/2019/OPF"
Fuel_mix_files = glob("HydrogenFuelMix*.csv", resultspath)  # Use Glob to find only Hydrogen Results

# Create one DataFrame to store all the results for Fuel
all_Fuel_data = DataFrame()
for file in Fuel_mix_files
   data = CSV.read(file, DataFrame)
   append!(all_Fuel_data, data)
end

# Check for duplicates or inconsistencies in all_Fuel_data (optional)
println("Total rows before filtering: ", nrow(all_Fuel_data))
println("Unique rows in Fuel data: ", nrow(unique(all_Fuel_data)))

# Convert 'TimeStamp' in all_Fuel_data from string to DateTime
all_Fuel_data[!, :TimeStamp] = Dates.DateTime.(all_Fuel_data.TimeStamp, "MM/dd/yyyy HH:MM:SS")

# Create an empty DataFrame to store the filtered results
FuelMix = DataFrame()
Fuel_zone = DataFrame()

# Loop through each row in all_data to find the matching timestamps for when the hydrogen plant needs to buy from the windfarm
for i in 1:nrow(all_data)
    if all_data.MWFromGrid[i] > 0 # Find when using power from the grid
        Fuel_date = all_data[i, :]
        # Match based on the Timestamp in all_data 
        matched_fuel_data = filter(row -> row.TimeStamp == Fuel_date.Timestamp, all_Fuel_data)

        append!(FuelMix, matched_fuel_data)
        #=

        matched_zone = filter(row -> row.Timestamp == Fuel_date.Timestamp, all_data)
        
        if nrow(matched_fuel_data) == 0
            println("No matches found for TimeStamp: ", Fuel_date.Timestamp)
        else
            # Append the matched fuel data to 'FuelMix' and 'Fuel_zone'
            append!(FuelMix, matched_fuel_data)
            append!(Fuel_zone, matched_zone)
        end
        =#
    end
end

# Remove duplicates from the final FuelMix
unique!(FuelMix)
unique!(Fuel_zone)
display(FuelMix)





# Step 2: Create percentages for the pie chart
# Group the fuel data
grouped_fuel_data = groupby(FuelMix, :TimeStamp)

# Loop through each group of rows with the same timestamp to create pie charts with percentages
for group in grouped_fuel_data
   current_timestamp = group.TimeStamp[1]
   clean_timestamp = replace(current_timestamp, r"[ :/]" => "_")
   fuel_category = group.FuelCategory
   total_gen = sum(group.GenMW)  # Total generation for that timestamp
   percentages = group.GenMW ./ total_gen .* 100  # Calculate percentage for each fuel category

   # Create pie chart with percentages
   Plots.pie(fuel_category, percentages,
       title = "Fuel Mix (in %) for $current_timestamp",
       legend = true)
   savefig(joinpath(save_dir, "FuelMix_$clean_timestamp.png"))
end

# Step 3: Create the stacked bar chart
# Pivot the data to make fuel categories the columns and zones the rows
pivot_data = unstack(grouped_fuelzone_data, :Zone, :FuelCategory, :Total_GenMW)

# Now, extract the data needed for the stacked bar chart:
zone_labels = pivot_data.Zone               # X-axis: Zone labels
fuel_data = Matrix(pivot_data[:, Not(:Zone)])  # Y-values: All fuel categories

# Ensure the number of colors matches the number of fuel categories
fuel_colors = distinguishable_colors(size(fuel_data, 2))  # Adjust color list length

# Create a stacked bar chart with color coding
bar(zone_labels,
    fuel_data,  # Stack fuel data for each zone
    label=names(pivot_data, Not(:Zone)),  # Label based on fuel categories
    title="Fuel Mix by Zone",
    xlabel="Zone", ylabel="Percentage (%)",  # Adjust to show percentages if needed
    legend=:topright,
    bar_width=0.8,
    color=fuel_colors,  # Assign colors to fuel categories
    lw=0,  # Line width for separating the stacks (optional)
    seriestype=:bar, orientation=:vertical, stacked=true)  # Ensure bars are stacked

# Save the stacked bar chart
savefig(joinpath(save_dir, "FuelMix_by_Zone_Stacked_Bar.png"))



#println("Final row count in FuelMix: ", nrow(FuelMix))

# Group the fuel data 
grouped_fuel_data = groupby(FuelMix, :TimeStamp)
# Loop through each group of rows with the same timestamp
for group in grouped_fuel_data
    current_timestamp = group.TimeStamp[1]
    clean_timestamp = replace(current_timestamp, r"[ :/]" => "_")
    fuel_category = group.FuelCategory
    generation_fuel = group.GenMW
    # Create pie chart
    Plots.pie(fuel_category, generation_fuel,
        title = "Fuel Mix for $current_timestamp",
        legend = true)
    savefig(joinpath(save_dir, "FuelMix_$clean_timestamp.png"))
end

rename!(Fuel_zone, :Timestamp => :TimeStamp) # Rename 'Timestamp' column in Fuel_zone to 'TimeStamp' to match with FuelMix
merged_data = innerjoin(FuelMix, Fuel_zone, on=:TimeStamp) # Merge the FuelMix and Fuel_zone data
grouped_fuelzone_data = combine(groupby(merged_data, [:Zone, :FuelCategory]), :GenMW => sum => :Total_GenMW) # Group the merged data by Zone and FuelCategory + sum the generation

# Pivot the data to make fuel categories the columns and zones the rows
pivot_data = unstack(grouped_fuelzone_data, :Zone, :FuelCategory, :Total_GenMW)

# Now, extract the data needed for the bar chart:
zone_labels = pivot_data.Zone               # X-axis: Zone labels
fuel_data = Matrix(pivot_data[:, Not(:Zone)])  # Y-values: All fuel categories
# Ensure the number of colors matches the number of fuel categories
fuel_colors = distinguishable_colors(10)  # Adjust color list length

# Create a stacked bar chart with color coding
bar(zone_labels, 
    fuel_data,  # Stack fuel data
    label=names(pivot_data, Not(:Zone)),  # Label based on fuel categories
    title="Fuel Mix by Zone",
    xlabel="Zone", ylabel="Generation (MW)",
    legend= false,
    bar_width=0.8,
    color=fuel_colors)  # Assign colors to fuel categories

##################################################### Plotting for power sold vs bought #####################################################
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
    xlabel="Zone", ylabel="Amount ",
    xticks=(1:length(group_data_sold.Zone), group_data_sold.Zone),  # Zone labels on x-axis
    color=[:green :red], bar_width=0.8)

# Save figure
savefig(joinpath(save_dir, "Net_Market_Participation_Revenue_vs_Cost_by_Zone.png"))

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
    color=[:green :red], bar_width=0.8)

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
#------------------------------------------------------- Plotting by zone - net revenue vs cost -------------------------------------------------------#

=#