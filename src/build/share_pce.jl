using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query

using SLiDE

"""
    share_pce!(d::Dict)
`pce`: Regional shares of final consumption
"""
function share_pce!(d::Dict)
    println("  Calculating regional shares of final consumption")
    d[:pce] /= transform_over(d[:pce], :r)
    verify_over(d[:pce],:r) !== true && @error("PCE shares don't sum to 1.")
    return d[:pce]
end

# share_pce!(d)
# benchmark!(nshr_comp, :pce, bshr, d)