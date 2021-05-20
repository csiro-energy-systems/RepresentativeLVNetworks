function to_dataframe(element)

    members = get_members(element)

    df = initialise_empty_dataframe(members)

    for i in _ODSS.EachMember(element)
        for m in members
            push!(df[!,m], element.eval(m)())
        end
    end

    return df
end


function initialise_empty_dataframe(column_names)
    df = DataFrames.DataFrame()
    for i in column_names
        df[!,i] = Any[]
    end

    return df
end



function get_members(element)
    allnames = names(element, all=true)

    filter!(x->!startswith(String(x), "#"),  allnames)
    filter!(x->!startswith(String(x), "_"),  allnames)
    filter!(x->x∉[names(element)[1], :First, :Next, :AllNames, :eval, :New, :Count, :include, :ByteStream, :Channel], allnames)
end


# function line_buses_to_dataframe(lines_df)
#     bus_fr = lines_df[!,:Bus1]
#     bus_to = lines_df[!,:Bus2]

#     bus_df = DataFrames.DataFrame()
#     uniques_buses = unique([bus_fr; bus_to])
#     bus_df[!,:Bus] = [split(uniques_buses[i], ".")[1] for i in 1:length(uniques_buses)]
#     bus_df[!,:vma] .= 0.0
#     bus_df[!,:vmb] .= 0.0
#     bus_df[!,:vmc] .= 0.0
#     bus_df[!,:vmn] .= 0.0
#     bus_df[!,:vaa] .= 0.0
#     bus_df[!,:vab] .= 0.0
#     bus_df[!,:vac] .= 0.0
#     bus_df[!,:van] .= 0.0
#     bus_df[!,:time_sec] .= 0.0

#     return bus_df
# end


# function monitor_to_bus_dataframe!(buses_df)
#     for i in _ODSS.EachMember(_ODSS.Monitors)
        
#         monitor_file = _ODSS.Monitors.FileName()
#         monitor_element = _ODSS.Monitors.Element()
#         monitors_csv = CSV.read(monitor_file, DataFrames.DataFrame)

#         line_element = _ODSS.Lines.Name(String(split(monitor_element,".")[2]))
#         bus_name = split(_ODSS.Lines.Bus1(), ".")[1]
        
#         @show bus_name
#         @show monitors_csv[!," t(sec)"]
#         buses_df[buses_df[!,:Bus].==bus_name,:time_sec] = monitors_csv[!," t(sec)"]

#         ### monitors_csv has two rows for the same t(sec), we should resolve this issue
#         buses_df[buses_df[!,:Bus].==bus_name,:vma] = monitors_csv[!," V1"][1]
#         buses_df[buses_df[!,:Bus].==bus_name,:vmb] = monitors_csv[!," V2"][1]

#     end
#     return nothing
# end



function get_solution_bus_voltage()
    bus_dict = Dict()
    for i in _ODSS.EachMember(_ODSS.Lines)
        line_name = _ODSS.Lines.Name()
        bus_name = split(_ODSS.Lines.Bus1(), ".")[1]
        
        monitor_name = "monitor_line_"*line_name
        _ODSS.Monitors.Name(monitor_name)

        monitor_file = _ODSS.Monitors.FileName()
        # monitor_element = _ODSS.Monitors.Element()
        monitors_csv = CSV.read(monitor_file, DataFrames.DataFrame)

        # _ODSS.Lines.Name(String(split(monitor_element,".")[2]))
        
        
        bus_dict[bus_name] = Dict()
        bus_dict[bus_name]["monitor_file"] = monitor_file
        bus_dict[bus_name]["hour"] = monitors_csv[!,"hour"]
        bus_dict[bus_name]["time_sec"] = monitors_csv[!," t(sec)"]
        if " V1" in DataFrames.names(monitors_csv)
            bus_dict[bus_name]["vma"] = monitors_csv[!," V1"]
        end
        if " V2" in DataFrames.names(monitors_csv)
            bus_dict[bus_name]["vmb"] = monitors_csv[!," V2"]
        end
        if " V3" in DataFrames.names(monitors_csv)
            bus_dict[bus_name]["vmc"] = monitors_csv[!," V3"]
        end
        # if " V4" in DataFrames.names(monitors_csv)
        #     bus_dict[bus_name]["vmn"] = monitors_csv[!," V4"]
        # end
        if " VAngle1" in DataFrames.names(monitors_csv)
            bus_dict[bus_name]["vaa"] = monitors_csv[!," VAngle1"]
        end
        if " VAngle2" in DataFrames.names(monitors_csv)
            bus_dict[bus_name]["vab"] = monitors_csv[!," VAngle2"]
        end
        if " VAngle3" in DataFrames.names(monitors_csv)
            bus_dict[bus_name]["vac"] = monitors_csv[!," VAngle3"]
        end
        # if " VAngle4" in DataFrames.names(monitors_csv)
        #     bus_dict[bus_name]["van"] = monitors_csv[!," VAngle4"]
        # end

    end
    return bus_dict
end



function get_solution_bus_voltage_snap()
    bus_dict = Dict()

    for bus_name in _ODSS.Circuit.AllBusNames()
        _ODSS.Circuit.SetActiveBus(bus_name)

        bus_dict[bus_name] = Dict()
        bus_dict[bus_name]["hour"] = 0
        bus_dict[bus_name]["time_sec"] = 0.0

        bus_dict[bus_name]["vma"] = [_ODSS.Bus.VMagAngle()[1]]
        bus_dict[bus_name]["vaa"] = [_ODSS.Bus.VMagAngle()[2]]

        if length(_ODSS.Bus.VMagAngle()) > 2
            bus_dict[bus_name]["vmb"] = [_ODSS.Bus.VMagAngle()[3]]
            bus_dict[bus_name]["vab"] = [_ODSS.Bus.VMagAngle()[4]]
        end
        if length(_ODSS.Bus.VMagAngle()) > 4
            bus_dict[bus_name]["vmc"] = [_ODSS.Bus.VMagAngle()[5]]
            bus_dict[bus_name]["vac"] = [_ODSS.Bus.VMagAngle()[6]]
        end
        if length(_ODSS.Bus.VMagAngle()) > 6
            bus_dict[bus_name]["vmn"] = [_ODSS.Bus.VMagAngle()[7]]
            bus_dict[bus_name]["van"] = [_ODSS.Bus.VMagAngle()[8]]
        end
    end


    return bus_dict
end





function lines_to_dataframe()
    return to_dataframe(_ODSS.Lines)
end

function transformers_to_dataframe()
    return to_dataframe(_ODSS.Transformers)
end

function generators_to_dataframe()
    return to_dataframe(_ODSS.Generators)
end

function capacitors_to_dataframe()
    return to_dataframe(_ODSS.Capacitors)
end

function loads_to_dataframe()
    return to_dataframe(_ODSS.Loads)
end

function monitors_to_dataframe()
    return to_dataframe(_ODSS.Monitors)
end