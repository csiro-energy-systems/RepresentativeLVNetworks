cd("/Users/get050/Documents/repositories/GitHub/RepresentativeLVNetworks")
using Pkg
Pkg.activate("./")

file = "/Users/get050/Documents/data/CD_INTERVAL_READING_ALL_NO_QUOTES.csv"
using CSV


fileres = "/Users/get050/Documents/data/Representative_Australian_Electricity_Feeders_with_load_and_solar_generation_profiles/DataRelease/AdditionalData/Generic Load Profiles from NFTS/Normalised-Residential.csv"
# using XLSX 
# x = XLSX.readxlsx(fileres)


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



results = Dict()
for (i,t) in enumerate(time) 
    data = PowerModelsDistribution.parse_file(file)
    for (l,load) in data["load"]
        load["pd_nom"].*=p_summer[i]
        load["qd_nom"].*=p_summer[i]
    end

    results[t] = solve_mc_pf(data, ACPPowerModel, solver)
end

function extract_voltages(results, data)
    n_bus = length(data["bus"])
    v = zeros(length(results), n_bus)
    for (t, timestep) in results
        for (i, bus) in timestep["solution"]["bus"]["1"]
            v[t] = bus["vm"]
        end
    end
end

vms = extract_metric(result["solution"], data)


