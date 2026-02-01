# Copyright 2026 Luis M. B. Varona
#
# Licensed under the MIT license <LICENSE or
# http://opensource.org/licenses/MIT>. This file may not be copied, modified, or
# distributed except according to those terms.

module Utils

using BenchmarkTools
using Dates
using MatrixBandwidth
using Random
using Serialization

export BenchmarkResult, run_benchmark, generate_test_matrix_aff, generate_test_matrix_neg

struct BenchmarkPartialResult
    algorithm::String
    time_exceeded::Bool
    band_le_k::Union{Bool,Missing}
    time_ms::Union{Float64,Missing}
end

struct BenchmarkResult
    n::Int
    k::Int
    psi::Int
    p::Float64
    blb::Int
    algorithm::String
    time_exceeded::Bool
    band_le_k::Union{Bool,Missing}
    time_ms::Union{Float64,Missing}

    function BenchmarkResult(
        n::Int, k::Int, psi::Int, p::Float64, blb::Int, partial_res::BenchmarkPartialResult
    )
        return new(
            n,
            k,
            psi,
            p,
            blb,
            partial_res.algorithm,
            partial_res.time_exceeded,
            partial_res.band_le_k,
            partial_res.time_ms,
        )
    end
end

function generate_test_matrix_aff(n::Int, k::Int, p_min::Real, p_max::Real)
    psi = rand((k - 2):k)
    p = p_min + (p_max - p_min) * rand()

    A = MatrixBandwidth.random_banded_matrix(n, psi; p=p)

    while bandwidth(A) <= k
        perm = randperm(n)
        A = A[perm, perm]
    end

    return A, psi, p
end

function generate_test_matrix_neg(
    n::Int, k::Int, p_min::Real, p_max::Real, decider::MatrixBandwidth.AbstractDecider
)
    A = trues(n, n)
    psi = p = 0

    while (
        bandwidth_lower_bound(A) > k || has_bandwidth_k_ordering(A, k, decider).has_ordering
    )
        psi = rand((k + 1):(k + 3))
        p = p_min + (p_max - p_min) * rand()
        A = MatrixBandwidth.random_banded_matrix(n, psi; p=p)
    end

    perm = randperm(n)
    A = A[perm, perm]

    return A, psi, p
end

function run_benchmark(
    A::Matrix{Float64},
    k::Int,
    decider::MatrixBandwidth.AbstractDecider,
    time_limit_secs::Int;
    verbose::Bool=false,
)
    algorithm_name = summary(decider)

    if verbose
        println("Running $algorithm_name on $(summary(A)) for k=$k...")
    end

    project_dir = dirname(dirname(@__DIR__))
    tmp_dir = joinpath(project_dir, "tmp")
    mkpath(tmp_dir)

    input_file = tempname(tmp_dir)
    output_file = tempname(tmp_dir)
    impl_file = joinpath(@__DIR__, "Implementation.jl")

    open(input_file, "w") do io
        serialize(io, (A, k, decider))
        return nothing
    end

    script = """
    include("$impl_file")
    using .Implementation

    using BenchmarkTools
    using MatrixBandwidth
    using Serialization

    A, k, decider = open(deserialize, "$input_file")
    res = has_bandwidth_k_ordering(A, k, decider)

    open("$output_file", "w") do io
        serialize(io, res)
        return nothing
    end
    """

    script_file = tempname(tmp_dir) * ".jl"
    write(script_file, script)

    proc = run(`julia --project=$project_dir $script_file`; wait=false)
    start_time = now()
    timed_out = false

    while (process_running(proc) && !timed_out)
        elapsed_secs = (now() - start_time).value / 1000

        if elapsed_secs > time_limit_secs
            timed_out = true
            kill(proc)
        end

        sleep(0.1)
    end

    if verbose
        elapsed_secs = (now() - start_time).value / 1000
        println("Elapsed time: $(elapsed_secs)s")
    end

    if timed_out
        if verbose
            println("Time limit exceeded!\n")
        end

        out = BenchmarkPartialResult(algorithm_name, true, missing, missing)
    else
        if !success(proc)
            error(
                "CRITICAL: Error in subprocess! (Assuming I wasn't silly and missed another bug somewhere, likely OOM.",
            )
        end

        res = open(deserialize, output_file)

        if verbose
            println(res)
        end

        bench = @benchmark has_bandwidth_k_ordering($A, $k, $decider)

        if verbose
            display(bench)
            println()
        end

        time_ms = minimum(bench.times) / 1e6

        out = BenchmarkPartialResult(algorithm_name, false, res.has_ordering, time_ms)
    end

    rm(tmp_dir; force=true, recursive=true)

    return out
end

end
