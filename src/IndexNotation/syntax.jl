#TODO use MacroTools?

const incs = Dict(:+= => :+, :*= => :*, :&= => :&, :|= => :|)
function capture_index(ex; ctx...)
    #extra sugar
    if ex isa Expr && ex.head == :macrocall && length(ex.args) >= 3 && ex.args[1] == Symbol("@∀")
        idxs = ex.args[3:end-1]; body = ex.args[end]
        return capture_index(:(@loop($(idxs...), $body)); ctx...)
    elseif ex isa Expr && ex.head == :block
        bodies = filter(arg->!(arg isa LineNumberNode), ex.args)
        return capture_index(:(@multi($(bodies...),)); ctx...)
    elseif ex isa Expr && haskey(incs, ex.head)
        (lhs, rhs) = ex.args; op = incs[ex.head]
        return capture_index(:($lhs << $op >>= $rhs); ctx...)
    elseif false && ex isa Expr && ex.head == :comparison #TODO
        @assert length(ex.args) >= 3
        (a, cmp, b, tail...) = ex.args
        ex = :($cmp($a, $b))
        if isempty(tail)
            return capture_index(:($cmp($a, $b)); ctx...)
        else
            return capture_index(:($cmp($a, $b) && Expr(:comparison, b, tail...)); ctx...)
        end
    elseif ex isa Expr && ex.head == :&&
        (a, b) = ex.args
        return capture_index(:($a & $b); ctx...)
    elseif ex isa Expr && ex.head == :||
        (a, b) = ex.args
        return capture_index(:($a | $b); ctx...)
    end

    if @capture ex (@pass(args__))
        args = map(arg -> capture_index(arg; ctx..., namify=false), args)
        return :($pass($(args...)))
    elseif @capture ex (@loop idxs__ body_)
        idxs = map(idx -> capture_index(idx; ctx..., namify=true), idxs)
        body = capture_index(body; ctx...)
        return :($loop($(idxs...), $body))
    elseif @capture ex (@chunk idx_ ext_ body_)
        idx = capture_index(idx; ctx...)
        ext = capture_index(ext; ctx..., namify=false)
        body = capture_index(body; ctx...)
        return :($chunk($idx, $ext, $body))
    elseif @capture ex (cons_ where prod_)
        cons = capture_index(cons; ctx...)
        prod = capture_index(prod; ctx..., results=Set())
        return :($with($cons, $prod))
    elseif @capture ex (@multi bodies__)
        bodies = map(arg -> capture_index(arg; ctx...), bodies)
        return :($multi($(bodies...)))
    elseif @capture ex (lhs_ = rhs_)
        lhs = capture_index(lhs; ctx..., mode=Write())
        rhs = capture_index(rhs; ctx...)
        return :($assign($lhs, $rhs))
    elseif @capture ex (lhs_ << op_ >>= rhs_)
        lhs = capture_index(lhs; ctx..., mode=Update())
        rhs = capture_index(rhs; ctx...)
        op = capture_index(op; ctx..., namify=false)
        return :($assign($lhs, $op, $rhs))
    elseif ex isa Expr && ex.head == :comparison && length(ex.args) == 5 && ex.args[2] == :< && ex.args[4] == :>=
        lhs = capture_index(ex.args[1]; ctx..., mode=Update())
        op = capture_index(ex.args[3]; ctx..., namify=false)
        rhs = capture_index(ex.args[5]; ctx...)
        return :($assign($lhs, $op, $rhs))
    elseif @capture ex (op_(args__))
        op = capture_index(op; ctx..., namify=false, mode=Read())
        args = map(arg->capture_index(arg; ctx..., mode=Read()), args)
        return :($call($op, $(args...)))
    elseif @capture ex (tns_[idxs__])
        if values(ctx).mode isa Union{Write, Update} && tns isa Symbol
            push!(values(ctx).results, tns)
        end
        tns = capture_index(tns; ctx..., namify=false, mode=Read())
        idxs = map(idx->capture_index(idx; ctx..., namify=true, mode=Read()), idxs)
        return :($access($tns, $(values(ctx).mode), $(idxs...)))
    elseif ex isa Expr && ex.head == :$ && length(ex.args) == 1
        return esc(ex.args[1])
    elseif ex isa Symbol && values(ctx).namify
        return Name(ex)
    else
        return esc(ex)
    end
end

macro index_program(ex)
    return capture_index(ex; namify=true, mode = Read(), results = Set())
end

macro i(ex)
    return capture_index(ex; namify=true, mode = Read(), results = Set())
end

