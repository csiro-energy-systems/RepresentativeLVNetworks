cd("/Users/get050/Documents/repositories/GitHub/RepresentativeLVNetworks/data")
using Pkg
Pkg.activate("./")

#
using RepresentativeLVNetworks
using OpenDSSDirect

# filepaths = readdir(folder)
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

i = 5
file = case[i]*"/Master.dss"

path = joinpath(dirname(pathof(RepresentativeLVNetworks)),"..","data", case[i])
cd(path)
result = RepresentativeLVNetworks.dss!("Master.dss", "Snap")
@show case[i]
##

sols = Dict()
for (i, casename) in case
    @show casename
    path = joinpath(dirname(pathof(RepresentativeLVNetworks)),"..","data", case[i])
    cd(path)
    sols[casename] = RepresentativeLVNetworks.dss!("Master.dss", "Snap")
end

##
RepresentativeLVNetworks.check_voltages(sols)

