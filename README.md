# high-bandwidth-recognition-benchmarks

Companion code for the paper "A polynomial-time algorithm for recognizing high-bandwidth graphs" by Luis M. B. Varona.

## How to run

### Docker

```bash
mkdir -p data/
chmod 777 data/ # So Docker can write results here
docker build -t bandwidth-bench .
docker run -v $(pwd)/data:/app/data:Z bandwidth-bench
```

### Podman

```bash
mkdir -p data/
chmod 777 data/ # So Podman can write results here
podman build -t bandwidth-bench .
podman run -v $(pwd)/data:/app/data:Z bandwidth-bench
```

### Additional notes

To run the benchmark suites against Saxe&ndash;Gurari&ndash;Sudborough and Del Corso&ndash;Manzini/Caprara&ndash;Salazar-Gonz&aacute;lez separately, change the last line of the Docker file from

```dockerfile
CMD ["sh", "-c", "julia --project=. src/bench_GS84.jl && julia --project=. src/bench_DCM99_CSG05.jl"]
```

to either

```dockerfile
CMD ["julia", "--project=.", "src/bench_GS84.jl"]
```

or

```dockerfile
CMD ["julia", "--project=.", "src/bench_DCM99_CSG05.jl"]
```

as applicable.

Meanwhile, if you want to save terminal output while running, simply add

```bash
2>&1 | tee "benchmark_$(date +%Y%m%d_%H%M%S).log"
```

to the end of your `docker run` / `podman run` command.

## Output

Benchmark results are saved as CSV files in the `data/` directory:

- `compare_GS84_aff.csv` / `compare_GS84_neg.csv`
- `compare_DCM99_CSG05_aff.csv` / `compare_DCM99_CSG05_neg.csv`
