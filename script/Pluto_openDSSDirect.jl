### A Pluto.jl notebook ###
# v0.14.5

using Markdown
using InteractiveUtils

# ╔═╡ b25c669e-b3a2-11eb-10b2-b9cd9ec17bb2
begin
	
	# using Plots
	using PlutoUI
	using DataFrames
	using RepresentativeLVNetworks
	const _RepNets = RepresentativeLVNetworks
	using OpenDSSDirect

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

	##
	path = joinpath(dirname(pathof(_RepNets)),"..","data", casename)
	cd(path)
	file = "/Master.dss"	

	mode = "Daily"
	_RepNets.dss!(path*file, mode)


	##
	transformers_df = _RepNets.transformers_to_dataframe()
	generators_df = _RepNets.generators_to_dataframe()
	capacitors_df = _RepNets.capacitors_to_dataframe()
	lines_df = _RepNets.lines_to_dataframe()
	loads_df = _RepNets.loads_to_dataframe()

	if mode == "Snap"
		buses_dict = _RepNets.bus_voltages_snap()
	elseif mode == "Daily"
		buses_dict = _RepNets.monitor_to_bus_dict()
	end

	# with_terminal() do
# 		output = DataFrames.DataFrame()
# 		output["V_bus"] = []
	
# 		for bus_name in OpenDSSDirect.Circuit.AllBusNames()
# 			OpenDSSDirect.Circuit.SetActiveBus(bus_name)
# 			V_bus[bus_name] = OpenDSSDirect.Bus.PuVoltage()
# 		end
# 		@show V_bus
	# end


end

# ╔═╡ 10bccfd4-2728-48a3-9498-fda0010b5faf
lines_df

# ╔═╡ Cell order:
# ╠═b25c669e-b3a2-11eb-10b2-b9cd9ec17bb2
# ╠═10bccfd4-2728-48a3-9498-fda0010b5faf
