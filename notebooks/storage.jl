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

# ╔═╡ 46131770-bc48-11eb-0920-bdf898c3c759
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

# ╔═╡ 2476fd06-9c37-41b0-bf62-b75c3cc88c97
md"""
## Select the network file and press the button
Network: $(@bind i PlutoUI.Select(case_tuples))
$(@bind go Button("Generate Figures!"))
"""

# ╔═╡ 570f1884-11e3-439f-bb1b-1b4e54dea16f
begin	
	path = joinpath(dirname(pathof(_RepNets)),"..","data/",case[parse(Int,i)])
	cd(path)
	file = "/Master.dss"
	
	_RepNets.dss!(path*file, "Snap")
	buses_dict_snap = _RepNets.get_solution_bus_voltage_snap()

	load_bus_mapping_dict = _RepNets.load_bus_mapping()
	bus_phase_mapping_dict = _RepNets.bus_phase_mapping()
	load_names = collect(keys(load_bus_mapping_dict))
	bus_names = collect(values(load_bus_mapping_dict))
end

# ╔═╡ be06145a-39ab-4cef-8fd8-82500be24112
md"""
## load data
"""

# ╔═╡ 5f47b8f6-2823-4b37-8f48-ed3c96fffa15
md"""
load magnitude multiplier (0,10) $(@bind load_magnitude_slider PlutoUI.Slider(0:0.2:10; default=1, show_value=true))
"""

# ╔═╡ 08c2977a-dd3a-4de9-b1cd-31122ee48d04
md"""
load angle (-pi,pi) $(@bind load_angle_slider PlutoUI.Slider(-3.1:0.1:3.1; default=0.4, show_value=true))
"""

# ╔═╡ 5a504138-8ccc-420a-b5ca-97cfcb0a1e29
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

# ╔═╡ 500aadb2-2812-4187-9af4-2c21839d4d3e
md"""
## storage data
"""

# ╔═╡ bc65c15d-39a7-42f1-82b0-5f082f9d840f
md"Number of storage buses (0, $(length(bus_names))) $(@bind n_storagebus PlutoUI.Slider(0:1:length(bus_names); default=Int(ceil(length(bus_names)/2)), show_value=true))"

# ╔═╡ 90c6666a-3a2d-4fdc-ad93-2ec9db4e60b8
md"""
random selection of storage buses? $(@bind random_storage_buses CheckBox(default=false))
"""

# ╔═╡ 0cfbf7a9-c555-41aa-8915-c79bd4cde7b8
md"""
phases: a $(@bind phase_a CheckBox(default=true)), b $(@bind phase_b CheckBox(default=true)), c $(@bind phase_c CheckBox(default=true))
"""

# ╔═╡ 3a1019bb-b4e4-49c4-acff-89c08e73d0c0
md"""
kVA (0, 20) $(@bind kVA PlutoUI.Slider(0:0.5:20; default=5, show_value=true))
"""

# ╔═╡ 7ae129c6-bc47-496c-9b32-2fdcddd4d632
md"""
connection (delta,wye) $(@bind conn PlutoUI.Select(["first"=>"wye", "second"=>"delta"]))
"""

# ╔═╡ f5af133d-7a38-4c06-8297-db14f896b80f
md"""
power factor (-1,1) $(@bind PF PlutoUI.Slider(-1:0.01:1; default=0.95, show_value=true))
"""

# ╔═╡ 8517b0eb-b543-48bc-a9e8-6735652ad542
md"""
charge/discharge power (0,20) $(@bind kWrated PlutoUI.Slider(0:0.1:20; default=5, show_value=true))
"""

# ╔═╡ b48fd0a1-185c-47b8-ab2e-224970a77be7
md"""
storage energy capacity (0,20) $(@bind kWhrated PlutoUI.Slider(0:0.1:20; default=5, show_value=true))
"""

# ╔═╡ acb64e04-1d61-4685-8802-4e4c96773cb9
begin
	n_buses = length(bus_names)
	
	if random_storage_buses
		storage_buses = bus_names[randperm(n_buses)][1:n_storagebus]
	else
		storage_buses = bus_names[1:n_storagebus]
	end
	
	phases = collect(1:3)[BitArray([phase_a, phase_b, phase_c])]
	@assert length(phases) > 0 "You should select at least one phase"
	
	storage = [_RepNets.add_storage(storage_buses, bus_phase_mapping_dict; phases=phases, kVA=kVA, conn=conn, PF=PF, kWrated=kWrated, kWhrated=kWhrated)]	
end

# ╔═╡ 8b17beb3-4727-431d-b986-8cdb9aa9e281
md"""
## solve multiperiod problem
This is the multiperiod problem for the representative network.

The network does not include pv and storage systems.


We first run the model in the snapshot mode to extract load and bus names. Then the loadshapes are assigned to the multiperiod mode.
"""

# ╔═╡ 8ffb81df-cace-43e3-a79d-e1478dfca1df
begin
	cd(path)
	mode = "Daily"
	
	_, storage_bus_dict = _RepNets.dss!(path*file, mode; loadshapesP=loaddata_Pmatrix, loadshapesQ=loaddata_Qmatrix, useactual=true, storage=storage)

