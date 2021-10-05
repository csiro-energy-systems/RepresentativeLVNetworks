folder = "/Users/hei06j/Documents/repositories/remote/RepresentativeLVNetworks/data copy"



for case in readdir(folder)

    (tmppath, tmpio) = mktemp()
    file = folder*"/"*case*"/"*"Master.dss"
        open(file) do io
            for line in eachline(io, keep=true)
                if occursin("New Circuit", line) && ~occursin("phases", line)
                    line = line*" phases=3"
                end
                write(tmpio, line)
            end
        end
    close(tmpio)
    mv(tmppath, file, force=true)   

    (tmppath, tmpio) = mktemp()
    file = folder*"/"*case*"/"*"Loads.dss"
        open(file) do io
            for line in eachline(io, keep=true)
                if occursin("Phases=4", line) && occursin("1.2.3 ", line)
                    line = replace(line, "Phases=4" => "Phases=3")
                end
                write(tmpio, line)
            end
        end
    close(tmpio)
    mv(tmppath, file, force=true)  

    (tmppath, tmpio) = mktemp()
    file = folder*"/"*case*"/"*"LineCodes.dss"
        open(file) do io
            @show file
            for line in eachline(io, keep=true)
                if occursin("Cmatrix", line) && occursin("C1", line)
                    line = split(line, "Cmatrix")[1] * split(line, "Cmatrix")[2][108:end]
                end
                if occursin("Faultrate=0.1", line)
                    line = split(line, "Faultrate=0.1")[1] * split(line, "Faultrate=0.1")[2]
                end
                if occursin("BaseFreq=50", line)
                    line = split(line, "BaseFreq=50")[1] * split(line, "BaseFreq=50")[2]
                end
                if occursin("normamps=400.0", line)
                    line = split(line, "normamps=400.0")[1] * split(line, "normamps=400.0")[2]
                end
                if occursin("emergamps=600.0", line)
                    line = split(line, "emergamps=600.0")[1] * split(line, "emergamps=600.0")[2]
                end
                if occursin("R1=0.0", line)
                    line = replace(line, "R1=0.0" => "R1=0.01")
                    line = replace(line, "R0=0.0" => "R0=0.01")
                    line = replace(line, "X1=0.0" => "X1=0.01")
                    line = replace(line, "X0=0.0" => "X0=0.01")
                end
                write(tmpio, line)
            end
        end
    close(tmpio)
    mv(tmppath, file, force=true)  

end
