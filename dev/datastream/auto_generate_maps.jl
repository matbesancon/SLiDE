using CSV
using Dates
using DataFrames
using DelimitedFiles
using XLSX
using YAML
using InteractiveUtils
const IU = InteractiveUtils

using SLiDE  # see src/SLiDE.jl

function SLiDE.edit_with(df::DataFrame, x::Match)
    if x.on == r"expand range"
        ROWS, COLS = size(df)
        cols = names(df)
        df = [[DataFrame(Dict(cols[jj] =>
                cols[jj] == x.input ? SLiDE._expand_range(df[ii,jj]) : df[ii,jj]
            for jj in 1:COLS)) for ii in 1:ROWS]...;]
    else
        # Ensure all row values are strings and can be matched with a Regex, and do so.
        # Temporarily remove missing values, just in case.
        df[:,x.input] .= convert_type.(String, df[:,x.input])
        col = edit_with(copy(df), Replace(x.input, missing, ""))[:,x.input]
        m = match.(x.on, col)
        
        # Add empty columns for all output columns not already in the DataFrame.
        # Where there is a match, fill empty cells. If values in the input column,
        # leave cells without a match unchanged.
        df = edit_with(df, Add.(setdiff(x.output, names(df)), ""))
        [m[ii] != nothing && ([df[ii,out] = m[ii][out] for out in x.output])
            for ii in 1:length(m)]
    end
    return df
end


# function SLiDE.write_yaml(path, file::XLSXInput)
#     # List all key words in the yaml file and use to add (purely aesthetic) spacing.
#     KEYS = string.([IU.subtypes.(IU.subtypes(DataStream))...; "PathIn"], ":")
    
#     # Read the XLSX file, identify relevant (not "missing"), and generate list of resultant
#     # yaml file names.
#     df_all = read_file(path, file)
#     df_all = df_all[:, .!occursin.(:missing, names(df_all))]

#     # Make sure the path exists and save the names of yaml names to generaate.
#     path = joinpath(SLIDE_DIR, path, file.sheet)
#     !isdir(path) && mkpath(path)
#     filenames = joinpath.(path, string.(names(df_all), ".yml"))

#     # Iterate through columns. For each column, create a new yaml file and fill it with
#     # the column text. Mark the yaml file as "Autogenerated" and ensure one space only
#     # between each input file element that corresponds with a SLiDE Datastream subtype.
#     for COL in 1:size(df_all,2)
#         println("Generating ", filenames[COL])
        
#         # Remove all lines that do not contain text.
#         # df_all = edit_with(df_all, names(df_all)[COL], " ", missing))
#         lines = dropmissing(df_all, COL)[:,COL]
#         lines = lines[match.(r"\S.*", lines) .!= nothing]

#         open(filenames[COL], "w") do f
#             println(f, string("# Autogenerated from ", file.name))
#             for line in lines
#                 any(occursin.(KEYS, line)) && (println(f, ""))
#                 println(f, line)
#             end
#         end
#     end
#     return filenames
# end


function SLiDE.edit_with(df::DataFrame, x::Replace)
    !(x.col in names(df)) && (return df)

    if x.from === missing && Symbol(x.to) in names(df)
        df[ismissing.(df[:,x.col]),x.col] .= df[ismissing.(df[:,x.col]), Symbol(x.to)]
        return df
    end

    df[!,x.col] .= if x.to === "lower"  lowercase.(df[:,x.col])
    elseif x.to === "upper"             uppercase.(df[:,x.col])
    elseif x.to === "uppercasefirst"    uppercasefirst.(lowercase.(df[:,x.col]))
    elseif x.to === "titlecase"         titlecase.(df[:,x.col])
    else
        replace(strip.(copy(df[:,x.col])), x.from => x.to)
    end
    return df
end



