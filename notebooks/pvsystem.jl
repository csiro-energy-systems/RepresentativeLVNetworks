### A Pluto.jl notebook ###
# v0.14.7

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ 9326d206-bc46-11eb-202d-1716f033df55
begin
	using RepresentativeLVNetworks
	const _RepNets = RepresentativeLVNetworks
	using PlutoUI
	using OpenDSSDirect
	using JSON
	using Plots
	using Random

	case = Dict()

	case[1] = "A" 
	case[2] = "B" 
	case[3] = "C" 
	case[4] = "D"
	case[5] = "E"
	case[6] = "F"
	case[7] = "G"
	case[8] = "H" 
	case[9] = "I" 
	case[10] = "J"
	case[11] = "K"
	case[12] = "L"
	case[13] = "M"
	case[14] = "N"
	case[15] = "O"
	case[16] = "P"
	case[17] = "Q"
	case[18] = "R"
	case[19] = "S"
	case[20] = "T"
	case[21] = "U"
	case[22] = "V"
	case[23] = "W"
	
		case_tuples = [(string(key) => value) for (key, value) in sort(collect(case), by=x->x[1])];

end

# ╔═╡ 51cf36b1-1a0c-4514-8e74-3887718e8c4d
md"""
## Select the network file and press the button
Network: $(@bind i PlutoUI.Select(case_tuples))
$(@bind go Button("Generate Figures!"))
"""

# ╔═╡ e52daa14-1f3c-4572-924e-5d08c4972d1b
begin	
	path = joinpath(dirname(pathof(_RepNets)),"..","data/",case[parse(Int,i)])
	cd(path)
	file = "/Master.dss"
	
	_RepNets.dss!(path*file, "Snap")
# 	buses_dict_snap = _RepNets.get_solution_bus_voltage_snap()
# 	bus_names = collect(keys(buses_dict_snap))	
	
# 	loads_df_snap = _RepNets.loads_to_dataframe()
# 	load_names = loads_df_snap[!,:Name]
	
	load_bus_mapping_dict = _RepNets.load_bus_mapping()
	bus_phase_mapping_dict = _RepNets.bus_phase_mapping()
	load_names = collect(keys(load_bus_mapping_dict))
	bus_names = collect(values(load_bus_mapping_dict))
end

# ╔═╡ c40d64d4-e27e-461c-ac0c-5c0784f3b8dc
md"""
## load data
"""

# ╔═╡ 17680849-0829-4f14-9ac8-5124bed42108
md"""
load magnitude multiplier (0,10) $(@bind load_magnitude_slider PlutoUI.Slider(0:0.2:10; default=1, show_value=true))
"""

# ╔═╡ 2a20d0a2-c274-4b24-80db-38e2af330731
md"""
load angle (-pi,pi) $(@bind load_angle_slider PlutoUI.Slider(-3.1:0.1:3.1; default=0.4, show_value=true))
"""

