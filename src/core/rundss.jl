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
    sol["branch"] = branch_currents()
    sol["topology"] = topology()
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
        if length(U)>=3
            voltage[bus_name]["vuf%"] = 100* abs(v012[3])/abs(v012[2])
        else
            voltage[bus_name]["vuf%"] = NaN
        end
        voltage[bus_name]["nterminals"] = l/2
        
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



function branch_currents()
    branch = Dict()
    linenumber = _ODSS.PDElements.First()
    while linenumber > 0
        name = _ODSS.PDElements.Name()
        branch[name] = Dict()
        nphases = _ODSS.PDElements.AllNumPhases()[1]
        currents_fr = _ODSS.PDElements.AllCurrentsAllCurrents()[1:nphases]
        currents_to = _ODSS.PDElements.AllCurrentsAllCurrents()[nphases+1:2*nphases]
        
        branch[name]["c_fr"] = currents_fr
        branch[name]["c_to"] = currents_to

        linenumber = _ODSS.PDElements.Next()
    end
    return branch
end


function topology()
    topology = Dict()
    linenumber = _ODSS.Lines.First()
    while linenumber > 0
        name = _ODSS.Lines.Name()
        topology[name] = Dict()
        topology[name]["fbus"] = fbus = _ODSS.Lines.Bus1()
        topology[name]["tbus"] = tbus = _ODSS.Lines.Bus2()
        topology[name]["c_rated"] = normamps = _ODSS.Lines.NormAmps()
        topology[name]["length"] = l = _ODSS.Lines.Length()
        topology[name]["R0"] = l = _ODSS.Lines.R0()
        topology[name]["R1"] = l = _ODSS.Lines.R1()
        topology[name]["X0"] = l = _ODSS.Lines.X0()
        topology[name]["X1"] = l = _ODSS.Lines.X1()
        topology[name]["C0"] = l = _ODSS.Lines.C0()
        topology[name]["C1"] = l = _ODSS.Lines.C1()
        topology[name]["R"] = l = _ODSS.Lines.RMatrix()
        topology[name]["X"] = l = _ODSS.Lines.XMatrix()
        linenumber = _ODSS.Lines.Next()
    end
    return topology
end


function check_voltages(sols)
    for (j, data) in sols
        println("case $j")
        n_voltageproblems = 0
        n_voltageproblems2 = 0
        n_voltageproblems3 = 0
        for (i,bus) in data["bus"]
           
            if all(bus["vm"].>0)
                # all good
            else
                @show bus["vm"]
                n_voltageproblems+=1
            end

            if all(bus["vm"].>1.1*230)
                @show bus["vm"]
                n_voltageproblems2+=1
            end

            if all(bus["vm"].<0.9*230)
                @show bus["vm"]
                n_voltageproblems3+=1
            end
        end
        n_buses = length(data["bus"])
        println("    amount of buses: $n_buses")
        println("    amount of buses with 0 voltage: $n_voltageproblems")
        println("    amount of buses with under voltage: $n_voltageproblems2")
        println("    amount of buses with over voltage: $n_voltageproblems3")
    end
end