"""
    catmullrom(points, interpolants)

    `points` is a tuple of points-as-tuples
    `interpolants` is a tuple of values from 0.0 to 1.0 (inclusive)

interpolating points from points[2] through points[end-1] (inclusive)
"""
function catmullrom(points::PointSeq{M,D,R}, interpolants::ValueSeq{L,F}) where {L,F,M,D,R}
    npoints = length(points)
    npoints < 4 && throw(ErrorException("at least four points are required"))

    return points === 4 ? catmullrom_4points(points, interpolants) : catmullrom_npoints(points, interpolants)
end


# some of the following is adapted from https://ideone.com/NoEbVM

# compute Catmull-Rom cubic curve over [0, 1]
function catmullrom_cubic(x0::T, x1::T, x2::T, x3::T, dt0::T, dt1::T, dt2::T) where {T}
    # compute tangents when parameterized in [t1,t2]
    t1 = (x1 - x0) / dt0 - (x2 - x0) / (dt0 + dt1) + (x2 - x1) / dt1
    t2 = (x2 - x1) / dt1 - (x3 - x1) / (dt1 + dt2) + (x3 - x2) / dt2
 
    # rescale tangents for parametrization in [0,1]
    t1 *= dt1
    t2 *= dt1
 
    # return hermite cubic over [0,1]
    return hermite_cubic(x1, x2, t1, t2)
end

#=
   Compute coefficients for a cubic polynomial
     p(s) = c0 + c1*s + c2*s^2 + c3*s^3
   such that
     p(0) = x0, p(1) = x1
    and
     p'(0) = dx0, p'(1) = dx1.
=#
function hermite_cubic(x0::T, x1::T, dx0::T, dx1::T) where {T}
    c0 = x0
    c1 = dx0
    c2 = -3*x0 + 3*x1 - 2*dx0 - dx1
    c3 =  2*x0 - 2*x1 +   dx0 + dx1
    return Poly([c0, c1, c2, c3])
end


#=
   given four x-ordinate sequenced ND points
   obtain N polys, parameterized over [0,1]
   interpolating from p1 to p2 inclusive
   one poly for each coordinate axis
=#
function catmullrom_polys(points::PointSeq{M,D,R}) where {M,D,R}
    dt0, dt1, dt2 = prep_centripetal_catmullrom(points)
    pt0, pt1, pt2, pt3 = pts
    
    polys = Vector{Poly{eltype(points[1])}}(undef, N)

    for i=1:N
        polys[i] = catmullrom_cubic(pt0[i], pt1[i], pt2[i], pt3[i], dt0, dt1, dt2)
    end

    return polys
end


qrtrroot(x) = sqrt(sqrt(x))

#=
   determine the delta_traversal constants for the centripetal parameterization
      of the Catmull Rom cubic specified by four points (of increasing abcissae) 
=#
function prep_centripetal_catmullrom(points::PointSeq{M,D,R}) where {M,D,R}
    dt0 = qrtrroot(dot(pts[1], pts[2]))
    dt1 = qrtrroot(dot(pts[2], pts[3]))
    dt2 = qrtrroot(dot(pts[3], pts[4]))
 
    #safety check for repeated points
    if (dt1 < 1e-4) dt1 = 1.0 end
    if (dt0 < 1e-4) dt0 = dt1 end
    if (dt2 < 1e-4) dt2 = dt1 end
 
    return dt0, dt1, dt2   
 end

 
"""
    catmullrom_npoints(points, interpolants)

    `points` is a tuple of points-as-tuples
    `interpolants` is a tuple of values from 0.0 to 1.0 (inclusive)

interpolating points from points[2] through points[end-1] (inclusive)
"""
function catmullrom_npoints(points::PointSeq{M,D,R}, interpolants::ValueSeq{L,F}) where {L,F,M,D,R}
    points_per_interpolation = length(interpolants)
    totalinterps = (I-4+1)*(points_per_interpolation - 1) + 1 # -1 for the shared end|1 point
    
    allpoints = Array{T, 2}(undef, (totalinterps,D))
   
    niters = I - 5
   
    allpoints[1:points_per_interpolation,   :] = catmullrom_4points(points[1:4], interpolants)
   
    idx₁ = 2; idx₂ = idx₁ + 3; sub₁ = 0; mul₁ = 1 
    for k in 1:niters
        sub₂ = sub₁ - 1
        mul₂ = mul₁ + 1
        allpoints[(mul₁ * points_per_interpolation + sub₁):(mul₂ * points_per_interpolation + sub₂), :] =
            catmullrom_4points(points[idx₁:idx₂], interpolants)
        idx₁ += 1; idx₂ += 1;
        sub₁, mul₁ = sub₂, mul₂
    end
   
    allpoints[(end-points_per_interpolation+1):end, :] = catmullrom_4points(points[end-3:end], interpolants)
   
    return allpoints
end

#=
   given four ND points in increasing abcissae order
   and k+2 interpolant values in 0..1 where 0.0 and 1.0 are the +2
   determine the k+2 interpolant determined ND points
   where the first interpolant point is the second ND point
   and the final interplant point is the third ND point
=#
function catmullrom_4points(points::PointSeq{M,D,R}, interpolants::ValueSeq{L,F}) where {L,F,M,D,R}
    polys = catmullrom_polys(points)
    ninterps = length(interpolants)
    
    allpoints = Array{T, 2}(undef, (ninterps,D))
    for col in 1:D
        allpoints[1, col] = points[2][col]
        allpoints[end, col] = points[3][col]
    end
   
    ninterps -= 1
   
    for col in 1:D
        ply = polys[col]
        for row in 2:ninterps
            value = interpolants[row]
            allpoints[row, col] = polyval(ply, value)
        end
    end

    return allpoints
end


function catmullrom_allpolys(points::PointSeq{M,D,R}; 
                             deriv1::Bool=false, deriv2::Bool=false, integ1::Bool=false) where {M,D,R}
    polys = catmullrom_polys(points)
    
    d1polys = deriv1 ? polyder.(polys)    : nothing 
    d2polys = deriv2 ? polyder.(d1polys)  : nothing
    i1polys = integ1 ? polyint.(polys)    : nothing

    result = (polys, d1polys, d2polys, i1polys)
    return result
end