# ╔═╡ 07da56bc-8eb3-46f4-a249-b171953c124f
begin 
	loadpath = joinpath(dirname(pathof(_RepNets)),"..","data")
	loaddata_file = loadpath*"/smartgridsmartcities.json"
	loaddata = JSON.parsefile(loaddata_file)

	loaddata_vector = [(load["p"][1:2:end] + load["p"][2:2:end])/2  for (l,load) in loaddata]
	
	loaddata_matrix = zeros(length(loaddata_vector), length(loaddata_vector[1]))
	for i=1:length(loaddata_vector)
		loaddata_matrix[i,:] = loaddata_vector[i]
	end
	
	loaddata_Pmatrix = loaddata_matrix .* load_magnitude_slider
	loaddata_Qmatrix = loaddata_Pmatrix .* tan(load_angle_slider)
	
	p_plot = plot(0:size(loaddata_Pmatrix,2)-1,loaddata_Pmatrix', legend=false, ylabel="power (kW)")
	q_plot = plot(0:size(loaddata_Qmatrix,2)-1,loaddata_Qmatrix', legend=false, xlabel="time (hour)", ylabel="power (kvar)")
	plot(p_plot, q_plot, layout=(2,1), link=:both)
end

# ╔═╡ f270f4b6-c875-4dcb-b2c9-5176713bd9f9
md"""
## pvsystem data
"""

# ╔═╡ ea3a93e3-0152-45a0-aff0-70b4131e0989
md"Number of pv buses (0, $(length(bus_names))) $(@bind n_pvbus PlutoUI.Slider(0:1:length(bus_names); default=1, show_value=true))"


# ╔═╡ a4f09d24-9f5d-4bea-8529-823f95b3b15e
md"""
random selection of pv buses? $(@bind random_pv_buses CheckBox(default=false))
"""

# ╔═╡ 66754599-3fa5-49d6-a3a2-c463b3eb40ca
md"""
phases: a $(@bind phase_a CheckBox(default=true)), b $(@bind phase_b CheckBox(default=true)), c $(@bind phase_c CheckBox(default=true))
"""

# ╔═╡ f16ac2da-e148-4854-a784-ac7e53ca0526
md"""
kVA (0, 20) $(@bind kVA PlutoUI.Slider(0:0.5:20; default=5, show_value=true))
"""

# ╔═╡ cc84c5b5-c9a4-449c-9c89-4e3abce2b625
md"""
connection (delta,wye) $(@bind conn PlutoUI.Select(["first"=>"wye", "second"=>"delta"]))
"""

# ╔═╡ 58f8f9c3-9478-4a0d-bfb6-9dc90390dda4
md"""
Select var control:
$(@bind var_control PlutoUI.Select([("constant PF" => "constant PF"), ("volt/var" => "volt/var")]))
"""

# ╔═╡ 8689056f-9135-4794-9684-da202086a979
md"""
power factor (-1,1) $(@bind PF PlutoUI.Slider(-1:0.01:1; default=0.95, show_value=true))
"""

# ╔═╡ 7cad5e72-9ee4-4583-93dc-7b00460f412d
md"""
maximum power point (0, 20) $(@bind Pmpp PlutoUI.Slider(0:0.5:20; default=5.5, show_value=true))
"""

# ╔═╡ 4da21b95-f2d7-431f-933e-b650c7e7d23d
begin
	n_buses = length(bus_names)
	
	if random_pv_buses
		pv_buses = bus_names[randperm(n_buses)][1:n_pvbus]
	else
		pv_buses = bus_names[1:n_pvbus]
	end
	
	phases = collect(1:3)[BitArray([phase_a, phase_b, phase_c])]
	@assert length(phases) > 0 
	if var_control == "constant PF"
		pvsystems = [_RepNets.add_pvsystem(pv_buses, bus_phase_mapping_dict; phases=phases, kVA=kVA, conn=conn, PF=PF, Pmpp=Pmpp, voltvar_control=false)]	
	elseif var_control == "volt/var"
		pvsystems = [_RepNets.add_pvsystem(pv_buses, bus_phase_mapping_dict; phases=phases, kVA=kVA, conn=conn, Pmpp=Pmpp, voltvar_control=true)]
	end

end

# ╔═╡ 6adcda53-28d2-4323-909b-d17612c0f772
md"""
## solve multiperiod problem
This is the multiperiod problem for the representative network.

The network does not include pv and storage systems.


We first run the model in the snapshot mode to extract load and bus names. Then the loadshapes are assigned to the multiperiod mode.
"""

# ╔═╡ 4bc59303-506c-431a-9de1-f6a76df46fdb
begin
	cd(path)
	mode = "Daily"
	
	pvsystem_bus_dict,  = _RepNets.dss!(path*file, mode; loadshapesP=loaddata_Pmatrix, loadshapesQ=loaddata_Qmatrix, useactual=true, pvsystems=pvsystems)

end


# ╔═╡ 6f56a6de-f608-46f1-9be1-b264fcffff5e
md"""
## inspect results
Extract information for all transformers, generators, capacitors, lines from OpenDSSDirect and store them in dataframes

Extract load, bus and pvsystem data to dictionaries
"""

# ╔═╡ 273753d2-ee13-4cf0-aa53-fcd02df6dd93
begin
	go
	transformers_df = _RepNets.transformers_to_dataframe()
	generators_df = _RepNets.generators_to_dataframe()
	capacitors_df = _RepNets.capacitors_to_dataframe()
	lines_df = _RepNets.lines_to_dataframe()
	
	buses_dict = _RepNets.get_solution_bus_voltage()
	load_dict = _RepNets.get_solution_load()
	pvsystem_dict = _RepNets.get_solution_pvsystem(pvsystem_bus_dict)
end

# ╔═╡ 459c2272-146c-4bb5-8d0c-9187637fb486
md"""
## Plots
"""

# ╔═╡ bbf6ab7d-66d3-4011-b033-31562d9a1d88
md"""
time step (1,24) $(@bind time_step PlutoUI.Slider(1:24; default=1, show_value=true))
"""

# ╔═╡ eeed8faa-047e-49c9-a242-6ac8bcc18530
begin 
	go
	p1 = _RepNets.plot_voltage_snap(buses_dict, lines_df; t=time_step)
end

# ╔═╡ 21a53ead-04b8-4722-b3af-ccd12e0c4f83
begin
	go
	figpath = joinpath(pwd(), "network_"*case[parse(Int,i)]*"_pvsystem_voltage_drop_time_$time_step.pdf")
	savefig(p1, figpath)
	@show "figure saved: $figpath"
end

# ╔═╡ 8456d500-939d-4604-9e89-46a3d06f5826
begin
	go
	p2 = _RepNets.plot_voltage_boxplot(buses_dict)
end

# ╔═╡ 9f7b593a-2b77-4ff7-bf02-9c11bf420fb4
begin
	go
	figpath2 = joinpath(pwd(), "network_"*case[parse(Int,i)]*"_pvsystem_voltage_bus_phase.pdf")
	savefig(p2, figpath2)
	@show "figure saved: $figpath"
end

# ╔═╡ 67171603-2d03-43b1-88a3-423cb274d9e1
begin
	go
	p3 = _RepNets.plot_substation_power()
end

# ╔═╡ 58be9758-2acd-42bf-9fc8-e84211665efb
begin
	go
	figpath3 = joinpath(pwd(), "network_"*case[parse(Int,i)]*"_pvsystem_substation_power.pdf")
	savefig(p3,figpath3)
	@show "figure saved: $figpath"
end

# ╔═╡ Cell order:
# ╟─9326d206-bc46-11eb-202d-1716f033df55
# ╟─51cf36b1-1a0c-4514-8e74-3887718e8c4d
# ╠═e52daa14-1f3c-4572-924e-5d08c4972d1b
# ╟─c40d64d4-e27e-461c-ac0c-5c0784f3b8dc
# ╟─17680849-0829-4f14-9ac8-5124bed42108
# ╟─2a20d0a2-c274-4b24-80db-38e2af330731
# ╟─07da56bc-8eb3-46f4-a249-b171953c124f
# ╟─f270f4b6-c875-4dcb-b2c9-5176713bd9f9
# ╟─ea3a93e3-0152-45a0-aff0-70b4131e0989
# ╟─a4f09d24-9f5d-4bea-8529-823f95b3b15e
# ╟─66754599-3fa5-49d6-a3a2-c463b3eb40ca
# ╟─f16ac2da-e148-4854-a784-ac7e53ca0526
# ╟─cc84c5b5-c9a4-449c-9c89-4e3abce2b625
# ╟─58f8f9c3-9478-4a0d-bfb6-9dc90390dda4
# ╟─8689056f-9135-4794-9684-da202086a979
# ╟─7cad5e72-9ee4-4583-93dc-7b00460f412d
# ╠═4da21b95-f2d7-431f-933e-b650c7e7d23d
# ╟─6adcda53-28d2-4323-909b-d17612c0f772
# ╠═4bc59303-506c-431a-9de1-f6a76df46fdb
# ╟─6f56a6de-f608-46f1-9be1-b264fcffff5e
# ╠═273753d2-ee13-4cf0-aa53-fcd02df6dd93
# ╟─459c2272-146c-4bb5-8d0c-9187637fb486
# ╟─bbf6ab7d-66d3-4011-b033-31562d9a1d88
# ╟─eeed8faa-047e-49c9-a242-6ac8bcc18530
# ╟─21a53ead-04b8-4722-b3af-ccd12e0c4f83
# ╟─8456d500-939d-4604-9e89-46a3d06f5826
# ╟─9f7b593a-2b77-4ff7-bf02-9c11bf420fb4
# ╟─67171603-2d03-43b1-88a3-423cb274d9e1
# ╟─58be9758-2acd-42bf-9fc8-e84211665efb
