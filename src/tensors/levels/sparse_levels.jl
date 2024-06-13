struct DictTable{Ti, Tp, Ptr, Idx, Val, Tbl}
    ptr::Ptr
    idx::Idx
    val::Val
    tbl::Tbl
end

Base.:(==)(a::DictTable, b::DictTable) =
    a.ptr == b.ptr &&
    a.idx == b.idx &&
    a.val == b.val &&
    a.tbl == b.tbl

DictTable{Ti, Tp}() where {Ti, Tp} =
    DictTable{Ti, Tp}(Tp[1], Ti[], Tp[], Dict{Tuple{Tp, Ti}, Tp}())
DictTable{Ti, Tp}(ptr::Ptr, idx::Idx, val::Val, tbl::Tbl) where {Ti, Tp, Ptr, Idx, Val, Tbl} =
    DictTable{Ti, Tp, Ptr, Idx, Val, Tbl}(ptr, idx, val, tbl)

function table_coords(tbl::DictTable{Ti, Tp}, pos) where {Ti, Tp}
    @view tbl.idx[tbl.ptr[pos]:tbl.ptr[pos + 1] - 1]
end

function declare_table!(tbl::DictTable{Ti, Tp}, pos) where {Ti, Tp}
    resize!(tbl.ptr, pos + Tp(1))
    fill_range!(tbl.ptr, 0, pos + Tp(1), pos + Tp(1))
    empty!(tbl.tbl)
    return Tp(0)
end

function assemble_table!(tbl::DictTable, pos_start, pos_stop)
    resize_if_smaller!(tbl.ptr, pos_stop + 1)
    fill_range!(tbl.ptr, 0, pos_start + 1, pos_stop + 1)
end

function freeze_table!(tbl::DictTable, pos_stop)
    max_pos = maximum(tbl.ptr)
    resize!(tbl.ptr, pos_stop + 1)
    tbl.ptr[1] = 1
    for p = 2:pos_stop + 1
        tbl.ptr[p] += tbl.ptr[p - 1]

    end

    resize!(tbl.idx, length(tbl.tbl))
    resize!(tbl.val, length(tbl.tbl))
    pos_pts = copy(tbl.ptr)
    for ((p, i), v) in pairs(tbl.tbl)
        pos = pos_pts[p]
        tbl.idx[pos] = i
        tbl.val[pos] = v
        pos_pts[p] += 1
    end

    # To reduce allocations, we pre-allocate the workspaces for perm, idx, and val
    perm_vec = Vector{Int64}(undef, max_pos)
    idx_temp = typeof(tbl.idx)(undef, max_pos)
    val_temp = typeof(tbl.val)(undef, max_pos)
    for p = 1:pos_stop
        start = tbl.ptr[p]
        stop = tbl.ptr[p+1] - 1
        perm = perm_vec[1:stop-start+1]
        sortperm!(perm, tbl.idx[start:stop])
        # Store the correctly permuted version of the idxs and vals in a temporary
        for i in eachindex(perm)
            idx_temp[i] = tbl.idx[start + perm[i] - 1]
            val_temp[i] = tbl.val[start + perm[i] - 1]
        end
        # Overwrite the segment of the idx and vals array with the correct order
        for i in eachindex(perm)
            tbl.idx[start + i - 1] = idx_temp[i]
            tbl.val[start + i - 1] = val_temp[i]
        end
    end
    return tbl.ptr[pos_stop + 1] - 1
end

function thaw_table!(tbl::DictTable, pos_stop)
    qos_stop = tbl.ptr[pos_stop + 1] - 1
    for p = pos_stop:-1:1
        tbl.ptr[p + 1] -= tbl.ptr[p]
    end
    qos_stop
end

function table_length(tbl::DictTable)
    return length(tbl.ptr) - 1
end

function moveto(tbl::DictTable, arch)
    error(
        "The table type $(typeof(tbl)) does not support moveto. ",
        "Please use a table type that supports moveto."
    )
end

table_isdefined(tbl::DictTable{Ti, Tp}, p) where {Ti, Tp} = p + 1 <= length(tbl.ptr)

table_pos(tbl::DictTable{Ti, Tp}, p) where {Ti, Tp} = tbl.ptr[p + 1]

table_query(tbl::DictTable{Ti, Tp}, p) where {Ti, Tp} = (p, tbl.ptr[p], tbl.ptr[p + 1])

