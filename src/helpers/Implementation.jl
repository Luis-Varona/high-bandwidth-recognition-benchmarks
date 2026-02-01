# Copyright 2026 Luis M. B. Varona
#
# Licensed under the MIT license <LICENSE or
# http://opensource.org/licenses/MIT>. This file may not be copied, modified, or
# distributed except according to those terms.

module Implementation

using Combinatorics: permutations
using MatrixBandwidth

export VaronaHBR

struct VaronaHBR <: MatrixBandwidth.Recognition.AbstractDecider end

Base.summary(::VaronaHBR) = "Varona HBR"

MatrixBandwidth._requires_structural_symmetry(::VaronaHBR) = true

function MatrixBandwidth.Recognition._has_bandwidth_k_ordering_impl(
    A::AbstractMatrix{Bool}, k::Integer, ::VaronaHBR
)
    n = size(A, 1)
    nodes = axes(A, 1)
    left_domain = 1:(n - k - 1)
    right = Vector{Int}(undef, n - k - 1)

    for left in permutations(nodes, n - k - 1)
        remaining_nodes = setdiff(nodes, left)

        blocked = Dict(
            node => minimum(
                Iterators.filter(i -> A[left[i], node], left_domain); init=typemax(Int)
            ) for node in remaining_nodes
        )

        sort!(remaining_nodes; by=node -> blocked[node])

        j = 1
        valid_right = true

        while (j <= n - k - 1 && valid_right)
            num_blocked = searchsortedlast(
                remaining_nodes, j; lt=(val, node) -> val < blocked[node]
            )

            if k + 1 - num_blocked >= n - k - j
                right[j] = remaining_nodes[2k - n + j + 2]
                j += 1
            else
                valid_right = false
            end
        end

        if valid_right
            return vcat(left, setdiff(remaining_nodes, right), right)
        end
    end

    return nothing
end

end
