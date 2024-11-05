# Author: Gabriela Ackermann Logan, Cornell University
# Last modified: November 2024

# Import Fundtions 
include("OpenDataHydrogen.jl")

# Define Scenario 
Scenario = 0

# Define the directory where the plots will be saved
save_dir = "/Users/ga345/Desktop/Hydrogen Results/Scenario$(Scenario)"
mkpath(save_dir) # Create the directory if it doesn't exist

################################################################### Simulated Fuel Mix ##########################################################################################
function fuelmixploting(scenario)
    # Define the result path based on the scenario
    results_path = if scenario == 0
        "/Users/ga345/Desktop/NYgrid-main/Result_Baseline/2019/OPF/"
    else
        "/Users/ga345/Desktop/NYgrid-main/Result_Scenario$(scenario)/2019/OPF/"
    end

    # Filter for .mat files in the specified directory
    mat_files = filter(f -> endswith(f, ".mat"), readdir(results_path; join=true))
    
    # Initialize an empty DataFrame to store aggregated results
    all_fuel_data = DataFrame(Timestamp = DateTime[], FuelType = String[], Power = Float64[])

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
                    push!(import_power, power - demandExt)
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
            total_import_power = sum(import_power) - demandExt
            total_solar_power = sum(solar_power)
            total_wind_power = sum(wind_power)

            # Store the totals in all_fuel_data with the timestamp
            fuel_totals = DataFrame(
                Timestamp = [timestamp, timestamp, timestamp, timestamp, timestamp, timestamp],
                FuelType = ["Thermal", "Nuclear", "Hydro", "Import", "Solar", "Wind"],
                Power = [total_thermal_power, total_nuclear_power, total_hydro_power, total_import_power, total_solar_power, total_wind_power]
            )

            # Append to the main DataFrame
            append!(all_fuel_data, fuel_totals)
        end
    end

    # Add a YearMonth column for monthly grouping
    all_fuel_data.YearMonth = Dates.format.(all_fuel_data.Timestamp, "yyyy-mm")

    # Group and aggregate data by YearMonth and FuelType
    grouped_data = combine(groupby(all_fuel_data, [:YearMonth, :FuelType]), :Power => sum => :TotalPower)

    # Unstack data for plotting
    plot_data = unstack(grouped_data, :FuelType, :TotalPower)

    # Return the full data for inspection or further use
    return all_fuel_data, plot_data
end

# Call the function and retrieve both the data and the plot data
all_fuel_data, plot_data = fuelmixploting(1)

thermal_fuel = plot_data[!, "Thermal"]
nuclear = plot_data[!, "Nuclear"]
hydro = plot_data[!, "Hydro"]
#import_data = plot_data[!, "Import"]
wind_pivot = plot_data[!,"Wind"]
solar_pivot = plot_data[!,"Solar"]

groupedbar([thermal_fuel nuclear hydro wind_pivot solar_pivot],
    label= ["Dual Fuel" "Hydro" "Natural Gas" "Nuclear" "Other Fossil Fuels" "Other Renewables" "Wind"],
    bar_position = :stack,
    xlabel="Months", ylabel="Generation (MWh)",  
    xticks=(1:length(grouped_fuel.YearMonth), month_abbreviations_fuel),  # Use month abbreviations for x-axis labels
    title= "Fuel Mix Over Year",
    legend=:topright,
    rotation=45,
    color=["#648FFF" "#785EF0" "#DC267F" "#004D40" "#FE6100" ], bar_width=0.8)

# Extract x and y data from plot_data DataFrame
##x = plot_data.YearMonth
y_data = plot_data[:, Not(:YearMonth)]  # Extract all columns except YearMonth for the stacked data

# Convert y_data to a matrix for easy stacking
#y_matrix = Matrix(y_data)

# Plot stacked bar chart
#bar(x, y_matrix, label=names(plot_data)[2:end],
   # xlabel="Months", ylabel="Generation (MWh)",
   # legend=:topright, title="Fuel Mix Over Year", bar_width=0.8)

# Save the plot
savefig(joinpath(save_dir, "Simulated_FuelMix_by_Zone_Scenario$(Scenario).png"))


