# Partial Pose3 constraints


mutable struct PartialPriorRollPitchZ <: IncrementalInference.FunctorSingleton
  rp::Distributions.MvNormal
  z::Distributions.Normal
  partial::Tuple
  PartialPriorRollPitchZ() = new()
  PartialPriorRollPitchZ(rp::MvNormal,z::Normal) = new(rp, z, (3,4,5))
  # PartialPriorRollPitchZ(x1,x2,x3,x4) = new(MvNormal(x1,x2), Normal(x3,x4), (3,4,5))
  # PartialPriorRollPitchZ(rpz::PackedPartialPriorRollPitchZ) = new(MvNormal(d.rpmu, reshapeVec2Mat(d.rpsig,2)),
                                                    # Normal(rpz.zmu, rpz.zsig) )
end
function getSample(pprz::PartialPriorRollPitchZ, N::Int=1)
  return ([rand(pprz.z,N)';rand(pprz.rp,N)], )
end

mutable struct PackedPartialPriorRollPitchZ <: IncrementalInference.PackedInferenceType
  rpmu::Vector{Float64}
  rpsig::Vector{Float64}
  zmu::Float64
  zsig::Float64
  PackedPartialPriorRollPitchZ() = new()
  PackedPartialPriorRollPitchZ(x1,x2,x3,x4) = new(x1,x2,x3,x4)
  PackedPartialPriorRollPitchZ(rp::MvNormal,z::Normal) = new(rp.μ, rp.Σ.mat[:], z.μ, z.σ)
  # PackedPartialPriorRollPitchZ(rpz::PartialPriorRollPitchZ) = new(rpz.rp.μ, rpz.rp.Σ.mat[:], rpz.z.μ, rpz.z.σ)
end
function convert(::Type{PartialPriorRollPitchZ}, d::PackedPartialPriorRollPitchZ)
  PartialPriorRollPitchZ( MvNormal(d.rpmu, reshapeVec2Mat(d.rpsig,2)),Normal(d.zmu, d.zsig)  )
end
function convert(::Type{PackedPartialPriorRollPitchZ}, d::PartialPriorRollPitchZ)
  PackedPartialPriorRollPitchZ( d.rp, d.z )
end


function compare(a::PartialPriorRollPitchZ, b::PartialPriorRollPitchZ; tol::Float64=1e-10)
  TP = true
  TP = TP && norm(a.rp.μ-b.rp.μ) < tol
  TP = TP && norm(a.rp.Σ.mat[:]-b.rp.Σ.mat[:]) < tol
  TP = TP && norm(a.z.μ-b.z.μ) < tol
  TP = TP && norm(a.z.σ-b.z.σ) < tol
  TP = TP && norm(collect(a.partial)-collect(b.partial)) < tol
  return TP
end





# Partial pairwise constraint between poses X,Y,Yaw
# ------------------------------------------------------------------------------

mutable struct PartialPose3XYYaw <: FunctorPairwise #RoME.BetweenPoses
  xyy::Distributions.MvNormal
  partial::Tuple
  PartialPose3XYYaw() = new()
  PartialPose3XYYaw(xyy::MvNormal) = new(xyy, (1,2,6))
end
function getSample(pxyy::PartialPose3XYYaw, N::Int=1)
  return (rand(pxyy.xyy,N), )
end
function (pxyy::PartialPose3XYYaw)(res::Array{Float64},
            userdata,
            idx::Int,
            meas::Tuple{Array{Float64,2}},
            wXi::Array{Float64,2},
            wXj::Array{Float64,2}  )
  #
  wXjhat = SE2(wXi[[1;2;6],idx])*SE2(meas[1][:,idx]) #*SE2(pp2.Zij[:,1])*SE2(meas[1][:,idx])
  jXjhat = SE2(wXj[[1;2;6],idx]) \ wXjhat
  se2vee!(res, jXjhat)
  nothing
end


mutable struct PackedPartialPose3XYYaw <: IncrementalInference.PackedInferenceType
  vecZij::Array{Float64,1} # 3translations, 3rotation
  vecCov::Array{Float64,1}
  PackedPartialPose3XYYaw() = new()
  PackedPartialPose3XYYaw(x1::Vector{Float64}, x2::Array{Float64}) = new(x1, x2[:])
end
function convert(::Type{PartialPose3XYYaw}, d::PackedPartialPose3XYYaw)
  return PartialPose3XYYaw( Distributions.MvNormal(d.vecZij,
               reshapeVec2Mat(d.vecCov, 3))  )
end
function convert(::Type{PackedPartialPose3XYYaw}, d::PartialPose3XYYaw)
  return PackedPartialPose3XYYaw(d.xyy.μ, d.xyy.Σ.mat )
end



function compare(a::PartialPose3XYYaw, b::PartialPose3XYYaw; tol::Float64=1e-10)
  TP = true
  TP = TP && norm(a.xyy.μ-b.xyy.μ) < tol
  TP = TP && norm(a.xyy.Σ.mat[:]-b.xyy.Σ.mat[:]) < tol
  TP = TP && norm(collect(a.partial)-collect(b.partial)) < tol
  return TP
end










mutable struct PartialPose3XYYawNH <: IncrementalInference.FunctorPairwiseNH
  xyy::Distributions.MvNormal
  partial::Tuple
  nullhypothesis::Distributions.Categorical
  PartialPose3XYYawNH() = new()
  PartialPose3XYYawNH(xyy::MvNormal, vh::Vector{Float64}) = new(xyy, (1,2,6),  Distributions.Categorical(vh))
end
function getSample(pxyy::PartialPose3XYYawNH, N::Int=1)
  return (rand(pxyy.xyy,N), )
end
function (pxyy::PartialPose3XYYawNH)(res::Array{Float64},
            userdata,
            idx::Int,
            meas::Tuple{Array{Float64,2}},
            wXi::Array{Float64,2},
            wXj::Array{Float64,2}  )
  #
  wXjhat = SE2(wXi[[1;2;6],idx])*SE2(meas[1][:,idx]) #*SE2(pp2.Zij[:,1])*SE2(meas[1][:,idx])
  jXjhat = SE2(wXj[[1;2;6],idx]) \ wXjhat
  se2vee!(res, jXjhat)
  nothing
end



mutable struct PackedPartialPose3XYYawNH <: IncrementalInference.PackedInferenceType
  vecZij::Array{Float64,1} # 3translations, 3rotation
  vecCov::Array{Float64,1}
  nullhypothesis::Vector{Float64}
  PackedPartialPose3XYYawNH() = new()
  PackedPartialPose3XYYawNH(x1::Vector{Float64}, x2::Array{Float64}, x3::Vector{Float64}) = new(x1, x2[:], x3)
end
function convert(::Type{PartialPose3XYYawNH}, d::PackedPartialPose3XYYawNH)
  return PartialPose3XYYawNH( Distributions.MvNormal(d.vecZij,
               reshapeVec2Mat(d.vecCov, 3)), d.nullhypothesis  )
end
function convert(::Type{PackedPartialPose3XYYawNH}, d::PartialPose3XYYawNH)
  return PackedPartialPose3XYYawNH(d.xyy.μ, d.xyy.Σ.mat, d.nullhypothesis.p )
end


function compare(a::PartialPose3XYYawNH, b::PartialPose3XYYawNH; tol::Float64=1e-10)
  TP = true
  TP = TP && norm(a.xyy.μ-b.xyy.μ) < tol
  TP = TP && norm(a.xyy.Σ.mat[:]-b.xyy.Σ.mat[:]) < tol
  TP = TP && norm(collect(a.partial)-collect(b.partial)) < tol
  TP = TP && norm(a.nullhypothesis.p-b.nullhypothesis.p) < tol
  return TP
end






#
