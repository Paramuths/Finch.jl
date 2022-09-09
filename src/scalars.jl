mutable struct Scalar{D, Tv}# <: AbstractArray{Tv, 0}
    val::Tv
end

Scalar{D}(args...) where {D} = Scalar{D, typeof(D)}(args...)
Scalar{D, Tv}() where {D, Tv} = Scalar{D, Tv}(D)


@inline Base.ndims(tns::Scalar) = 0
#Base.ndims(tns::Scalar) = ndims(tns)
@inline Base.size(tns::Scalar) = ()
#Base.size(tns::Scalar) = size(tns)
@inline Base.axes(tns::Scalar) = ()
#Base.axes(tns::Scalar) = axes(tns)
@inline Base.eltype(tns::Scalar{D, Tv}) where {D, Tv} = Tv
#Base.eltype(tns::Scalar) = eltype(tns)
@inline default(tns::Scalar{D}) where {D} = D

function (tns::Scalar)()
    return tns.val
end

#function Base.getindex(tns::Scalar, idxs::Integer...) where {Tv, N}
#    tns(idxs...)
#end

struct VirtualScalar
    ex
    Tv
    D
    name
    val
end

(ctx::Finch.LowerJulia)(tns::VirtualScalar) = :($Scalar{$(tns.D), $(tns.Tv)}($(tns.val)))
function virtualize(ex, ::Type{Scalar{D, Tv}}, ctx, tag) where {D, Tv}
    sym = ctx.freshen(tag)
    val = Symbol(tag, :_val) #TODO hmm this is risky
    push!(ctx.preamble, quote
        $sym = $ex
        $val = $sym.val
    end)
    VirtualScalar(sym, Tv, D, tag, val)
end

getsize(::VirtualScalar, ctx, mode) = ()
getsites(::VirtualScalar) = []

@inline default(tns::VirtualScalar) = tns.D

isliteral(::VirtualScalar) = false

getname(tns::VirtualScalar) = tns.name
setname(tns::VirtualScalar, name) = VirtualScalar(tns.ex, tns.Tv, tns.D, name, tns.val)

function initialize!(tns::VirtualScalar, ctx, mode::Union{Write, Update}, idxs...)
    push!(ctx.preamble, quote
        $(tns.val) = $(tns.D)
    end)
    access(tns, mode, idxs...)
end

function finalize!(tns::VirtualScalar, ctx, mode)
    return tns
end

function (ctx::LowerJulia)(root::Access{<:VirtualScalar}, ::DefaultStyle)
    @assert isempty(root.idxs)
    tns = root.tns
    return tns.val
end