cd("C:/Users/Frederik Geth/Documents/GitHub/RepresentativeLVNetworks/data")
using Pkg
Pkg.activate("./")

##
using RepresentativeLVNetworks
using OpenDSSDirect

# filepaths = readdir(folder)
case = Dict()

case[1] = "11000.118_744"
case[2] = "11000.130_1438"
case[3] = "11000.trafo_75586070_75586070_2"
case[4] = "11000.trafo_75586990_75586990"
case[5] = "11000.trafo_75594672_75594672"
case[6] = "11000.trafo_75605182_75605182"
case[7] = "11000.trafo_75617346_75617346"
case[8] = "11000.trafo_75619308_75619308_1"
case[9] = "22000.50-3185-substation_site133534_856"
case[10] = "22000.trafo_75589197_75589197"
case[11] = "22000.trafo_75609294_75609294"
case[12] = "22000.trafo_75616217_75616217"
case[13] = "22000.trafo_75618801_75618801_3"
case[14] = "22000.trafo_75628065_75628065"
case[15] = "D002900"
case[16] = "D009819"
case[17] = "D014470"
case[18] = "D022565"
case[19] = "D031431"
case[20] = "D035190"
case[21] = "D049573"
case[22] = "D052609"
case[23] = "D058461"



i = 9
file = "data/"*case[i]*"/Master.dss"
##
cd("C:/Users/Frederik Geth/Documents/GitHub/RepresentativeLVNetworks/data")
RepresentativeLVNetworks.run_dss!(file)
##










sols = Dict()
for (i, casename) in case
    file = "data/"*casename*"/Master.dss"
    cd("C:/Users/Frederik Geth/Documents/GitHub/RepresentativeLVNetworks/data")
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