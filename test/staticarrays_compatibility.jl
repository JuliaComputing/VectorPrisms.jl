using StaticArrays

for (SAType, ismut) in [(SVector, false), (MVector, true), (SizedVector, true)]
    _sa = SAType{3}([1.0, 2.0, 3.0])
    sa = VectorPrism(_sa)
    @test eltype(sa) == Float64
    @test size(sa) == (3,)
    @test sa[1] == 1.0
    @test sa[2] == 2.0
    @test sa[3] == 3.0
    if ismut
        sa[1] = 2.0
        @test sa[1] == 2.0
    else
        @test_throws ErrorException sa[1]=1.0
    end
    @test_throws BoundsError sa[4]
    @test_throws BoundsError sa[-1]
    @test paths(typeof(sa)) == ["CartesianIndex(1,)]", "CartesianIndex(2,)]", "CartesianIndex(3,)]"]
    @test paths(Expr, typeof(sa); start_from=:x) == [:(x[$(CartesianIndex(1))]), :(x[$(CartesianIndex(2))]), :(x[$(CartesianIndex(3))])]
    @test indexof(typeof(sa), CartesianIndex(2)) == 2
end

_sa = SVector{2}(MRecord3(1.0, 2.0, 3.0), MRecord3(4.0, 5.0, 6.0))
sa = VectorPrism(_sa)
@test eltype(sa) == Float64
@test size(sa) == (6,)
@test sa[1] == 1.0
@test sa[2] == 2.0
@test sa[3] == 3.0
@test sa[4] == 4.0
@test sa[5] == 5.0
@test sa[6] == 6.0
sa[3] = 3.5
@test sa[3] == 3.5
@test_throws BoundsError sa[7]
@test_throws BoundsError sa[-1]
@test_throws BoundsError sa[7]=1.0
@test_throws BoundsError sa[-1]=1.0
@test paths(typeof(sa)) == ["[CartesianIndex(1,)]).a", "[CartesianIndex(1,)]).b", "[CartesianIndex(1,)]).c", "[CartesianIndex(2,)]).a", "[CartesianIndex(2,)]).b", "[CartesianIndex(2,)]).c"]
@test paths(Expr, typeof(sa); start_from=:x) == [:(x[$(CartesianIndex(1))].a), :(x[$(CartesianIndex(1))].b), :(x[$(CartesianIndex(1))].c), :(x[$(CartesianIndex(2))].a), :(x[$(CartesianIndex(2))].b), :(x[$(CartesianIndex(2))].c)]
@test indexof(typeof(sa), CartesianIndex(2), :b) == 5
@test _sa[2].b === sa[indexof(typeof(sa), CartesianIndex(2), :b)]

nt = VectorPrism((; a = 1, b = SVector{2}(2, 3), c = MVector{2}(4, 5), d = SizedVector{2}([6, 7])))
@test eltype(nt) == Int
@test size(nt) == (7,)
for i in 1:7
    @test nt[i] == i
end
nt[4] = 8
@test nt[4] == 8
@test_throws BoundsError nt[9]
@test_throws BoundsError nt[-1]
@test_throws BoundsError nt[9]=9
@test_throws BoundsError nt[-1]=-1
@test paths(typeof(nt)) == ["a", "b[CartesianIndex(1,)]", "b[CartesianIndex(2,)]", "c[CartesianIndex(1,)]", "c[CartesianIndex(2,)]", "d[CartesianIndex(1,)]", "d[CartesianIndex(2,)]"]
@test paths(Expr, typeof(nt); start_from=:x) == [:(x.a), :(x.b[$(CartesianIndex(1))]), :(x.b[$(CartesianIndex(2))]), :(x.c[$(CartesianIndex(1))]), :(x.c[$(CartesianIndex(2))]), :(x.d[$(CartesianIndex(1))]), :(x.d[$(CartesianIndex(2))])]
