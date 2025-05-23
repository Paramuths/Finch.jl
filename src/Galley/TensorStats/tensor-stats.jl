# This struct holds the high-level definition of a tensor. This information should be
# agnostic to the statistics used for cardinality estimation. Any information which may be
# `Nothing` is considered a part of the physical definition which may be undefined for logical
# intermediates but is required to be defined for the inputs to an executable query.
@auto_hash_equals mutable struct TensorDef
    index_set::StableSet{IndexExpr}
    dim_sizes::OrderedDict{IndexExpr,Float64}
    fill_val::Any
    level_formats::Union{Nothing,Vector{LevelFormat}}
    index_order::Union{Nothing,Vector{IndexExpr}}
    index_protocols::Union{Nothing,Vector{AccessProtocol}}
end
function TensorDef(x)
    TensorDef(
        StableSet{IndexExpr}(),
        OrderedDict{IndexExpr,Float64}(),
        x,
        IndexExpr[],
        IndexExpr[],
        IndexExpr[],
    )
end

function copy_def(def::TensorDef)
    TensorDef(StableSet{IndexExpr}(x for x in def.index_set),
        OrderedDict{IndexExpr,Float64}(x for x in def.dim_sizes),
        def.fill_val,
        isnothing(def.level_formats) ? nothing : [x for x in def.level_formats],
        isnothing(def.index_order) ? nothing : [x for x in def.index_order],
        isnothing(def.index_protocols) ? nothing : [x for x in def.index_protocols])
end

function level_to_enums(lvl)
    if typeof(lvl) <: SparseListLevel
        return [t_sparse_list]
    elseif typeof(lvl) <: SparseDictLevel
        return [t_hash]
    elseif typeof(lvl) <: SparseCOOLevel
        return [t_coo for _ in lvl.shape]
    elseif typeof(lvl) <: SparseByteMap
        return [t_bytemap]
    elseif typeof(lvl) <: DenseLevel
        return [t_dense]
    else
        throw(Base.error("Level Not Recognized"))
    end
end

function get_tensor_formats(tensor::Tensor)
    level_formats = LevelFormat[]
    current_lvl = tensor.lvl
    while length(level_formats) < length(size(tensor))
        append!(level_formats, level_to_enums(current_lvl))
        current_lvl = current_lvl.lvl
    end
    # Because levels are built outside-in, we need to reverse this.
    level_formats = reverse(level_formats)
end

function TensorDef(tensor::Tensor, indices)
    shape_tuple = size(tensor)
    level_formats = get_tensor_formats(tensor::Tensor)
    dim_size = OrderedDict{IndexExpr,Float64}(
        indices[i] => shape_tuple[i] for i in 1:length(size(tensor))
    )
    fill_val = Finch.fill_value(tensor)
    return TensorDef(
        StableSet{IndexExpr}(indices), dim_size, fill_val, level_formats, indices, nothing
    )
end

function reindex_def(indices, def::TensorDef)
    @assert length(indices) == length(def.index_order)
    rename_dict = OrderedDict{IndexExpr,IndexExpr}()
    for i in eachindex(indices)
        rename_dict[def.index_order[i]] = indices[i]
    end
    new_index_set = StableSet{IndexExpr}()
    for idx in def.index_set
        push!(new_index_set, rename_dict[idx])
    end

    new_dim_sizes = OrderedDict{IndexExpr,Float64}()
    for (idx, size) in def.dim_sizes
        new_dim_sizes[rename_dict[idx]] = size
    end

    return TensorDef(
        new_index_set,
        new_dim_sizes,
        def.fill_val,
        def.level_formats,
        indices,
        def.index_protocols,
    )
end

function set_fill_value!(def::TensorDef, fill_val)
    TensorDef(
        def.index_set,
        def.dim_sizes,
        fill_val,
        def.level_formats,
        def.index_order,
        def.index_protocols,
    )
end

