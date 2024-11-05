# Author: Gabriela Ackermann Logan, Cornell University
# Last modified: Novemeber 2024

# Import Fundtions 
include("OpenDataHydrogen.jl")
include("GroupData.jl")

using MAT, DataFrames, Dates

# Define Scenario 
Scenario = 1

# Define the directory where the plots will be saved
save_dir = "/Users/ga345/Desktop/Hydrogen Results/Scenario$(Scenario)"
mkpath(save_dir) # Create the directory if it doesn't exist

# Define a seperate directory for hourly figures (for each month)
save_dir2 = "/Users/ga345/Desktop/Hydrogen Results/Scenario$(Scenario)/Hourly"
mkpath(save_dir2) # Create the directory if it doesn't exist

if Scenario == 0 # This is the baseline scenario
    # Define the directory and pattern for .mat files
    results_path = "/Users/ga345/Desktop/NYgrid-main/Result_Baseline/2019/OPF/"
    Fuel_data = OpenBaseline(results_path)
    wind_data = filter(row -> row.fuel == "Wind", Fuel_data)
    if nrow(wind_data) > 0
        # Create the bar chart for all zones
        bar(1:length(wind_data.zone), wind_data.Total_Power,
            label="Wind Generation (MWh)",
            title= "Wind Generation Across Zones",
            xlabel= "Zones", ylabel="Power (MWh)",
            xticks=(1:length(grouped_data_windgen.Zone), grouped_data_windgen.Zone),  # Use zone names for x-axis labels
            legend = :topright,
            color="#1E88E5", bar_width=0.8)
        savefig(joinpath(save_dir, "Wind_Generation_Baseline.png"))
    end
