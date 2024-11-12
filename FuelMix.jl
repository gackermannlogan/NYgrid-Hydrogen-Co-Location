# Author: Gabriela Ackermann Logan, Cornell University
# Last modified: November 2024

# Import Fundtions 
include("OpenDataHydrogen.jl")

# Define Scenario 
Scenario = 0

# Define the directory where the plots will be saved
save_dir = "/Users/ga345/Desktop/Hydrogen Results/Scenario$(Scenario)"
mkpath(save_dir) # Create the directory if it doesn't exist

# Define a seperate directory for hourly figures (for each month)
save_dir2 = "/Users/ga345/Desktop/Hydrogen Results/Scenario$(Scenario)/Hourly"
mkpath(save_dir2) # Create the directory if it doesn't exist

################################################################### Simulated Fuel Mix ##########################################################################################
function fuelmixplotting(scenario)
    # Define the result path based on the scenario
    results_path = if scenario == 0
        "/Users/ga345/Desktop/NYgrid-main/Result_Baseline/2019/OPF/"
    else
        "/Users/ga345/Desktop/NYgrid-main/Result_Scenario$(scenario)/2019/OPF/"
    end

    # Filter for .mat files in the specified directory
    mat_files = filter(f -> endswith(f, ".mat"), readdir(results_path; join=true))
    
    # Initialize an empty DataFrame to store aggregated results
    all_fuel_data = DataFrame(Timestamp = DateTime[], FuelType = String[], Power = Float64[], Demand = Float64[])

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

            # Extract the relevant data
            gen_data = data["gen"]
            fueltype = data["genfuel"]
            bus_data = data["bus"]

            # Define different types of generators
            thermalType = ["Combined Cycle", "Combustion Turbine", "Internal Combustion", "Jet Engine", "Steam Turbine"]

            # Initialize separate vectors for each fuel type
            thermal_power = Float64[]
            nuclear_power = Float64[]
            hydro_power = Float64[]
            import_power = Float64[]
            solar_power = Float64[]
            wind_power = Float64[]

            # Define external bus IDs
            busIdNE = [21, 29, 35]
            busIdIESO = [100, 102, 103]
            busIdPJM = [124, 125, 132, 134, 138]
            external_bus_ids = vcat(busIdNE, busIdIESO, busIdPJM)

            # Calculate external demand (PD column is assumed to be the third column in MATPOWER bus data)
            demandExt = sum(bus_data[i, 3] for i in 1:size(bus_data, 1) if bus_data[i, 1] in external_bus_ids)

            # Loop through each row to categorize and store power generation by fuel type
            for i in 1:size(gen_data, 1)
                fuel = fueltype[i]
                power = gen_data[i, 2]

                if fuel in thermalType
                    push!(thermal_power, power)
                elseif fuel == "Nuclear"
                    push!(nuclear_power, power)
                elseif fuel == "Hydro"
                    push!(hydro_power, power)
                elseif fuel == "Import"
                    push!(import_power, power)
                elseif addrenew && fuel == "Solar"
                    push!(solar_power, power)
                elseif addrenew && fuel == "Wind"
                    push!(wind_power, power)
                end
            end

            # Sum each vector to get total generation by fuel type
            total_thermal_power = sum(thermal_power)
            total_nuclear_power = sum(nuclear_power)
            total_hydro_power = sum(hydro_power)
            total_import_power = sum(import_power) #- demandExt
            total_solar_power = sum(solar_power)
            total_wind_power = sum(wind_power)

            # Store the totals in all_fuel_data with the timestamp
            fuel_totals = DataFrame(
                Timestamp = [timestamp, timestamp, timestamp, timestamp, timestamp, timestamp],
                FuelType = ["Thermal", "Nuclear", "Hydro", "Import", "Solar", "Wind"],
                Power = [total_thermal_power, total_nuclear_power, total_hydro_power, total_import_power, total_solar_power, total_wind_power],
                Demand = demandExt
            )

            # Append to the main DataFrame
            append!(all_fuel_data, fuel_totals)
        end
    end

    # Add a YearMonth column for monthly grouping
    all_fuel_data.YearMonth = Dates.format.(all_fuel_data.Timestamp, "yyyy-mm-dd")
    all_fuel_data[!, :YearMonth] = Dates.Date.(all_fuel_data.YearMonth, "yyyy-mm-dd")
    all_fuel_data[!, :YearMonthDate] = Dates.format.(all_fuel_data.YearMonth, "yyyy-mm")

    # Group and aggregate data by YearMonth and FuelType
    grouped_data = combine(groupby(all_fuel_data, [:YearMonthDate, :FuelType]), :Power => sum => :TotalPower)

    # Unstack data for plotting
    plot_data = unstack(grouped_data, :FuelType, :TotalPower)

    # Return the full data for inspection or further use
    return all_fuel_data, plot_data, grouped_data