function relabel_index!(def::TensorDef, i::IndexExpr, j::IndexExpr)
    if i == j || i ∉ def.index_set
        return nothing
    end
    delete!(def.index_set, i)
    push!(def.index_set, j)
    def.dim_sizes[j] = def.dim_sizes[i]
    delete!(def.dim_sizes, i)
    if !isnothing(def.index_order)
        for k in eachindex(def.index_order)
            if def.index_order[k] == i
                def.index_order[k] = j
            end
        end
    end
end

function add_dummy_idx!(def::TensorDef, i::IndexExpr; idx_pos=-1)
    def.dim_sizes[i] = 1
    push!(def.index_set, i)
    if idx_pos > -1
        insert!(def.index_order, idx_pos, i)
        insert!(def.level_formats, idx_pos, t_dense)
    end
end

get_dim_sizes(def::TensorDef) = def.dim_sizes
get_dim_size(def::TensorDef, idx::IndexExpr) = def.dim_sizes[idx]
get_index_set(def::TensorDef) = def.index_set
get_index_order(def::TensorDef) = def.index_order
get_fill_value(def::TensorDef) = def.fill_val
function get_index_format(def::TensorDef, idx::IndexExpr)
    def.level_formats[findfirst(x -> x == idx, def.index_order)]
end
get_index_formats(def::TensorDef) = def.level_formats
function get_index_protocol(def::TensorDef, idx::IndexExpr)
    def.index_protocols[findfirst(x -> x == idx, def.index_order)]
end
get_index_protocols(def::TensorDef) = def.index_protocols

function get_dim_space_size(def::TensorDef, indices)
    dim_space_size::Float64 = 1
    for idx in indices
        dim_space_size *= def.dim_sizes[idx]
    end
    if dim_space_size == 0 || dim_space_size > typemax(Int)
        return Float64(typemax(Int))^(sizeof(Int) * 8 - 1)
    end
    return dim_space_size
end

abstract type TensorStats end

get_dim_space_size(stat::TensorStats, indices) = get_dim_space_size(get_def(stat), indices)
get_dim_sizes(stat::TensorStats) = get_dim_sizes(get_def(stat))
get_dim_size(stat::TensorStats, idx::IndexExpr) = get_dim_size(get_def(stat), idx)
get_index_set(stat::TensorStats) = get_index_set(get_def(stat))
get_index_order(stat::TensorStats) = get_index_order(get_def(stat))
get_fill_value(stat::TensorStats) = get_fill_value(get_def(stat))
get_index_format(stat::TensorStats, idx::IndexExpr) = get_index_format(get_def(stat), idx)
get_index_formats(stat::TensorStats) = get_index_formats(get_def(stat))
function get_index_protocol(stat::TensorStats, idx::IndexExpr)
    get_index_protocol(get_def(stat), idx)
end
get_index_protocols(stat::TensorStats) = get_index_protocols(get_def(stat))
copy_stats(stat::Nothing) = nothing
#################  NaiveStats Definition ###################################################

@auto_hash_equals mutable struct NaiveStats <: TensorStats
    def::TensorDef
    cardinality::Float64

    function NaiveStats(def::TensorDef, cardinality)
        return new(def, cardinality)
    end

    function NaiveStats(tensor, indices)
        if !(tensor isa Tensor)
            tensor = Tensor(tensor)
        end
        def = TensorDef(tensor, indices)
        cardinality = countstored(tensor)
        return new(def, cardinality)
    end
end

get_def(stat::NaiveStats) = stat.def
function get_cannonical_stats(stat::NaiveStats, rel_granularity=4)
    NaiveStats(copy_def(stat.def), geometric_round(rel_granularity, stat.cardinality))
end

# This function assumes that stat1 and stat2 have ONLY differ in the value of their DCs.
function issimilar(stat1::NaiveStats, stat2::NaiveStats, rel_granularity)
    return abs(
        log(rel_granularity, stat1.cardinality) - log(rel_granularity, stat2.cardinality)
    ) <= 1
end

function estimate_nnz(
    stat::NaiveStats; indices=get_index_set(stat),
    conditional_indices=StableSet{IndexExpr}(),
)
    return stat.cardinality / get_dim_space_size(stat, conditional_indices)
