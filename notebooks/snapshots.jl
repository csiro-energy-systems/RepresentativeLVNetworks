### A Pluto.jl notebook ###
# v0.14.5

using Markdown
using InteractiveUtils

# ╔═╡ d663dc4c-b926-11eb-1760-6d7e227eebd3
begin

	# using RepresentativeLVNetworks
	import RepresentativeLVNetworks
	const _RepNets = RepresentativeLVNetworks

	using OpenDSSDirect

	case = Dict()

	case[1] = "D003278" 
	case[2] = "D009819"
	case[3] = "D014683"
	case[4] = "D023303" 
	case[5] = "D037984" 
	case[6] = "D047205"
	case[7] = "D049759" 
	case[8] = "D052609" 
	case[9] = "D058461" 
	case[10] = "sourcebus_11000.118_744"
	case[11] = "sourcebus_11000.130_1438"
	case[12] = "sourcebus_11000.trafo_75585177_75585177"
	case[13] = "sourcebus_11000.trafo_75588995_75588995"
	case[14] = "sourcebus_11000.trafo_75589759_75589759"
	case[15] = "sourcebus_11000.trafo_75592323_75592323"
	case[16] = "sourcebus_11000.trafo_75604448_75604448"
	case[17] = "sourcebus_11000.trafo_75615289_75615289"
	case[18] = "sourcebus_11000.trafo_75617346_75617346"
	case[19] = "sourcebus_22000.trafo_75612682_75612682"
	case[20] = "sourcebus_22000.trafo_75618991_75618991"
	case[21] = "sourcebus_22000.trafo_75621868_75621868"
	case[22] = "sourcebus_22000.trafo_75628143_75628143"
	case[23] = "sourcebus_22000.trafo_75628932_75628932"

	i = 9
	
	path = joinpath(dirname(pathof(_RepNets)),"..","data/",case[i])
	cd(path)
	file = "/Master.dss"
	
	
	# getproperty(_RepNets, )
	# typeof(_RepNets)
	 # mode = "Snap"
	# _RepNets.dss!(path*file, mode)
	
end

# ╔═╡ 78e32c08-a45b-41f0-8858-b9919b94cdc9
md"""
# solve snapshot problem
This is the single period problem for the representative network.

The network does not include pv and storage systems.

The network data includes snapshot load data.
"""

# ╔═╡ e72d955a-0658-4cab-9071-14996a3c1ceb
begin
	cd(path)
	
	mode = "Snap"
	_RepNets.dss!(path*file, mode)	
	
end

# ╔═╡ c0f3f3c0-d528-4bbf-822f-ea47eba174bd
md"""
# inspect results
bus voltages, 

discuss data frames + column names
plot some simple things
"""

# ╔═╡ 29debbaa-1aa8-47f0-b0df-ab9e58703575
begin
	buses_dict = _RepNets.get_solution_bus_voltage_snap()
	loads_df = _RepNets.loads_to_dataframe()
	transformers_df = _RepNets.transformers_to_dataframe()
	generators_df = _RepNets.generators_to_dataframe()
	capacitors_df = _RepNets.capacitors_to_dataframe()
	lines_df = _RepNets.lines_to_dataframe()
	
	names(loads_df)
	
	@show buses_dict
end

# ╔═╡ f0bf97fd-4630-4fc1-8df1-5625925da248
begin 
	using Plots
	bus_voltages = [v["vma"] for (bus, v) in buses_dict]
	scatter(1:length(bus_voltages), bus_voltages)
end

# ╔═╡ 247aa5cd-c59d-4391-a395-badef95d1d44
md"""
## Plotting"""

# ╔═╡ Cell order:
# ╠═d663dc4c-b926-11eb-1760-6d7e227eebd3
# ╟─78e32c08-a45b-41f0-8858-b9919b94cdc9
# ╠═e72d955a-0658-4cab-9071-14996a3c1ceb
# ╟─c0f3f3c0-d528-4bbf-822f-ea47eba174bd
# ╠═29debbaa-1aa8-47f0-b0df-ab9e58703575
# ╟─247aa5cd-c59d-4391-a395-badef95d1d44
# ╠═f0bf97fd-4630-4fc1-8df1-5625925da248