function capture_index_instance(ex; ctx...)
    #extra sugar
    if ex isa Expr && ex.head == :macrocall && length(ex.args) >= 3 && ex.args[1] == Symbol("@∀")
        idxs = ex.args[3:end-1]; body = ex.args[end]
        return capture_index_instance(:(@loop($(idxs...), $body)); ctx...)
    elseif ex isa Expr && ex.head == :block
        bodies = filter(arg->!(arg isa LineNumberNode), ex.args)
        return capture_index_instance(:(@multi($(bodies...),)); ctx...)
    elseif ex isa Expr && haskey(incs, ex.head)
        (lhs, rhs) = ex.args; op = incs[ex.head]
        return capture_index_instance(:($lhs << $op >>= $rhs); ctx...)
    elseif false && ex isa Expr && ex.head == :comparison #TODO
        @assert length(ex.args) >= 3
        (a, cmp, b, tail...) = ex.args
        ex = :($cmp($a, $b))
        if isempty(tail)
            return capture_index_instance(:($cmp($a, $b)); ctx...)
        else
            return capture_index_instance(:($cmp($a, $b) && Expr(:comparison, b, tail...)); ctx...)
        end
    elseif ex isa Expr && ex.head == :&&
        (a, b) = ex.args
        return capture_index_instance(:($a & $b); ctx...)
    elseif ex isa Expr && ex.head == :||
        (a, b) = ex.args
        return capture_index_instance(:($a | $b); ctx...)
    end

    if @capture ex (@pass(args__))
        args = map(arg -> capture_index_instance(arg; ctx..., namify=false), args)
        return :($pass_instance($(args...)))
    elseif @capture ex (@loop idxs__ body_)
        idxs = map(idx -> capture_index_instance(idx; ctx..., namify=true), idxs)
        body = capture_index_instance(body; ctx...)
        return :($loop_instance($(idxs...), $body))
    elseif @capture ex (@chunk idx_ ext_ body_)
        idx = capture_index_instance(idx; ctx...)
        ext = capture_index_instance(ext; ctx..., namify=false)
        body = capture_index_instance(body; ctx...)
        return :($chunk_instance($idx, $ext, $body))
    elseif @capture ex (cons_ where prod_)
        cons = capture_index_instance(cons; ctx...)
        prod = capture_index_instance(prod; ctx..., results=Set())
        return :($with_instance($cons, $prod))
    elseif @capture ex (@multi bodies__)
        bodies = map(arg -> capture_index_instance(arg; ctx...), bodies)
        return :($multi_instance($(bodies...)))
    elseif @capture ex (lhs_ = rhs_)
        lhs = capture_index_instance(lhs; ctx..., mode=Write())
        rhs = capture_index_instance(rhs; ctx...)
        return :($assign_instance($lhs, $rhs))
    elseif @capture ex (lhs_ << op_ >>= rhs_)
        lhs = capture_index_instance(lhs; ctx..., mode=Update())
        rhs = capture_index_instance(rhs; ctx...)
        op = capture_index_instance(op; ctx..., namify=false)
        return :($assign_instance($lhs, $op, $rhs))
    elseif ex isa Expr && ex.head == :comparison && length(ex.args) == 5 && ex.args[2] == :< && ex.args[4] == :>=
        lhs = capture_index_instance(ex.args[1]; ctx..., mode=Update())
        op = capture_index_instance(ex.args[3]; ctx..., namify=false)
        rhs = capture_index_instance(ex.args[5]; ctx...)
        return :($assign_instance($lhs, $op, $rhs))
    elseif @capture ex (op_(args__))
        op = capture_index_instance(op; ctx..., namify=false, mode=Read())
        args = map(arg->capture_index_instance(arg; ctx..., mode=Read()), args)
        return :($call_instance($op, $(args...)))
    elseif @capture ex (tns_[idxs__])
        if values(ctx).mode isa Union{Write, Update} && tns isa Symbol
            push!(values(ctx).results, tns)
        end
        tns = capture_index_instance(tns; ctx..., namify=false, mode=Read())
        idxs = map(idx->capture_index_instance(idx; ctx..., namify=true, mode=Read()), idxs)
        return :($access_instance($tns, $(values(ctx).mode), $(idxs...)))
    elseif ex isa Expr && ex.head == :(::) && length(ex.args) == 2 #TODO
        return :($(esc(ex.args[2]))($(capture_index_instance(ex.args[1]; ctx...))))
    elseif ex isa Expr && ex.head == :$ && length(ex.args) == 1
        return esc(ex.args[1])
    elseif ex isa Symbol && values(ctx).namify
        return name_instance(ex)
    elseif ex isa Symbol
        return :($label_instance($(QuoteNode(ex)), $value_instance($(esc(ex)))))
    else
        return :($value_instance($(esc(ex))))
    end
end

macro index_program_instance(ex)
    capture_index_instance(ex; namify=true, mode = Read(), results = Set())
end