end

# If the scenario is the baseline, then plot as normal, else will plot the differences
if Scenario == 0
    all_fuel_data, plot_data, grouped_fuel = fuelmixplotting(Scenario)
    month_abbreviations_fuel = Dates.format.(all_fuel_data.YearMonth, "UUU")  # Extract month abbreviations
    unique!(month_abbreviations_fuel)

    thermal_fuel = plot_data[!, "Thermal"]
    nuclear = plot_data[!, "Nuclear"]
    hydro = plot_data[!, "Hydro"]
    import_data = plot_data[!, "Import"]
    wind_pivot = plot_data[!,"Wind"]
    solar_pivot = plot_data[!,"Solar"]

    groupedbar([thermal_fuel nuclear hydro import_data wind_pivot solar_pivot],
        label= ["Thermal" "Nuclear" "Hydro" "Import" "Wind" "Solar"],
        bar_position = :stack,
        xlabel="Months", ylabel="Generation (MWh)",  
        xticks=(1:length(grouped_fuel.YearMonthDate), month_abbreviations_fuel),  # Use month abbreviations for x-axis labels
        title= "Fuel Mix Over Year",
        legend=:topright,
        rotation=45,
        color=["#648FFF" "#785EF0" "#DC267F" "#004D40" "#FE6100" "#FFB000"], bar_width=0.8)
    # Save the plot
    savefig(joinpath(save_dir, "Simulated_FuelMix_by_Zone_Scenario$(Scenario).png"))

    plot([thermal_fuel nuclear hydro import_data wind_pivot solar_pivot],
        label= ["Thermal" "Nuclear" "Hydro" "Import" "Wind" "Solar"],
        xlabel="Months", ylabel="Generation (MWh)", 
        xticks=(1:length(grouped_fuel.YearMonthDate), month_abbreviations_fuel),  # Use month abbreviations for x-axis labels
        title="Fuel Mix Over Year",
        legend=:topright, lw=2,  rotation=45,
        color=["#648FFF" "#785EF0" "#DC267F" "#004D40" "#FE6100" "#FFB000"])
    savefig(joinpath(save_dir, "FuelMix_AreaChart_Scenario$(Scenario).png"))

    fuel_matrix = hcat(thermal_fuel, nuclear, hydro, wind_pivot, solar_pivot)'

    heatmap(month_abbreviations_fuel, ["Thermal", "Nuclear", "Hydro", "Wind", "Solar"], fuel_matrix,
        xlabel="Month", ylabel="Fuel Type", 
        title="Monthly Fuel Mix Heatmap",
        color=:thermal, rotation=45)
    savefig(joinpath(save_dir, "FuelMix_Heatmap_Scenario$(Scenario).png"))
    
