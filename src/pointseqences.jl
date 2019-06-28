# The sorts of sequences understood to hold point coordinates
const VecNumVec = AbstractArray{Array{T,1},1} where {T<:Number};
const VecNumTup = AbstractArray{NTuple{N,T},1} where {N,T<:Number};
const TupNumTup = NTuple{M,NTuple{N,T}} where {M,N,T<:Number};
const TupNumVec = NTuple{M,Array{T,1}} where {M,N,T<:Number};
const VecNumNT = AbstractArray{NamedTuple{S,NTuple{N,T}},1} where {S,N,T<:Number};
const TupNumNT = NTuple{M,NamedTuple{S,NTuple{N,T}}} where {M,S,N,T<:Number};

const Points = Union{VecNumVec, VecNumTup, TupNumTup, TupNumVec, VecNumNT, TupNumNT};

npoints(pts::Points) = length(pts)
ndims(pts::Points) = eltype(pts) <: NamedTuple ? length(Tuple(pts[1])) : length(pts[1])