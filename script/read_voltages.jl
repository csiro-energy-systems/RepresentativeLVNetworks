using Pkg
# cd("/Users/get050/Documents/repositories/GitHub/RepresentativeLVNetworks/script/")
Pkg.activate("./script")

# using Plots
# using Ipopt
# using MadNLP
using CSV
using DataFrames
using RepresentativeLVNetworks
const _RepNets = RepresentativeLVNetworks
# using PowerModelsDistribution
# const PMD = PowerModelsDistribution

cid = 12

#

case = Dict()
case[1] = "D014470"
case[2] = "D016907"
case[3] = "D023544" #segfault
case[4] = "D026799" #segfault
case[5] = "D032602" #segfault
case[6] = "D037763" #segfault
case[7] = "D045978"
case[8] = "sourcebus_11000.trafo_75615289_75615289"
case[9] = "sourcebus_11000.trafo_75617346_75617346"
case[10] = "sourcebus_11000.trafo_75617582_75617582"
case[11] = "sourcebus_22000.trafo_75612178_75612178"
case[12] = "sourcebus_22000.trafo_75612672_75612672"
case[13] = "sourcebus_22000.trafo_75616874_75616874"
case[14] = "sourcebus_22000.trafo_75620917_75620917"

casename = case[cid]

##
path = joinpath(dirname(pathof(_RepNets)),"..","data", casename)
cd(path)
file = "/Master.dss"

##
mode = "Snap"
pvsystem_bus_dict, storage_bus_dict = _RepNets.dss!(path*file, mode)
buses_dict = _RepNets.get_solution_bus_voltage_snap()
loads_df = _RepNets.loads_to_dataframe()



##
mode = "Daily"
load_names = loads_df[!,:Name]
bus_names = collect(keys(buses_dict))
pvsystems = [_RepNets.add_pvsystem(bus_names[1:10]); _RepNets.add_pvsystem(bus_names[11:20]; kVA=10, phases=[1,2])]
storage = [_RepNets.add_storage(bus_names[1:10]); _RepNets.add_storage(bus_names[21:30]; kWrated=10, phases=[1])]
_RepNets.change_cvr_loads!(load_names[1:20]; cvrwatts=0.4, cvrvars=2.0)
cd(path)
pvsystem_bus_dict, storage_bus_dict = _RepNets.dss!(path*file, mode; loadshapesP=rand(3,24), loadshapesQ=rand(3,24), useactual=true, pvsystems=pvsystems, storage=storage)



##
transformers_df = _RepNets.transformers_to_dataframe()
generators_df = _RepNets.generators_to_dataframe()
capacitors_df = _RepNets.capacitors_to_dataframe()
lines_df = _RepNets.lines_to_dataframe()
# loads_df = _RepNets.loads_to_dataframe()

if mode == "Snap"
    buses_dict = _RepNets.get_solution_bus_voltage_snap()
elseif mode == "Daily"
    buses_dict = _RepNets.get_solution_bus_voltage()
    load_dict = _RepNets.get_solution_load()
    pvsystem_dict = _RepNets.get_solution_pvsystem(pvsystem_bus_dict)
    storage_dict = _RepNets.get_solution_storage(storage_bus_dict)
end