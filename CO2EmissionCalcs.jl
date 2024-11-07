# Author: Gabriela Ackermann Logan, Cornell University
# Last modified: Novemeber 2024

# Import Fundtions 
# include("FuelMix.jl")

# Import relevant packages
using DataFrames, CSV, Glob, Dates, Plots, Statistics, StatsPlots, MAT

# Define Scenario 
Scenario = 0

# Define the directory where the plots will be saved
save_dir = "/Users/ga345/Desktop/Hydrogen Results/Scenario$(Scenario)"
mkpath(save_dir) # Create the directory if it doesn't exist

##################################################### CO₂ Emissions Calculations by Technology #####################################################
function SimulatedCO2EmissionCalc(scenario)
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
            fuel_types = data["genfuel"]

            # Create a DataFrame for the current timestep
            gen_power = gen_data[:,2]  # Power output for each generator
            df = DataFrame(FuelType = fuel_types[:], Power = gen_data[:2])
            df.Timestamp .=timestamp
            # Append to the aggregated DataFrame
            append!(all_fuel_data, df)
        end
    end

    all_fuel_data.YearMonth = Dates.format.(all_fuel_data.Timestamp, "yyyy-mm-dd")
    all_fuel_data[!, :YearMonth] = Dates.Date.(all_fuel_data.YearMonth, "yyyy-mm-dd")
    all_fuel_data[!, :YearMonthDate] = Dates.format.( all_fuel_data.YearMonth, "yyyy-mm")

    # Group and aggregate data by YearMonth and FuelType
    grouped_data = combine(groupby(all_fuel_data, [:YearMonthDate, :FuelType]), :Power => sum => :TotalPower)

    # Pivot the DataFrame to have FuelTypes as columns
    pivot_data = unstack(grouped_data, :FuelType, :TotalPower)
    
    # Fill missing values with zeros for consistent calculations
    #replace!(pivot_data, missing => 0.0)

    # Define heat rates (in MMBtu/MWh) and carbon contents (in tons CO₂/MMBtu) for each new fuel type
    heat_rates = Dict(
        "Combined Cycle" => 7.0,
        "Combustion Turbine" => 9.0,
        "Internal Combustion" => 8.0,
        "Jet Engine" => 9.0,
        "Steam Turbine" => 10.0
    )

    carbon_contents = Dict(
        "Combined Cycle" => 0.0549,
        "Combustion Turbine" => 0.0549,
        "Internal Combustion" => 0.07396,
        "Jet Engine" => 0.07222,
        "Steam Turbine" => 0.07510
    )

    # Initialize arrays to store emissions
    emissions_combined_cycle = Float64[]
    emissions_combustion_turbine = Float64[]
    emissions_internal_combustion = Float64[]
    emissions_jet_engine = Float64[]
    emissions_steam_turbine = Float64[]

    for i in 1:nrow(pivot_data)
        # Retrieve generation for each fuel type at this timestamp, using 0.0 if not present
        combined_cycle_gen = pivot_data[i, "Combined Cycle"]
        combustion_turbine_gen = pivot_data[i, "Combustion Turbine"]
        internal_combustion_gen = pivot_data[i, "Internal Combustion"]
        jet_engine_gen = pivot_data[i, "Jet Engine"]
        steam_turbine_gen = pivot_data[i, "Steam Turbine"]

        # Calculate emissions for each type
        emission_cc = combined_cycle_gen * heat_rates["Combined Cycle"] * carbon_contents["Combined Cycle"]
        emission_ct = combustion_turbine_gen * heat_rates["Combustion Turbine"] * carbon_contents["Combustion Turbine"]
        emission_ic = internal_combustion_gen * heat_rates["Internal Combustion"] * carbon_contents["Internal Combustion"]
        emission_je = jet_engine_gen * heat_rates["Jet Engine"] * carbon_contents["Jet Engine"]
        emission_st = steam_turbine_gen * heat_rates["Steam Turbine"] * carbon_contents["Steam Turbine"]

        # Append results to each array
        push!(emissions_combined_cycle, emission_cc)
        push!(emissions_combustion_turbine, emission_ct)
        push!(emissions_internal_combustion, emission_ic)
        push!(emissions_jet_engine, emission_je)
        push!(emissions_steam_turbine, emission_st)
    end

    # Add emissions to pivot_data DataFrame
    pivot_data[!, "Combined_Cycle_CO2_Emissions"] = emissions_combined_cycle
    pivot_data[!, "Combustion_Turbine_CO2_Emissions"] = emissions_combustion_turbine
    pivot_data[!, "Internal_Combustion_CO2_Emissions"] = emissions_internal_combustion
    pivot_data[!, "Jet_Engine_CO2_Emissions"] = emissions_jet_engine
    pivot_data[!, "Steam_Turbine_CO2_Emissions"] = emissions_steam_turbine
    
    return pivot_data