end

condense_stats!(::NaiveStats; timeout=100000, cheap=true) = nothing
function fix_cardinality!(stat::NaiveStats, card)
    stat.cardinality = card
end

copy_stats(stat::NaiveStats) = NaiveStats(copy_def(stat.def), stat.cardinality)

function NaiveStats(index_set, dim_sizes, cardinality, fill_val)
    NaiveStats(TensorDef(index_set, dim_sizes, fill_val, nothing), cardinality)
end

function NaiveStats(x)
    def = TensorDef(
        StableSet{IndexExpr}(), OrderedDict{IndexExpr,Int}(), x, nothing, nothing, nothing
    )
    return NaiveStats(def, 1)
end

function reindex_stats(stat::NaiveStats, indices)
    return NaiveStats(reindex_def(indices, stat.def), stat.cardinality)
end

function set_fill_value!(stat::NaiveStats, fill_val)
    return NaiveStats(set_fill_value!(stat.def, fill_val), stat.cardinality)
end

function relabel_index!(stats::NaiveStats, i::IndexExpr, j::IndexExpr)
    relabel_index!(stats.def, i, j)
end

function add_dummy_idx!(stats::NaiveStats, i::IndexExpr; idx_pos=-1)
    add_dummy_idx!(stats.def, i; idx_pos=idx_pos)
end

#################  DCStats Definition ######################################################

struct DegreeConstraint
    X::BitSet
    Y::BitSet
    d::Float64
end
DC = DegreeConstraint

function get_dc_key(dc::DegreeConstraint)
    return (X=dc.X, Y=dc.Y)
end

@auto_hash_equals mutable struct DCStats <: TensorStats
    def::TensorDef
    idx_2_int::OrderedDict{IndexExpr,Int}
    int_2_idx::OrderedDict{Int,IndexExpr}
    dcs::StableSet{DC}

    DCStats(def, idx_2_int, int_2_idx, dcs) = new(def, idx_2_int, int_2_idx, dcs)

    function DCStats(tensor, indices)
        if !(tensor isa Tensor)
            tensor = Tensor(tensor)
        end
        def = TensorDef(tensor, indices)
        idx_2_int = OrderedDict{IndexExpr,Int}()
        int_2_idx = OrderedDict{Int,IndexExpr}()
        for (i, idx) in enumerate(StableSet(indices))
            idx_2_int[idx] = i
            int_2_idx[i] = idx
        end
        if all([f == t_dense for f in get_index_formats(def)])
            return new(
                def,
                idx_2_int,
                int_2_idx,
                dense_dcs(def, int_2_idx, [idx_2_int[i] for i in indices]),
            )
        end
        sparsity_structure = pattern!(tensor)
        dcs = _structure_to_dcs(
            int_2_idx, [idx_2_int[i] for i in indices], sparsity_structure
        )
        return new(def, idx_2_int, int_2_idx, dcs)
    end
end

function copy_stats(stat::DCStats)
    DCStats(
        copy_def(stat.def),
        copy(stat.idx_2_int),
        copy(stat.int_2_idx),
        StableSet{DC}(dc for dc in stat.dcs),
    )
end
function DCStats(x)
    DCStats(
        TensorDef(x), OrderedDict{IndexExpr,Int}(), OrderedDict{Int,IndexExpr}(),
        StableSet{DC}(),
    )
end

# Return a stats object where values have been geometrically rounded.
function get_cannonical_stats(stat::DCStats, rel_granularity=4)
    new_dcs = StableSet{DC}()
    for dc in stat.dcs
        push!(new_dcs, DC(dc.X, dc.Y, geometric_round(rel_granularity, dc.d)))
    end
    return DCStats(copy_def(stat.def), copy(stat.idx_2_int), copy(stat.int_2_idx), new_dcs)
end

