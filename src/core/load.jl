function load_matrix_to_dict(pmatrix, qmatrix)
    load_names = _ODSS.Loads.AllNames()
    load_dict = Dict()
    @assert size(pmatrix,2) >= 24
    @assert size(pmatrix) == size(qmatrix)

    n_rows = size(pmatrix,1)
    for (i,load) in enumerate(load_names)
        load_dict[load] = Dict()
        load_dict[load]["p"] = pmatrix[1+mod(i-1,n_rows),:]
        load_dict[load]["q"] = qmatrix[1+mod(i-1,n_rows),:]
    end
    return load_dict
end


function array_to_dss_string(array)
    return "[" * join(string.(array).*" ") * "]"
end


function add_loadshapes!(load_dict; useactual=true)
    for (load_name, loadshape) in load_dict
        _ODSS.Loads.Name(load_name)
        mult_loadshape = array_to_dss_string(loadshape["p"])
        Qmult_loadshape = array_to_dss_string(loadshape["q"])

        _ODSS.dss("""
            New "LoadShape.$load_name" npts=24 interval=1.0 mult=$mult_loadshape Qmult=$Qmult_loadshape UseActual=$useactual 
        """)
        _ODSS.Loads.Daily(load_name)
    end
end


function change_cvr_loads!(load_names; cvrwatts=0.4, cvrvars=2.0, Vsource_pu=1.0)
    function cvr_load_constructor()
        for load_name in load_names
            _ODSS.Loads.Name(string(load_name))
            _ODSS.Loads.CVRwatts(cvrwatts)
            _ODSS.Loads.CVRvars(cvrvars)
            _ODSS.Loads.Model(4)
        end
        _ODSS.Vsources.First()
        _ODSS.Vsources.PU(Vsource_pu)
    end
    return cvr_load_constructor
end



function add_load_monitors!()
    for i in _ODSS.EachMember(_ODSS.Loads)
        load_name =  _ODSS.Loads.Name()
        _ODSS.dss("""
            New Monitor.monitor_load_$load_name  element=Load.$load_name Mode=1
        """)
    end
end


function export_load_monitors!()
    for i in _ODSS.EachMember(_ODSS.Loads)
        load_name =  _ODSS.Loads.Name()
        _ODSS.dss("""
            Export Monitor monitor_load_$load_name
        """)
    end
end


function load_bus_mapping()
    load_bus_mapping_dict = Dict()

    for bus_name in _ODSS.Circuit.AllBusNames()
        _ODSS.Circuit.SetActiveBus(bus_name)
        for load in _ODSS.Bus.LoadList()
            if !isempty(load)
                load_name = split(load,".")[2]
                load_bus_mapping_dict[load_name] = bus_name
            end
        end
    end
    return load_bus_mapping_dict
end


function bus_phase_mapping()
    bus_phase_mapping_dict = Dict()
    for bus_name in _ODSS.Circuit.AllBusNames()
        _ODSS.Circuit.SetActiveBus(bus_name)
        bus_phase_mapping_dict[bus_name] = _ODSS.Bus.Nodes()  # this phase list in not sorted. To sort, look at Lines busname
    end
    return bus_phase_mapping_dict
end


function load_line_mapping()
    load_line_mapping_dict = Dict()
    for bus_name in _ODSS.Circuit.AllBusNames()
        _ODSS.Circuit.SetActiveBus(bus_name)
        if ~isempty(_ODSS.Bus.LoadList()) && length(_ODSS.Bus.LineList()) == 1 
            for load in _ODSS.Bus.LoadList()
                load_name = split(load,".")[2]
                load_line_mapping_dict[load_name] = Dict()

                line_name = split(_ODSS.Bus.LineList()[1],".")[2] 
                load_line_mapping_dict[load_name]["line"] = line_name
                load_line_mapping_dict[load_name]["bus"] = bus_name
            end
        end
    end
    return load_line_mapping_dict
end

function get_solution_load()
    load_dict = Dict()

    for i in _ODSS.EachMember(_ODSS.Loads)
        load_name =  _ODSS.Loads.Name()
        # bus_name =  _ODSS.Loads.Bus()
        monitor_name = "monitor_load_"*load_name
        _ODSS.Monitors.Name(monitor_name)
        monitor_file = _ODSS.Monitors.FileName()
        monitors_csv = CSV.read(monitor_file, DataFrames.DataFrame)

        load_dict[load_name] = Dict()
        # load_dict[load_name]["bus"] = bus_name
        load_dict[load_name]["monitor_file"] = monitor_file
        load_dict[load_name]["hour"] = monitors_csv[!,"hour"]
        load_dict[load_name]["time_sec"] = monitors_csv[!,"t(sec)"]
        if "S1 (kVA)" in DataFrames.names(monitors_csv)
            load_dict[load_name]["pa"] = monitors_csv[!,"S1 (kVA)"] .* cos.( pi/180*monitors_csv[!,"Ang1"])
            load_dict[load_name]["qa"] = monitors_csv[!,"S1 (kVA)"] .* sin.( pi/180*monitors_csv[!,"Ang1"])
        end
        if "S2 (kVA)" in DataFrames.names(monitors_csv)
            load_dict[load_name]["pb"] = monitors_csv[!,"S2 (kVA)"] .* cos.( pi/180*monitors_csv[!,"Ang2"])
            load_dict[load_name]["qb"] = monitors_csv[!,"S2 (kVA)"] .* sin.( pi/180*monitors_csv[!,"Ang2"])
        end
        if "S3 (kVA)" in DataFrames.names(monitors_csv)
            load_dict[load_name]["pc"] = monitors_csv[!,"S3 (kVA)"] .* cos.( pi/180*monitors_csv[!,"Ang3"])
            load_dict[load_name]["qc"] = monitors_csv[!,"S3 (kVA)"] .* sin.( pi/180*monitors_csv[!,"Ang3"])
        end
        if "S4 (kVA)" in DataFrames.names(monitors_csv)
            load_dict[load_name]["pn"] = monitors_csv[!,"S4 (kVA)"] .* cos.( pi/180*monitors_csv[!,"Ang4"])
            load_dict[load_name]["qn"] = monitors_csv[!,"S4 (kVA)"] .* sin.( pi/180*monitors_csv[!,"Ang4"])
        end
    end
    return load_dict
end
