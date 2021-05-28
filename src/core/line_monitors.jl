function get_linenames()
    return _ODSS.Lines.AllNames()
end


function add_line_monitors!()
    for linename in get_linenames()
        _ODSS.dss("""
            New Monitor.monitor_lineT1_$linename  element=Line.$linename  Terminal=1
            New Monitor.monitor_lineT2_$linename  element=Line.$linename  Terminal=2
        """)
    end
end


function export_line_monitors!()
    for linename in get_linenames()
        _ODSS.dss("""
            Export Monitor monitor_lineT1_$linename
            Export Monitor monitor_lineT2_$linename
        """)
    end
end


function find_Vsource_pdelement()
    pde_name = ""
    for bus_name in _ODSS.Circuit.AllBusNames()
        _ODSS.Circuit.SetActiveBus(bus_name)
        for pce in _ODSS.Bus.AllPCEatBus()
            if startswith(pce, "Vsource")
                # source_bus = bus_name
                pde_name = _ODSS.Bus.AllPDEatBus()[1]
            end
        end
    end
    return pde_name
end

