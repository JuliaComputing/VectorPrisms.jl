module VectorPrisms
using CedarSim.VectorPrisms
using Test

mutable struct MRecord3 <: AbstractRecordVector{Float64}
    a::Float64
    b::Float64
    c::Float64
end


mr3 = MRecord3(1.0, 2.0, 3.0)
@test size(mr3) == (3,)
@test mr3[1] == 1.0
@test mr3[2] == 2.0
@test mr3[3] == 3.0
mr3[2] = 20.0
@test mr3[2] == 20.0
@test_throws BoundsError mr3[4]
@test_throws BoundsError mr3[-1]
@test_throws BoundsError mr3[4]=10.0
@test_throws BoundsError mr3[-1]=11.0
@test paths(typeof(mr3)) == ["a", "b", "c"]
@test paths(Expr, typeof(mr3); start_from=:x) == [:(x.a), :(x.b), :(x.c)]
@test indexof(typeof(mr3), :a) == 1


mutable struct MRecord2NoSubtype
    alpha::Float64
    beta::Float64
end

vp2 = VectorPrism(MRecord2NoSubtype(1.0, 2.0))
@test eltype(vp2) == Float64
@test size(vp2) == (2,)
@test propertynames(vp2) == (:alpha, :beta)
@test vp2[1] == 1.0 == vp2.alpha
@test vp2[2] == 2.0 == vp2.beta
@test_throws BoundsError vp2[3]
@test_throws BoundsError vp2[-1]
@test_throws BoundsError vp2[4]=10.0
@test_throws BoundsError vp2[-1]=11.0
vp2[1]=10.0
@test vp2[1]==10.0==vp2.alpha
vp2.beta=20.0
@test vp2[2]==20.0==vp2.beta
@test paths(typeof(vp2)) == ["backing.alpha", "backing.beta"]
@test paths(Expr, typeof(vp2); start_from=:x) == [:(x.backing.alpha), :(x.backing.beta)]
@test startswith(repr(vp2), "VectorPrism{Float64}(")
@test startswith(repr("text/plain", vp2), "VectorPrism{Float64} view of")
@test indexof(typeof(vp2), :backing, :beta) == 2

vp3 = VectorPrism((;x=1, y=2, z=3))
@test eltype(vp3) == Int
@test size(vp3) == (3,)
@test propertynames(vp3) == (:x, :y, :z)
@test vp3[1] == 1 == vp3.x
@test vp3[2] == 2 == vp3.y
@test vp3[3] == 3 == vp3.z
@test_throws BoundsError vp3[4]
@test_throws BoundsError vp3[-1]
@test_throws BoundsError vp3[4]=10.0
@test_throws BoundsError vp3[-1]=11.0
@test_throws ErrorException vp3[1]=10

vp5 = VectorPrism((;x=1.0, y=(;a=2.1, b=2.2, c=2.3), z=3.0))
@test eltype(vp5) == Float64
@test vp5[1] == 1.0
@test vp5[2] == 2.1
@test vp5[3] == 2.2
@test vp5[4] == 2.3
@test vp5[5] == 3.0
@test vp5.y == (;a=2.1, b=2.2, c=2.3)
@test_throws BoundsError vp5[6]
@test_throws BoundsError vp5[-1]
@test_throws BoundsError vp5[6]=10.0
@test_throws BoundsError vp5[-1]=11.0
@test_throws ErrorException vp5[1]=10.0
@test paths(typeof(vp5)) == ["backing.x", "backing.y.a", "backing.y.b", "backing.y.c", "backing.z"]
@test paths(Expr, typeof(vp5); start_from=:x) ==  [:(x.backing.x), :(x.backing.y.a), :(x.backing.y.b), :(x.backing.y.c), :(x.backing.z)]
@test indexof(typeof(vp5), :backing, :x) == 1
@test indexof(typeof(vp5), :backing, :y, :b) == 3
@test indexof(typeof(vp5), :backing, :z) == 5

vp6 = VectorPrism((;x=1, y=2, w=(a=Ref(3.1), b=Ref(3.2)), z=(4.1, 4.2)))
@test eltype(vp6) == Union{Int, Float64}
@test vp6[1]==1
@test vp6[2]==2
@test vp6[3]==3.1
@test vp6[4]==3.2
@test vp6[5]==4.1
@test vp6[6]==4.2
@test_throws BoundsError vp6[7]
@test_throws BoundsError vp6[-1]
@test_throws BoundsError vp6[7]=10.0
@test_throws BoundsError vp6[-1]=11.0
vp6[4]=300.1
@test vp6[4] == 300.1
@test_throws ErrorException vp6[1]=10
@test indexof(typeof(vp6), :backing, :w, :a, :x) == 3

struct IRecord3 <: AbstractRecordVector{Union{Float64, Int}}
    a::Float64
    b::Tuple{Float64, Int}
end

r3=IRecord3(1.0, (2.0, 3))
@test size(r3) == (3,)
@test r3[1] == 1.0
@test r3[2] == 2.0
@test r3[3] == 3
@test_throws BoundsError r3[4]
@test_throws BoundsError r3[-1]
@test_throws BoundsError r3[4]=10.0
@test_throws BoundsError r3[-1]=11.0
@test_throws ErrorException r3[1]=10.0
@test paths(typeof(r3)) == ["a", "b.:(1)", "b.:(2)"]  # not sure this is ideal, but it will do for now
@test paths(Expr, typeof(r3); start_from=:x) == [:(x.a), :(x.b.:(1)), :(x.b.:(2))] 
@test indexof(typeof(r3), :a) == 1
@test indexof(typeof(r3), :b, 1) == 2
@test indexof(typeof(r3), :b, 2) == 3

mix1 = VectorPrism{Float64}((;a=1.5, b=nothing))
@test size(mix1) == (1,)
@test only(mix1) == 1.5

mt_callable = VectorPrism{Float64}(x->2x)
@test size(mt_callable) == (0,)
@test mt_callable(4.5) == 9.0
end  # module