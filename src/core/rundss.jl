function run_dss!(filename)
    
    dss!(filename)
    
    return solution()
end


function dss!(filename)
    _ODSS.dss("""
        Clear
        compile $filename
        Solve

        Set Toler=0.00000001
        // Dump Line.*  debug
        // Show Voltages LN Nodes
    """)
end

function solution()
    (V_bus_fr, line_fr_name), (V_bus_to, line_to_name) = bus_line_info()
    return V_bus_fr, V_bus_to
end

function bus_line_info()
    # voltage at reference bus and finding line_fr_name
    bus_fr_name = "b1"
    line_fr_name = [] # line_fr_name = ["Line.line1"]
    for bus_name in _ODSS.Circuit.AllBusNames()
        _ODSS.Circuit.SetActiveBus(bus_name)
        if _ODSS.Bus.Name() == bus_fr_name
            line_fr_name = _ODSS.Bus.LineList()
        end
    end
    _ODSS.Circuit.SetActiveBus(bus_fr_name)
    V_bus_fr = _ODSS.Bus.PuVoltage()
    
    # voltage at load bus and finding line_to_name
    V_bus_to = []
    bus_to_name = []
    line_to_name = []
    for bus_name in _ODSS.Circuit.AllBusNames()
        _ODSS.Circuit.SetActiveBus(bus_name)
        if ~isempty(_ODSS.Bus.LoadList())
            bus_to_name = bus_name
            V_bus_to = _ODSS.Bus.PuVoltage()
            line_to_name = _ODSS.Bus.LineList()
        end
    end

    return (V_bus_fr, line_fr_name), (V_bus_to, line_to_name)
end


