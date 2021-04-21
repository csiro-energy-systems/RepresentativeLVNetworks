cd("/Users/get050/Documents/repositories/GitHub/RepresentativeLVNetworks")
using Pkg
Pkg.activate("./")

file = "/Users/get050/Documents/data/CD_INTERVAL_READING_ALL_NO_QUOTES.csv"
using CSV


fileres = "/Users/get050/Documents/data/Representative_Australian_Electricity_Feeders_with_load_and_solar_generation_profiles/DataRelease/AdditionalData/Generic Load Profiles from NFTS/Normalised-Residential.csv"
# using XLSX 
# x = XLSX.readxlsx(fileres)

using StatsPlots

data = CSV.File(fileres)
timesteps = 48
time = zeros(timesteps)
p_summer = zeros(timesteps)
p_winter = zeros(timesteps)
p_shoulder = zeros(timesteps)
for (i,row) in enumerate(data)
    p_summer[i] = row.Summer
    p_winter[i] = row.Winter
    p_shoulder[i] = row.Shoulder
    time[i] = row.Hour
end


using Plots
plot(time, p_summer)
plot!(time, p_winter)
plot!(time, p_shoulder)


using PowerModelsDistribution
using Ipopt
using Plots


casename = "D014470"
file = "data/"*casename*"/Master.dss"

SCALING = 10

results = Dict()
for (i,t) in enumerate(time) 
    data = PowerModelsDistribution.parse_file(file)
    for (l,load) in data["load"]
        
        load["pd_nom"].*=p_summer[i]*SCALING
        load["qd_nom"].*=p_summer[i]*SCALING
    end

    results[i] = solve_mc_pf(data, ACPPowerModel, solver)
    results[i]["time"] = t
end
##

data = PowerModelsDistribution.parse_file(file)
busmap = Dict(i=>n for (n,(i,bus)) in enumerate(data["bus"]))
busmaprev = Dict(n=>i for (i,n) in busmap)

##
function extract_voltages(results, data)
    n_bus = length(data["bus"])
    va = zeros(length(results), n_bus)
    vb = zeros(length(results), n_bus)
    vc = zeros(length(results), n_bus)
    for (t, timestep) in results
        for (i, bus) in timestep["solution"]["bus"]
            n = busmap[i]
            va[t,n] = bus["vm"][1]
            vb[t,n] = bus["vm"][2]
            vc[t,n] = bus["vm"][3]
        end
    end
    return (va, vb, vc)
end

(va,vb,vc) = extract_voltages(results, data)

##
p1 = boxplot(va, legend = false)
title!("Phase a")
# xlabel!("bus number")
ylabel!("Voltage (kV)")
plot!([0, 16], 0.230*[1.1, 1.1], linestyle = :dot, linecolor=:red)
plot!([0, 16], 0.230*[0.94, 0.94], linestyle = :dot, linecolor=:red)
p2 = boxplot(vb, legend = false)
title!("Phase b")
# xlabel!("bus number")
ylabel!("Voltage (kV)")
plot!([0, 16], 0.230*[1.1, 1.1], linestyle = :dot, linecolor=:red)
plot!([0, 16], 0.230*[0.94, 0.94], linestyle = :dot, linecolor=:red)
p3 = boxplot(vc, legend = false)
title!("Phase c")
xlabel!("Bus number (-)")
ylabel!("Voltage L-N (kV)")
plot!([0, 16], 0.230*[1.1, 1.1], linestyle = :dot, linecolor=:red)
plot!([0, 16], 0.230*[0.94, 0.94], linestyle = :dot, linecolor=:red)


p = plot(p1, p2, p3, layout = (3, 1), legend = false, size=(500,1000))
savefig(p, casename*".pdf")
