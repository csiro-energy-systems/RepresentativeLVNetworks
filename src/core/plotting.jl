# function plot_voltage_along_feeder(eng, solution; transformer=false, vmin = 0.94*0.230, vmax = 1.1*0.230)
#     p = plot(legend=false)
#     ylabel!("Voltage magnitude P-N (kV)")
#     title!("Voltage drop along feeder by phase")
#     xlabel!("Distance from reference bus (m)")
#     colors = [:blue, :red, :black]
#     for (i,line) in solution["line"]
#         connections = min(length(eng["line"][i]["f_connections"]), length(eng["line"][i]["t_connections"]))
#         for c in 1:connections
#             f_bus = eng["line"][i]["f_bus"]
#             t_bus = eng["line"][i]["t_bus"]
#             dist_f_bus = eng["bus"][f_bus]["distance"]
#             dist_t_bus = eng["bus"][t_bus]["distance"]
#             vm_f = solution["bus"][f_bus]["vm"]
#             vm_t = solution["bus"][t_bus]["vm"]
#             plot!([dist_f_bus; dist_t_bus], [vm_f[c]; vm_t[c]], color=colors[c], marker=:circle, markersize=1)
#         end
#     end

#     if transformer
#         for (i,tf) in solution["transformer"]
#             connections = min(length(eng["transformer"][i]["connections"][1]), length(eng["transformer"][i]["connections"][2]))
#             for c in 1:connections
#                 f_bus = eng["transformer"][i]["bus"][1]
#                 t_bus = eng["transformer"][i]["bus"][2]
#                 dist_f_bus = eng["bus"][f_bus]["distance"]
#                 dist_t_bus = eng["bus"][t_bus]["distance"]
#                 vm_f = solution["bus"][f_bus]["vm"]
#                 vm_t = solution["bus"][t_bus]["vm"]
#                 plot!([dist_f_bus; dist_t_bus], [vm_f[c]; vm_t[c]], color=colors[c], marker=:circle, markersize=1)
#             end
#         end
#     end
#     maxdist = maximum([bus["distance"] for (i,bus) in eng["bus"]])
#     plot!([0; maxdist], [vmin; vmin], color=:red, linestyle=:dash)
#     plot!([0; maxdist], [vmax; vmax], color=:red, linestyle=:dash)
#     display(p)
#     return p
# end
#
# function plot_VUF_along_feeder(eng, solution; threshold_vuf_percent=2)
#     p = plot(legend=false)
#     title!("Voltage unbalance change along feeder")
#     xlabel!("Distance from reference bus (m)")
#     ylabel!("Voltage unbalance factor (%)")
#     for (i,line) in solution["line"]
#         f_bus = eng["line"][i]["f_bus"]
#         t_bus = eng["line"][i]["t_bus"]
#         dist_f_bus = eng["bus"][f_bus]["distance"]
#         dist_t_bus = eng["bus"][t_bus]["distance"]
#         vuf_f = solution["bus"][f_bus]["VUF"]
#         vuf_t = solution["bus"][t_bus]["VUF"]

#         if any(isnan.([vuf_f; vuf_t]))
#             #do nothing
#         else
#             plot!([dist_f_bus; dist_t_bus], 100*[vuf_f; vuf_t], color=:blue, marker=:circle, markersize=1)
#         end
#     end
#     maxdist = maximum([bus["distance"] for (i,bus) in eng["bus"]])
#     plot!([0; maxdist], [threshold_vuf_percent; threshold_vuf_percent], color=:red, linestyle=:dash)
#     display(p)
#     return p
# end


function get_bus_name_phases(bus_name)
    bus_split = split(bus_name, ".")
    bus = bus_split[1]
    bus_phases = parse.(Int64, bus_split[2:end])

    return (bus, bus_phases)
end

function plot_voltage_along_feeder_snap(buses_dict, lines_df; t=1, Vthreshold=1000, vmin = 0.94*230, vmax = 1.1*230)
    # plot(1:10)
    p = plot(legend=false)
    ylabel!("Voltage magnitude P-N (V)")
    title!("Voltage drop along feeder")
    xlabel!("Distance from reference bus (km)")
    colors = [:blue, :red, :black]
    for line in DataFrames.eachrow(lines_df)
        (bus1_name, bus1_phases) = get_bus_name_phases(line.Bus1)
        (bus2_name, bus2_phases) = get_bus_name_phases(line.Bus2)
        @assert length(bus1_phases) == length(bus2_phases)
        for c in 1:length(bus1_phases)
            dist_f_bus = buses_dict[bus1_name]["distance"]
            dist_t_bus = buses_dict[bus2_name]["distance"]
            phase = bus1_phases[c]
            vm_f = 1000
            vm_t = 1000
            if phase == 1
                vm_f = buses_dict[bus1_name]["vma"][t]
                vm_t = buses_dict[bus2_name]["vma"][t]
            elseif phase == 2
                vm_f = buses_dict[bus1_name]["vmb"][t]
                vm_t = buses_dict[bus2_name]["vmb"][t]
            elseif phase == 3
                vm_f = buses_dict[bus1_name]["vmc"][t]
                vm_t = buses_dict[bus2_name]["vmc"][t]
            end
            if vm_f < Vthreshold && vm_t < Vthreshold
                plot!([dist_f_bus; dist_t_bus], [vm_f; vm_t], color=colors[phase], marker=:circle, markersize=1)
            end
        end
    end

    maxdist = maximum([bus["distance"] for (i,bus) in buses_dict])
    plot!([0; maxdist], [vmin; vmin], color=:red, linestyle=:dash)
    plot!([0; maxdist], [vmax; vmax], color=:red, linestyle=:dash)
    display(p)
    return p
end


