### A Pluto.jl notebook ###
# v0.16.1

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

# ╔═╡ df30e911-e0f9-4110-acf0-b770123c6c53
begin
	using Pkg
	Pkg.activate(joinpath(pwd(),".."))
end

# ╔═╡ d663dc4c-b926-11eb-1760-6d7e227eebd3
begin
	using RepresentativeLVNetworks
	const _RepNets = RepresentativeLVNetworks
	using PlutoUI
	using OpenDSSDirect
	using JSON

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

# ╔═╡ a43ff009-fde4-4f38-b2fd-c679e2276fa8
md"""
## Select Network

Network: $(@bind i PlutoUI.Select(case_tuples))
"""

# ╔═╡ 78e32c08-a45b-41f0-8858-b9919b94cdc9
md"""
# solve snapshot problem
This is the single period problem for the representative network.

The network does not include pv and storage systems.

The network data includes snapshot load data.
"""

# ╔═╡ e72d955a-0658-4cab-9071-14996a3c1ceb
begin
	path = joinpath(dirname(pathof(_RepNets)),"..","data/",case[parse(Int,i)])
	cd(path)
	file = "/Master.dss"
	
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
# ╟─df30e911-e0f9-4110-acf0-b770123c6c53
# ╟─d663dc4c-b926-11eb-1760-6d7e227eebd3
# ╟─a43ff009-fde4-4f38-b2fd-c679e2276fa8
# ╟─78e32c08-a45b-41f0-8858-b9919b94cdc9
# ╟─e72d955a-0658-4cab-9071-14996a3c1ceb
# ╟─c0f3f3c0-d528-4bbf-822f-ea47eba174bd
# ╟─29debbaa-1aa8-47f0-b0df-ab9e58703575
# ╟─247aa5cd-c59d-4391-a395-badef95d1d44
# ╟─f0bf97fd-4630-4fc1-8df1-5625925da248