# Check whether two tensors have similar sparsity distributions.
# This function assumes that stat1 and stat2 have ONLY differ in the value of their DCs.
function issimilar(stat1::DCStats, stat2::DCStats, rel_granularity)
    if length(stat1.dcs) < 50
        for dc1 in stat1.dcs
            for dc2 in stat2.dcs
                if dc1.X == dc2.X && dc1.Y == dc2.Y &&
                    abs(log(rel_granularity, dc1.d) - log(rel_granularity, dc2.d)) > 1
                    return false
                end
            end
        end
    else
        dc_dict = OrderedDict{DCKey}()
        for dc1 in stat1.dcs
            dc_dict[get_dc_key(dc1)] = dc1.d
        end
        for dc2 in stat2.dcs
            if abs(
                log(rel_granularity, dc_dict[get_dc_key(dc2)]) - log(rel_granularity, dc2.d)
            ) > 1
                return false
            end
        end
    end
    return true
end

get_def(stat::DCStats) = stat.def
function get_index_bitset(stat::DCStats)
    BitSet(Int[stat.idx_2_int[x] for x in get_index_set(stat)])
end

idxs_to_bitset(stat::DCStats, indices) = idxs_to_bitset(stat.idx_2_int, indices)
function idxs_to_bitset(idx_2_int::OrderedDict{IndexExpr,Int}, indices)
    BitSet(Int[idx_2_int[idx] for idx in indices])
end
bitset_to_idxs(stat::DCStats, bitset) = bitset_to_idxs(stat.int_2_idx, bitset)
function bitset_to_idxs(int_2_idx::OrderedDict{Int,IndexExpr}, bitset)
    StableSet{IndexExpr}(int_2_idx[idx] for idx in bitset)
end

function add_dummy_idx!(stats::DCStats, i::IndexExpr; idx_pos=-1)
    add_dummy_idx!(stats.def, i; idx_pos=idx_pos)
    new_idx_int = maximum(values(stats.idx_2_int); init=0) + 1
    stats.idx_2_int[i] = new_idx_int
    stats.int_2_idx[new_idx_int] = i
    Y = idxs_to_bitset(stats, StableSet([i]))
    push!(stats.dcs, DC(BitSet(), Y, 1))
end

function fix_cardinality!(stat::DCStats, card)
    had_dc = false
    new_dcs = StableSet{DC}()
    for dc in stat.dcs
        if length(dc.X) == 0 && dc.Y == get_index_bitset(stat)
            push!(new_dcs, DC(BitSet(), get_index_bitset(stat), min(card, dc.d)))
            had_dc = true
        else
            push!(new_dcs, dc)
        end
    end
    if !had_dc
        push!(new_dcs, DC(BitSet(), get_index_bitset(stat), card))
    end
    stat.dcs = new_dcs
end

DCKey = NamedTuple{(:X, :Y),Tuple{BitSet,BitSet}}

function infer_dc(l, ld, r, rd, all_dcs, new_dcs)
    if l.Y ⊇ r.X
        new_key = (X=l.X, Y=setdiff(∪(l.Y, r.Y), l.X))
        new_degree = ld * rd
        if get(all_dcs, new_key, Inf) > new_degree &&
            get(new_dcs, new_key, Inf) > new_degree
            new_dcs[new_key] = new_degree
        end
    end
end

