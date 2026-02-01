# Copyright 2026 Luis M. B. Varona
#
# Licensed under the MIT license <LICENSE or
# http://opensource.org/licenses/MIT>. This file may not be copied, modified, or
# distributed except according to those terms.

include("helpers/Implementation.jl")
include("helpers/Utils.jl")
using .Implementation
using .Utils

using BenchmarkTools
using CSV
using DataFrames
using MatrixBandwidth
using MatrixBandwidth.Recognition
using Random

const SEED = 1011 # My friend's birthday <3

const N_VALUES = 12:2:18
const P_RANGE_AFF = (0.3, 0.6)
const P_RANGE_NEG = (0.85, 0.95)
const NUM_ITER = 5
const TIME_LIM_SECS = 90

const DATA_AFF_PATH = joinpath(dirname(@__DIR__), "data", "compare_GS84_aff.csv")
const DATA_NEG_PATH = joinpath(dirname(@__DIR__), "data", "compare_GS84_neg.csv")

function k_values_aff(n::Int)
    return (n - 6):2:(n - 2)
end

function k_values_and_deciders_neg(n::Int)
    return [(n - 6, CapraraSalazarGonzalez), (n - 4, CapraraSalazarGonzalez)]
end

function main()
    Random.seed!(SEED)
    mkpath(dirname(DATA_AFF_PATH))
    mkpath(dirname(DATA_NEG_PATH))
    results_aff = BenchmarkResult[]
    results_neg = BenchmarkResult[]

    for n in N_VALUES
        for k in k_values_aff(n)
            for _ in 1:NUM_ITER
                A, psi, p = generate_test_matrix_aff(n, k, P_RANGE_AFF...)
                blb = bandwidth_lower_bound(A)

                partial_varona = run_benchmark(
                    A, k, VaronaHBR(), TIME_LIM_SECS; verbose=true
                )
                push!(results_aff, BenchmarkResult(n, k, psi, p, blb, partial_varona))

                partial_sgs = run_benchmark(
                    A, k, SaxeGurariSudborough(), TIME_LIM_SECS; verbose=true
                )
                push!(results_aff, BenchmarkResult(n, k, psi, p, blb, partial_sgs))
            end
        end

        for (k, decider_type) in k_values_and_deciders_neg(n)
            for _ in 1:NUM_ITER
                A, psi, p = generate_test_matrix_neg(n, k, P_RANGE_NEG..., decider_type())
                blb = bandwidth_lower_bound(A)

                partial_var26 = run_benchmark(
                    A, k, VaronaHBR(), TIME_LIM_SECS; verbose=true
                )
                push!(results_neg, BenchmarkResult(n, k, psi, p, blb, partial_var26))

                partial_gs84 = run_benchmark(
                    A, k, SaxeGurariSudborough(), TIME_LIM_SECS; verbose=true
                )
                push!(results_neg, BenchmarkResult(n, k, psi, p, blb, partial_gs84))
            end
        end
    end

    df_aff = DataFrame(;
        n=map(result -> result.n, results_aff),
        k=map(result -> result.k, results_aff),
        psi=map(result -> result.psi, results_aff),
        p=map(result -> result.p, results_aff),
        blb=map(result -> result.blb, results_aff),
        algorithm=map(result -> result.algorithm, results_aff),
        time_exceeded=map(result -> result.time_exceeded, results_aff),
        band_le_k=map(result -> result.band_le_k, results_aff),
        time_ms=map(result -> result.time_ms, results_aff),
    )

    df_neg = DataFrame(;
        n=map(result -> result.n, results_neg),
        k=map(result -> result.k, results_neg),
        psi=map(result -> result.psi, results_neg),
        p=map(result -> result.p, results_neg),
        blb=map(result -> result.blb, results_neg),
        algorithm=map(result -> result.algorithm, results_neg),
        time_exceeded=map(result -> result.time_exceeded, results_neg),
        band_le_k=map(result -> result.band_le_k, results_neg),
        time_ms=map(result -> result.time_ms, results_neg),
    )

    CSV.write(DATA_AFF_PATH, df_aff)
    println("Affirmative results saved to $DATA_AFF_PATH")

    CSV.write(DATA_NEG_PATH, df_neg)
    println("Negative results saved to $DATA_NEG_PATH")

    return nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