end

#=
if Scenario == 0
    # Calculate emissions for the baseline scenario using SimulatedCO2EmissionCalc
    simulated_emissions = SimulatedCO2EmissionCalc(Scenario)

    # Extract CO₂ emissions for each fuel type from the baseline scenario
    combined_cycle = simulated_emissions[!, "Combined_Cycle_CO2_Emissions"]
    combustion_turbine = simulated_emissions[!, "Combustion_Turbine_CO2_Emissions"]
    internal_combustion = simulated_emissions[!, "Internal_Combustion_CO2_Emissions"]
    jet_engine = simulated_emissions[!, "Jet_Engine_CO2_Emissions"]
    steam_turbine = simulated_emissions[!, "Steam_Turbine_CO2_Emissions"]

    # Plot the baseline emissions
    
    
    month_abbreviations_fuel = Dates.format.(simulated_emissions.YearMonth, "UUU")  # Extract month abbreviations  
    unique!(month_abbreviations_fuel)

    groupedbar([combined_cycle combustion_turbine internal_combustion jet_engine steam_turbine],
        label=["Combined Cycle" "Combustion Turbine" "Internal Combustion" "Jet Engine" "Steam Turbine"],
        bar_position=:stack,
        xlabel="Months",
        ylabel="CO₂ Emissions (tons)",
        xticks=(1:length(simulated_emissions.Timestamp), month_abbreviations_fuel),  # Use month abbreviations for x-axis labels
        title="CO₂ Emissions by Technology and Month (Baseline Scenario)",
        legend=:topright,
        rotation=45
    )

    # Save the plot
    savefig(joinpath(save_dir, "CO2Emissions_Baseline.png"))

else
    # Calculate emissions for both baseline and specified scenario
    simulated_emissions_baseline = SimulatedCO2EmissionCalc(0)
    simulated_emissions_scenario = SimulatedCO2EmissionCalc(Scenario)

    # Extract CO₂ emissions for each fuel type from both baseline and scenario
    combined_cycle_base = simulated_emissions_baseline[!, "Combined_Cycle_CO2_Emissions"]
    combustion_turbine_base = simulated_emissions_baseline[!, "Combustion_Turbine_CO2_Emissions"]
    internal_combustion_base = simulated_emissions_baseline[!, "Internal_Combustion_CO2_Emissions"]
    jet_engine_base = simulated_emissions_baseline[!, "Jet_Engine_CO2_Emissions"]
    steam_turbine_base = simulated_emissions_baseline[!, "Steam_Turbine_CO2_Emissions"]

    combined_cycle_scenario = simulated_emissions_scenario[!, "Combined_Cycle_CO2_Emissions"]
    combustion_turbine_scenario = simulated_emissions_scenario[!, "Combustion_Turbine_CO2_Emissions"]
    internal_combustion_scenario = simulated_emissions_scenario[!, "Internal_Combustion_CO2_Emissions"]
    jet_engine_scenario = simulated_emissions_scenario[!, "Jet_Engine_CO2_Emissions"]
    steam_turbine_scenario = simulated_emissions_scenario[!, "Steam_Turbine_CO2_Emissions"]

    # Calculate the difference in emissions between the baseline and scenario
    combined_cycle_diff = combined_cycle_scenario .- combined_cycle_base
    combustion_turbine_diff = combustion_turbine_scenario .- combustion_turbine_base
    internal_combustion_diff = internal_combustion_scenario .- internal_combustion_base
    jet_engine_diff = jet_engine_scenario .- jet_engine_base
    steam_turbine_diff = steam_turbine_scenario .- steam_turbine_base

    # Prepare data for plotting the difference
    months = simulated_emissions_scenario.Timestamp
    diff_data = [combined_cycle_diff combustion_turbine_diff internal_combustion_diff jet_engine_diff steam_turbine_diff]
    month_abbreviations_fuel = Dates.format.(simulated_emissions_scenario.YearMonth, "UUU")  # Extract month abbreviations
    unique!(month_abbreviations_fuel)

    groupedbar(
        months, diff_data,
        label=["Combined Cycle" "Combustion Turbine" "Internal Combustion" "Jet Engine" "Steam Turbine"],
        bar_position=:stack,
        xlabel="Months",
        ylabel="CO₂ Emissions Difference (tons)",
        xticks=(1:length(months), [monthname(month) for month in months]),
        title="Difference in CO₂ Emissions by Technology and Month (Scenario $(Scenario))",
        legend=:topright,
        rotation=45
    )

    # Save the plot
    savefig(joinpath(save_dir, "CO2Emissions_Difference_Scenario$(Scenario).png"))
