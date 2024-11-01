function GroupData(all_data)
    # Group by zone and the total generation from the wind farm 
    grouped_data_windgen = combine(groupby(all_data, :Zone),
                        :WindGen => mean => :Total_Wind)

    # Group by zone and see when demand is met from the wind farm vs when energy from the grid is needed 
    grouped_data_demand = combine(groupby(all_data, :Zone),
                        :MWFromWind => mean => :Total_Wind,
                        :MWFromGrid => mean => :Total_Grid)
    grouped_data_demand.Total_Grid = -grouped_data_demand.Total_Grid # Ensure that demand is negative for plotting 


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

    # Group by zone and see when demand is met from the wind farm vs when energy from the grid is needed 
    grouped_data_wind = combine(groupby(all_data, :Zone),
                        :MWFromWind => mean => :Wind_Used,
                        :WindGen => mean => :Total_Wind,
                        :WindpowerSold=> mean => :Excess_Wind)

    # Aggregated based on month - the chart will be power on y and month on x for the entire year 
    grouped_data_wind_monthly = combine(groupby(all_data, [:Zone, :YearMonth]),
                        :MWFromWind => mean => :Wind_Used,
                        :WindGen => mean => :Total_Wind,
                        :WindpowerSold=> mean => :Excess_Wind)
    # Sort the 'grouped_data_monthly' by YearMonth
    sorted_monthly_wind1 = sort(grouped_data_wind_monthly, :YearMonth)
    sorted_monthly_wind = filter(row ->row.YearMonth !="2020-01",sorted_monthly_wind1)

    return grouped_data_windgen, grouped_data_demand, sorted_data_monthly, grouped_data_wind, sorted_monthly_wind
end