subtable_init(tbl::DictTable{Ti}, (p, start, stop)) where {Ti} = start < stop ? (tbl.idx[start], tbl.idx[stop - 1], start) : (Ti(1), Ti(0), start)

subtable_next(tbl::DictTable, (p, start, stop), q) = q + 1

subtable_get(tbl::DictTable, (p, start, stop), q) = (tbl.idx[q], tbl.val[q])

function subtable_seek(tbl, subtbl, state, i, j)
    while i < j
        state = subtable_next(tbl, subtbl, state)
        (i, q) = subtable_get(tbl, subtbl, state)
    end
    return (i, state)
end

function subtable_seek(tbl::DictTable, (p, start, stop), q, i, j)
    q = Finch.scansearch(tbl.idx, j, q, stop - 1)
    return (tbl.idx[q], q)
end

function table_register(tbl::DictTable, pos)
    pos
end

function table_commit!(tbl::DictTable, pos)
end

function subtable_register(tbl::DictTable, pos, idx)
    return get(tbl.tbl, (pos, idx), length(tbl.tbl) + 1)
end

function subtable_commit!(tbl::DictTable, pos, qos, idx)
    if qos > length(tbl.tbl)
        tbl.tbl[(pos, idx)] = qos
        tbl.ptr[pos + 1] += 1
    end
end

"""
    SparseLevel{[Ti=Int], [Tp=Int], [Tbl=TreeTable]}(lvl, [dim])

A subfiber of a sparse level does not need to represent slices `A[:, ..., :, i]`
which are entirely [`fill_value`](@ref). Instead, only potentially non-fill
slices are stored as subfibers in `lvl`.  A datastructure specified by Tbl is used to record which
slices are stored. Optionally, `dim` is the size of the last dimension.

`Ti` is the type of the last fiber index, and `Tp` is the type used for
positions in the level. The types `Ptr` and `Idx` are the types of the
arrays used to store positions and indicies.

```jldoctest
julia> Tensor(Dense(Sparse(Element(0.0))), [10 0 20; 30 0 0; 0 0 40])
3×3-Tensor
└─ Dense [:,1:3]
   ├─ [:, 1]: Sparse (0.0) [1:3]
   │  ├─ [1]: 10.0
   │  └─ [2]: 30.0
   ├─ [:, 2]: Sparse (0.0) [1:3]
   └─ [:, 3]: Sparse (0.0) [1:3]
      ├─ [1]: 20.0
      └─ [3]: 40.0

julia> Tensor(Sparse(Sparse(Element(0.0))), [10 0 20; 30 0 0; 0 0 40])
3×3-Tensor
└─ Sparse (0.0) [:,1:3]
   ├─ [:, 1]: Sparse (0.0) [1:3]
   │  ├─ [1]: 10.0
   │  └─ [2]: 30.0
   └─ [:, 3]: Sparse (0.0) [1:3]
      ├─ [1]: 20.0
      └─ [3]: 40.0

```
"""
struct SparseLevel{Ti, Tbl, Lvl} <: AbstractLevel
    lvl::Lvl
    shape::Ti
    tbl::Tbl
end
const Sparse = SparseLevel
const SparseDict = SparseLevel
SparseLevel(lvl) = SparseLevel{Int}(lvl)
SparseLevel(lvl, shape::Ti) where {Ti} = SparseLevel{Ti}(lvl, shape)
SparseLevel{Ti}(lvl) where {Ti} = SparseLevel{Ti}(lvl, zero(Ti))
SparseLevel{Ti}(lvl, shape) where {Ti} = SparseLevel{Ti}(lvl, shape, DictTable{Ti, postype(lvl)}())

SparseLevel{Ti}(lvl::Lvl, shape, tbl::Tbl) where {Ti, Lvl, Tbl} =
    SparseLevel{Ti, Tbl, Lvl}(lvl, shape, tbl)

Base.summary(lvl::SparseLevel) = "Sparse($(summary(lvl.lvl)))"
similar_level(lvl::SparseLevel, fill_value, eltype::Type, dim, tail...) =
    Sparse(similar_level(lvl.lvl, fill_value, eltype, tail...), dim)

function postype(::Type{SparseLevel{Ti, Tbl, Lvl}}) where {Ti, Tbl, Lvl}
    return postype(Lvl)
end

Base.resize!(lvl::SparseLevel{Ti}, dims...) where {Ti} =
    SparseLevel{Ti}(resize!(lvl.lvl, dims[1:end-1]...), dims[end], lvl.tbl)

