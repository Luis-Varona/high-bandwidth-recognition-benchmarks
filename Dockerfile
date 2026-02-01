FROM julia:1.12.4
WORKDIR /app

COPY Project.toml Manifest.toml ./
RUN julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

COPY src/ ./src/
CMD ["sh", "-c", "julia --project=. src/bench_GS84.jl && julia --project=. src/bench_DCM99_CSG05.jl"]