# When we're only attempting to infer for nnz estimation, we only need to consider
# left dcs which have X = {}.
function _infer_dcs(dcs::StableSet{DC}; timeout=Inf, strength=0)
    all_dcs = OrderedDict{DCKey,Float64}()
    for dc in dcs
        all_dcs[(X=dc.X, Y=dc.Y)] = dc.d
    end
    prev_new_dcs = all_dcs
    time = 1
    finished = false
    max_dc_size = 0
    while time < timeout && !finished
        if strength <= 0
            max_dc_size = maximum([length(x.Y) for x in keys(prev_new_dcs)]; init=0)
        end
        new_dcs = OrderedDict{DCKey,Float64}()

        for (l, ld) in all_dcs
            strength <= 1 && length(l.X) > 0 && continue
            for (r, rd) in prev_new_dcs
                strength <= 0 && length(r.Y) + length(l.Y) < max_dc_size && continue
                infer_dc(l, ld, r, rd, all_dcs, new_dcs)
                time += 1
                time > timeout && break
            end
            time > timeout && break
        end

        for (l, ld) in prev_new_dcs
            strength <= 1 && length(l.X) > 0 && continue
            for (r, rd) in all_dcs
                strength <= 0 && length(r.Y) + length(l.Y) < max_dc_size && continue
                infer_dc(l, ld, r, rd, all_dcs, new_dcs)
                time += 1
                time > timeout && break
            end
            time > timeout && break
        end

        prev_new_dcs = OrderedDict{DCKey,Float64}()
        for (dc_key, dc) in new_dcs
            strength <= 0 && length(dc_key.Y) < max_dc_size && continue
            all_dcs[dc_key] = dc
            prev_new_dcs[dc_key] = dc
        end
        if length(prev_new_dcs) == 0
            finished = true
        end
    end
    final_dcs = StableSet{DC}()
    for (dc_key, dc) in all_dcs
        push!(final_dcs, DC(dc_key.X, dc_key.Y, dc))
    end
    return final_dcs
end

function condense_stats!(stat::DCStats; timeout=100000, cheap=false)
    current_indices_bitset = get_index_bitset(stat)
    inferred_dcs = nothing
    if !cheap
        inferred_dcs = _infer_dcs(stat.dcs; timeout=timeout, strength=2)
    else
        inferred_dcs = _infer_dcs(stat.dcs; timeout=min(timeout, 10000), strength=1)
        inferred_dcs = _infer_dcs(inferred_dcs; timeout=max(timeout - 10000, 0), strength=0)
    end
    min_dcs = OrderedDict{DCKey,Float64}()
    for dc in inferred_dcs
        valid = true
        for x in dc.X
            if !(x in current_indices_bitset)
                valid = false
                break
            end
        end
        valid == false && continue
        new_Y = dc.Y ∩ current_indices_bitset
        y_dim_size = get_dim_space_size(stat.def, bitset_to_idxs(stat, new_Y))
        min_dcs[(X=dc.X, Y=new_Y)] = min(
            get(min_dcs, (X=dc.X, Y=new_Y), Inf), dc.d, y_dim_size
        )
    end

    end_dcs = StableSet{DC}()
    for (dc_key, d) in min_dcs
        push!(end_dcs, DC(dc_key.X, dc_key.Y, d))
    end
    stat.dcs = end_dcs
    return nothing
end

function estimate_nnz(
    stat::DCStats; indices=get_index_set(stat), conditional_indices=StableSet{IndexExpr}()
)
    if length(indices) == 0
        return 1
    end
    indices_bitset = idxs_to_bitset(stat, indices)
    conditional_indices_bitset = idxs_to_bitset(stat, conditional_indices)
    current_weights = OrderedDict{BitSet,Float64}(
        conditional_indices_bitset => 1, BitSet() => 1
    )
    frontier = StableSet{BitSet}([BitSet(), conditional_indices_bitset])
    finished = false
    while !finished
        current_bound::Float64 = get(current_weights, indices_bitset, typemax(Float64))
        new_frontier = StableSet{BitSet}()
        finished = true
        for x in frontier
            weight = current_weights[x]
            for dc in stat.dcs
                if x ⊇ dc.X
                    y = ∪(x, dc.Y)
                    if min(current_bound, get(current_weights, y, typemax(Float64))) >
                       weight * dc.d && !((
                        (weight > (2^(sizeof(UInt) * 8 - 2))) ||
                        (dc.d > (2^(sizeof(UInt) * 8 - 2)))
                    ))
                        # We need to be careful about overflow here. Turns out UInts overflow as 0 >:(
                        current_weights[y] =
                            if (
                                (weight > (2^(sizeof(UInt) * 8 - 2))) ||
                                (dc.d > (2^(sizeof(UInt) * 8 - 2)))
                            )
                                Float64(2)^(sizeof(UInt) * 8)
                            else
                                (weight * dc.d)
                            end
                        finished = false
                        push!(new_frontier, y)
                    end
                end
            end
        end
        frontier = new_frontier
    end
    min_weight = get_dim_space_size(stat, indices)
    for (x, weight) in current_weights
        if x ⊇ indices_bitset
            min_weight = min(min_weight, weight)
        end
    end
    return min_weight
