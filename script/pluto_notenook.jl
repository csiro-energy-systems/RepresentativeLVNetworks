using Pkg
path = joinpath(dirname(pathof(RepresentativeLVNetworks)),"..","script")
Pkg.activate(path)
cd(path)

using Pluto
Pluto.run()