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
## Select Network

Network: $(@bind i PlutoUI.Select(case_tuples))
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
## Attach load data
We attach time series data automatically. You can further increase the load levels and the P/Q ratio (using the angle).
"""

# ╔═╡ db40a422-b0c3-456c-9f1c-e3af9695598e
md"""
load magnitude multiplier (0,10) $(@bind load_magnitude_slider PlutoUI.Slider(0:0.2:10; default=1, show_value=true))
"""

# ╔═╡ b2949fff-54d4-45c6-93a5-9e2373862c66
md"""
load angle (-pi,pi) $(@bind load_angle_slider PlutoUI.Slider(-3.1:0.1:3.1; default=0.4, show_value=true))
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

# ╔═╡ cdf19e2e-e548-48c6-9839-a0e3803c2f60
md"""
## Power Flow simulation
By default the load behavior is constant-power, i.e. when the network voltage changes, the load compensates by drawing a higher current to keep the power constant. It is well-known that this is a conservative approach to modelling load.
The power flow through the substation bus now is the following.
"""

# ╔═╡ 59dac11a-ddf9-4266-955e-32ac68824780
md"""
## Demand response through CVR
We now change the voltage-dependence of the loads, by changing the load exponent

$P = (P_{ref}/V_{ref}) \cdot V^{CVRP}$
$Q = (Q_{ref}/V_{ref}) \cdot V^{CVRQ}$

Note that voltage V is in per unit in this context.
If the exponents are set 0, we re-obtain the constant power results. Alternatively, with an exponent of 1, we get the constant current behavior. Finally, with an exponent of 2 we obtain constant admittance behavior. Use the sliders to play with the exponents for P and Q. 
"""

# ╔═╡ 8e158284-0c24-4689-8930-bc8d51a01753
md"""
link P and Q (note: active power slider will control both)? $(@bind PQlink CheckBox(default=false))
"""

# ╔═╡ fc96c5ed-0e8b-4a4c-84c0-8dd23180b0e3
md"""
active power cvr exponent (CVRP) (0,4) $(@bind p_cvr_exponent PlutoUI.Slider(0.0:.1:4.0; default=0.4, show_value=true))
"""

# ╔═╡ c08bdaea-29e7-44e4-8817-ec1cd82cf7fa
md"""
reactive power cvr exponent (CVRQ) (0,4) $(@bind q_cvr_exponent PlutoUI.Slider(0.0:.1:4.0; default=0.8, show_value=true))
"""

# ╔═╡ 6850f8f7-be2c-4726-849a-f66ab029c09f
md"""
We can also change the value of the voltage source on the reference bus to represent tap changing upstream. This will mean the loads now see different voltages.

voltage source p.u. (0.9,1.1) $(@bind Vsource_pu PlutoUI.Slider(0.9:.01:1.1; default=0.9, show_value=true))

$(@bind go Button("Refresh Figures!"))
"""

# ╔═╡ 441feab9-f16c-4660-86ce-278c6a426eaa
begin
	go
	cd(path)
	_RepNets.dss!(path*file, "Daily"; loadshapesP=loaddata_Pmatrix, loadshapesQ=loaddata_Qmatrix, useactual=true)
	PQ_dict_before = _RepNets.get_solution_substation_power()
	energy_before = Dict(PQ =>sum(timeseries) for (PQ, timeseries) in PQ_dict_before)
	p_before = _RepNets.plot_substation_power()
end

# ╔═╡ 2095c811-7da4-4496-a895-c8743ae9d099
begin
	go
	
	if PQlink
		q_cvr = p_cvr_exponent
	else
		q_cvr = q_cvr_exponent
	end
	
	cvr_load = [_RepNets.change_cvr_loads!(load_names; cvrwatts=p_cvr_exponent, cvrvars=q_cvr, Vsource_pu=Vsource_pu)]
end

# ╔═╡ c2466922-5325-40d1-962d-4124fa00c9de
begin
	cd(path)
	mode = "Daily"
	
	_RepNets.dss!(path*file, mode; loadshapesP=loaddata_Pmatrix, loadshapesQ=loaddata_Qmatrix, useactual=true, cvr_load=cvr_load)

end

# ╔═╡ c8af4c62-d2a1-4f1b-a8d3-e1b57a2f9a80
md"""
We extract information for all transformers, generators, capacitors, lines from OpenDSSDirect and store them in dataframes. Furthermore we extract load, bus and pvsystem data to dictionaries
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

# ╔═╡ 0ae36f88-12b9-4f0a-8253-101154503953
md"""
# Comparison 
We now plot the total power (sum of phase powers) through the substation. 
"""

# ╔═╡ b23d9099-6f49-437c-bcba-0e4610031fa1
md"""
## More plots for exploration
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
	@show "figure saved: $figpath2"
end

# ╔═╡ 555d55cb-c5fe-4f56-991f-abf58cad0d3e
begin
	go
	PQ_dict_after = _RepNets.get_solution_substation_power()
	p_after = _RepNets.plot_substation_power()
end

