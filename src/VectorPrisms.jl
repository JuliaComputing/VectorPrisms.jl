# TODO release this as a stand-alone package

"""
# VectorPrisms.jl

If you have a basic fixed sized "record" type struct,
which basically is a container for (relatively) homogenously typed data.
And is made up either of that data or of nested structs/tuples
that eventually contain that data, then this module lets you view that record as an array.

You can either directly subtype `AbstractRecordVector`(@ref) or wrap your type in `VectorPrism`(@ref).
Either way you will automatically get a view onto your data that fills the `AbstractVector` type requirements.
"""
module VectorPrisms
export AbstractRecordVector, VectorPrism
export paths

function check_compatible(::Type{T}) where T
    isconcretetype(T) || error("Type is not fully concrete")
    for ft in fieldtypes(T)
        check_compatible(ft)
    end
end
check_compatible(::Type{<:Array}) = error("Type contains an array")


"""
    AbstractRecordVector{T}

Subtype this to automatically be an `AbstractVector{T}`.
This has undefined behavour if any of your (nested) fields are `Array`s.
Or if any of your nested fields are not concretely typed, or typed `Nothing`.
Check for this by calling `VectorPrisms.check_compatible` on your type.
"""
abstract type AbstractRecordVector{T} <: AbstractVector{T} end

"Can use this to wrap anything else to make it a AbstractVector"
struct VectorPrism{T, B} <: AbstractRecordVector{T}
    backing::B
end
function VectorPrism(x::B) where B
    check_compatible(B)
    T = determine_eltype(B)
    return VectorPrism{T, B}(x)
end

Base.propertynames(obj::VectorPrism, private::Bool=false) = propertynames(getfield(obj, :backing), private)
Base.getproperty(obj::VectorPrism, sym::Symbol) = getproperty(getfield(obj, :backing), sym)
Base.getproperty(obj::VectorPrism, sym::Symbol, order::Symbol) = getproperty(getfield(obj, :backing), sym, order)
Base.setproperty!(obj::VectorPrism, sym::Symbol, x) = setproperty!(getfield(obj, :backing), sym, x)
Base.setproperty!(obj::VectorPrism, sym::Symbol, x, order::Symbol) = setproperty!(getfield(obj, :backing), sym, x, order)

function determine_eltype(::Type{B}) where B
    fieldcount(B) == 0 && return B
    eltype = Union{}
    for ft in fieldtypes(B)
        eltype = Union{eltype, determine_eltype(ft)}
    end
    return eltype
end


@generated function Base.getindex(x::AbstractRecordVector{T}, ii::Int) where T
    block = getsome_expr!(Expr(:block), T, x, :x)
    push!(block.args, :(throw(BoundsError())))
    return block
end
function getsome_expr!(block, ::Type{Terminal}, ::Type{<:Terminal}, get_path_expr) where Terminal
    ind_val = length(block.args) + 1
    push!(block.args, :(ii==$(ind_val) && return $get_path_expr))
    return block
end
function getsome_expr!(block, Terminal, S, get_path_expr)
    for field_ind in 1:fieldcount(S)
        fpath = :(getfield($get_path_expr, $field_ind))
        ft = fieldtype(S, field_ind)
        getsome_expr!(block, Terminal, ft, fpath)
    end
    return block
end


@generated function Base.size(x::AbstractRecordVector{T}) where T
    return tuple(size_from(T, x))
end
size_from(::Type{Terminal}, ::Type{<:Terminal}) where Terminal = 1
function size_from(Terminal, ::Type{V}) where V
    sum(fieldtypes(V)) do fieldtype
        size_from(Terminal, fieldtype)
    end
end

"returns all the paths to indexed values"
paths(R::Type{<:AbstractRecordVector}) = paths(String, R)
function paths(::Type{String}, R::Type{<:AbstractRecordVector})
    map(paths(Expr, R, start_from=:_)) do path_expr
        string(path_expr)[3:end]
    end
end
function paths(::Type{Expr}, S::Type{<:AbstractRecordVector{T}}; start_from=:_) where T
    return _paths!(Expr[], T, S, start_from)
end
function _paths!(acc, ::Type{Terminal}, ::Type{<:Terminal}, get_path_expr) where Terminal
    return push!(acc, get_path_expr)
end
function _paths!(acc, Terminal, S, get_path_expr)
    for field_ind in 1:fieldcount(S)
        fname = fieldname(S, field_ind)
        fpath = :($(get_path_expr).$fname)
        ft = fieldtype(S, field_ind)
        _paths!(acc, Terminal, ft, fpath)
    end
    return acc
end


# Note: this will error if the particular index does not line up with a mutable struct position
# This could be made more powerful using Accessors.jl
@generated function Base.setindex!(x::AbstractRecordVector{T}, value, ii::Int)::T where T
    block = setsome_expr!(Expr(:block), T, x, :x)
    push!(block.args, :(throw(BoundsError())))
    return block
end

function setsome_expr!(block, Terminal, S, get_path_expr)
    for field_ind in 1:fieldcount(S)
        ft = fieldtype(S, field_ind)
        if ft <: Terminal
            ind_val = length(block.args) + 1
            set_path_expr = :(setfield!($get_path_expr, $field_ind, value))
            push!(block.args, :(ii==$(ind_val) && return $set_path_expr))
        else
            fpath = :(getfield($get_path_expr, $field_ind))
            setsome_expr!(block, Terminal, ft, fpath)
        end
    end
    return block
end

end  # module
using .VectorPrisms