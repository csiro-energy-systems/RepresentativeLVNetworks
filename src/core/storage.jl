function add_storage_dispatch(;storage_file=pwd()*"/../storage_dispatch.csv")
    _ODSS.dss("""
        New Loadshape.storageShape  npts=24  interval=1 mult=(File=$storage_file)
    """)
end


function add_storage(buses, bus_phases; phases=[1,2,3], kV=0.4, kVA=5, conn="Wye", PF=1, kWrated=5, kWhrated=5, stored=50, Vminpu=0.7, Vmaxpu=1.3)
    function storage_constructor()
        storage_bus_dict = Dict()
        for bus in buses
            @assert _ODSS.Circuit.SetActiveBus(bus) != -1 "storage bus name is not in the list of buses"
            @assert !isempty(intersect(Set(bus_phases[bus]), Set(phases))) "no phases to connect the storage system to"
            phases2 = collect(intersect(Set(bus_phases[bus]), Set(phases)))
            nphases = length(phases2)
            bus_name = phase_to_bus_string(bus, phases2)
            storage_uuid = string(UUIDs.uuid1())
            storage_names = "storage_"*bus*"_"*storage_uuid
            storage_bus_dict[storage_names] = Dict()
            storage_bus_dict[storage_names]["bus"] = bus
            storage_bus_dict[storage_names]["phases"] = phases2
            storage_bus_dict[storage_names]["uuid"] = storage_uuid
            _ODSS.dss("""
                New Storage.$storage_names Bus1=$bus_name phases=$nphases kV=$kV kVA=$kVA conn=$conn PF=$PF kWrated=$kWrated kWhrated=$kWhrated %stored=$stored Vminpu=$Vminpu Vmaxpu=$Vmaxpu dispmode=follow  daily=storageShape
                New Monitor.monitor_$storage_names element=Storage.$storage_names
            """)
        end
        return storage_bus_dict
    end
    return storage_constructor
end


function export_storage_monitors!(storage_names)
    for name in storage_names
        _ODSS.dss("""
            Export Monitor $name
        """)
    end
end



function get_solution_storage(storage_bus_dict)
    storage_dict = Dict()

    for (storage_name, storage_object) in storage_bus_dict
        bus_name = storage_object["bus"]
        monitor_name = "monitor_"*storage_name
        _ODSS.Monitors.Name(monitor_name)
        monitor_file = _ODSS.Monitors.FileName()
        monitors_csv = CSV.read(monitor_file, DataFrames.DataFrame)

        storage_dict[storage_name] = Dict()
        storage_dict[storage_name]["bus"] = bus_name
        storage_dict[storage_name]["monitor_file"] = monitor_file
        storage_dict[storage_name]["hour"] = monitors_csv[!,"hour"]
        storage_dict[storage_name]["time_sec"] = monitors_csv[!," t(sec)"]
        if " I1" in DataFrames.names(monitors_csv)
            storage_dict[storage_name]["cma"] = monitors_csv[!," I1"]
        end
        if " I2" in DataFrames.names(monitors_csv)
            storage_dict[storage_name]["cmb"] = monitors_csv[!," I2"]
        end
        if " I3" in DataFrames.names(monitors_csv)
            storage_dict[storage_name]["cmc"] = monitors_csv[!," I3"]
        end
        if " I4" in DataFrames.names(monitors_csv)
            storage_dict[storage_name]["cmn"] = monitors_csv[!," I4"]
        end
        if " IAngle1" in DataFrames.names(monitors_csv)
            storage_dict[storage_name]["caa"] = monitors_csv[!," IAngle1"]
        end
        if " IAngle2" in DataFrames.names(monitors_csv)
            storage_dict[storage_name]["cab"] = monitors_csv[!," IAngle2"]
        end
        if " IAngle3" in DataFrames.names(monitors_csv)
            storage_dict[storage_name]["cac"] = monitors_csv[!," IAngle3"]
        end
        if " IAngle4" in DataFrames.names(monitors_csv)
            storage_dict[storage_name]["can"] = monitors_csv[!," IAngle4"]
        end

    end
    return storage_dict
end