else 
    # Get the baseline fuel mix
    all_fuel_data_base, plot_data_base, grouped_fuel_base = fuelmixplotting(0)

    # Get the relevant scenario data 
    all_fuel_data_scenario, plot_data_scenario, grouped_fuel_scenario= fuelmixplotting(Scenario)
    plot_data = deepcopy(plot_data_scenario)
    # Calculate the difference in datasets 
    plot_data[:, Not([:YearMonthDate])] .= plot_data_base[:, Not([:YearMonthDate])] .- plot_data_scenario[:, Not([:YearMonthDate])]
    month_abbreviations_fuel = Dates.format.(all_fuel_data_scenario.YearMonth, "UUU")  # Extract month abbreviations
    unique!(month_abbreviations_fuel)

    thermal_fuel = plot_data[!, "Thermal"]
    nuclear = plot_data[!, "Nuclear"]
    hydro = plot_data[!, "Hydro"]
    import_data = plot_data[!, "Import"]
    wind_pivot = plot_data[!,"Wind"]
    solar_pivot = plot_data[!,"Solar"]

    groupedbar([thermal_fuel nuclear hydro import_data wind_pivot solar_pivot],
        label= ["Thermal" "Nuclear" "Hydro" "Import" "Wind" "Solar"],
        bar_position = :stack,
        xlabel="Months", ylabel="Generation (MWh)",  
        xticks=(1:length( grouped_fuel_base.YearMonthDate), month_abbreviations_fuel),  # Use month abbreviations for x-axis labels
        title= "Difference in Fuel Mix Over Year",
        legend=:topright,
        rotation=45,
        color=["#648FFF" "#785EF0" "#DC267F" "#004D40" "#FE6100" "#FFB000"], bar_width=0.8)
    # Save the plot
    savefig(joinpath(save_dir, "Simulated_FuelMix_by_Zone_Scenario$(Scenario).png"))   

    plot([thermal_fuel nuclear hydro wind_pivot solar_pivot],
        label= ["Thermal" "Nuclear" "Hydro" "Import" "Wind" "Solar"],
        xlabel="Months", ylabel="Generation (MWh)", 
        xticks=(1:length(grouped_fuel.YearMonthDate), month_abbreviations_fuel),  # Use month abbreviations for x-axis labels
        title="Fuel Mix Over Year",
        legend=:topright, lw=2,  rotation=45,
        color=["#648FFF" "#785EF0" "#DC267F" "#004D40" "#FE6100" "#FFB000"])
    savefig(joinpath(save_dir, "FuelMix_AreaChart_Scenario$(Scenario).png"))
    
    # Prepare data matrix for heatmap
    fuel_matrix = hcat(thermal_fuel, nuclear, hydro, wind_pivot, solar_pivot)'

    heatmap(month_abbreviations_fuel, ["Thermal", "Nuclear", "Hydro", "Wind", "Solar"], fuel_matrix,
        xlabel="Month", ylabel="Fuel Type", 
        title="Monthly Fuel Mix Heatmap",
        color=:thermal, rotation=45)
    savefig(joinpath(save_dir, "FuelMix_Heatmap_Scenario$(Scenario).png"))

end

#------------------ Plot hourly for day 7 - 12 in Janurary ------------------# 
all_fuel_data1, plot_data1, grouped_fuel1 = fuelmixplotting(Scenario)
# Want to see how this changes hourly
m = 1
# Define the start and end date for the month 
start_date2 = Date(2019, m, 1)
end_date2 = start_date2 + Month(1) - Day(1)
        
# Filter for the specific month 
Fuel_Janurary = filter(row -> row.Timestamp >= start_date2 && row.Timestamp <= end_date2, all_fuel_data1)

# Filter for just days 7 -12
start_day = 7 
end_day = 12
jan_days = filter(row -> day(row.Timestamp) >= start_day &&  day(row.Timestamp)<= end_day, Fuel_Janurary)

thermal_fuel = filter(row -> row.FuelType == "Thermal", jan_days)
nuclear_fuel = filter(row -> row.FuelType == "Nuclear", jan_days)
hydro_fuel = filter(row -> row.FuelType == "Hydro", jan_days)
import_fuel = filter(row -> row.FuelType == "Import", jan_days)
wind_fuel = filter(row -> row.FuelType == "Wind", jan_days)
solar_fuel = filter(row -> row.FuelType == "Solar", jan_days)

