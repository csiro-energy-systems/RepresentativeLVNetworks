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

# ╔═╡ 4d7ec2f9-0263-465e-b736-3270b1fb7584
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

# ╔═╡ 9a50652c-a9f7-4165-8548-80c861b53863
md"""
## Select the network file and press the button
Network: $(@bind i PlutoUI.Select(case_tuples))
$(@bind go Button("Generate Figures!"))
"""

# ╔═╡ 614c3e75-9651-4bfd-ba1c-fd4f1a6ec3c6
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

# ╔═╡ 5cf99fe1-4859-463e-bbf8-03236a8e237a
md"""
## load data
"""

# ╔═╡ db40a422-b0c3-456c-9f1c-e3af9695598e
md"""
load magnitude multiplier (0,10) $(@bind load_magnitude_slider PlutoUI.Slider(0:0.2:10; default=1, show_value=true))
"""

# ╔═╡ b2949fff-54d4-45c6-93a5-9e2373862c66
md"""
load angle (-pi,pi) $(@bind load_angle_slider PlutoUI.Slider(-3.1:0.1:3.1; default=0.4, show_value=true))
"""

# ╔═╡ fc96c5ed-0e8b-4a4c-84c0-8dd23180b0e3
md"""
active power cvr exponent (0,4) $(@bind p_cvr_exponent PlutoUI.Slider(0.0:.1:4.0; default=0.4, show_value=true))
"""

# ╔═╡ c08bdaea-29e7-44e4-8817-ec1cd82cf7fa
md"""
reactive power cvr exponent (0,4) $(@bind q_cvr_exponent PlutoUI.Slider(0.0:.1:4.0; default=0.8, show_value=true))
"""

# ╔═╡ 8e158284-0c24-4689-8930-bc8d51a01753
md"""
link P and Q (note: active power slider will control both)? $(@bind PQlink CheckBox(default=false))
"""

# ╔═╡ 08d8960c-b8a4-487e-bb83-056e7d1957d8
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

# ╔═╡ 59dac11a-ddf9-4266-955e-32ac68824780
md"""
## CVR load
"""

# ╔═╡ 2095c811-7da4-4496-a895-c8743ae9d099
begin
	go
	
	if PQlink
		q_cvr = p_cvr_exponent
	else
		q_cvr = q_cvr_exponent
	end
	
	cvr_load = [_RepNets.change_cvr_loads!(load_names; cvrwatts=p_cvr_exponent, cvrvars=q_cvr)]
end

# ╔═╡ 689a9150-c445-4586-9305-4f6c2a9c1b9e
md"""
## solve multiperiod problem
This is the multiperiod problem for the representative network.

The network does not include pv and storage systems.


We first run the model in the snapshot mode to extract load and bus names. Then the loadshapes are assigned to the multiperiod mode.
"""

# ╔═╡ c2466922-5325-40d1-962d-4124fa00c9de
begin
	cd(path)
	mode = "Daily"
	
	
	_RepNets.dss!(path*file, mode; loadshapesP=loaddata_Pmatrix, loadshapesQ=loaddata_Qmatrix, useactual=true, cvr_load=cvr_load)

end

# ╔═╡ c8af4c62-d2a1-4f1b-a8d3-e1b57a2f9a80
md"""
## inspect results
Extract information for all transformers, generators, capacitors, lines from OpenDSSDirect and store them in dataframes

Extract load, bus and pvsystem data to dictionaries
"""

# ╔═╡ 66970eca-d709-4b1f-9243-171fe776fa33
begin
	go
	transformers_df = _RepNets.transformers_to_dataframe()
	generators_df = _RepNets.generators_to_dataframe()
	capacitors_df = _RepNets.capacitors_to_dataframe()
	lines_df = _RepNets.lines_to_dataframe()
	
    load_dict = _RepNets.get_solution_load()
	buses_dict = _RepNets.get_solution_bus_voltage()
end

# ╔═╡ b23d9099-6f49-437c-bcba-0e4610031fa1
md"""
## Plots
"""

# ╔═╡ 5d2407c1-98ad-4500-bfcd-c75660dc6e8a
md"""
time step (1,24) $(@bind time_step PlutoUI.Slider(1:24; default=1, show_value=true))
"""

# ╔═╡ 0432e80e-54fe-40e6-8469-87a5f0d8c116
begin
	go
	p1 = _RepNets.plot_voltage_snap(buses_dict, lines_df; t=time_step)
end

# ╔═╡ dd2cb4a4-2d42-4429-b934-3e40402e1568
begin
	go
	figpath = joinpath(pwd(), "network_"*case[parse(Int,i)]*"_cvr_voltage_drop_time_$time_step.pdf")
	savefig(p1, figpath)
	@show "figure saved: $figpath"
end

# ╔═╡ 55737303-9100-471a-9ba4-d63d48935675
begin
	go
	p2 = _RepNets.plot_voltage_boxplot(buses_dict)
end

# ╔═╡ 836d1582-5845-43f1-87cc-c0f1cee9a6d8
begin
	go
	figpath2 = joinpath(pwd(), "network_"*case[parse(Int,i)]*"_cvr_voltage_bus_phase.pdf")
	savefig(p2, figpath2)
	@show "figure saved: $figpath"
end

# ╔═╡ 555d55cb-c5fe-4f56-991f-abf58cad0d3e
begin
	go
	p3 = _RepNets.plot_substation_power()
end

# ╔═╡ db0cd563-ed72-4196-adca-27bb639fdd73
begin
	go
	figpath3 = joinpath(pwd(), "network_"*case[parse(Int,i)]*"_cvr_substation_power.pdf")
	savefig(p3,figpath3)
	@show "figure saved: $figpath"
end

# ╔═╡ Cell order:
# ╟─4d7ec2f9-0263-465e-b736-3270b1fb7584
# ╟─9a50652c-a9f7-4165-8548-80c861b53863
# ╟─614c3e75-9651-4bfd-ba1c-fd4f1a6ec3c6
# ╟─5cf99fe1-4859-463e-bbf8-03236a8e237a
# ╟─db40a422-b0c3-456c-9f1c-e3af9695598e
# ╟─b2949fff-54d4-45c6-93a5-9e2373862c66
# ╟─fc96c5ed-0e8b-4a4c-84c0-8dd23180b0e3
# ╟─c08bdaea-29e7-44e4-8817-ec1cd82cf7fa
# ╟─8e158284-0c24-4689-8930-bc8d51a01753
# ╟─08d8960c-b8a4-487e-bb83-056e7d1957d8
# ╟─59dac11a-ddf9-4266-955e-32ac68824780
# ╟─2095c811-7da4-4496-a895-c8743ae9d099
# ╟─689a9150-c445-4586-9305-4f6c2a9c1b9e
# ╟─c2466922-5325-40d1-962d-4124fa00c9de
# ╟─c8af4c62-d2a1-4f1b-a8d3-e1b57a2f9a80
# ╠═66970eca-d709-4b1f-9243-171fe776fa33
# ╟─b23d9099-6f49-437c-bcba-0e4610031fa1
# ╟─5d2407c1-98ad-4500-bfcd-c75660dc6e8a
# ╟─0432e80e-54fe-40e6-8469-87a5f0d8c116
# ╟─dd2cb4a4-2d42-4429-b934-3e40402e1568
# ╟─55737303-9100-471a-9ba4-d63d48935675
# ╟─836d1582-5845-43f1-87cc-c0f1cee9a6d8
# ╠═555d55cb-c5fe-4f56-991f-abf58cad0d3e
# ╟─db0cd563-ed72-4196-adca-27bb639fdd73