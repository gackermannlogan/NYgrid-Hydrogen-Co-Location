# Author: Gabriela Ackermann Logan, Cornell University
# Last modified: September 2024

# Import relevant packages
using DataFrames, CSV, Glob, Dates, Plots, Statistics, StatsPlots

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
    label=["Demand Not Met from Wind (MWh)" "Demand Met from Wind (MWh)"],
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

################################################################### Fuel Mix ##########################################################################################
# Define the file path and find all matching files
resultspath = "/Users/ga345/Desktop/NYgrid-main/Result/2019/OPF"
Fuel_mix_files = glob("HydrogenFuelMix_*.csv", resultspath)  # Use Glob to find only Hydrogen Results

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
all_Fuel_data.TimeStamp = String.(all_Fuel_data.TimeStamp)
all_Fuel_data[!, :TimeStamp] = Dates.DateTime.(all_Fuel_data.TimeStamp, "mm/dd/yyyy HH:MM:SS")

# Create an empty DataFrame to store the filtered results
FuelMix = DataFrame()
# Loop through each row in all_data to find the matching timestamps for when the hydrogen plant needs to buy from the windfarm
for i in 1:100
    if all_data.MWFromGrid[i] > 0 # Find when using power from the grid
        Fuel_date = all_data[i,:]
        matched_fuel_data = filter(row -> row.TimeStamp == Fuel_date.Timestamp, all_Fuel_data)

        if !isempty(matched_fuel_data)
            # Add the zone from all_data to the matched_fuel_data
            matched_fuel_data[!,:Zone] .= Fuel_date.Zone

            # Append the matched fuel data to 'FuelMix'
            append!(FuelMix, matched_fuel_data)

        else
            println("No matches found for TimeStamp: ", Fuel_date.Timestamp)
        end
    end
end

# Remove duplicates from the final FuelMix
unique!(FuelMix)

# Group the merged data by Zone and FuelCategory + sum the generation
grouped_fuelzone_data = combine(groupby(FuelMix, [:Zone, :FuelCategory]), :GenMW => mean => :Total_GenMW) 

# Pivot the data to make fuel categories the columns and zones the rows
pivot_data = unstack(grouped_fuelzone_data, :Zone, :FuelCategory, :Total_GenMW)
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
    xlabel="Zones", ylabel="Generation (MWh)",  
    xticks=(1:length(pivot_data.Zone), pivot_data.Zone),
    title= "Fuel Mix by Zone",
    legend=:topright,
    color=["#648FFF" "#785EF0" "#DC267F" "#004D40" "#FE6100" "#FFB000" "#994F00"], bar_width=0.8)

# Save the stacked bar chart
savefig(joinpath(save_dir, "FuelMix_by_Zone_Stacked_Bar.png"))

total_MW_grid = pivot_data[1, "Dual Fuel"]+ pivot_data.Hydro[1] + pivot_data[1, "Natural Gas"] + pivot_data.Nuclear[1] + pivot_data[1, "Other Fossil Fuels"] + pivot_data[1, "Other Renewables"] +pivot_data.Wind[1]