# ╔═╡ fcdf5943-25d0-4322-9fbf-0088be00c471
begin
	PP = plot()
	Ptot_before = PQ_dict_before["P1"] + PQ_dict_before["P2"] + PQ_dict_before["P3"]
	Ptot_after = PQ_dict_after["P1"] + PQ_dict_after["P2"] + PQ_dict_after["P3"]
	Qtot_before = PQ_dict_before["Q1"] + PQ_dict_before["Q2"] + PQ_dict_before["Q3"]
	Qtot_after = PQ_dict_after["Q1"] + PQ_dict_after["Q2"] + PQ_dict_after["Q3"]
	
	plot!(Ptot_before, label="P total at 1 pu")
	plot!(Qtot_before, label="Q total at 1 pu")
	plot!(Ptot_after, label="P total at $Vsource_pu pu")
	plot!(Qtot_after, label="Q total at $Vsource_pu pu")
	ylabel!("Power flow (kW/kvar)")
	xlabel!("Time (h)")
	title!("Power flow through substation bus")
	PP
end

# ╔═╡ e59cb760-c03c-4121-8216-95503df2b003
begin
	go
	figpath4 = joinpath(pwd(), "network_"*case[parse(Int,i)]*"_cvr_substation_power_comp.pdf")
	savefig(PP,figpath4)
	@show "figure saved: $figpath4"
end

# ╔═╡ d5d03d19-9682-4a20-81f1-3c0ef7ecd25a
begin
	energy_after = Dict(PQ =>sum(timeseries) for (PQ, timeseries) in PQ_dict_after)
	E_tot_P_after = energy_after["P1"] + energy_after["P2"] + energy_after["P3"]
	E_tot_Q_after = energy_after["Q1"] + energy_after["Q2"] + energy_after["Q3"]
	E_tot_P_before = energy_before["P1"] + energy_before["P2"] + energy_before["P3"]
	E_tot_Q_before = energy_before["Q1"] + energy_before["Q2"] + energy_before["Q3"]
	ratio_P = Int(floor(100*(1-E_tot_P_after/E_tot_P_before)))
	ratio_Q = Int(floor(100*(1-E_tot_Q_after/E_tot_Q_before)))
	
	md"""
	The energy consumption originally was $(Int(floor(E_tot_P_before))) kWh and changed to $(Int(floor(E_tot_P_after))) kWh. 
	
	The reactive power consumption originally was $(Int(floor(E_tot_Q_before))) kvar and changed to $(Int(floor(E_tot_Q_after))) kvar. 
	
	This represents a reduction of $ratio_P % active power and $ratio_Q % reactive power
	"""
end

# ╔═╡ dc5dcfef-977f-4910-9da3-5f7a725d950e
begin
	go
	figpath3 = joinpath(pwd(), "network_"*case[parse(Int,i)]*"_cvr_substation_power.pdf")
	savefig(p_after,figpath3)
	@show "figure saved: $figpath3"
end

# ╔═╡ db0cd563-ed72-4196-adca-27bb639fdd73


# ╔═╡ Cell order:
# ╟─4d7ec2f9-0263-465e-b736-3270b1fb7584
# ╟─9a50652c-a9f7-4165-8548-80c861b53863
# ╟─614c3e75-9651-4bfd-ba1c-fd4f1a6ec3c6
# ╟─5cf99fe1-4859-463e-bbf8-03236a8e237a
# ╟─db40a422-b0c3-456c-9f1c-e3af9695598e
# ╟─b2949fff-54d4-45c6-93a5-9e2373862c66
# ╟─08d8960c-b8a4-487e-bb83-056e7d1957d8
# ╟─cdf19e2e-e548-48c6-9839-a0e3803c2f60
# ╟─441feab9-f16c-4660-86ce-278c6a426eaa
# ╟─59dac11a-ddf9-4266-955e-32ac68824780
# ╟─8e158284-0c24-4689-8930-bc8d51a01753
# ╟─fc96c5ed-0e8b-4a4c-84c0-8dd23180b0e3
# ╟─c08bdaea-29e7-44e4-8817-ec1cd82cf7fa
# ╟─6850f8f7-be2c-4726-849a-f66ab029c09f
# ╟─2095c811-7da4-4496-a895-c8743ae9d099
# ╟─c2466922-5325-40d1-962d-4124fa00c9de
# ╟─c8af4c62-d2a1-4f1b-a8d3-e1b57a2f9a80
# ╟─66970eca-d709-4b1f-9243-171fe776fa33
# ╟─0ae36f88-12b9-4f0a-8253-101154503953
# ╟─fcdf5943-25d0-4322-9fbf-0088be00c471
# ╟─e59cb760-c03c-4121-8216-95503df2b003
# ╟─d5d03d19-9682-4a20-81f1-3c0ef7ecd25a
# ╟─b23d9099-6f49-437c-bcba-0e4610031fa1
# ╟─5d2407c1-98ad-4500-bfcd-c75660dc6e8a
# ╟─0432e80e-54fe-40e6-8469-87a5f0d8c116
# ╟─dd2cb4a4-2d42-4429-b934-3e40402e1568
# ╟─55737303-9100-471a-9ba4-d63d48935675
# ╟─836d1582-5845-43f1-87cc-c0f1cee9a6d8
# ╟─555d55cb-c5fe-4f56-991f-abf58cad0d3e
# ╟─dc5dcfef-977f-4910-9da3-5f7a725d950e
# ╟─db0cd563-ed72-4196-adca-27bb639fdd73
