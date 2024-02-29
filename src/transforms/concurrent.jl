struct FinchConcurrencyError
    msg
end

"""
    is_injective(tns, ctx)

Returns a vector of booleans, one for each dimension of the tensor, indicating
whether the access is injective in that dimension.  A dimension is injective if
each index in that dimension maps to a different memory space in the underlying
array.
"""
function is_injective end

"""
    is_atomic(tns, ctx)

    Returns a tuple (below, overall) where below is a vector, indicating which indicies are safe to write to out of order, 
    and overall is a boolean that indicates if this is true for the entire tensor.

"""
function is_atomic end

"""
ensure_concurrent(root, ctx)

Ensures that all nonlocal assignments to the tensor root are consistently
accessed with the same indices and associative operator.  Also ensures that the
tensor is either atomic, or accessed by `i` and concurrent and injective on `i`.
"""
function ensure_concurrent(root, ctx)
    @assert @capture root loop(~idx, ~ext, ~body)

    #get local definitions
    locals = Set(filter(!isnothing, map(PostOrderDFS(body)) do node
        if @capture(node, declare(~tns, ~init)) tns end
    end))

    #get nonlocal assignments and group by root
    nonlocal_assigns = Dict()
    for node in PostOrderDFS(body)
        if @capture(node, assign(~lhs, ~op, ~rhs)) && !(getroot(lhs.tns) in locals) && getroot(lhs.tns) !== nothing #TODO remove the nothing check
            push!(get!(nonlocal_assigns, getroot(lhs.tns), []), node)
        end
    end

    # Get all indicies in the parallel region.
    indicies_in_region = [idx]
    for node in PostOrderDFS(body)
        if  @capture root loop(~idxp, ~ext, ~body)
            push!(indicies_in_region, idxp)
        end
    end
    


    for (root, agns) in nonlocal_assigns
        ops = map(agn -> (@capture agn assign(~lhs, ~op, ~rhs); op), agns)
        if !allequal(ops)
            throw(FinchConcurrencyError("Nonlocal assignments to $(root) are not all the same operator"))
        end

        accs = map(agn -> (@capture agn assign(~lhs, ~op, ~rhs); lhs), agns)
        acc = first(accs)
        # The operation must be associative.
        if !(isassociative(ctx.algebra, first(ops)))
            throw(FinchConcurrencyError("Nonlocal assignments to $(root) are not associative"))
        end
        # If the acceses are different, then all acceses must be atomic.
        if !allequal(accs)
            for acc in accs
                (below, overall) = is_atomic(acc.tns, ctx)
                if !all(below)
                    throw(FinchConcurrencyError("Nonlocal assignments to $(root) are not all the same access so atomics are needed on all acceses!"))
                end
            end 
            continue
        else
            #Since all operations/acceses are the same, a more fine grained analysis takes place:
            #Every access must be injective or they must all be atomic.
            if (@capture(acc, access(~tns, ~mode, ~i...)))
                locations_with_parallel_vars = []
                injectivity = is_injective(tns, ctx)
                for loc in 1:length(i)
                    if i[loc] in indicies_in_region
                        push!(locations_with_parallel_vars, loc + 1)
                    end
                end
                if length(locations_with_parallel_vars) == 0
                    (below, overall) = is_atomic(acc.tns, ctx)
                    if !below[0]
                        throw(FinchConcurrencyError("Assignment $(acc) requires last level atomics!"))
                        # FIXME: we could do atomic operations here.
                    else
                        continue
                    end
                end

                if all(injectivity[locations_with_parallel_vars])
                    continue # We pass due to injectivity!
                end
                (below, _) = is_atomic(acc.tns, ctx)
                if all(below[locations_with_parallel_vars])
                    continue # we pass due to atomics!
                else
                    throw(FinchConcurrencyError("Assignment $(acc) requires injectivity or atomics in at least places $(locations_with_parallel_vars), but does not have them, due to injectivity=$(injectivity) and atomics=$(below) "))
                end
                
            end
        end
    end
    # we validated everything so we are done!
    return root
end