function plot_voltage_histogram_snap(buses_dict; t=1, Vthreshold=1000, vmin = 0.94*230, vmax = 1.1*230)
    colors = [:blue, :red, :black]
    phase_a = []
    phase_b = []
    phase_c = []
    for (bus_name, bus_data) in buses_dict
        if haskey(bus_data, "vma") && bus_data["vma"][t] < Vthreshold
            push!(phase_a, bus_data["vma"][t])
        end
        if haskey(bus_data, "vmb") && bus_data["vmb"][t] < Vthreshold
            push!(phase_b, bus_data["vmb"][t])
        end
        if haskey(bus_data, "vmc") && bus_data["vmc"][t] < Vthreshold
            push!(phase_c, bus_data["vmc"][t])
        end
    end

    bins = (vmin-1):0.5:(vmax+1)
    p = histogram(phase_a; bins, color=colors[1], label="phase a")
    histogram!(phase_b; bins, color=colors[2], label="phase b")
    histogram!(phase_c; bins, color=colors[3], label="phase c")
    ylabel!("Counts (-)")
    title!("Voltage histogram")
    xlabel!("Voltage magnitude (V)")

    # plot!([0; maxdist], [vmin; vmin], color=:red, linestyle=:dash)
    # plot!([0; maxdist], [vmax; vmax], color=:red, linestyle=:dash)
    display(p)
    return p
end

function plot_voltage_snap(buses_dict, lines_df; t=1, Vthreshold=1000, vmin = 0.94*230, vmax = 1.1*230)
    p1 = plot_voltage_along_feeder_snap(buses_dict, lines_df; t=t, Vthreshold=Vthreshold, vmin = vmin, vmax = vmax)
    p2 = plot_voltage_histogram_snap(buses_dict; t=t, Vthreshold=Vthreshold, vmin = vmin, vmax = vmax)
    p = plot(p1, p2, layout=(1,2))
    return p
end


function plot_voltage_boxplot(buses_dict; Vthreshold=1000, vmin = 0.94*230, vmax = 1.1*230)
    voltage_vector = []
    phase_vector = []
    bus_vector = []
    for (bus_name, bus_data) in buses_dict
        if haskey(bus_data, "vma") && all(bus_data["vma"] .< Vthreshold)
            append!(voltage_vector, bus_data["vma"])
            append!(phase_vector, ["phase a" for i=1:length(bus_data["vma"])])
            append!(bus_vector, [bus_name for i=1:length(bus_data["vma"])])
        end
        if haskey(bus_data, "vmb") && all(bus_data["vmb"] .< Vthreshold)
            append!(voltage_vector, bus_data["vmb"])
            append!(phase_vector, ["phase b" for i=1:length(bus_data["vmb"])])
            append!(bus_vector, [bus_name for i=1:length(bus_data["vmb"])])
        end
        if haskey(bus_data, "vmc") && all(bus_data["vmc"] .< Vthreshold)
            append!(voltage_vector, bus_data["vmc"])
            append!(phase_vector, ["phase c" for i=1:length(bus_data["vmc"])])
            append!(bus_vector, [bus_name for i=1:length(bus_data["vmc"])])
        end
    end
    p = groupedboxplot(bus_vector, voltage_vector, group=phase_vector, xrotation=90, bottom_margin=10mm, legend=:outertopright)

    maxdist = length(unique(bus_vector))
    plot!([0; maxdist], [vmin; vmin], color=:red, linestyle=:dash, label="Vmin")
    plot!([0; maxdist], [vmax; vmax], color=:red, linestyle=:dash, label="Vmax")

    xlabel!("Bus name (-)")
    ylabel!("Voltage magnitude (V)")
    title!("Voltage magnitudes by bus and phase")

    return p
end



function plot_substation_power()
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

    # phase_mapping = Dict(1=>"a", 2=>"b", 3=>"c")
    plt_P = plot()
    title!("Power flow through substation bus")
    ylabel!("Active power (kW)")
    plt_Q = plot()
    ylabel!("Reactive power (kvar)")
    xlabel!("Time (hour)")
    for (p, phase) in enumerate(fbus_phases)
        sm = monitors_csv[!,"S$p (kVA)"]
        sa = monitors_csv[!,"Ang$p"]
        S = sm.*exp.(im*sa./180*pi) 
        P = real.(S)
        Q = imag.(S)
        plot!(plt_P, P, label="phase $phase")
        plot!(plt_Q, Q, label=false)
    end
    plt = plot(plt_P, plt_Q, layout=(2,1))
    return plt
end


function plot_storage(storage_system)
    plt = plot()
    title!("Storage dispatch")
    xlabel!("time (h)")
    ylabel!("power (kW/kvar)")
    for p ∈ [1,2,3]
        if haskey(storage_system, "P$p")
            plot!(storage_system["P$p"], label="P$p") 
            plot!(storage_system["Q$p"], label="Q$p")
        end
    end
    return plt
end



function plot_storage_boxplot(storage_dict)
    PQ_vector = []
    phase_vector = []
    storage_vector = []
    for (storage_name, storage_data) in storage_dict
        for p ∈ [1,2,3]
            if haskey(storage_data, "P$p")
                append!(PQ_vector, storage_data["P$p"])
                append!(phase_vector, ["phase $p" for i=1:length(storage_data["P$p"])])
                append!(storage_vector, [storage_name for i=1:length(storage_data["P$p"])])
            end
        end
    end
    p = groupedboxplot(storage_vector, PQ_vector, group=phase_vector, xrotation=90, bottom_margin=10mm, legend=:outertopright)

    xlabel!("Storage name (-)")
    ylabel!("Power (kW/kvar)")
    title!("Power dispatch by storage and phase")

    return p
end

