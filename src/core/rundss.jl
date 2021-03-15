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
    sol = Dict()
    sol["bus"] = bus_voltages()
    return sol
end

function bus_voltages()
    voltage = Dict()
    for bus_name in _ODSS.Circuit.AllBusNames()
        _ODSS.Circuit.SetActiveBus(bus_name)

        Umagang = _ODSS.Bus.VMagAngle()
        l = length(Umagang)
        Umag = Umagang[1:2:l]
        Uang = Umagang[2:2:l]*pi/180 #radians
        U = Umag .* exp.(im*Uang)
        voltage[bus_name] = Dict()
        voltage[bus_name]["v"] = U
        voltage[bus_name]["vm"] = abs.(U)
        voltage[bus_name]["va"] = angle.(U)
        voltage[bus_name]["v012"] = v012 = safe_calc_v012(U)
        voltage[bus_name]["vuf%"] = 100* abs(v012[3])/abs(v012[2])
    end
    return voltage
end


function safe_calc_v012(U)
    if length(U)>=3
        return calc_v012(U[1:3])
    else
        return NaN
    end
end

function calc_v012(Uabc)
    α = exp(im*2*pi/3)
    A = [   1 1 1;
            1 α^2 α;
            1 α α^2;
        ]
    U012 = A*Uabc[1:3]
end


