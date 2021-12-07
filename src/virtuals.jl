Base.@kwdef struct VirtualAbstractArray
    ndims
    name
    ex
end

virtual_expr(arr::VirtualAbstractArray) = arr.ex

function Pigeon.lower_axes(arr::VirtualAbstractArray, ctx::LowerJuliaContext) where {T <: AbstractArray}
    dims = map(i -> gensym(Symbol(arr.name, :_, i, :_stop)), 1:arr.ndims)
    push!(ctx.preamble, quote
        ($(dims...),) = size($(arr.ex))
    end)
    return map(i->Extent(1, Virtual{Int}(dims[i])), 1:arr.ndims)
end

function Pigeon.lower_axis_merge(ctx::Finch.LowerJuliaContext, a::Extent, b::Extent)
    push!(ctx.preamble, quote
        $(virtual_expr(a.start)) == $(virtual_expr(b.start)) || throw(DimensionMismatch("mismatched dimension starts"))
        $(virtual_expr(a.stop)) == $(virtual_expr(b.stop)) || throw(DimensionMismatch("mismatched dimension stops"))
    end)
    a #TODO could do some simplify stuff here
end
Pigeon.getsites(arr::VirtualAbstractArray) = 1:arr.ndims
Pigeon.getname(arr::VirtualAbstractArray) = arr.name

virtualize(ex, T) = Virtual{T}(ex)