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

using StaticArraysCore: StaticArray, size_to_tuple, tuple_prod

export AbstractRecordVector, VectorPrism
export paths, indexof

function check_compatible(::Type{T}) where T
    isconcretetype(T) || error("Type is not fully concrete")
    for ft in fieldtypes(T)
        check_compatible(ft)
    end
end
check_compatible(::Type{<:Array}) = error("Type contains an array")
function check_compatible(::Type{<:StaticArray{S, T}}) where {S, T}
    isconcretetype(T) || error("Type is not fully concrete")
    check_compatible(T)
end


"""
    AbstractRecordVector{T}

Subtype this to automatically be an `AbstractVector{T}`.
This has undefined behavour if any of your (nested) fields are `Array`s.
Or if any of your nested fields are not concretely typed, or typed `Nothing`.
Check for this by calling `VectorPrisms.check_compatible` on your type.
"""
abstract type AbstractRecordVector{T} <: AbstractVector{T} end

"""
    VectorPrism{T, B} <: AbstractRecordVector{T}

Can use this to wrap anything else to make it a `AbstractVector{T}`.
If `T` is passed directly then noncomposite fields of types other than `T` are ingored.
Otherwise `T` is inferred as the union of all noncomposite fields
"""
struct VectorPrism{T, B} <: AbstractRecordVector{T}
    backing::B
end
VectorPrism(x::B) where B = VectorPrism{determine_eltype(B)}(x)
function VectorPrism{T}(x::B) where {T, B}
    check_compatible(B)
    return VectorPrism{T, B}(x)
end

Base.propertynames(obj::VectorPrism, private::Bool=false) = propertynames(getfield(obj, :backing), private)
Base.getproperty(obj::VectorPrism, sym::Symbol) = getproperty(getfield(obj, :backing), sym)
Base.getproperty(obj::VectorPrism, sym::Symbol, order::Symbol) = getproperty(getfield(obj, :backing), sym, order)
Base.setproperty!(obj::VectorPrism, sym::Symbol, x) = setproperty!(getfield(obj, :backing), sym, x)
Base.setproperty!(obj::VectorPrism, sym::Symbol, x, order::Symbol) = setproperty!(getfield(obj, :backing), sym, x, order)

(this::VectorPrism)(args...; kwargs...) = getfield(this, :backing)(args...; kwargs...)

function Base.show(io::IO, vp::VectorPrism{T}) where T
    print(io, "VectorPrism{$T}(")
    show(io, getfield(vp, :backing))
    print(io, ")")
end

function Base.show(io::IO, mime::MIME"text/plain", vp::VectorPrism{T}) where T
    print(io, "VectorPrism{$T} view of ")
    show(io, mime, getfield(vp, :backing))
end


function determine_eltype(::Type{B}) where B
    fieldcount(B) == 0 && return B
    eltype = Union{}
    for ft in fieldtypes(B)
        eltype = Union{eltype, determine_eltype(ft)}
    end
    return eltype
end
function determine_eltype(::Type{<:StaticArray{S, T}}) where {S, T}
    fieldcount(T) == 0 && return T
    eltype = Union{}
    for ft in fieldtypes(T)
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
function getsome_expr!(block, Terminal, ::Type{<:StaticArray{S, T}}, get_path_expr) where {S, T}
    for idx in CartesianIndices(size_to_tuple(S))
        fpath = :(getindex($get_path_expr, $idx))
        VectorPrisms.getsome_expr!(block, Terminal, T, fpath)
    end
    return block
end


@generated function Base.size(x::AbstractRecordVector{T}) where T
    return tuple(size_from(T, x))
end
size_from(::Type{Terminal}, ::Type{<:Terminal}) where Terminal = 1
function size_from(Terminal, ::Type{V}) where V
    sum(fieldtypes(V); init=0) do fieldtype
        size_from(Terminal, fieldtype)
    end
end
function size_from(::Type{Terminal}, ::Type{<:StaticArray{S, T}}) where {Terminal, S, T <: Terminal}
    tuple_prod(S)
end
function size_from(Terminal, ::Type{<:StaticArray{S, T}}) where {S, T}
    tuple_prod(S) * size_from(Terminal, T)
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
function _paths!(acc, Terminal, S::Type{<:VectorPrism}, get_path_expr)
    # special logic to hide the backing field. Constrast to `_paths!(acc, Terminal, S, get_path_expr)`
    ft = fieldtype(S, :backing)
    return _paths!(acc, Terminal, ft, get_path_expr)
end
function _paths!(acc, Terminal, ::Type{<:StaticArray{S, T}}, get_path_expr) where {S, T}
    for idx in CartesianIndices(size_to_tuple(S))
        fpath = :($(get_path_expr)[$idx])
        _paths!(acc, Terminal, T, fpath)
    end
    return acc
end

"""
    indexof(R::Type{<:AbstractRecordVector}, path)

Returns the index corresponding to a given path to a field inside a abstract record vector.
"""
function indexof(R::Type{<:AbstractRecordVector}, path...)
    #PRE-OPT: this could be made to constant fold away if written as a generated function
    all_paths = paths(Expr, R)
    this_path = foldl(path, init=:_) do acc, x
        if x isa CartesianIndex
            Expr(:ref, acc, x)
        else
            Expr(:., acc, QuoteNode(x))
        end
    end
    index = findfirst(==(this_path), all_paths)
    if isnothing(index)
        throw(BoundsError(R, path))
    end
    return index
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
function setsome_expr!(block, ::Type{Terminal}, ::Type{<:StaticArray{S, T}}, get_path_expr) where {Terminal, S, T <: Terminal}
    for idx in CartesianIndices(size_to_tuple(S))
        ind_val = length(block.args) + 1
        set_path_expr = :(setindex!($get_path_expr, value, $idx))
        push!(block.args, :(ii==$(ind_val) && return $set_path_expr))
    end
    return block
end
function setsome_expr!(block, Terminal, ::Type{<:StaticArray{S, T}}, get_path_expr) where {S, T}
    for idx in CartesianIndices(size_to_tuple(S))
        fpath = :(getindex($get_path_expr, $idx))
        setsome_expr!(block, Terminal, T, fpath)
    end
    return block
end

end  # module