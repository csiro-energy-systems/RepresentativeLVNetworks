# RepresentativeLVNetworks.jl
RepresentativeLVNetworks.jl is a package that contains some of the outputs from the "National Low-Voltage Feeder Taxonomy Study". This package heavily relies on OpenDSSDirect.jl, a wrapper for OpenDSS's calculation engine.

The package contains:
- the taxonomy data set (in `/data`)
- convenience functions for working with OpenDSSDirect.jl (in `src`)
- Pluto.jl notebooks (in `notebooks`) that explore: 
 1) multiperiod unbalanced power flow
 2) multiperiod unbalanced power flow with PV
 3) multiperiod unbalanced power flow with storage
 4) multiperiod unbalanced power flow with demand response through transformer tap changing (a.k.a. conservation voltage reduction)

 ## Installation instructions
Install:
- Visual studio code https://code.visualstudio.com/Download
- Julia 1.6 https://julialang.org/

Install the Julia plug-in for VSCode: https://www.julia-vscode.org/docs/dev/gettingstarted/#Installation-and-Configuration-1 

Installation instructions of RepresentativeLVNetworks.jl
 1) Unzip the file downloaded from NEAR (https://near.csiro.au/)
 2) Browser in VSCode to the root of the unzipped folder
 3) Open a Julia terminal within VSCode. E.g. menu 'view' -> 'command pallete' and type "Julia start REPL". Press enter
 4) if you type `pwd() [enter]` you should see the path of the unzipped folder.
 5) type: `include("script/initial_setup.jl") [enter]` to set up the environment

Running the notebooks of RepresentativeLVNetworks.jl
 1) Open a Julia terminal within VSCode. E.g. menu 'view' -> 'command pallete' and type "Julia start REPL". Press enter.
 2) In the VSCode file browser, go to the `/notebooks` folder and choose a notebook to run, e.g. `multiperiod.jl` and right-click to 'copy path'.
 3) Type: `include("script/pluto_launch.jl") [enter]` to launch Pluto.jl
 4) In the 'open from file' text box, paste the path and click 'open'.
 5) Julia will now just-in-time compile a lot of code, which means you'll have to wait about 3 minutes before the notebook becomes interactive. 
 6) 



## Resources
- https://discourse.julialang.org/
- https://www.youtube.com/c/TheJuliaLanguage 

## Acknowledgements
This work received funding from ARENA, the Australian Renewable Energy Agency. The views expressed herein are not necessarily the views of the Australian government, and the Australian government does not accept responsibility for any information or advice contained herein.

CSIRO contributors to this code include:
- Thomas Brinsmead
- Rahmat Heidarihaei
- Matt Amos

## TODO
- add link to NEAR
- pluto use instructions
- where to find saved figures