function SLiDE.edit_with(df::DataFrame, x::Map; kind = :left)
    # Save all input column names, read the map file, and isolate relevant columns.
    # # This prevents duplicate columns in the final DataFrame.
    cols = unique([names(df); x.output])
    df_map = copy(read_file(x))
    df_map = unique(df_map[:,unique([x.from; x.to])])
    
    # If there are duplicate columns in from/to, differentiate between the two to save results.
    duplicates = intersect(x.from, x.to)
    if length(duplicates) > 0
        (ii_from, ii_to) = (occursin.(duplicates, x.from), occursin.(duplicates, x.to));
        x.from[ii_from] = Symbol.(x.from[ii_from], :_0)
        [df_map[!,Symbol(col, :_0)] .= df_map[:,col] for col in duplicates]
    end
    
    # Rename columns in the mapping DataFrame to temporary values in case any of these
    # columns were already present in the input DataFrame.
    temp_to = Symbol.(:to_, 1:length(x.to))
    temp_from = Symbol.(:from_, 1:length(x.from))
    df_map = edit_with(df_map, Rename.([x.to; x.from], [temp_to; temp_from]))

    # Ensure the input and mapping DataFrames are consistent in type. Types from the mapping
    # DataFrame are used since all values in each column should be of the same type.
    # Ensure the input and mapping DataFrames are consistent in type. Types from the mapping
    # DataFrame are used since all values in each column should be of the same type.
    for (col, col_map) in zip(x.input, temp_from)
        try
            new_type = eltypes(dropmissing(df_map[:,[col_map]]))
            df[!,col] .= convert_type.(new_type, df[:,col])
        catch
            df_map[!,col_map] .= convert_type.(String, df_map[:,col_map])
        end
    end

    
    
    # types = [eltypes(dropmissing(df[:,x.input])) eltypes(dropmissing(df_map[:,temp_from]))]
    # types = [any(row .== String) ? String : row[end] for row in eachrow(types)]
    # for (col, col_map, type) in zip(x.input, temp_from, types)
    #     df[!,col] .= convert_type.(type, df[:,col])
    #     df_map[!,col_map] .= convert_type.(type, df_map[:,col_map])
    # end
            
    df = join(df, df_map, on = Pair.(x.input, temp_from); kind = x.kind, makeunique = true)
    
    # Remove all output column names that might already be in the DataFrame. These will be
    # overwritten by the columns from the mapping DataFrame. Finally, remane mapping "to"
    # columns from their temporary to output values.
    df = df[:, setdiff(names(df), x.output)]
    df = edit_with(df, Rename.(temp_to, x.output))
    return df[:,cols]
end



READ_DIR = joinpath("data", "readfiles")

files_map = [
    XLSXInput("generate_yaml.xlsx", "map_parse",     "B1:Z150", "map_parse"),
    XLSXInput("generate_yaml.xlsx", "map_scale",     "B1:Z150", "map_scale"),
    XLSXInput("generate_yaml.xlsx", "map_bluenote",  "B1:Z150", "map_bluenote"),
    XLSXInput("generate_yaml.xlsx", "map_crosswalk", "B1:Z150", "map_crosswalk")
]

files_map = write_yaml(READ_DIR, files_map)
y_read = [read_file(files_map[ii]) for ii in 1:length(files_map)]

files_map = run_yaml(files_map)

include(joinpath(SLIDE_DIR, "dev", "datastream", "adjust_maps.jl"))
df = [read_file(joinpath(y_read[ii]["PathOut"]...)) for ii in 1:length(y_read)];

# ******************************************************************************************
# EDIT MANUALLY TO CHECK:
# ii_file = length(y_read);
# y = y_read[ii_file];
# files = [[y[k] for k in collect(keys(y))[occursin.("Input", keys(y))]]...;]

# ii_input = 1;
# for ii_input in 1:1
#     file = files[ii_input]
#     println(file)
#     global df = read_file(y["PathIn"], file)

#     "Drop"     in keys(y) && (df = edit_with(df, y["Drop"]))
#     "Rename"   in keys(y) && (df = edit_with(df, y["Rename"]))
#     "Group"    in keys(y) && (df = edit_with(df, y["Group"]))
#     "Stack"    in keys(y) && (df = edit_with(df, y["Stack"]))
#     "Match"    in keys(y) && (df = edit_with(df, y["Match"]))
#     "Melt"     in keys(y) && (df = edit_with(df, y["Melt"]))
#     "Add"      in keys(y) && (df = edit_with(df, y["Add"]))
#     "Map"      in keys(y) && (df = edit_with(df, y["Map"]))
#     "Replace"  in keys(y) && (df = edit_with(df, y["Replace"]))
#     "Drop"     in keys(y) && (df = edit_with(df, y["Drop"]))
#     "Operate"  in keys(y) && (df = edit_with(df, y["Operate"]))
#     "Describe" in keys(y) && (df = edit_with(df, y["Describe"], file))
#     "Order"    in keys(y) && (df = edit_with(df, y["Order"]))
# end