end

DCStats() = DCStats(TensorDef(), StableSet())

function _calc_dc_from_structure(
    X::StableSet{IndexExpr}, Y::StableSet{IndexExpr}, indices::Vector{IndexExpr},
    s::Tensor,
)
    Z = [i for i in indices if i ∉ ∪(X, Y)] # Indices that we want to project out before counting
    XY_ordered = [i for i in indices if i ∉ Z]
    if length(Z) > 0
        XY_tensor = one_off_reduce(max, indices, XY_ordered, s)
    else
        XY_tensor = s
    end

    if length(XY_ordered) == 0
        return XY_tensor[]
    end

    X_ordered = collect(X)
    x_counts = one_off_reduce(+, XY_ordered, X_ordered, XY_tensor)
    if length(X) == 0
        return x_counts[] # If X is empty, we don't need to do a second pass
    end
    dc = one_off_reduce(max, X_ordered, IndexExpr[], x_counts)

    return dc[] # `[]` used to retrieve the actual value of the Finch.Scalar type
end

function _vector_structure_to_dcs(indices::Vector{Int}, s::Tensor)
    d_i = Scalar(0)
    @finch begin
        for i in _
            d_i[] += s[i]
        end
    end
    return StableSet{DC}([DC(BitSet(), BitSet(indices), d_i[])])
end

function _matrix_structure_to_dcs(indices::Vector{Int}, s::Tensor)
    n_j, n_i = size(s)
    d_ij = Scalar(0)
    @finch begin
        d_ij .= 0
        for i in _
            for j in _
                d_ij[] += s[j, i]
            end
        end
    end

    X = d_ij[] / n_i < 0.1 ? Tensor(SparseList(Element(0))) : Tensor(Dense(Element(0)))
    Y = d_ij[] / n_j < 0.1 ? Tensor(Sparse(Element(0))) : Tensor(Dense(Element(0)))
    d_i = Scalar(0)
    d_j = Scalar(0)
    d_i_j = Scalar(0)
    d_j_i = Scalar(0)
    @finch begin
        X .= 0
        Y .= 0
        for i in _
            for j in _
                X[i] += s[j, i]
                Y[j] += s[j, i]
            end
        end
        d_i .= 0
        d_i_j .= 0
        for i in _
            d_i[] += X[i] > 0
            d_i_j[] << max >>= X[i]
        end
        d_j .= 0
        d_j_i .= 0
        for j in _
            d_j[] += Y[j] > 0
            d_j_i[] << max >>= Y[j]
        end
    end
    i = indices[2]
    j = indices[1]
    return StableSet{DC}([DC(BitSet(), BitSet([i]), d_i[]),
        DC(BitSet(), BitSet([j]), d_j[]),
        DC(BitSet([i]), BitSet([j]), d_i_j[]),
        DC(BitSet([j]), BitSet([i]), d_j_i[]),
        DC(BitSet(), BitSet([i, j]), d_ij[]),
    ])
end

