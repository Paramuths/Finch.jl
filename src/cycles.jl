function lower_cycle(root, ctx, ext, style)
    i = getname(root.idx)
    i0 = ctx.freshen(i, :_start)
    push!(ctx.preamble, quote
        $i = $(ctx(getstart(root.ext)))
    end)

    guard = :($i <= $(ctx(getstop(root.ext))))
    body = Postwalk(node->unwrap_cycle(node, ctx, ext, style))(root.body)

    body_2 = contain(ctx) do ctx_2
        push!(ctx_2.preamble, :($i0 = $i))
        ctx_2(Chunk(root.idx, Extent(start = i0, stop = getstop(root.ext), lower = 1), body))
    end

    if simplify((@i $(getlower(ext)) >= 1)) == true  && simplify((@i $(getupper(ext)) <= 1)) == true
        body_2
    else
        return quote
            while $guard
                $body_2
            end
        end
    end
end

unwrap_cycle(node, ctx, ext, style) = nothing