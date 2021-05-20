cd("/Users/get050/Documents/repositories/GitHub/RepresentativeLVNetworks")
using Pkg
Pkg.activate("./")

##
using RepresentativeLVNetworks
using OpenDSSDirect

# filepaths = readdir(folder)
case = Dict()

case[1] = "D003278" 
case[2] = "D009819"
case[3] = "D014683"
case[4] = "D023303" 
case[5] = "D037984" 
case[6] = "D047205"
case[7] = "D049759" 
case[8] = "D052609" 
case[9] = "D058461" 
case[10] = "sourcebus_11000.118_744"
case[11] = "sourcebus_11000.130_1438"
case[12] = "sourcebus_11000.trafo_75585177_75585177"
case[13] = "sourcebus_11000.trafo_75588995_75588995"
case[14] = "sourcebus_11000.trafo_75589759_75589759"
case[15] = "sourcebus_11000.trafo_75592323_75592323"
case[16] = "sourcebus_11000.trafo_75604448_75604448"
case[17] = "sourcebus_11000.trafo_75615289_75615289"
case[18] = "sourcebus_11000.trafo_75617346_75617346"
case[19] = "sourcebus_22000.trafo_75612682_75612682"
case[20] = "sourcebus_22000.trafo_75618991_75618991"
case[21] = "sourcebus_22000.trafo_75621868_75621868"
case[22] = "sourcebus_22000.trafo_75628143_75628143"
case[23] = "sourcebus_22000.trafo_75628932_75628932"

i = 9
file = "k23/"*case[i]*"/Master.dss"
##
cd("/Users/get050/Documents/repositories/GitHub/RepresentativeLVNetworks")
RepresentativeLVNetworks.run_dss!(file)
##










sols = Dict()
for (i, casename) in case
    file = "data/"*casename*"/Master.dss"
    cd("/Users/get050/Documents/repositories/GitHub/RepresentativeLVNetworks")
    @show casename
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




##
alpha = exp(2pi*im/3)
A = [1 1 1; 1 alpha alpha^2; 1 alpha^2 alpha ]

Zabcn = []

Zabc = [1 0 0 ; 0 0 0 ; 0 0 0]

Zabc = [1 1 0 ; 1 1 0 ; 0 0 0]

Zabc = [1 1 1 ; 1 1 1 ; 1 1 1]

Zabc =[ 1.3238+im*1.3569   0.0000+im*0.0000   0.2066+im*0.4591;
        0.0000+im*0.0000  0.0000+im*0.0000   0.0000+im*0.0000;
        0.2066+im*0.4591   0.0000+im*0.0000  1.3294+im*1.3471] 


# Zabc =[  0.3465+im*1.0179   0.1560+im*0.5017   0.1580+im*0.4236;
# 0.1560+im*0.5017  0.3375+im*1.0478   0.1535+im*0.3849;
# 0.1580+im*0.4236   0.1535+im*0.3849              0.3414+im*1.0348] 


Z012 = inv(A)*Zabc*A
Z012

Z00 = Z012[1,1]
Z11 = Z012[2,2]
Z22 = Z012[3,3]

Z00/Z11