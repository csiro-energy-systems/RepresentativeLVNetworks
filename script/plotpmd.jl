using Plots
using Ipopt
using PowerModelsDistribution
const PMD = PowerModelsDistribution

# file = "/Users/get050/Documents/Repositories/github/pmd-storage/data/lvtestcase_t1000_notrans.dss"
file = "/Users/get050/Documents/repositories/GitHub/RepresentativeLVNetworks/data/D014470/Master.dss"
# file2 = "test/data/opendss/case3_unbalanced.dss"
eng = parse_file(file)
# eng["voltage_source"]["source"]["rs"] *=0.01
# eng["voltage_source"]["source"]["xs"] *=0.01
math = transform_data_model(eng)

eng2 = transform_data_model(math)

result = solve_ac_mc_opf(eng, Ipopt.Optimizer)
solution = result["solution"]
vm = Dict(i=>bus["vm"] for (i,bus) in solution["bus"])

function add_distances_to_buses!(data)
    sourcebus = [voltage_source["bus"] for (i,voltage_source) in data["voltage_source"]]
    if length(sourcebus)>1
        @warn("taking first bus "*sourcebus[1]*" as reference bus for defining distance")
    elseif length(sourcebus)==0
        error()
    else
        sourcebus = sourcebus[1]
    end
    all_buses = Set(i for (i, bus) in data["bus"])

    buses_visited= Set()
    branches_used= Set()

    #We define distances relative to the reference bus
    data["bus"][sourcebus]["distance"] = 0
    push!(buses_visited, sourcebus)

    while all_buses!=buses_visited
        #find a branch connecting to a bus we've already visited
        candidatelines_to = [l for (l, line) in data["line"] if l ∉ branches_used && string(line["t_bus"]) in buses_visited ]
        candidatelines_from = [l for (l, line) in data["line"] if l ∉ branches_used && string(line["f_bus"]) in buses_visited ]
        if length(candidatelines_to)>=1
            #pick first branch
            newlineid = candidatelines_to[1]
            newline = data["line"][newlineid]
            #find the bus on the other side
            newbusid = string(newline["f_bus"])
            currentbus = string(newline["t_bus"])
        elseif length(candidatelines_from)>=1
            newlineid = candidatelines_from[1]
            newline = data["line"][newlineid]
            newbusid = string(newline["t_bus"])
            currentbus = string(newline["f_bus"])
        else
            error()
        end
        newbus = data["bus"][string(newbusid)]
        #calculate distance and store it in the bus dict
        newbus["distance"] = data["bus"][currentbus]["distance"] + newline["length"]
        #add bus to list of buses we've found the distance for
        push!(buses_visited, newbusid)
        #avoid passing through the same branch in the future
        push!(branches_used, newlineid)
    end
end

add_distances_to_buses!(eng)

function add_sequence_indicators_to_buses!(eng)
    a = exp(-im*2*pi/3)
    A = [1 1 1; 1 a a^2; 1 a^2 a]
    Ainv = inv(A)
    for (i,bus) in solution["bus"]
        vm = bus["vm"]
        va = bus["va"]
        vabc = vm.*exp.(im*pi*va/180)
        v012 = Ainv*vabc
        bus["vabc"] = vabc
        bus["v012"] = v012
        bus["v012m"] = abs.(v012)
        bus["VUF"] = abs(v012[3])/abs(v012[2])
    end
end
add_sequence_indicators_to_buses!(eng)
function plot_voltage_along_feeder(eng, solution; normalize=true)
    p = plot(legend=false)
    if normalize
        sourcebus = [voltage_source for (i,voltage_source) in eng["voltage_source"]]
        if length(sourcebus)>1
            @warn("taking first bus "*sourcebus[1]*" to normalize voltage values")
        elseif length(sourcebus)==0
            error()
        else
            sourcebus = sourcebus[1]
        end
        scalefactor = sourcebus["vm"]
        ylabel!("Voltage magnitude (pu)")
    else
        scalefactor = ones(3)
        ylabel!("Voltage magnitude (kV)")
    end
    title!("Voltage change along feeder by phase")
    xlabel!("Distance from reference bus (m)")
    colors = [:blue, :red, :black]
    for (i,line) in solution["line"]
        for c in eng["line"][i]["f_connections"]
            f_bus = eng["line"][i]["f_bus"]
            t_bus = eng["line"][i]["t_bus"]
            dist_f_bus = eng["bus"][f_bus]["distance"]
            dist_t_bus = eng["bus"][t_bus]["distance"]
            vm_f = solution["bus"][f_bus]["vm"]./scalefactor
            vm_t = solution["bus"][t_bus]["vm"]./scalefactor
            plot!([dist_f_bus; dist_t_bus], [vm_f[c]; vm_t[c]], color=colors[c], marker=:circle, markersize=1)
        end
    end
    display(p)
end

plot_voltage_along_feeder(eng, solution)

function plot_VUF_along_feeder(eng, solution; threshold_vuf_percent = 2)
    p = plot(legend=false)
    title!("Voltage unbalance change along feeder")
    xlabel!("Distance from reference bus (m)")
    ylabel!("Voltage unbalance factor (%)")
    for (i,line) in solution["line"]
        f_bus = eng["line"][i]["f_bus"]
        t_bus = eng["line"][i]["t_bus"]
        dist_f_bus = eng["bus"][f_bus]["distance"]
        dist_t_bus = eng["bus"][t_bus]["distance"]
        vuf_f = solution["bus"][f_bus]["VUF"]
        vuf_t = solution["bus"][t_bus]["VUF"]
        plot!([dist_f_bus; dist_t_bus], 100*[vuf_f; vuf_t], color=:blue, marker=:circle, markersize=1)
    end
    maxdist = maximum([bus["distance"] for (i,bus) in eng["bus"]])
    plot!([0; maxdist], [threshold_vuf_percent; threshold_vuf_percent], color=:red)
    display(p)