hourly_demand =  combine(groupby(jan_days, :Timestamp), 
    :Demand => mean => :Demand)

timestamp = thermal_fuel.Timestamp 
thermal = thermal_fuel.Power
nuclear = nuclear_fuel.Power
hydro = hydro_fuel.Power
imports = import_fuel.Power

Fuel_Mix_Jan = DataFrame(Timestamp = timestamp , Demand = hourly_demand.Demand, Thermal = thermal, Nuclear = nuclear, Hydro = hydro, Imports = imports)

groupedbar([nuclear_fuel.Power thermal_fuel.Power hydro_fuel.Power wind_fuel.Power solar_fuel.Power],
    label = ["Nuclear" "Thermal" "Hydro" "Wind" "Solar"],
    bar_position=:stack,
    xlabel="Hour", ylabel= "Generation (MW)",
    xticks = 0:24:150,
    title="Fuel Mix Hourly Scenario $(Scenario)",
    legend=:topright, rotation=45,
    color=["#785EF0" "#648FFF" "#DC267F" "#004D40" "#FE6100"], bar_width=0.8
)
# Save the plot
savefig(joinpath(save_dir2, "Simulated_FuelMix_Jan.png"))

# Plot hourly demand
bar(hourly_demand.Demand,
    label = "Demand", 
    xlabel = "Hour", ylabel = "Demand", 
    xticks = 0:24:150,
    title = "Demand Hourly",
    legend=:topright, rotation=45,bar_width=0.8
    )
savefig(joinpath(save_dir2, "Demand_Jan.png"))

################################################################### Real(data) Fuel Mix ##########################################################################################
function fuelmix(scenario)
    if scenario == 0
        resultspath2 = "/Users/ga345/Desktop/NYgrid-main/Result_Baseline/2019/OPF"
        FuelMix = OpenFuelData(resultspath2)
    else
        resultspath = "/Users/ga345/Desktop/NYgrid-main/Result_Scenario$(Scenario)/2019/OPF"
        #resultspath = "/Users/ga345/Desktop/NYgrid-main/Result/2019/OPF"
        all_data = OpenDataScenario(resultspath, Scenario)
        #resultspath2 = "/Users/ga345/Desktop/NYgrid-main/Result_Scenario$(scenario)/2019/OPF"
        FuelMix = OpenFuelDataScenario(resultspath, scenario, all_data)
    end

    # Convert the timestamp to a "Year-Month" string for grouping
    FuelMix[!, :YearMonth] = Dates.format.(FuelMix.TimeStamp, "yyyy-mm")
    FuelMix = filter(row ->row.YearMonth !="2020-01",FuelMix)
    FuelMix[!, :YearMonthDate] = Dates.Date.(FuelMix.YearMonth, "yyyy-mm") # Convert 'YearMonth' string back into a DateTime
    FuelMix[!, :YearMonthDate] = Dates.Date.(FuelMix.YearMonth, "yyyy-mm")
    FuelMix = sort(FuelMix, :YearMonth)
    month_abbreviations_fuel = Dates.format.(FuelMix.YearMonthDate, "UUU")  # Extract month abbreviations
    unique!(month_abbreviations_fuel)

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
    return pivot_data, dual_fuel, hydro, natural_gas, nuclear, other_fossil, other_renewables, wind_pivot
end
#=
pivot_data, dual_fuel, hydro, natural_gas, nuclear, other_fossil, other_renewables, wind_pivot = fuelmix(Scenario)

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
savefig(joinpath(save_dir, "Real_FuelMix_by_Zone_Scenario$(Scenario).png"))

#-------------------------------------------------------  Pie Chart for Fuel Mix per Zone-------------------------------------------------------#

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
