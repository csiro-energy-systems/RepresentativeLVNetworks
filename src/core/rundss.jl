# function run_dss!(filename)
#     mode = "Daily"
#     dss!(filename, mode)
#     return solution()
# end

function phase_to_bus_string(bus, phases)
    bus_string = bus
    if length(phases) > 0
        for i in phases
        bus_string = bus_string*"."*string(i)
        end
    end
    return bus_string
end


function remove_solve_command(filename)
    dss_string = open(f->read(f, String), filename)
    ids = findfirst("solve", lowercase(dss_string))
    before_solve = dss_string[1:ids[1]-1]
    after_solve = length(dss_string)>ids[end] ? dss_string[ids[end]+1:end] : ""
    return before_solve, after_solve
end


function dss!(filename, mode; loadshapesP=ones(1,24), loadshapesQ=ones(1,24), useactual=true, pvsystems=[], irradiance=CSV.read(pwd()*"/../irradiance.csv", DataFrames.DataFrame, header=false)[!,:Column1], storage=[], cvr_load=[], data_path=pwd()*"/../csv_results")
    before_solve, after_solve = remove_solve_command(filename)
    
    _ODSS.dss("""  Clear  """)
    _ODSS.dss(before_solve)

    # add_loadshapes!(pwd()*"/../LoadShape2.csv")
    load_dict = load_matrix_to_dict(loadshapesP, loadshapesQ)
    add_loadshapes!(load_dict; useactual=useactual)
    
    for cvr_load_constructor in cvr_load
        cvr_load_constructor()
    end
    
    _ODSS.dss("""
        New XYCurve.VoltVarCurve npts=4  Yarray=(1,  1, -1, -1 )  Xarray=(0.5, 0.95, 1.04 1.5)
    """)
    add_irradiance(irradiance)
    pvsystem_bus_dict = Dict()
    for pvsystem_constructor in pvsystems
        pv_dict = pvsystem_constructor()
        merge!(pvsystem_bus_dict, pv_dict)
    end

    add_storage_dispatch()
    storage_bus_dict = Dict()
    for storage_constructor in storage
        storage_dict = storage_constructor()
        merge!(storage_bus_dict, storage_dict)
    end

    add_line_monitors!()
    add_load_monitors!()

    pde_name = find_Vsource_pdelement()
    _ODSS.dss("""  New Monitor.substation Element=$pde_name mode=1  """)
    _ODSS.dss("""  New Energymeter.substation Element=$pde_name   """)

    _ODSS.dss("""
        Set Mode = $mode
        Solve
        Export Monitor substation
        Set Toler=0.00000001
        // Dump Line.*  debug
        // Show Voltages LN Nodes
    """)
    _ODSS.dss(after_solve)

    @assert _ODSS.Solution.Converged() "OpenDSS failed to converge"

    _ODSS.dss(""" Set Datapath = $data_path """)
    export_line_monitors!()
    export_load_monitors!()
    export_pvsystem_monitors!()
    export_storage_monitors!("monitor_".*keys(storage_bus_dict))
    
    return pvsystem_bus_dict, storage_bus_dict
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
    U012 = inv(A)*Uabc[1:3]
    return U012
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
        n_voltageproblems4 = 0
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


            if !isnan(bus["vuf%"]) && bus["vuf%"] >=2
                @show bus["vuf%"]
                n_voltageproblems4+=1
            end
        end
        n_buses = length(data["bus"])
        println("    amount of buses: $n_buses")
        println("    amount of buses with 0 voltage: $n_voltageproblems")
        println("    amount of buses with over voltage: $n_voltageproblems2")
        println("    amount of buses with under voltage: $n_voltageproblems3")
        println("    amount of buses with excessive VUF%: $n_voltageproblems4") 
    end
end