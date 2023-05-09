"""Useful functions to be used throughout the library."""
module UtilsModule

import Printf: @printf
import StaticArrays: MVector
import LoopVectorization: @turbo

function debug(verbosity, string...)
    if verbosity > 0
        println(string...)
    end
end

function debug_inline(verbosity, string...)
    if verbosity > 0
        print(string...)
    end
end

pseudo_time = 0

function get_birth_order(; deterministic=false)::Int
    """deterministic gives a birth time with perfect resolution, but is not thread safe."""
    if deterministic
        global pseudo_time
        pseudo_time += 1
        return pseudo_time
    else
        resolution = 1e7
        return round(Int, resolution * time())
    end
end

function check_numeric(n)
    return tryparse(Float64, n) !== nothing
end

function is_anonymous_function(op)
    op_string = string(nameof(op))
    return length(op_string) > 1 && op_string[1] == '#' && check_numeric(op_string[2:2])
end

function recursive_merge(x::AbstractVector...)
    return cat(x...; dims=1)
end

function recursive_merge(x::AbstractDict...)
    return merge(recursive_merge, x...)
end

function recursive_merge(x...)
    return x[end]
end

const max_ops = 8192
const vals = ntuple(Val, max_ops)

"""Return the bottom k elements of x, and their indices."""
bottomk_fast(x, k) = _bottomk_dispatch(x, vals[k])

function _bottomk_dispatch(x::AbstractVector{T}, ::Val{k}) where {T,k}
    @assert k >= 2
    indmin = MVector{k}(ntuple(_ -> 0, k))
    minval = MVector{k}(ntuple(_ -> typemax(T), k))
    _bottomk!(x, minval, indmin)
    return [minval...], [indmin...]
end
function _bottomk!(x, minval, indmin)
    @inbounds @fastmath for i in eachindex(x)
        new_min = x[i] < minval[end]
        if new_min
            minval[end] = x[i]
            indmin[end] = i
            for ki in length(minval):-1:2
                need_swap = minval[ki] < minval[ki - 1]
                if need_swap
                    minval[ki], minval[ki - 1] = minval[ki - 1], minval[ki]
                    indmin[ki], indmin[ki - 1] = indmin[ki - 1], indmin[ki]
                end
            end
        end
    end
    return nothing
end

# Thanks Chris Elrod
# https://discourse.julialang.org/t/why-is-minimum-so-much-faster-than-argmin/66814/9
function findmin_fast(x)
    indmin = 0
    minval = typemax(eltype(x))
    @turbo for i in eachindex(x)
        newmin = x[i] < minval
        minval = newmin ? x[i] : minval
        indmin = newmin ? i : indmin
    end
    return minval, indmin
end
argmin_fast(x) = findmin_fast(x)[2]

end