end

plot_VUF_along_feeder(eng, solution)



using StatsPlots
boxplot(rand(5,5))

# import GR

# ---------------------------------------------------------------------------
# Box Plot

notch_width(q2, q4, N) = 1.58 * (q4-q2)/sqrt(N)

@recipe function f(::Type{Val{:boxplot}}, x, y, z; notch=false, range=1.5, outliers=true, whisker_width=:match)
    # if only y is provided, then x will be UnitRange 1:size(y,2)
    if typeof(x) <: AbstractRange
        if step(x) == first(x) == 1
            x = plotattributes[:series_plotindex]
        else
            x = [getindex(x, plotattributes[:series_plotindex])]
        end
    end
    xsegs, ysegs = Segments(), Segments()
    glabels = sort(collect(unique(x)))
    warning = false
    outliers_x, outliers_y = zeros(0), zeros(0)
    bw = plotattributes[:bar_width]
    bw == nothing && (bw = 0.8)
    @assert whisker_width == :match || whisker_width >= 0 "whisker_width must be :match or a positive number"
    ww = whisker_width == :match ? bw : whisker_width
    for (i,glabel) in enumerate(glabels)
        # filter y
        values = y[filter(i -> _cycle(x,i) == glabel, 1:length(y))]

        # compute quantiles
        q1,q2,q3,q4,q5 = quantile(values, Base.range(0,stop=1,length=5))

        # notch
        n = notch_width(q2, q4, length(values))

        # warn on inverted notches?
        if notch && !warning && ( (q2>(q3-n)) || (q4<(q3+n)) )
            @warn("Boxplot's notch went outside hinges. Set notch to false.")
            warning = true # Show the warning only one time
        end

        # make the shape
        center = Plots.discrete_value!(plotattributes[:subplot][:xaxis], glabel)[1]
        hw = 0.5_cycle(bw, i) # Box width
        HW = 0.5_cycle(ww, i) # Whisker width
        l, m, r = center - hw, center, center + hw
        lw, rw = center - HW, center + HW

        # internal nodes for notches
        L, R = center - 0.5 * hw, center + 0.5 * hw

        # outliers
        if Float64(range) != 0.0  # if the range is 0.0, the whiskers will extend to the data
            limit = range*(q4-q2)
            inside = Float64[]
            for value in values
                if (value < (q2 - limit)) || (value > (q4 + limit))
                    if outliers
                        push!(outliers_y, value)
                        push!(outliers_x, center)
                    end
                else
                    push!(inside, value)
                end
            end
            # change q1 and q5 to show outliers
            # using maximum and minimum values inside the limits
            q1, q5 = Plots.ignorenan_extrema(inside)
        end

        # Box
        if notch
            push!(xsegs, m, lw, rw, m, m)       # lower T
            push!(xsegs, l, l, L, R, r, r, l) # lower box
            push!(xsegs, l, l, L, R, r, r, l) # upper box
            push!(xsegs, m, lw, rw, m, m)       # upper T

            push!(ysegs, q1, q1, q1, q1, q2)             # lower T
            push!(ysegs, q2, q3-n, q3, q3, q3-n, q2, q2) # lower box
            push!(ysegs, q4, q3+n, q3, q3, q3+n, q4, q4) # upper box
            push!(ysegs, q5, q5, q5, q5, q4)             # upper T
        else
            push!(xsegs, m, lw, rw, m, m)         # lower T
            push!(xsegs, l, l, r, r, l)         # lower box
            push!(xsegs, l, l, r, r, l)         # upper box
            push!(xsegs, m, lw, rw, m, m)         # upper T

            push!(ysegs, q1, q1, q1, q1, q2)    # lower T
            push!(ysegs, q2, q3, q3, q2, q2)    # lower box
            push!(ysegs, q4, q3, q3, q4, q4)    # upper box
            push!(ysegs, q5, q5, q5, q5, q4)    # upper T
        end
    end

    # To prevent linecolor equal to fillcolor (It makes the median visible)
    if plotattributes[:linecolor] == plotattributes[:fillcolor]
        plotattributes[:linecolor] = plotattributes[:markerstrokecolor]
    end

    # Outliers
    if outliers
        primary := false
        @series begin
            seriestype  := :scatter
            if get!(plotattributes, :markershape, :circle) == :none
                	plotattributes[:markershape] = :circle
            end

            fillrange   := nothing
            x           := outliers_x
            y           := outliers_y
            primary     := true
            ()
        end
    end

    seriestype := :shape
    x := xsegs.pts
    y := ysegs.pts
    ()
end
Plots.@deps boxplot shape scatter


file = "/Users/get050/Downloads/trafo_75586241_75586241_3094650/Master.dss"
eng = parse_file(file)
math = transform_data_model(eng)
result = run_ac_mc_pf(math, Ipopt.Optimizer)

busbranches = Dict(i => [] for (i, bus) in eng["bus"])
