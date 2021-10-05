### A Pluto.jl notebook ###
# v0.14.5

using Markdown
using InteractiveUtils

# ╔═╡ 6b3d0da9-8a05-4bfd-9d32-4f7f9e28a19a
begin
	using Plots
	using Ipopt
	using MadNLP
	using RepresentativeLVNetworks
	using PowerModelsDistribution
	const PMD = PowerModelsDistribution

	cid = 12

	#

	case = Dict()
	case[1] = "D014470"
	case[2] = "D016907"
	case[3] = "D023544" 
	case[4] = "D026799" 
	case[5] = "D032602" 
	case[6] = "D037763" 
	case[7] = "D045978"
	case[8] = "sourcebus_11000.trafo_75615289_75615289"
	case[9] = "sourcebus_11000.trafo_75617346_75617346"
	case[10] = "sourcebus_11000.trafo_75617582_75617582"
	case[11] = "sourcebus_22000.trafo_75612178_75612178"
	case[12] = "sourcebus_22000.trafo_75612672_75612672"
	case[13] = "sourcebus_22000.trafo_75616874_75616874"
	case[14] = "sourcebus_22000.trafo_75620917_75620917"

	casename = case[cid]
	file = "../data/"*casename*"/Master.dss"

	eng = parse_file(file)
	math = transform_data_model(eng)

	result = solve_mc_opf(eng, ACPUPowerModel, MadNLP.Optimizer)
	solution = result["solution"]
	vm = Dict(i=>bus["vm"] for (i,bus) in solution["bus"])

	add_distances_to_buses!(eng)
	add_sequence_indicators_to_buses!(eng, solution)

	p1 = plot_VUF_along_feeder(eng, solution)
	p2 = plot_voltage_along_feeder(eng, solution)
end

# ╔═╡ Cell order:
# ╠═6b3d0da9-8a05-4bfd-9d32-4f7f9e28a19a
