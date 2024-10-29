# Author: Gabriela Ackermann Logan, Cornell University
# Last modified: October 2024

# Import relevant packages
using DataFrames, CSV, Glob, Dates, Plots, Statistics, StatsPlots

# Define Functions
function OpenData(resultspath)
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

    all_data[!, :Timestamp] = fix_timestamp.(String.(all_data.Timestamp))
    all_data[!, :Timestamp] = replace_month.(all_data.Timestamp)  # Replace month abbreviations

    # Convert the Timestamp column to datetime for easier grouping by months
    try
        all_data[!, :Timestamp] = Dates.DateTime.(all_data.Timestamp, "dd-mm-yyyy HH:MM:SS")
        println("Successfully converted all timestamps to DateTime.")
    catch e
        println("Error converting timestamps: ", e)
    end

    return all_data
end

# Define Functions
function OpenData_Scenario2(resultspath)
    all_result_files = glob("HydrogenResults_Scenario2_date*.csv", resultspath) # Use Glob to find only Hydrogen Results 

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

    all_data[!, :Timestamp] = fix_timestamp.(String.(all_data.Timestamp))
    all_data[!, :Timestamp] = replace_month.(all_data.Timestamp)  # Replace month abbreviations

    # Convert the Timestamp column to datetime for easier grouping by months
    try
        all_data[!, :Timestamp] = Dates.DateTime.(all_data.Timestamp, "dd-mm-yyyy HH:MM:SS")
        println("Successfully converted all timestamps to DateTime.")
    catch e
        println("Error converting timestamps: ", e)
    end
    
    return all_data
end

function OpenFuelData(resultspath)
    Fuel_mix_files = glob("BaslineFuelMix_*.csv", resultspath)  # Use Glob to find only Hydrogen Results
    # Create one DataFrame to store all the results for Fuel
    all_Fuel_data = DataFrame()
    for file in Fuel_mix_files
        data = CSV.read(file, DataFrame)
        append!(all_Fuel_data, data)
    end

    # Convert 'TimeStamp' in all_Fuel_data from string to DateTime
    all_Fuel_data.TimeStamp = String.(all_Fuel_data.TimeStamp)
    all_Fuel_data[!, :TimeStamp] = Dates.DateTime.(all_Fuel_data.TimeStamp, "mm/dd/yyyy HH:MM:SS")

    all_Fuel_data1 = sort(all_Fuel_data, :TimeStamp)
    all_Fuel_data= filter(row ->row.TimeStamp !="2020-01",all_Fuel_data1)

    # Create an empty DataFrame to store the filtered results
    FuelMix = DataFrame()
    # Loop through each row in all_data to find the matching timestamps for when the hydrogen plant needs to buy from the windfarm
    for i in 1:nrow(all_data)
        if all_data.MWFromGrid[i] > 0 # Find when using power from the grid
            Fuel_date = all_data[i,:]
            matched_fuel_data = filter(row -> row.TimeStamp == Fuel_date.Timestamp, all_Fuel_data)

            if !isempty(matched_fuel_data)
                # Append the matched fuel data to 'FuelMix'
                append!(FuelMix, matched_fuel_data)

            else
                println("No matches found for TimeStamp: ", Fuel_date.Timestamp)
            end
        end
    end
    # Remove duplicates from the final FuelMix
    unique!(FuelMix)
    return FuelMix
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

# Function to replace the month abbreviation with numeric value
function replace_month(ts::String)
    # Create a dictionary to map month abbreviations to numeric values
    month_mapping = Dict("Jan" => "01", "Feb" => "02", "Mar" => "03", "Apr" => "04", 
    "May" => "05", "Jun" => "06", "Jul" => "07", "Aug" => "08", 
    "Sep" => "09", "Oct" => "10", "Nov" => "11", "Dec" => "12")

    for (abbr, num) in month_mapping
        if occursin(abbr, ts)
            return replace(ts, abbr => num)
        end
    end
    return ts  # Return the timestamp if no replacement is needed
end





