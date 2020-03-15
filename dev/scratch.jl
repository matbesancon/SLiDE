using Complementarity
using CSV
using Dates
using DataFrames
using DelimitedFiles
using JuMP
using Revise
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

READ_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data", "readfiles"))
x = XLSXInput("generate_yaml.xlsx", "2_standardize", "B1:Z150", "std")

df_all = read_file(READ_DIR, x)



function write_yaml(path, file)
    
    KEYS = string.(string.([subtypes.(subtypes(SLiDE.DataStream))...; ["Path", "PathOut"]]), ":")
    df_all = read_file(path, file)

    for COL in 1:size(df_all,2)

        filename = string(names(df_all)[COL], ".yml")
        occursin("missing", filename) ? continue : println("Generating ", filename)
        
        lines = dropmissing(df_all, COL)[:,COL]
        open(joinpath(path, x.sheet, filename), "w") do f
            println(f, string("# Autogenerated from ", file.name))
            for line in lines
                any(occursin.(KEYS, line)) ? println(f, "") : nothing
                println(f, line)
            end
        end
    end
end

write_yaml(READ_DIR, x)

READ_DIR = joinpath(READ_DIR, x.sheet)

println("")
# for col in names(df_all)[19:end]
#     filename = string(col, ".yml")
#     occursin("missing", filename) ? continue : println(string("Standardizing ", filename))
#     y = read_file(joinpath(READ_DIR, string(col, ".yml")));
#     df = unique(edit_with(y))
#     CSV.write(joinpath(y["PathOut"]...), df)
# end

file = joinpath(READ_DIR, "bea_gsp_county.yml")
y = read_file(file)
# df = read_file(y["Path"], y["XLSXInput"][1])
# y = YAML.load(open(file))



# x = ["std", "region.csv"]


# y = read_file(joinpath(READ_DIR, "cfs.yml"))
# df = read_file(y["Path"], y["CSVInput"][1])
# df = edit_with(df, y["Drop"])
# df = edit_with(df, y["Rename"])
# df = edit_with(df, y["Match"])
# df = edit_with(df, y["Map2"])
# df = edit_with(df, y["Replace"])
# df = unique(edit_with(y))
# CSV.write(joinpath(y["PathOut"]...), df)



# y = read_file(joinpath(READ_DIR, "sgf_1997.yml"));
# df = unique(edit_with(y))
# CSV.write(joinpath(y["PathOut"]...), df)

# y = read_file(joinpath(READ_DIR, "sgf_1998.yml"));
# df = unique(edit_with(y))
# CSV.write(joinpath(y["PathOut"]...), df)

# y = read_file(joinpath(READ_DIR, "sgf_1999-2011.yml"))
# df = unique(edit_with(y))
# CSV.write(joinpath(y["PathOut"]...), df)



# y = read_file(joinpath(READ_DIR, "sgf_2012-2013.yml"))
# df = read_file(y["Path"], y["CSVInput"][2])
# df = edit_with(df, y["Drop"])
# df = edit_with(df, y["Rename"])
# df = edit_with(df, y["Melt"])
# df = edit_with(df, y["Map2"])
# df = edit_with(df, y["Replace"])
# df = unique(edit_with(y))



# x = y["Replace"]

# any(ismissing.(df[:,x.col])) ? df[!,x.col] .= convert_type.(String, df[:,x.col]) : nothing

# (x.col in names(df)) & (x.from in df[:,x.col])




# df[!, x.col][strip.(df[:, x.col]) .== x.from] .= x.to


# CSV.write(joinpath(y["PathOut"]...), df)

# y = read_file(joinpath(READ_DIR, "sgf_2014-2016.yml"))
# df = unique(edit_with(y))
# CSV.write(joinpath(y["PathOut"]...), df)


