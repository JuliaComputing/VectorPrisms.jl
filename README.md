# VectorPrisms

[![Build Status](https://github.com/JuliaComputing/VectorPrisms.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaComputing/VectorPrisms.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaComputing/VectorPrisms.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaComputing/VectorPrisms.jl)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)


VectorPrisms.jl exposes the ability to view a (potentially nested) `struct` as a `AbstractVector`.
It exposes this both through composition with the `VectorPrism` wrapper type, and through inheritance with the `AbstractRecordVector` type.
These conceptually work by recursively (depth first) searching all fields looking for elements that subtype the declared eltype (which may be concrete, abstract, or a union).

Throughout these documentation we will refer to the example of:

```julia
mutable struct Foo
    a::Int
    b::String
end
struct Bar <: AbstractRecordVector{Int}
    x::Int
    foo::Foo
    y::Int
end

bar = Bar(10, Foo(20, "a"), 30)
```
All the usual operations expected of an `AbstractVector` work on `Bar`.

```
julia> size(bar)
(3,)

julia> using LinearAlgebra

julia> LinearAlgebra.norm(bar)
37.416573867739416

julia> LinearAlgebra.dot(bar, bar)
1400

julia> bar'
1×3 adjoint(::Bar) with eltype Int64:
 10  20  30

julia> view(bar, 1:2)
2-element view(::Bar, 1:2) with eltype Int64:
 10
 20
```

`setindex!` works on indexes matching to mutable fields and not on ones that do not.
```
julia> bar[2] = 200
200

julia> bar
3-element Bar:
  10
 200
  30

julia> bar[1]=100
ERROR: setfield!: immutable struct of type Bar cannot be changed
```

### Extra operations only for `AbstractRecordVector`/`VectorPrisms`: `paths`, `indexof`

By and large the operations on our types are characterized by the `AbstractVector` API -- that is the whole point.
But we do provide a couple of operations that only make sense for these types/

`paths` returns a vector of all the paths within the object, in the order of their index.
It takes an optional first argument that specifies if it should return `String`s (default), or `Expr`s.
```julia
julia> paths(Bar)
3-element Vector{String}:
 "x"
 "foo.a"
 "y"

julia> paths(Expr, Bar)
3-element Vector{Expr}:
 :(_.x)
 :(_.foo.a)
 :(_.y)
```

`indexof` takes a path (given as a series of `Symbol`s) into the object and returns the matching index:
```julia
julia> indexof(Bar, :foo, :a)
2

julia> indexof(Bar, :y)
3
```
### How do I use VectorPrism?

In implementation, there is little more to `VectorPrism` than simply being a single field struct that subtypes `AbstractRecordVector`.
A simple wrapper type.

For example we could take a VectorPrism of a `ComplexF64` as follows:
```julia
julia> cvp = VectorPrism(10.0 + 20im)
VectorPrism{Float64} view of 10.0 + 20.0im

julia> cvp[1]
10.0

julia> cvp[2]
20.0
```

### How do I control what types are ignored by VectorPrism?

By default `VectorPrism` determines the element type as the union of all the leaf types in your object.

```
julia> vp = VectorPrism((;a=1.0, b=(1f0, 2)))
VectorPrism{Union{Float32, Float64, Int64}} view of (a = 1.0, b = (1.0f0, 2))

julia> length(vp)
3
```
However, if you specify the `eltype` in the constructor it will ignore anything that doesn't match it.
```
julia> vp2 = VectorPrism{AbstractFloat}((;a=1.0, b=(1f0, 2)))
VectorPrism{AbstractFloat} view of (a = 1.0, b = (1.0f0, 2))

julia> length(vp2)
2
```

### Should I use `AbstractRecordVector` or `VectorPrism`?
In general it is a bit nicer to use `AbstractRecordVector` if you can slot it nicely into your existing type hierarchy,
since this means your type is always exposed as itself to methods.
However, this is not always possible since Julia does not have multiple inheritance.

This is where `VectorPrism` enters.
You can wrap your type in it to get the `AbstractVector` view.
However, now you do not get your methods anymore.
Some things like `getproperty` and function invocation are delegated to the original object, but by no means all possible operations.



### Limitations: no dynamically sized memory
The size of types with the structs must be compile-time known.
They can be `struct`s or`Tuples`, they can not be `Vectors`s.
This also means it can not contain types like `Dict`s which are built on type of `Vector`s.

### How does it work under the hood and is it fast?

The core functionality is that `getindex` is an `@generated` function which basically generates a chain of `if`-`else`s for all the fields of the eltype.
So for our example it would rounghly look like:
```julia
function getindex(bar::Bar, ii::Int)
    if ii==1
        return bar.x
    elseif ii==2
        return bar.foo.a
    elseif ii==3
        return bar.y
    else
        throw(BoundsError(bar, ii))
    end
end
```

This is indeed fast.
If the index is compile-time known (like a literal) then all the branches are eliminated and `bar[2]` directly compiles into `bar.foo.a`.
If not, this gets analysed this as a switch statement for which it has many options for how to compile including to a jump statement or a series of conditionals depending which is faster. You can check it isn't actually running the series of conditions for large structs because the timing remands constant not changing with index.
`getindex` on a `AbstractRecordVector`/`VectorPrism` of any size remains on the order of a couple of CPU instructions, similar to `getindex` on `Vector`.

Wrapping things in `VectorPrism` is also very cheap since it does not allocate.
Further more, it will often be removed entirely the compiler during SROA optimiation (Scalar Replacement of Aggregates).


### Differences from `StaticArrays.FieldVector`
`AbstractRecordVector` is conceptually very similar to [StaticArrays.FieldVector](https://juliaarrays.github.io/StaticArrays.jl/stable/pages/api/#FieldVector).
The primary difference is that `AbstractRecordVector` works recursively on all structs contained within your struct.
So for

we would have that `bar[2]` would return `bar.foo.a` (which was 2). (as well as `bar[1]` returning (which was `10`)).
In contrast had `Bar<:FieldVector{2, Int}` when `bar[2]` would have returned `Bar.foo` (and violated the declared element type).

A second (related) difference is that leaf types that do not subtype the declared `eltype` are simply ignored.
So, continuing our previous example `bar[3]` would return `bar.y` (which was `30`).

### What is a prism?
A prism is a type of optic, like a lens.
This concept is relatively well established in Closure and Haskell.
Julia programmers may be familar with [Accessors.jl](https://github.com/JuliaObjects/Accessors.jl) uses lenses.

A lens is about fields, it encodes a _has-a_ relationship.
A prism on the other-hand encodes a _is-a_ relationship.
So the `VectorPrism` allows us to view a struct as if it was an `AbstractVector`.

We do not do this though a standard optic construction of a forward-function which returns both the new object and a back-function (closure) that returns the object to the original, but rather though exposing that API fully and without new memory allocation, thus no need for a back function.

We do note that there are many implementation of the standard vector prism construction in julia, with various tweaks to meet various needs, for example [`FiniteDifferences.to_vec`](https://github.com/JuliaDiff/FiniteDifferences.jl/blob/0766bbc7b81381b134835d31145ad4822fd7e65f/src/to_vec.jl), [`Optimizers.destructure`](https://docs.sciml.ai/Flux/stable/destructure/#Optimisers.destructure) and others.``