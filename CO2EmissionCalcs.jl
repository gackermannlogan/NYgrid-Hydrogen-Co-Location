# Author: Gabriela Ackermann Logan, Cornell University
# Last modified: Novemeber 2024

# Import Fundtions 
include("FuelMix.jl")

# Define Scenario 
Scenario = 1

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
    mat_files = filter(f -> occursin(r"resultOPF.*\.mat", f), readdir(results_path; join=true))

    # Initialize an empty DataFrame to store aggregated results
    all_fuel_data = DataFrame(Timestamp = DateTime[], FuelType = String[], Power = Float64[])

    for file_path in mat_files
        # Extract the timestamp from the filename
        filename = basename(file_path)
        timestamp_match = match(r"(\d{8}_\d{2})", filename)
        timestamp = DateTime(timestamp_match.captures[1], "yyyymmdd_HH")

        # Open the .mat file and read data
        file = matopen(file_path)
        data = read(file, "resultOPF")
        close(file)

        # Extract generation data and fuel types
        gen_data = data["gen"]  # Assuming gen_data[2,:] contains power output
        fuel_types = data["genfuel"]  # Array of fuel types corresponding to generators

        # Create a DataFrame for the current timestep
        gen_power = gen_data[2, :]  # Power output for each generator
        df = DataFrame(Timestamp = fill(timestamp, length(fuel_types)),
                       FuelType = fuel_types,
                       Power = gen_power)

        # Append to the aggregated DataFrame
        append!(all_fuel_data, df)
    end

    # Group data by FuelType and Timestamp, sum the power
    grouped_data = combine(groupby(all_fuel_data, [:Timestamp, :FuelType]), :Power => sum => :TotalPower)

    # Pivot the DataFrame to have FuelTypes as columns
    pivot_data = unstack(grouped_data, :FuelType, :TotalPower)

    # Fill missing values with zeros
    replace!(pivot_data, missing => 0.0)

    # Now, calculate CO₂ emissions using heat rates and carbon contents
    # Heat rates (MMBtu/MWh)
    Fueltypes = ["Combined Cycle", "Combustion Turbine", "Internal Combustion", "Jet Engine", "Steam Turbine"]

end



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