function _3d_structure_to_dcs(indices::Vector{Int}, s::Tensor)
    n_k, n_j, n_i = size(s)
    d_ijk = Scalar(0)
    @finch begin
        d_ijk .= 0
        for i in _
            for j in _
                for k in _
                    d_ijk[] += s[k, j, i]
                end
            end
        end
    end
    X = d_ijk[] / n_i < 0.1 ? Tensor(SparseList(Element(0))) : Tensor(Dense(Element(0)))
    Y = d_ijk[] / n_j < 0.1 ? Tensor(Sparse(Element(0))) : Tensor(Dense(Element(0)))
    Z = d_ijk[] / n_k < 0.1 ? Tensor(Sparse(Element(0))) : Tensor(Dense(Element(0)))

    d_i = Scalar(0)
    d_j = Scalar(0)
    d_k = Scalar(0)
    d_i_jk = Scalar(0)
    d_j_ik = Scalar(0)
    d_k_ij = Scalar(0)
    d_ijk = Scalar(0)
    @finch begin
        X .= 0
        Y .= 0
        Z .= 0
        for i in _
            for j in _
                for k in _
                    X[i] += s[k, j, i]
                    Y[j] += s[k, j, i]
                    Z[k] += s[k, j, i]
                end
            end
        end
        d_i .= 0
        d_i_jk .= 0
        d_ijk .= 0
        for i in _
            d_i[] += X[i] > 0
            d_i_jk[] << max >>= X[i]
            d_ijk[] += X[i]
        end

        d_j .= 0
        d_j_ik .= 0
        for j in _
            d_j[] += Y[j] > 0
            d_j_ik[] << max >>= Y[j]
        end

        d_k .= 0
        d_k_ij .= 0
        for k in _
            d_k[] += Z[k] > 0
            d_k_ij[] << max >>= Z[k]
        end
    end
    i = indices[3]
    j = indices[2]
    k = indices[1]
    return StableSet{DC}([DC(BitSet(), BitSet([i]), d_i[]),
        DC(BitSet(), BitSet([j]), d_j[]),
        DC(BitSet(), BitSet([k]), d_k[]),
        DC(BitSet([i]), BitSet([j, k]), d_i_jk[]),
        DC(BitSet([j]), BitSet([i, k]), d_j_ik[]),
        DC(BitSet([k]), BitSet([i, j]), d_k_ij[]),
        DC(BitSet(), BitSet([i, j, k]), d_ijk[]),
    ])
end

function _4d_structure_to_dcs(indices::Vector{Int}, s::Tensor)
    n_l, n_k, n_j, n_i = size(s)
    d_ijkl = Scalar(0)
    @finch begin
        d_ijk .= 0
        for i in _
            for j in _
                for k in _
                    for l in _
                        d_ijkl[] += s[l, k, j, i]
                    end
                end
            end
        end
    end
    X = d_ijkl[] / n_i < 0.1 ? Tensor(SparseList(Element(0))) : Tensor(Dense(Element(0)))
    Y = d_ijkl[] / n_j < 0.1 ? Tensor(Sparse(Element(0))) : Tensor(Dense(Element(0)))
    Z = d_ijkl[] / n_k < 0.1 ? Tensor(Sparse(Element(0))) : Tensor(Dense(Element(0)))
    U = d_ijkl[] / n_l < 0.1 ? Tensor(Sparse(Element(0))) : Tensor(Dense(Element(0)))

    d_i = Scalar(0)
    d_j = Scalar(0)
    d_k = Scalar(0)
    d_l = Scalar(0)
    d_i_jkl = Scalar(0)
    d_j_ikl = Scalar(0)
    d_k_ijl = Scalar(0)
    d_l_ijk = Scalar(0)
    d_ijkl = Scalar(0)
    @finch begin
        X .= 0
        Y .= 0
        Z .= 0
        U .= 0
        for i in _
            for j in _
                for k in _
                    for l in _
                        X[i] += s[l, k, j, i]
                        Y[j] += s[l, k, j, i]
                        Z[k] += s[l, k, j, i]
                        U[l] += s[l, k, j, i]
                    end
                end
            end
        end
        d_i .= 0
        d_i_jkl .= 0
        d_ijkl .= 0
        for i in _
            d_i[] += X[i] > 0
            d_i_jkl[] << max >>= X[i]
            d_ijkl[] += X[i]
        end

        d_j .= 0
        d_j_ikl .= 0
        for j in _
            d_j[] += Y[j] > 0
            d_j_ikl[] << max >>= Y[j]
        end

        d_k .= 0
        d_k_ijl .= 0
        for k in _
            d_k[] += Z[k] > 0
            d_k_ijl[] << max >>= Z[k]
        end

        d_l .= 0
        d_l_ijk .= 0
        for l in _
            d_l[] += U[l] > 0
            d_l_ijk[] << max >>= U[l]
        end
    end
    i = indices[4]
    j = indices[3]
    k = indices[2]
    l = indices[1]
    return StableSet{DC}([DC(BitSet(), BitSet([i]), d_i[]),
        DC(BitSet(), BitSet([j]), d_j[]),
        DC(BitSet(), BitSet([k]), d_k[]),
        DC(BitSet(), BitSet([l]), d_l[]),
        DC(BitSet([i]), BitSet([j, k, l]), d_i_jkl[]),
        DC(BitSet([j]), BitSet([i, k, l]), d_j_ikl[]),
        DC(BitSet([k]), BitSet([i, j, l]), d_k_ijl[]),
        DC(BitSet([l]), BitSet([i, j, k]), d_l_ijk[]),
        DC(BitSet(), BitSet([i, j, k, l]), d_ijkl[]),
    ])