function moveto(lvl::SparseLevel{Ti, Tbl, Lvl}, Tm) where {Ti, Tbl, Lvl}
    lvl_2 = moveto(lvl.lvl, Tm)
    tbl_2 = moveto(lvl.tbl, Tm)
    return SparseLevel{Ti}(lvl_2, lvl.shape, tbl_2)
end

function countstored_level(lvl::SparseLevel, pos)
    pos == 0 && return countstored_level(lvl.lvl, pos)
    countstored_level(lvl.lvl, table_pos(lvl.tbl, pos) - 1)
end

pattern!(lvl::SparseLevel{Ti}) where {Ti} =
    SparseLevel{Ti}(pattern!(lvl.lvl), lvl.shape, lvl.tbl)

set_fill_value!(lvl::SparseLevel{Ti}, init) where {Ti} =
    SparseLevel{Ti}(set_fill_value!(lvl.lvl, init), lvl.shape, lvl.tbl)

function Base.show(io::IO, lvl::SparseLevel{Ti, Tbl, Lvl}) where {Ti, Tbl, Lvl}
    if get(io, :compact, false)
        print(io, "Sparse(")
    else
        print(io, "Sparse{$Ti}(")
    end
    show(io, lvl.lvl)
    print(io, ", ")
    show(IOContext(io, :typeinfo=>Ti), lvl.shape)
    print(io, ", ")
    if get(io, :compact, false)
        print(io, "…")
    else
        show(io, lvl.tbl)
    end
    print(io, ")")
end

labelled_show(io::IO, fbr::SubFiber{<:SparseLevel}) =
    print(io, "Sparse (", fill_value(fbr), ") [", ":,"^(ndims(fbr) - 1), "1:", size(fbr)[end], "]")

function labelled_children(fbr::SubFiber{<:SparseLevel})
    lvl = fbr.lvl
    pos = fbr.pos
    table_isdefined(lvl.tbl, pos) || return []
    subtbl = table_query(lvl.tbl, pos)
    i, stop, state = subtable_init(lvl.tbl, subtbl)
    res = []
    while i <= stop
        (i, q) = subtable_get(lvl.tbl, subtbl, state)
        push!(res, LabelledTree(cartesian_label([range_label() for _ = 1:ndims(fbr) - 1]..., i), SubFiber(lvl.lvl, q)))
        if i == stop
            break
        end
        state = subtable_next(lvl.tbl, subtbl, state)
    end
    res
end

@inline level_ndims(::Type{<:SparseLevel{Ti, Tbl, Lvl}}) where {Ti, Tbl, Lvl} = 1 + level_ndims(Lvl)
@inline level_size(lvl::SparseLevel) = (level_size(lvl.lvl)..., lvl.shape)
@inline level_axes(lvl::SparseLevel) = (level_axes(lvl.lvl)..., Base.OneTo(lvl.shape))
@inline level_eltype(::Type{<:SparseLevel{Ti, Tbl, Lvl}}) where {Ti, Tbl, Lvl} = level_eltype(Lvl)
@inline level_fill_value(::Type{<:SparseLevel{Ti, Tbl, Lvl}}) where {Ti, Tbl, Lvl} = level_fill_value(Lvl)
data_rep_level(::Type{<:SparseLevel{Ti, Tbl, Lvl}}) where {Ti, Tbl, Lvl} = SparseData(data_rep_level(Lvl))

(fbr::AbstractFiber{<:SparseLevel})() = fbr
function (fbr::SubFiber{<:SparseLevel{Ti}})(idxs...) where {Ti}
    isempty(idxs) && return fbr
    lvl = fbr.lvl
    p = fbr.pos
    crds = table_coords(lvl.tbl, p)
    r = searchsorted(crds, idxs[end])
    q = lvl.tbl.ptr[p] + first(r) - 1
    length(r) == 0 ? fill_value(fbr) : SubFiber(lvl.lvl, lvl.tbl.val[q])(idxs[1:end-1]...)
end

mutable struct VirtualSparseLevel <: AbstractVirtualLevel
    lvl
    ex
    Ti
    tbl
    shape
    qos_stop
end

is_level_injective(ctx, lvl::VirtualSparseLevel) = [is_level_injective(ctx, lvl.lvl)..., false]
function is_level_atomic(ctx, lvl::VirtualSparseLevel)
    (below, atomic) = is_level_atomic(ctx, lvl.lvl)
    return ([below; [atomic]], atomic)
