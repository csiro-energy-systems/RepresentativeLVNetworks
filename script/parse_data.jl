cd("/Users/get050/Documents/repositories/GitHub/RepresentativeLVNetworks")
using Pkg
Pkg.activate("./")

##

file = "/Users/get050/Documents/data/CD_INTERVAL_READING_ALL_NO_QUOTES.csv"
using CSV
using Dates
using Ipopt
solver = Ipopt.Optimizer
r = CSV.File(file, limit=10_000_000)
a = Dict()
for row in r
    d = DateTime(row.READING_DATETIME, dateformat"yyyy-mm-dd HH:MM:SS")
    if haskey(a, row.CUSTOMER_ID)
        # do nothing
    else
        # initialise dict
        a[row.CUSTOMER_ID] = Dict()
        a[row.CUSTOMER_ID]["E"] = []
        a[row.CUSTOMER_ID]["time"] = []
    end
    push!(a[row.CUSTOMER_ID]["E"], row[Symbol(" GENERAL_SUPPLY_KWH")])
    push!(a[row.CUSTOMER_ID]["time"], d)
end

custids = Dict(i=>c for (i,(c, customer)) in enumerate(a))

n_timesteps = 48
tt = 0.5.*collect(1:48)
for (c,customer) in a
    customer["tdiff"] = diff(customer["time"])
    T = 0.5 #h 
    customer["p"] = customer["E"]/T #convert kWh to kW

    customer["E"] = customer["E"][1:n_timesteps]
    customer["time"] = customer["time"][1:n_timesteps]
    customer["tdiff"]  = customer["tdiff"][1:n_timesteps]
    customer["p"] = customer["p"][1:n_timesteps]
end


##
using Plots
p = plot(size=(600,600))
for (c,customer) in a
    plot!(tt,customer["p"], legend=false)
end
xlabel!("Time (h)")
ylabel!("Power (kW)")
display(p)
savefig(p, "all_curves.pdf")
##
using JSON

file_timeseries= "smartgridsmartcities.csv"
_ = open(file_timeseries, "w") do io
    JSON.print(io, a)
end

b = JSON.parsefile(file_timeseries)



##
stotals = zeros(48)
for (c,customer) in a
    totals .+= customer["p"]
end

plot(tt,totals)



##
# fileres = "/Users/get050/Documents/data/Representative_Australian_Electricity_Feeders_with_load_and_solar_generation_profiles/DataRelease/AdditionalData/Generic Load Profiles from NFTS/Normalised-Residential.csv"
# using XLSX 
# x = XLSX.readxlsx(fileres)

using StatsPlots

# data = CSV.File(fileres)
# timesteps = 48
# time = zeros(timesteps)
# p_summer = zeros(timesteps)
# p_winter = zeros(timesteps)
# p_shoulder = zeros(timesteps)
# for (i,row) in enumerate(data)
#     p_summer[i] = row.Summer
#     p_winter[i] = row.Winter
#     p_shoulder[i] = row.Shoulder
#     time[i] = row.Hour
# end


# using Plots
# plot(time, p_summer)
# plot!(time, p_winter)
# plot!(time, p_shoulder)


using PowerModelsDistribution
using Ipopt
using Plots


case = Dict()
case[1] = "D014470"
case[2] = "D016907"
case[3] = "D023544" #segfault
case[4] = "D026799" #segfault
case[5] = "D032602" #segfault
case[6] = "D037763" #segfault
case[7] = "D045978"
# case[8] = "sourcebus_11000.trafo_75615289_75615289"
# case[9] = "sourcebus_11000.trafo_75617346_75617346"
# case[10] = "sourcebus_11000.trafo_75617582_75617582"
# case[11] = "sourcebus_22000.trafo_75612178_75612178"
# case[12] = "sourcebus_22000.trafo_75612672_75612672"
# case[13] = "sourcebus_22000.trafo_75616874_75616874"
# case[14] = "sourcebus_22000.trafo_75620917_75620917"

casename = "D037763"


loadphasemap = Dict((i,p)=>(i-1)*3+p for i in 1:floor(length(a)/3) for p in 1:3)