end

function _structure_to_dcs(int_2_idx, indices::Vector{Int}, s::Tensor)
    if length(indices) == 1
        return _vector_structure_to_dcs(indices, s)
    elseif length(indices) == 2
        return _matrix_structure_to_dcs(indices, s)
    elseif length(indices) == 3
        return _3d_structure_to_dcs(indices, s)
    elseif length(indices) == 4
        return _4d_structure_to_dcs(indices, s)
    end
    dcs = StableSet{DC}()
    # Calculate DCs for all combinations of X and Y
    for X in subsets(indices)
        X = BitSet(X)
        Y = BitSet(setdiff(indices, X))
        isempty(Y) && continue # Anything to the empty set has degree 1
        d = _calc_dc_from_structure(
            bitset_to_idxs(int_2_idx, X),
            bitset_to_idxs(int_2_idx, Y),
            [int_2_idx[i] for i in indices],
            s,
        )
        push!(dcs, DC(X, Y, d))

        d = _calc_dc_from_structure(
            StableSet{IndexExpr}(),
            bitset_to_idxs(int_2_idx, Y),
            [int_2_idx[i] for i in indices],
            s,
        )
        push!(dcs, DC(BitSet(), Y, d))
    end
    return dcs
end

function dense_dcs(def, int_2_idx, indices::Vector{Int})
    dcs = StableSet()
    for X in subsets(indices)
        Y = setdiff(indices, X)
        for Z in subsets(Y)
            push!(
                dcs,
                DC(
                    BitSet(X),
                    BitSet(Z),
                    get_dim_space_size(def, bitset_to_idxs(int_2_idx, Z)),
                ),
            )
        end
    end
    return dcs
end

function reindex_stats(stats::DCStats, indices)
    new_def = reindex_def(indices, stats.def)
    rename_dict = OrderedDict(
        get_index_order(stats)[i] => indices[i] for i in eachindex(indices)
    )
    new_idx_to_int = OrderedDict{IndexExpr,Int}()
    for (idx, int) in stats.idx_2_int
        if haskey(rename_dict, idx)
            new_idx_to_int[rename_dict[idx]] = int
        else
            new_idx_to_int[idx] = int
        end
    end
    new_int_to_idx = OrderedDict{Int,IndexExpr}()
    for (idx, int) in new_idx_to_int
        new_int_to_idx[int] = idx
    end
    return DCStats(new_def, new_idx_to_int, new_int_to_idx, copy(stats.dcs))
end

function set_fill_value!(stats::DCStats, fill_val)
    return DCStats(
        set_fill_value!(stats.def, fill_val), stats.idx_2_int, stats.int_2_idx, stats.dcs
    )
end

function relabel_index!(stats::DCStats, i::IndexExpr, j::IndexExpr)
    if i == j || i ∉ get_index_set(stats)
        return nothing
    end
    relabel_index!(stats.def, i, j)
    stats.idx_2_int[j] = stats.idx_2_int[i]
    delete!(stats.idx_2_int, i)
    for (int, idx) in stats.int_2_idx
        if idx == i
            stats.int_2_idx[int] = j
            break
        end
    end
end