end
function is_level_concurrent(ctx, lvl::VirtualSparseLevel)
    (data, _) = is_level_concurrent(ctx, lvl.lvl)
    #FIXME:
    return ([data; [false]], false)
end

function virtualize(ctx, ex, ::Type{SparseLevel{Ti, Tbl, Lvl}}, tag=:lvl) where {Ti, Tbl, Lvl}
    sym = freshen(ctx, tag)
    tbl = freshen(ctx, tag, :_tbl)
    qos_stop = freshen(ctx, tag, :_qos_stop)
    push_preamble!(ctx, quote
        $sym = $ex
        $tbl = $sym.tbl
        $qos_stop = table_length($tbl)
    end)
    lvl_2 = virtualize(ctx, :($sym.lvl), Lvl, sym)
    shape = value(:($sym.shape), Int)
    VirtualSparseLevel(lvl_2, sym, Ti, tbl, shape, qos_stop)
end
function lower(ctx::AbstractCompiler, lvl::VirtualSparseLevel, ::DefaultStyle)
    quote
        $SparseLevel{$(lvl.Ti)}(
            $(ctx(lvl.lvl)),
            $(ctx(lvl.shape)),
            $(lvl.tbl),
        )
    end
end

Base.summary(lvl::VirtualSparseLevel) = "Sparse($(summary(lvl.lvl)))"

function virtual_level_size(ctx, lvl::VirtualSparseLevel)
    ext = make_extent(lvl.Ti, literal(lvl.Ti(1)), lvl.shape)
    (virtual_level_size(ctx, lvl.lvl)..., ext)
end

function virtual_level_resize!(ctx, lvl::VirtualSparseLevel, dims...)
    lvl.shape = getstop(dims[end])
    lvl.lvl = virtual_level_resize!(ctx, lvl.lvl, dims[1:end-1]...)
    lvl
end

virtual_level_eltype(lvl::VirtualSparseLevel) = virtual_level_eltype(lvl.lvl)
virtual_level_fill_value(lvl::VirtualSparseLevel) = virtual_level_fill_value(lvl.lvl)

postype(lvl::VirtualSparseLevel) = postype(lvl.lvl)

function declare_level!(ctx::AbstractCompiler, lvl::VirtualSparseLevel, pos, init)
    #TODO check that init == fill_value
    Ti = lvl.Ti
    Tp = postype(lvl)
    qos = freshen(ctx, :qos)
    push_preamble!(ctx, quote
        $qos = Finch.declare_table!($(lvl.tbl), $(ctx(pos)))
        $(lvl.qos_stop) = 0
    end)
    lvl.lvl = declare_level!(ctx, lvl.lvl, value(qos, Tp), init)
    return lvl
end

function assemble_level!(ctx, lvl::VirtualSparseLevel, pos_start, pos_stop)
    pos_start = ctx(cache!(ctx, :p_start, pos_start))
    pos_stop = ctx(cache!(ctx, :p_start, pos_stop))
    quote
        Finch.assemble_table!($(lvl.tbl), $(ctx(pos_start)), $(ctx(pos_stop)))
    end
end

function freeze_level!(ctx::AbstractCompiler, lvl::VirtualSparseLevel, pos_stop)
    p = freshen(ctx, :p)
    pos_stop = cache!(ctx, :pos_stop, simplify(ctx, pos_stop))
    qos_stop = freshen(ctx, :qos_stop)
    push_preamble!(ctx, quote
        $qos_stop = Finch.freeze_table!($(lvl.tbl), $(ctx(pos_stop)))
    end)
    lvl.lvl = freeze_level!(ctx, lvl.lvl, value(qos_stop))
    return lvl
end

function thaw_level!(ctx::AbstractCompiler, lvl::VirtualSparseLevel, pos_stop)
    p = freshen(ctx, :p)
    pos_stop = ctx(cache!(ctx, :pos_stop, simplify(ctx, pos_stop)))
    push_preamble!(ctx, quote
        $(lvl.qos_stop) = Finch.thaw_table!($(lvl.tbl), $(ctx(pos_stop)))
    end)
    lvl.lvl = thaw_level!(ctx, lvl.lvl, value(lvl.qos_stop))
    return lvl
end

function virtual_moveto_level(ctx::AbstractCompiler, lvl::VirtualSparseLevel, arch)
    ptr_2 = freshen(ctx, lvl.ptr)
    idx_2 = freshen(ctx, lvl.idx)
    push_preamble!(ctx, quote
        $tbl_2 = $(lvl.tbl)
        $(lvl.tbl) = $moveto($(lvl.tbl), $(ctx(arch)))
    end)
    push_epilogue!(ctx, quote
        $(lvl.tbl) = $tbl_2
    end)
    virtual_moveto_level(ctx, lvl.lvl, arch)