PF = 0.95
QtoP = tan(acos(PF))
for (_, casename) in case
    @show casename
    file = "data/"*casename*"/Master.dss"
    data = PowerModelsDistribution.parse_file(file)
    loadmap = Dict(l=>i for (i,(l,load)) in enumerate(data["load"]))
    
    results = Dict()
    for (i,t) in enumerate(tt) 
        data = PowerModelsDistribution.parse_file(file)

        for (l,load) in (data["load"])
            @show l
            @show loadmap[l]
            loadid = loadmap[l]
            ph_a = custids[loadphasemap[(loadid,1)]]
            ph_b = custids[loadphasemap[(loadid,2)]]
            ph_c = custids[loadphasemap[(loadid,3)]]
            @show ph_a, ph_b, ph_c
            
            p = [a[ph_a]["p"][i], a[ph_b]["p"][i], a[ph_c]["p"][i]]

            load["pd_nom"]=p
            load["qd_nom"]=QtoP.*p
        end

        results[i] = solve_mc_pf(data, ACPPowerModel, solver)
        results[i]["time"] = t
    end
    ##

    data = PowerModelsDistribution.parse_file(file)
    busmap = Dict(i=>n for (n,(i,bus)) in enumerate(data["bus"]))
    busmaprev = Dict(n=>i for (i,n) in busmap)

    ##
    function extract_voltages(results, data)
        n_bus = length(data["bus"])
        va = zeros(length(results), n_bus)
        vb = zeros(length(results), n_bus)
        vc = zeros(length(results), n_bus)
        for (t, timestep) in results
            for (i, bus) in timestep["solution"]["bus"]
                n = busmap[i]
                va[t,n] = bus["vm"][1]
                vb[t,n] = bus["vm"][2]
                vc[t,n] = bus["vm"][3]
            end
        end
        return (va, vb, vc)
    end

    (va,vb,vc) = extract_voltages(results, data)

    n_bus = length(data["bus"])
    ##
    p1 = boxplot(va, legend = false)
    title!("Phase a")
    # xlabel!("bus number")
    ylabel!("Voltage (kV)")
    plot!([0, n_bus], 0.230*[1.1, 1.1], linestyle = :dot, linecolor=:red)
    plot!([0, n_bus], 0.230*[0.94, 0.94], linestyle = :dot, linecolor=:red)
    p2 = boxplot(vb, legend = false)
    title!("Phase b")
    # xlabel!("bus number")
    ylabel!("Voltage (kV)")
    plot!([0, n_bus], 0.230*[1.1, 1.1], linestyle = :dot, linecolor=:red)
    plot!([0, n_bus], 0.230*[0.94, 0.94], linestyle = :dot, linecolor=:red)
    p3 = boxplot(vc, legend = false)
    title!("Phase c")
    xlabel!("Bus number (-)")
    ylabel!("Voltage L-N (kV)")
    plot!([0, n_bus], 0.230*[1.1, 1.1], linestyle = :dot, linecolor=:red)
    plot!([0, n_bus], 0.230*[0.94, 0.94], linestyle = :dot, linecolor=:red)


    p = plot(p1, p2, p3, layout = (3, 1), legend = false, size=(500,1000))
    savefig(p, casename*".pdf")


    ##
    sourcebus = data["voltage_source"]["source"]["bus"]
    sourceelements = [i for (i, line ) in data["line"] if line["f_bus"] == sourcebus]
    sourceelement =0
    if length(sourceelements) ==1
        sourceelement = sourceelements[1]
    else
        sourceelement = [i for (i, line ) in data["transformer"] if line["f_bus"] == sourcebus]
    end
    

    ##
    p = [result["solution"]["line"][sourceelement]["pf"] for (t,result) in results]
    pa = [v[1] for v in p]
    pb = [v[2] for v in p]
    pc = [v[3] for v in p]

    q= [result["solution"]["line"][sourceelement]["qf"] for (t,result) in results]
    qa = [v[1] for v in q]
    qb = [v[2] for v in q]
    qc = [v[3] for v in q]

    p1 = plot(tt, pa, label="Phase a")
    plot!(tt, pb, label="Phase b")
    plot!(tt, pc, label="Phase c")
    plot!(tt, pa+pb+pc, label="Sum")
    xlabel!("Time (h)")
    ylabel!("Power (kW)")

    #

    p2 = plot(tt, qa, label="Phase a")
    plot!(tt, qb, label="Phase b")
    plot!(tt, qc, label="Phase c")
    plot!(tt, qa+qb+qc, label="Sum")
    xlabel!("Time (h)")
    ylabel!("Reactive Power (kvar)")

    p = plot(p1, p2, layout = (2, 1), size=(500,500))
    savefig(p, casename*"power.pdf")
end
##


using ArgParse 
function parse_commandline() 
    s = ArgParseSettings() 
    @add_arg_table s begin 
        "--opt1" 
        "--opt2" 
        "--opt3" 
        "--opt4" 
    end 
    return parse_args(s) 
end 
parsed_args = parse_commandline()


using Plots
using StatsPlots
using RDatasets
school = RDatasets.dataset("mlmRev", "Hsb82")
x = string.(school.Sector)
y = school.MAch
g = string.(school.Sx)
println(x[1:3])
println(y[1:3])
println(g[1:3])
groupedboxplot(x, y, group=g)
