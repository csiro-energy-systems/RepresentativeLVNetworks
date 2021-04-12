using Pkg
cd("/Users/get050/Documents/repositories/GitHub/RepresentativeLVNetworks")
Pkg.activate("./")

##
using PowerModelsDistribution
using Ipopt

solver = (Ipopt.Optimizer)

sols = Dict()
for (i, casename) in case
    file = "data/"*casename*"/Master.dss"
    # cd("/Users/get050/Documents/repositories/GitHub/RepresentativeLVNetworks")
    sols[casename] = run_mc_opf(file, ACPPowerModel, solver)
end

sols["D014470"]["termination_status"] == LOCALLY_SOLVED

[k for (k,v) in sols if v["termination_status"] != LOCALLY_SOLVED]