function PlotFuelData(scenario)
    if scenario == 0
        # Define the directory and pattern for .mat files
        results_path = "/Users/ga345/Desktop/NYgrid-main/Result_Baseline/2019/OPF/"
    else 
        # Define the directory and pattern for .mat files
        results_path = "/Users/ga345/Desktop/NYgrid-main/Result_Scenario$(Scenario)/2019/OPF/"
    end
    npcc =CSV.read("/Users/ga345/Desktop/NYgrid-main/Data/npcc.csv", DataFrame) 
    npcc = filter(row -> row[:zone] !="NA", npcc)
    bus_zonal = DataFrame(bus_id = npcc.idx, zone = npcc.zone)
    bus_to_zone = Dict(row.bus_id => row.zone for row in eachrow(bus_zonal))

    FuelMix = DataFrame(timestamp = DateTime[], zone = String[], fuel = String[], Total_Power = Float64[])  # Initialize an empty DataFrame to store all data with timestamps
    mat_files = filter(f-> endswith(f, ".mat"), readdir(results_path; join=true))

    for file_path in mat_files
        if occursin(r"resultOPF.*\.mat", file_path)  # Only process .mat files that match the pattern
            # Extract the timestamp from the filename 
            filename = basename(file_path)
            timestamp_str = match(r"\d{8}_\d{2}", filename).match  # Extract 'yyyymmdd_hh'
            timestamp = DateTime(timestamp_str, "yyyymmdd_HH")

            # Open the .mat file and read data
            file = matopen(file_path)
            data = read(file, "resultOPF")
            close(file)

            #Extract the relevant data and map zones
            gen_data = data["gen"]
            fueltype = data["genfuel"]

            df = DataFrame(bus_id = gen_data[:,1], power = gen_data[:2], fuel = fueltype[:])
            df = sort(df, :bus_id)

            #Filter and map zones based on bus_id
            matching = filter(row ->row.bus_id in bus_zonal.bus_id, df)
            matching.zone = [bus_to_zone[row.bus_id] for row in eachrow(matching)]
            
            # Group and aggregate by zone and fuel type
            grouped_matching = combine(groupby(matching,[:zone, :fuel]), :power => sum => :Total_Power)
            grouped_matching.timestamp .=timestamp
            append!(FuelMix, grouped_matching)
        end
    end

    # Convert the timestamp to a "Year-Month" string for grouping
    FuelMix[!, :YearMonth] = Dates.format.(FuelMix.timestamp, "yyyy-mm")
    FuelMix = filter(row ->row.YearMonth !="2020-01",FuelMix)
    FuelMix[!, :YearMonthDate] = Dates.Date.(FuelMix.YearMonth, "yyyy-mm") # Convert 'YearMonth' string back into a DateTime
    FuelMix[!, :YearMonthDate] = Dates.Date.(FuelMix.YearMonth, "yyyy-mm")
    FuelMix = sort(FuelMix, :YearMonth)
    month_abbreviations_fuel = Dates.format.(FuelMix.YearMonthDate, "UUU")  # Extract month abbreviations
    unique!(month_abbreviations_fuel)

    # Group the merged data by Zone and FuelCategory + sum the generation
    grouped_fuel = combine(groupby(FuelMix, [:YearMonth, :fuel]), :Total_Power => mean => :Total_GenMW) 

    # Pivot the data to make fuel categories the columns and zones the rows
    pivot_data = unstack(grouped_fuel, :fuel, :Total_GenMW)

    return pivot_data, grouped_fuel, month_abbreviations_fuel
end

#pivot_data, grouped_fuel, month_abbreviations_fuel= PlotFuelData(Scenario)

#fueltypes = names(pivot_data)[2:end]
#fuel_data = [pivot_data[!,col] for col in fueltypes]
#=
bar(fuel_data,
    label=:false,
    bar_position = :stack,
    xlabel="Months", ylabel="Generation (MWh)",  
    xticks=(1:length(grouped_fuel.YearMonth), month_abbreviations_fuel),  # Use month abbreviations for x-axis labels
    title= "Fuel Mix Over Year",
    legend=:topright,
    rotation=45,
    color=["#648FFF" "#785EF0" "#DC267F" "#004D40" "#FE6100" "#FFB000" "#994F00" "#648FFF"], bar_width=0.8) 
=#
#=
################################################################### Real Fuel Mix ##########################################################################################
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
=#
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
