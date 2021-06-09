function add_irradiance(irradiance)
    irradiance_data = array_to_dss_string(irradiance)
    _ODSS.dss("""
        New Loadshape.MyIrrad npts=24 interval=1.0 mult=$irradiance_data
    """)
end


function add_pvsystem(buses; phases=[1,2,3], kV=0.4, kVA=3, conn="Wye", PF=1, Pmpp=2, voltvar_control=false)
    nphases = length(phases)
    
    function pvsystem_constructor()
        pvsystem_bus_dict = Dict()
        for bus in buses
            @assert _ODSS.Circuit.SetActiveBus(bus) != -1 "PV bus name is not in the list of buses"
            bus_name = phase_to_bus_string(bus, phases)
            pv_uuid = string(UUIDs.uuid1())
            pvsystem_name = "pvsystem_"*bus*"_"*pv_uuid
            pvsystem_bus_dict[pvsystem_name] = Dict()
            pvsystem_bus_dict[pvsystem_name]["bus"] = bus
            pvsystem_bus_dict[pvsystem_name]["phases"] = phases
            pvsystem_bus_dict[pvsystem_name]["uuid"] = pv_uuid
            _ODSS.dss("""
                New PVSystem.$pvsystem_name Bus1=$bus_name phases=$nphases kV=$kV kVA=$kVA conn=$conn PF=$PF Pmpp=$Pmpp
                New Monitor.monitor_$pvsystem_name element=PVSystem.$pvsystem_name
                """)
            _ODSS.PVsystems.Daily("MyIrrad")
            if voltvar_control
                _ODSS.dss("""
                New InvControl.$pvsystem_name mode=VOLTVAR  vvc_curve1=VoltVarCurve  voltage_curvex_ref=rated
                """)
            end
        end
        return pvsystem_bus_dict
    end
    return pvsystem_constructor
end



function export_pvsystem_monitors!()
    for i in _ODSS.EachMember(_ODSS.PVsystems)
        name = _ODSS.PVsystems.Name()
        _ODSS.dss("""
            Export Monitor monitor_$name
        """)
    end
end


function get_solution_pvsystem(pvsystem_bus_dict)
    pvsystem_dict = Dict()

    for (pvsystem_name, pvsystem_object) in pvsystem_bus_dict
        bus_name = pvsystem_object["bus"]
        monitor_name = "monitor_"*pvsystem_name
        _ODSS.Monitors.Name(monitor_name)
        monitor_file = _ODSS.Monitors.FileName()
        monitors_csv = CSV.read(monitor_file, DataFrames.DataFrame)

        pvsystem_dict[pvsystem_name] = Dict()
        pvsystem_dict[pvsystem_name]["bus"] = bus_name
        pvsystem_dict[pvsystem_name]["monitor_file"] = monitor_file
        pvsystem_dict[pvsystem_name]["hour"] = monitors_csv[!,"hour"]
        pvsystem_dict[pvsystem_name]["time_sec"] = monitors_csv[!," t(sec)"]
        if " I1" in DataFrames.names(monitors_csv)
            pvsystem_dict[pvsystem_name]["cma"] = monitors_csv[!," I1"]
        end
        if " I2" in DataFrames.names(monitors_csv)
            pvsystem_dict[pvsystem_name]["cmb"] = monitors_csv[!," I2"]
        end
        if " I3" in DataFrames.names(monitors_csv)
            pvsystem_dict[pvsystem_name]["cmc"] = monitors_csv[!," I3"]
        end
        if " I4" in DataFrames.names(monitors_csv)
            pvsystem_dict[pvsystem_name]["cmn"] = monitors_csv[!," I4"]
        end
        if " IAngle1" in DataFrames.names(monitors_csv)
            pvsystem_dict[pvsystem_name]["caa"] = monitors_csv[!," IAngle1"]
        end
        if " IAngle2" in DataFrames.names(monitors_csv)
            pvsystem_dict[pvsystem_name]["cab"] = monitors_csv[!," IAngle2"]
        end
        if " IAngle3" in DataFrames.names(monitors_csv)
            pvsystem_dict[pvsystem_name]["cac"] = monitors_csv[!," IAngle3"]
        end
        if " IAngle4" in DataFrames.names(monitors_csv)
            pvsystem_dict[pvsystem_name]["can"] = monitors_csv[!," IAngle4"]
        end

    end
    return pvsystem_dict
end

