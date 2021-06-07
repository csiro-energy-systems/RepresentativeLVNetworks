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

# ╔═╡ b3a3a1e6-bc30-11eb-0277-7958bfc44407
begin
	using RepresentativeLVNetworks
	const _RepNets = RepresentativeLVNetworks
	using PlutoUI
	using OpenDSSDirect
	using JSON
	using Plots

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

# ╔═╡ 6f43db92-3968-4bb0-9198-d7c7f208d0f5
md"""
## Select the network file
Network: $(@bind i PlutoUI.Select(case_tuples))
"""

# ╔═╡ ab3df566-1373-42d3-9eab-34757f28c359
begin	
	path = joinpath(dirname(pathof(_RepNets)),"..","data/",case[parse(Int,i)])
	cd(path)
	file = "/Master.dss"
	
	_RepNets.dss!(path*file, "Snap")
	buses_dict_snap = _RepNets.get_solution_bus_voltage_snap()
	bus_names = collect(keys(buses_dict_snap))	
	
	loads_df_snap = _RepNets.loads_to_dataframe()
	load_names = loads_df_snap[!,:Name]
end

# ╔═╡ 4478bd4d-b1a3-4be2-866c-71725cc4fcd6
md"""
## load data
"""

# ╔═╡ 057a7171-d8bb-4dfa-a02e-6f3faf039d97
md"""
load magnitude multiplier (0,10) $(@bind load_magnitude_slider PlutoUI.Slider(0:0.2:10; default=1, show_value=true))
"""

# ╔═╡ 236e9fa0-0d49-4f04-b10c-001cf6a52e9e
md"""
load angle (-pi,pi) $(@bind load_angle_slider PlutoUI.Slider(-3.1:0.1:3.1; default=0.4, show_value=true))
"""

# ╔═╡ c83565e3-ae93-4ab3-a920-475f12523cc8
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

# ╔═╡ db64d15c-c56f-4ffd-ac2e-97d420665814
md"""
## solve multiperiod problem
This is the multiperiod problem for the representative network.

The network does not include pv and storage systems.


We first run the model in the snapshot mode to extract load and bus names. Then the loadshapes are assigned to the multiperiod mode.
"""

# ╔═╡ ff6b886b-e361-454c-9821-0f1d127ccfb9
begin
	cd(path)
	mode = "Daily"
	
	_RepNets.dss!(path*file, mode; loadshapesP=loaddata_Pmatrix, loadshapesQ=loaddata_Qmatrix, useactual=true)

end

# ╔═╡ 0665c264-4cb3-425e-984b-7d85c519e916
md"""
## inspect results
Extract information for all transformers, generators, capacitors, lines from OpenDSSDirect and store them in dataframes

Extract load, bus and pvsystem data to dictionaries
"""

# ╔═╡ 44bfe433-3187-4f6a-9848-19f748945d12
begin
	transformers_df = _RepNets.transformers_to_dataframe()
	generators_df = _RepNets.generators_to_dataframe()
	capacitors_df = _RepNets.capacitors_to_dataframe()
	lines_df = _RepNets.lines_to_dataframe()
	
    load_dict = _RepNets.get_solution_load()
	buses_dict = _RepNets.get_solution_bus_voltage()
end

# ╔═╡ 27748f89-7b63-474a-a638-f123fac0f0bf
md"""
## Plots
"""

# ╔═╡ 87b855a7-9e5e-4ee3-a6fa-c7c8fd8a6ffc
md"""
time step (1,24) $(@bind time_step PlutoUI.Slider(1:24; default=1, show_value=true))
"""

# ╔═╡ cc9bfff3-fc7a-480f-976f-1baebba730cb
begin
	p1 = _RepNets.plot_voltage_snap(buses_dict, lines_df; t=time_step)
end

# ╔═╡ 16c2d430-c00c-4bf6-9cea-ca41fad86803
begin
	figpath = joinpath(pwd(), "network_"*case[parse(Int,i)]*"_multiperiod_voltage_drop_time_$time_step.pdf")
	savefig(p1, figpath)
	@show "figure saved: $figpath"
end

# ╔═╡ 7e58a1cf-ac2e-4392-81ef-98b538c61fd4
begin
	p2 = _RepNets.plot_voltage_boxplot(buses_dict)
end

# ╔═╡ 34c51902-0d90-47a7-894e-205b880316ea
begin
	figpath2 = joinpath(pwd(), "network_"*case[parse(Int,i)]*"_multiperiod_voltage_bus_phase.pdf")
	savefig(p2, figpath2)
	@show "figure saved: $figpath"
end

# ╔═╡ f5894a60-fa43-4df0-80c5-4dd744c9bc9b
begin
	p3 = _RepNets.plot_substation_power()
end

# ╔═╡ 69816446-8938-40fc-8ef5-2b6f9eb56403
begin
	figpath3 = joinpath(pwd(), "network_"*case[parse(Int,i)]*"multiperiod_substation_power.pdf")
	savefig(p3,figpath3)
	@show "figure saved: $figpath"
end

# ╔═╡ Cell order:
# ╟─b3a3a1e6-bc30-11eb-0277-7958bfc44407
# ╟─6f43db92-3968-4bb0-9198-d7c7f208d0f5
# ╟─ab3df566-1373-42d3-9eab-34757f28c359
# ╟─4478bd4d-b1a3-4be2-866c-71725cc4fcd6
# ╟─057a7171-d8bb-4dfa-a02e-6f3faf039d97
# ╟─236e9fa0-0d49-4f04-b10c-001cf6a52e9e
# ╟─c83565e3-ae93-4ab3-a920-475f12523cc8
# ╟─db64d15c-c56f-4ffd-ac2e-97d420665814
# ╟─ff6b886b-e361-454c-9821-0f1d127ccfb9
# ╠═0665c264-4cb3-425e-984b-7d85c519e916
# ╟─44bfe433-3187-4f6a-9848-19f748945d12
# ╟─27748f89-7b63-474a-a638-f123fac0f0bf
# ╟─87b855a7-9e5e-4ee3-a6fa-c7c8fd8a6ffc
# ╟─cc9bfff3-fc7a-480f-976f-1baebba730cb
# ╟─16c2d430-c00c-4bf6-9cea-ca41fad86803
# ╟─7e58a1cf-ac2e-4392-81ef-98b538c61fd4
# ╟─34c51902-0d90-47a7-894e-205b880316ea
# ╟─f5894a60-fa43-4df0-80c5-4dd744c9bc9b
# ╟─69816446-8938-40fc-8ef5-2b6f9eb56403
