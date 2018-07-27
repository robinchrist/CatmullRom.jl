__precompile__()

module CatmullRom

export catmullrom,    # points, interpolants --> points, interpolated points
       Omit, Linear, Quadratic, Thiele3,
       Open, Closed,
       uniformspacing, into01,
       Poly, polyval, polyder, polyint  # reexported

using Polynomials
import Polynomials: Poly, polyval, polyder, polyint

import LinearAlgebra: dot, norm

include("consts.jl")
include("unions.jl")
include("catmullrom.jl")
include("interpolant.jl")

end # module CentripetalCatmullRom
