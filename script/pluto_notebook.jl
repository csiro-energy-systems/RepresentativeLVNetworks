using Pkg
using RepresentativeLVNetworks
path=pwd()
#path = joinpath(dirname(pathof(RepresentativeLVNetworks)),"..","script")
#path = joinpath(dirname(pathof(RepresentativeLVNetworks)),"..","notebooks")
Pkg.activate(path)
Pkg.instantiate()
Pkg.update()
# cd(path)



##
using Pluto
Pluto.run()