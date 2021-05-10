function add_distances_to_buses!(data; tflength = 2)
    sourcebus = [voltage_source["bus"] for (i,voltage_source) in data["voltage_source"]]
    if length(sourcebus)>1
        @warn("taking first bus "*sourcebus[1]*" as reference bus for defining distance")
    elseif length(sourcebus)==0
        error()
    else
        sourcebus = sourcebus[1]
    end
    all_buses = Set(i for (i, bus) in data["bus"])

    buses_visited = Set()
    branches_used = Set()

    #We define distances relative to the reference bus
    data["bus"][sourcebus]["distance"] = 0
    push!(buses_visited, sourcebus)

    while all_buses!=buses_visited
        #find a branch connecting to a bus we've already visited
        candidatelines_from = [l for (l, line) in data["line"] if l ∉ branches_used && string(line["f_bus"]) in buses_visited ]
        candidatelines_to = [l for (l, line) in data["line"] if l ∉ branches_used && string(line["t_bus"]) in buses_visited ]
        
        if haskey(data, "transformer")
            candidatetransformers_from = [l for (l, tf) in data["transformer"] if l ∉ branches_used && string(tf["bus"][1]) in buses_visited ]
            candidatetransformers_to = [l for (l, tf) in data["transformer"] if l ∉ branches_used && string(tf["bus"][2]) in buses_visited ]
        else
            candidatetransformers_from = []
            candidatetransformers_to = []
        end
        
        if length(candidatelines_to)>=1
            #pick first branch
            newlineid = candidatelines_to[1]
            newline = data["line"][newlineid]
            #find the bus on the other side
            newbusid = string(newline["f_bus"])
            currentbus = string(newline["t_bus"])
            ll = newline["length"]
            push!(branches_used, newlineid)
        elseif length(candidatelines_from)>=1
            newlineid = candidatelines_from[1]
            newline = data["line"][newlineid]
            newbusid = string(newline["t_bus"])
            currentbus = string(newline["f_bus"])
            ll = newline["length"]
            push!(branches_used, newlineid)
        elseif length(candidatetransformers_to)>=1
            newtfid = candidatetransformers_to[1]
            newtf = data["transformer"][newtfid]
            newbusid = string(newtf["bus"][1])
            currentbus = string(newtf["bus"][2])
            ll = tflength
            push!(branches_used, newtfid)
        elseif length(candidatetransformers_from)>=1
            newtfid = candidatetransformers_from[1]
            newtf = data["transformer"][newtfid]
            newbusid = string(newtf["bus"][2])
            currentbus = string(newtf["bus"][1])
            ll = tflength
            push!(branches_used, newtfid)
        else
            @show buses_visited 
            @show branches_used
            @show candidatelines_from
            @show candidatelines_to
            error()
        end
        @assert ll>0
        newbus = data["bus"][string(newbusid)]
        #calculate distance and store it in the bus dict
        newbus["distance"] = data["bus"][currentbus]["distance"] + ll
        #add bus to list of buses we've found the distance for
        push!(buses_visited, newbusid)
        #avoid passing through the same branch in the future
    end
end

function add_sequence_indicators_to_buses!(eng, sol)
    a = exp(-im*2*pi/3)
    A = [1 1 1; 1 a a^2; 1 a^2 a]
    Ainv = inv(A)
    for (i,bus) in sol["bus"]
        vm = bus["vm"]
        va = bus["va"]
        vabc = vm.*exp.(im*pi*va/180)
        @show vabc
        bus["vabc"] = vabc
        if length(vm) ==3
            v012 = Ainv*vabc
            bus["v012"] = v012
            bus["v012m"] = abs.(v012)
            bus["VUF"] = abs(v012[3])/abs(v012[2])
        else
            bus["v012"] = NaN
            bus["v012m"] =NaN
            bus["VUF"] = NaN
        end
    end
end