end

=#
function RealCO2EmissionCalc(scenario)
    pivot_data, dual_fuel, hydro, natural_gas, nuclear, other_fossil, other_renewables, wind_pivot = fuelmix(scenario)
    # Extract generation data for each fuel category from pivot_data
    dual_fuel_gen = pivot_data[!, "Dual Fuel"]          # MW from Dual Fuel
    natural_gas_gen = pivot_data[!, "Natural Gas"]       # MW from Natural Gas
    other_fossil_gen = pivot_data[!, "Other Fossil Fuels"]  # MW from Other Fossil Fuels

    # Define the number of operating hours (e.g., assume 10 hours of operation or calculate from data if available)
    operating_hours = length(pivot_data.YearMonth)

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
    # CSV.write(joinpath(save_dir, "CO2_Emissions_By_Technology_Monthly.csv"), emissions_data)

    Dual_Fuel = Float64.(emissions_data[!, "Dual_Fuel_CO2_Emissions"])
    Natural_gas =  Float64.(emissions_data[!, "Natural_Gas_CO2_Emissions"])
    Other_fossil = Float64.(emissions_data[!,"Other_Fossil_CO2_Emissions"])
    return Dual_Fuel, Natural_gas, Other_fossil
end


#=
if Scenario == 0
    Dual_Fuel, Natural_gas, Other_fossil = RealCO2EmissionCalc(Scenario)
else
    Dual_FuelBase, Natural_gasBase, Other_fossilBase = RealCO2EmissionCalc(baseline)
    Dual_Fuel_scenario, Natural_gas_scenario, Other_fossil_scenario = RealCO2EmissionCalc(Scenario)

    # Calculate the difference in CO2 Emissions
    Dual_Fuel = Dual_FuelBase - Dual_Fuel_scenario
    Natural_gas = Natural_gasBase - Natural_gas_scenario
    Other_fossil = Other_fossilBase - Other_fossil_scenario

    groupedbar([Dual_Fuel  Natural_gas Other_fossil ],
        label= ["Dual Fuel" "Natural Gas" "Other Fossil Fuels"],
        bar_position = :stack,
        xlabel="Months", ylabel="CO₂ Emissions(tons)",  
        xticks=(1:length(emissions_data.Month), month_abbreviations_fuel),  # Use month abbreviations for x-axis labels
        title= "CO₂ Emissions by Technology and Month (tons)",
        legend=:topright,
        rotation=45,
        color=["#648FFF" "#785EF0" "#DC267F" "#004D40" "#FE6100" "#FFB000" "#994F00"], bar_width=0.8)

    # Save the stacked bar chart
    savefig(joinpath(save_dir, "Co2Emissions_Scenario$(Scenario).png"))
end
=#