end

# ╔═╡ 8d995dd5-1ea3-4cd1-adf3-42cd121340a7
md"""
## inspect results
We can inspect variables and parameters for the network components
"""

# ╔═╡ 97ff0b8b-d5e1-4490-a813-109425e41e15
begin
	go
	transformers_df = _RepNets.transformers_to_dataframe()
	generators_df = _RepNets.generators_to_dataframe()
	capacitors_df = _RepNets.capacitors_to_dataframe()
	lines_df = _RepNets.lines_to_dataframe()
	
	buses_dict = _RepNets.get_solution_bus_voltage()
	load_dict = _RepNets.get_solution_load()
	storage_dict = _RepNets.get_solution_storage(storage_bus_dict)
end

# ╔═╡ 9a424d3e-8442-49de-b98d-646c27af30eb
md"""
## Plots
"""

# ╔═╡ 734cac0a-9f2f-465a-ad75-1be32766fe92
md"""
time step (1,24) $(@bind time_step PlutoUI.Slider(1:24; default=9, show_value=true))
"""

# ╔═╡ 34ebc99a-b203-474e-b08f-89a92a0c921e
begin 
	go
	p1 = _RepNets.plot_voltage_snap(buses_dict, lines_df; t=time_step)
end

# ╔═╡ 0d5d8eb0-b4ee-4320-b384-b2711ec777bf
begin
	go
	figpath = joinpath(pwd(), "network_"*case[parse(Int,i)]*"_storage_voltage_drop_time_$time_step.pdf")
	savefig(p1, figpath)
	@show "figure saved: $figpath"
end

# ╔═╡ e46de90b-89f6-48f6-b8fd-66a2eb208363
begin
	go
	p2 = _RepNets.plot_voltage_boxplot(buses_dict)
end

# ╔═╡ a8bbc39a-7232-42f2-bf0d-8e47c0cec96e
begin
	go
	figpath2 = joinpath(pwd(), "network_"*case[parse(Int,i)]*"_storage_voltage_bus_phase.pdf")
	savefig(p2, figpath2)
	@show "figure saved: $figpath2"
end

# ╔═╡ a2da2024-dab8-4056-89e8-f16f2d7658b6
begin
	go
	p3 = _RepNets.plot_substation_power()
end

# ╔═╡ 0dfafadc-9566-4f31-a6df-8625875d02eb
begin
	go
	figpath3 = joinpath(pwd(), "network_"*case[parse(Int,i)]*"storage_substation_power.pdf")
	savefig(p3,figpath3)
	@show "figure saved: $figpath3"
end

# ╔═╡ Cell order:
# ╟─46131770-bc48-11eb-0920-bdf898c3c759
# ╟─2476fd06-9c37-41b0-bf62-b75c3cc88c97
# ╟─570f1884-11e3-439f-bb1b-1b4e54dea16f
# ╟─be06145a-39ab-4cef-8fd8-82500be24112
# ╟─5f47b8f6-2823-4b37-8f48-ed3c96fffa15
# ╟─08c2977a-dd3a-4de9-b1cd-31122ee48d04
# ╟─5a504138-8ccc-420a-b5ca-97cfcb0a1e29
# ╟─500aadb2-2812-4187-9af4-2c21839d4d3e
# ╟─bc65c15d-39a7-42f1-82b0-5f082f9d840f
# ╟─90c6666a-3a2d-4fdc-ad93-2ec9db4e60b8
# ╟─0cfbf7a9-c555-41aa-8915-c79bd4cde7b8
# ╟─3a1019bb-b4e4-49c4-acff-89c08e73d0c0
# ╟─7ae129c6-bc47-496c-9b32-2fdcddd4d632
# ╟─f5af133d-7a38-4c06-8297-db14f896b80f
# ╟─8517b0eb-b543-48bc-a9e8-6735652ad542
# ╟─b48fd0a1-185c-47b8-ab2e-224970a77be7
# ╟─acb64e04-1d61-4685-8802-4e4c96773cb9
# ╟─8b17beb3-4727-431d-b986-8cdb9aa9e281
# ╟─8ffb81df-cace-43e3-a79d-e1478dfca1df
# ╟─8d995dd5-1ea3-4cd1-adf3-42cd121340a7
# ╠═97ff0b8b-d5e1-4490-a813-109425e41e15
# ╟─9a424d3e-8442-49de-b98d-646c27af30eb
# ╠═734cac0a-9f2f-465a-ad75-1be32766fe92
# ╟─34ebc99a-b203-474e-b08f-89a92a0c921e
# ╟─0d5d8eb0-b4ee-4320-b384-b2711ec777bf
# ╟─e46de90b-89f6-48f6-b8fd-66a2eb208363
# ╟─a8bbc39a-7232-42f2-bf0d-8e47c0cec96e
# ╟─a2da2024-dab8-4056-89e8-f16f2d7658b6
# ╟─0dfafadc-9566-4f31-a6df-8625875d02eb
