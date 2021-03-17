using Pkg
Pkg.activate("./")

##
using RepresentativeLVNetworks
using OpenDSSDirect

# filepaths = readdir(folder)
case = Dict()
case[1] = "D014470"
case[2] = "D016907"
case[3] = "D023544" #segfault
# case[4] = "D026799" #segfault
# case[5] = "D032602" #segfault
# case[6] = "D037763" #segfault
case[7] = "D045978"
case[8] = "sourcebus_11000.trafo_75615289_75615289"
case[9] = "sourcebus_11000.trafo_75617346_75617346"
case[10] = "sourcebus_11000.trafo_75617582_75617582"
case[11] = "sourcebus_22000.trafo_75612178_75612178"
case[12] = "sourcebus_22000.trafo_75612672_75612672"
case[13] = "sourcebus_22000.trafo_75616874_75616874"
case[14] = "sourcebus_22000.trafo_75620917_75620917"
##
# i = 7
# casename = case[i]
sols = Dict()
for (i, casename) in case
    file = "data/"*casename*"/Master.dss"
    cd("/Users/get050/Documents/Repositories/github/RepresentativeLVNetworks")
    sols[casename] = RepresentativeLVNetworks.run_dss!(file)
end
RepresentativeLVNetworks.check_voltages(sols)

##
# a = dss("""
#     clear
#     compile $file
#     solve
# """)

# Solution.Solve()
# Circuit.Losses()
# Circuit.TotalPower()
# Circuit.AllBusNames()
# Bus.VLL()
# Bus.Name()
# Bus.VMagAngle()

# ##


# # Circuit.AllBusVolts()

# v = bus_voltages()
# ##
# cd("/Users/get050/Documents/Repositories/github/RepresentativeLVNetworks")



# To validate
# - current relative to limits
# - power relative to limits
# - voltage drop per section
# - total load
# - maximum voltage drop overall
# - voltage unbalanced factor