end

function instantiate(ctx, fbr::VirtualSubFiber{VirtualSparseLevel}, mode::Reader, subprotos, ::Union{typeof(defaultread), typeof(walk)})
    (lvl, pos) = (fbr.lvl, fbr.pos)
    tag = lvl.ex
    Tp = postype(lvl)
    Ti = lvl.Ti
    my_i = freshen(ctx, tag, :_i)
    my_q = freshen(ctx, tag, :_q)
    my_q_stop = freshen(ctx, tag, :_q_stop)
    my_i1 = freshen(ctx, tag, :_i1)
    subtbl = freshen(ctx, tag, :_subtbl)
    state = freshen(ctx, tag, :_state)

    Furlable(
        body = (ctx, ext) -> Thunk(
            preamble = quote
                $subtbl = Finch.table_query($(lvl.tbl), $(ctx(pos)))
                ($my_i, $my_i1, $state) = Finch.subtable_init($(lvl.tbl), $subtbl)
            end,
            body = (ctx) -> Sequence([
                Phase(
                    stop = (ctx, ext) -> value(my_i1),
                    body = (ctx, ext) -> Stepper(
                        seek = (ctx, ext) -> quote
                            if $my_i < $(ctx(getstart(ext)))
                                ($my_i, $state) = Finch.subtable_seek($(lvl.tbl), $subtbl, $state, $my_i, $(ctx(getstart(ext))))
                            end
                        end,
                        preamble = :(($my_i, $my_q) = Finch.subtable_get($(lvl.tbl), $subtbl, $state)),
                        stop = (ctx, ext) -> value(my_i),
                        chunk = Spike(
                            body = FillLeaf(virtual_level_fill_value(lvl)),
                            tail = Simplify(instantiate(ctx, VirtualSubFiber(lvl.lvl, value(my_q, Ti)), mode, subprotos))
                        ),
                        next = (ctx, ext) -> :($state = Finch.subtable_next($(lvl.tbl), $subtbl, $state))
                    )
                ),
                Phase(
                    body = (ctx, ext) -> Run(FillLeaf(virtual_level_fill_value(lvl)))
                )
            ])
        )
    )
end

instantiate(ctx, fbr::VirtualSubFiber{VirtualSparseLevel}, mode::Updater, protos) = begin
    instantiate(ctx, VirtualHollowSubFiber(fbr.lvl, fbr.pos, freshen(ctx, :null)), mode, protos)
end
function instantiate(ctx, fbr::VirtualHollowSubFiber{VirtualSparseLevel}, mode::Updater, subprotos, ::Union{typeof(defaultupdate), typeof(extrude)})
    (lvl, pos) = (fbr.lvl, fbr.pos)
    tag = lvl.ex
    Tp = postype(lvl)
    qos = freshen(ctx, tag, :_qos)
    qos_stop = lvl.qos_stop
    dirty = freshen(ctx, tag, :_dirty)
    subtbl = freshen(ctx, tag, :_subtbl)

    Furlable(
        body = (ctx, ext) -> Thunk(
            preamble = quote
                $subtbl = Finch.table_register($(lvl.tbl), $(ctx(pos)))
            end,
            body = (ctx) -> Lookup(
                body = (ctx, idx) -> Thunk(
                    preamble = quote
                        $qos = Finch.subtable_register($(lvl.tbl), $subtbl, $(ctx(idx)))
                        if $qos > $qos_stop
                            $qos_stop = max($qos_stop << 1, 1)
                            $(contain(ctx_2->assemble_level!(ctx_2, lvl.lvl, value(qos, Tp), value(qos_stop, Tp)), ctx))
                        end
                        $dirty = false
                    end,
                    body = (ctx) -> instantiate(ctx, VirtualHollowSubFiber(lvl.lvl, value(qos, Tp), dirty), mode, subprotos),
                    epilogue = quote
                        if $dirty
                            Finch.subtable_commit!($(lvl.tbl), $subtbl, $qos, $(ctx(idx)))
                            $(fbr.dirty) = true
                        end
                    end
                )
            ),
            epilogue = quote
                Finch.table_commit!($(lvl.tbl), $(ctx(pos)))
            end
        )
    )
end
