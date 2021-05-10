function plot_voltage_along_feeder(eng, solution; transformer=false, vmin = 0.94*0.230, vmax = 1.1*0.230)
    p = plot(legend=false)
    ylabel!("Voltage magnitude P-N (kV)")
    title!("Voltage drop along feeder by phase")
    xlabel!("Distance from reference bus (m)")
    colors = [:blue, :red, :black]
    for (i,line) in solution["line"]
        connections = min(length(eng["line"][i]["f_connections"]), length(eng["line"][i]["t_connections"]))
        for c in 1:connections
            f_bus = eng["line"][i]["f_bus"]
            t_bus = eng["line"][i]["t_bus"]
            dist_f_bus = eng["bus"][f_bus]["distance"]
            dist_t_bus = eng["bus"][t_bus]["distance"]
            vm_f = solution["bus"][f_bus]["vm"]
            vm_t = solution["bus"][t_bus]["vm"]
            plot!([dist_f_bus; dist_t_bus], [vm_f[c]; vm_t[c]], color=colors[c], marker=:circle, markersize=1)
        end
    end

    if transformer
        for (i,tf) in solution["transformer"]
            connections = min(length(eng["transformer"][i]["connections"][1]), length(eng["transformer"][i]["connections"][2]))
            for c in 1:connections
                f_bus = eng["transformer"][i]["bus"][1]
                t_bus = eng["transformer"][i]["bus"][2]
                dist_f_bus = eng["bus"][f_bus]["distance"]
                dist_t_bus = eng["bus"][t_bus]["distance"]
                vm_f = solution["bus"][f_bus]["vm"]
                vm_t = solution["bus"][t_bus]["vm"]
                plot!([dist_f_bus; dist_t_bus], [vm_f[c]; vm_t[c]], color=colors[c], marker=:circle, markersize=1)
            end
        end
    end
    maxdist = maximum([bus["distance"] for (i,bus) in eng["bus"]])
    plot!([0; maxdist], [vmin; vmin], color=:red, linestyle=:dash)
    plot!([0; maxdist], [vmax; vmax], color=:red, linestyle=:dash)
    display(p)
    return p
end
#
function plot_VUF_along_feeder(eng, solution; threshold_vuf_percent=2)
    p = plot(legend=false)
    title!("Voltage unbalance change along feeder")
    xlabel!("Distance from reference bus (m)")
    ylabel!("Voltage unbalance factor (%)")
    for (i,line) in solution["line"]
        f_bus = eng["line"][i]["f_bus"]
        t_bus = eng["line"][i]["t_bus"]
        dist_f_bus = eng["bus"][f_bus]["distance"]
        dist_t_bus = eng["bus"][t_bus]["distance"]
        vuf_f = solution["bus"][f_bus]["VUF"]
        vuf_t = solution["bus"][t_bus]["VUF"]

        if any(isnan.([vuf_f; vuf_t]))
            #do nothing
        else
            plot!([dist_f_bus; dist_t_bus], 100*[vuf_f; vuf_t], color=:blue, marker=:circle, markersize=1)
        end
    end
    maxdist = maximum([bus["distance"] for (i,bus) in eng["bus"]])
    plot!([0; maxdist], [threshold_vuf_percent; threshold_vuf_percent], color=:red, linestyle=:dash)
    display(p)
    return p
end