using Pkg
Pkg.activate("./")

##
using RepresentativeLVNetworks
using OpenDSSDirect
file = "data/D016907/Master.dss"

##
# run_dss!(file)


##
a = dss("""
    clear
    compile $file
    solve
""")

Solution.Solve()
Circuit.Losses()
Circuit.TotalPower()
Circuit.AllBusNames()
# #
Bus.VLL()
Bus.Name()
Bus.VMagAngle()

Circuit.AllBusVolts()