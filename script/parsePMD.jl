using Pkg
cd("/Users/get050/Documents/repositories/GitHub/RepresentativeLVNetworks")
Pkg.activate("./")

##
using PowerModelsDistribution
using Ipopt
using Plots

solver = (Ipopt.Optimizer)

sols = Dict()
for (i, casename) in case
    file = "data/"*casename*"/Master.dss"
    # cd("/Users/get050/Documents/repositories/GitHub/RepresentativeLVNetworks")
    data = PowerModelsDistribution.parse_file(file)


    if i == 10  # sourcebus_11000.trafo_75617582_75617582
        for (l,load) in data["load"]
            load["pd_nom"] /= 3.235
            load["qd_nom"] /= 3.235
        end
    end

    if i == 11 # sourcebus_22000.trafo_75612178_75612178
        # for (l,load) in data["load"]
        #     load["pd_nom"] /= 1.924
        #     load["qd_nom"] /= 1.924
        # end
    else
        sols[casename] = solve_mc_opf(data, ACPPowerModel, solver)
    end
end

sols["D014470"]["termination_status"] == LOCALLY_SOLVED

r = Dict(k=>v["termination_status"] for (k,v) in sols if v["termination_status"] != LOCALLY_SOLVED)




##
s = sols[case[9]]["solution"] 
# vms = [bus["vm"] for (i,bus) in s["bus"]]
vmsa = [bus["vm"][1] for (i,bus) in s["bus"]]
vmsb = [bus["vm"][2] for (i,bus) in s["bus"]]
vmsc = [bus["vm"][3] for (i,bus) in s["bus"]]

plot(vmsa)
plot!(vmsb)
plot!(vmsc)
