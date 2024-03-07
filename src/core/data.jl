function get_solution_substation_power()
    pde_name = find_Vsource_pdelement()
    _ODSS.PDElements.Name(pde_name)
    buses = _ODSS.CktElement.BusNames()
    bus1 = buses[1]
    

    pde_split = split(pde_name,".")
    if pde_split[1] == "Line"
        (_, fbus_phases) = get_bus_name_phases(bus1)
    elseif pde_split[1] == "Transformer"
        _ODSS.Circuit.SetActiveBus(bus1)
        fbus_phases = _ODSS.Bus.Nodes()
    end
    
    monitor_fbus_name = "substation"
    _ODSS.Monitors.Name(monitor_fbus_name)
    monitor_file = _ODSS.Monitors.FileName()
    monitors_csv = CSV.read(monitor_file, DataFrames.DataFrame)

    PQ_dict = Dict()
    for (p, phase) in enumerate(fbus_phases)
        sm = monitors_csv[!,"S$p (kVA)"]
        sa = monitors_csv[!,"Ang$p"]
        S = sm.*exp.(im*sa./180*pi) 
        PQ_dict["P$phase"] = real.(S)
        PQ_dict["Q$phase"] = imag.(S)
    end
    return PQ_dict
end