else
    resultspath = "/Users/ga345/Desktop/NYgrid-main/Result_Scenario$(Scenario)/2019/OPF"
    all_data = OpenDataScenario(resultspath, Scenario)

    grouped_data_windgen, grouped_data_demand, sorted_data_monthly, grouped_data_wind, sorted_monthly_wind = GroupData(all_data)

    ############################################# Figure generation for Total Wind Generation #############################################
    # Create the bar chart for all zones
    bar(1:length(grouped_data_windgen.Zone), grouped_data_windgen.Total_Wind,
    label="Wind Generation (MWh)",
    title= "Wind Generation Across Zones",
    xlabel= "Zones", ylabel="Power (MWh)",
    xticks=(1:length(grouped_data_windgen.Zone), grouped_data_windgen.Zone),  # Use zone names for x-axis labels
    legend = :topright,
    color="#1E88E5", bar_width=0.8,
    ylims=(0, 400))
    savefig(joinpath(save_dir, "All_Zones_Wind_Generation.png"))

    ############################################# Figure generation for Hydrogen Demand Met #############################################
    # Create the bar chart for all zones
    bar(1:length(grouped_data_demand.Zone), [grouped_data_demand.Total_Grid grouped_data_demand.Total_Wind],
    label=["Demand Not Met from Wind (MWh)" "Demand Met from Wind (MWh)"],
    title= "Hydrogen Demand Met Across Zones",
    xlabel= "Zones", ylabel="Power (MWh)",
    xticks=(1:length(grouped_data_demand.Zone), grouped_data_demand.Zone),  # Use zone names for x-axis labels
    legend = :bottomright,
    color=["#D81B60" "#1E88E5"], bar_width=0.8, 
    ylims=(-150, 150))
    savefig(joinpath(save_dir, "All_Zones_Hydrogen_Demand.png"))

    #-----------------------------------------------  Figure generation for Hydrogen Demand Met (monthly)-----------------------------------------------#
    # Just focusing on zones D and K
    # ZONE D 
    zone_D  = filter(row -> row[:Zone] == "D", all_data)
    zone_D = sort(zone_D, :YearMonth)
    monthly_D1 = combine(groupby(zone_D, :YearMonthDate), 
                :MWFromGrid => mean => :Total_Grid, 
                :MWFromWind => mean => :Total_Wind)
    monthly_D = monthly_D1[1:12,:]
    monthly_D.Total_Grid = -monthly_D.Total_Grid # Ensure that demand is negative for plotting 

    # Convert the timestamp to a "Year-Month" string for grouping
    month_abbreviations_D = Dates.format.(monthly_D.YearMonthDate, "UUU")  # Extract month abbreviations
    unique!(month_abbreviations_D)

    #Create bar chart of Zone D
    bar([monthly_D.Total_Grid monthly_D.Total_Wind],
    label=["Demand Not Met from Wind (MWh)" "Demand Met from Wind (MWh)"],
    title= "Hydrogen Demand Met for Zone D",
    xlabel= "Month", ylabel="Power (MWh)",
    xticks= (1:length(monthly_D.YearMonthDate), month_abbreviations_D),  # Use month abbreviations for x-axis labels
    legend = :bottomright,
    rotation=45,
    color=["#D81B60" "#1E88E5"], bar_width=0.8, 
    ylims=(-150, 200))
    savefig(joinpath(save_dir, "Zone_D_Hydrogen_Demand.png"))

    #------------- Plot daily for each month to see if wind is ever dispatched -------------# 
    for m in 1:12
        # Define the start and end date for the month 
        start_date = Date(2019, m, 1)
        end_date = start_date + Month(1) - Day(1)
        
        #Filter for Zone D and the specific month 
        zone_D_month = filter(row -> row.Timestamp>= start_date && row.Timestamp <= end_date, zone_D)
        zone_D_month.MWFromGrid = - zone_D_month.MWFromGrid
        
        daily_D = combine(groupby(zone_D_month, :YearMonthDate),
                :MWFromGrid => mean => :Total_Grid, 
                :MWFromWind => mean => :Total_Wind)
        
        current_month = Dates.format.(daily_D.YearMonthDate, "UUU")
        unique!(current_month)

        #Create bar chart of Zone D for each month 
        bar([daily_D.Total_Grid daily_D.Total_Wind],
        label=["Demand Not Met from Wind (MWh)" "Demand Met from Wind (MWh)"],
        title= "Hydrogen Demand Met for Zone D for $(current_month)",
        xlabel= "Day", ylabel="Power (MW)",
        legend = :bottomright,
        rotation=45,
        color=["#D81B60" "#1E88E5"], bar_width=0.8, 
        ylims=(-150, 200))
        savefig(joinpath(save_dir2, "Zone_D_Hydrogen_Demand_Hourly_$(lpad(m,2,'0')).png"))
    end

    # ZONE K
    zone_K  = filter(row -> row[:Zone] == "K", all_data)
    zone_K = sort(zone_K, :YearMonth)
    monthly_K1 = combine(groupby(zone_K, :YearMonthDate), 
                :MWFromGrid => mean => :Total_Grid, 
                :MWFromWind => mean => :Total_Wind,
                :LMP => mean => :Total_LMP)
    monthly_K = monthly_K1[1:12,:]
    monthly_K.Total_Grid = -monthly_K.Total_Grid # Ensure that demand is negative for plotting 

    # Convert the timestamp to a "Year-Month" string for grouping
    month_abbreviations_K = Dates.format.(monthly_K.YearMonthDate, "UUU")  # Extract month abbreviations
    unique!(month_abbreviations_K)

    # Create bar chart of Zone D
    bar([monthly_K.Total_Grid monthly_K.Total_Wind],
    label=["Demand Not Met from Wind (MWh)" "Demand Met from Wind (MWh)"],
    title= "Hydrogen Demand Met for Zone K",
    xlabel= "Month", ylabel="Power (MWh)",
    xticks=(1:length(monthly_K.YearMonthDate), month_abbreviations_K),  # Use month abbreviations for x-axis labels
    legend = :bottomright,
    rotation=45,
    color=["#D81B60" "#1E88E5"], bar_width=0.8, 
    ylims=(-150, 200))
    savefig(joinpath(save_dir, "Zone_K_Hydrogen_Demand.png"))
end


