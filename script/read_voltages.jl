# using Pkg
# cd("/Users/get050/Documents/repositories/GitHub/RepresentativeLVNetworks/script/")
# Pkg.activate("./script")
cd("/Users/get050/Documents/repositories/GitHub/RepresentativeLVNetworks")
using Pkg
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

cid = 1

#

case = Dict()
case[1] = "A" 


casename = case[cid]

##
data_path = joinpath(dirname(pathof(_RepNets)),"..","data")
case_path = joinpath(dirname(pathof(_RepNets)),"..","data", casename)

cd(case_path)
file = "/Master.dss"

mode = "Snap"
pvsystem_bus_dict, storage_bus_dict = _RepNets.dss!(case_path*file, mode)
buses_dict = _RepNets.get_solution_bus_voltage_snap()
loads_df = _RepNets.loads_to_dataframe()
lines_df = _RepNets.lines_to_dataframe()

# _RepNets.plot_voltage_along_feeder_snap(buses_dict, lines_df)
# _RepNets.plot_voltage_histogram_snap(buses_dict)
# _RepNets.plot_voltage_snap(buses_dict, lines_df)
# _RepNets.plot_voltage_boxplot(buses_dict)

##
cd(case_path)
mode = "Daily"
load_names = loads_df[!,:Name]
bus_names = collect(keys(buses_dict))
irradiance = CSV.read(data_path*"/irradiance.csv", DataFrame, header=false)[!,:Column1]
pvsystems = [_RepNets.add_pvsystem(["156"])]
# pvsystems = [_RepNets.add_pvsystem(bus_names[1:5]); _RepNets.add_pvsystem(bus_names[6:10]; kVA=10, phases=[1,2])]
# storage = [_RepNets.add_storage(bus_names[1:5]); _RepNets.add_storage(bus_names[10:15]; kWrated=10, phases=[1])]
# _RepNets.change_cvr_loads!(load_names[1:4]; cvrwatts=0.4, cvrvars=2.0)
# pvsystem_bus_dict, storage_bus_dict = _RepNets.dss!(path*file, mode; loadshapesP=100*rand(3,24), loadshapesQ=100*rand(3,24), useactual=false, pvsystems=pvsystems, storage=storage)
pvsystem_bus_dict, _ = _RepNets.dss!(case_path*file, mode; loadshapesP=1*rand(3,24), loadshapesQ=1*rand(3,24), useactual=true, pvsystems=pvsystems, irradiance=irradiance)
# _RepNets.dss!(path*file, mode; loadshapesP=rand(3,24), loadshapesQ=rand(3,24), useactual=true)


##
transformers_df = _RepNets.transformers_to_dataframe()
generators_df = _RepNets.generators_to_dataframe()
capacitors_df = _RepNets.capacitors_to_dataframe()
lines_df = _RepNets.lines_to_dataframe()
# loads_df = _RepNets.loads_to_dataframe()

buses_dict = _RepNets.get_solution_bus_voltage()
load_dict = _RepNets.get_solution_load()
# pvsystem_dict = _RepNets.get_solution_pvsystem(pvsystem_bus_dict)
# storage_dict = _RepNets.get_solution_storage(storage_bus_dict)


# _RepNets.plot_voltage_along_feeder_snap(buses_dict, lines_df, t=20)
# _RepNets.plot_voltage_histogram_snap(buses_dict, t=20)
# _RepNets.plot_voltage_snap(buses_dict, lines_df, t=4)
# _RepNets.plot_voltage_boxplot(buses_dict)
_RepNets.plot_substation_power()
_RepNets.find_Vsource_pdelement()
