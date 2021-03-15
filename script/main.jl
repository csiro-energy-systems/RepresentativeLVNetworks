using Pkg
Pkg.activate("./")

##
using RepresentativeLVNetworks
using OpenDSSDirect
file = "data/D016907/Master.dss"

##
cd("/Users/get050/Documents/Repositories/github/RepresentativeLVNetworks")
sol = RepresentativeLVNetworks.run_dss!(file)



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