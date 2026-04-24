# Memory Testing

This repository contains a small Slurm-based experiment for answering a specific question:

- when a Python job reads a large amount of data, what does Slurm `sacct` report as memory usage?
- how do the actual `read` syscalls compare with `sacct MaxRSS`?

The current experiment reads `300 MiB` from a large input file using:

- `os.open`
- `os.lseek`
- `os.read`
- `os.close`

and then keeps the returned bytes object resident in memory during `sleep(45)` so Slurm has time to sample the job.

## Repository layout

- `scripts/memory_testing.py`
  The Python test program. It seeks to byte offset `500`, reads `300 MiB`, prints the byte count, and sleeps for `45` seconds.
- `slurm/run_memory_testing.sbatch`
  The Slurm batch script. It runs the Python program under `strace` and writes timestamped `.out`, `.err`, and `.strace` logs.
- `logs/`
  Example logs from one completed run.
- `data/`
  Local runtime input directory. This is ignored by git.
- `opt/`
  Local non-root install prefix for `strace`. This is ignored by git.

## What this experiment measures

The experiment is meant to compare two things:

1. bytes returned by the actual `read` syscall, recorded by `strace`
2. resident memory reported by Slurm in `sacct`

For the current script, the expected behavior is:

- `read(...) = 314572800`
- `sacct MaxRSS` should be around `300 MiB`

That is because the Python script stores the result of `os.read(...)` in a variable and keeps it alive during the sleep period.

## Prerequisites

You need:

- Python 3
- Slurm (`sbatch`, `sacct`)
- a input data file with data as `data/input.txt`
- a local install of `strace` at `opt/strace-6.19/bin/strace`

## Prepare the input file

This repo expects the benchmark input file at:

```bash
data/input.txt
```
## Install strace locally without root 

i do not have root access in HPC environment so installing it without root, but if you have root access you can directly install it.
From the repository root:

```bash
wget https://github.com/strace/strace/releases/download/v6.19/strace-6.19.tar.xz
tar -xf strace-6.19.tar.xz
mkdir -p build/strace-6.19 opt/strace-6.19
cd build/strace-6.19
../../strace-6.19/configure --prefix="$(pwd)/../../opt/strace-6.19"
make -j"$(nproc)"
make install
cd ../..
```

Verify:

```bash
opt/strace-6.19/bin/strace -V
```
add the path to env path variable for easy access of strace

## Run the experiment

Submit the Slurm job:

```bash
sbatch slurm/run_memory_testing.sbatch
```

The batch script writes timestamped logs under `logs/`:

- `memory_testing-<jobid>-<timestamp>.out`
- `memory_testing-<jobid>-<timestamp>.err`
- `memory_testing-<jobid>-<timestamp>.strace`

## What the batch script does

The Slurm script runs:

```bash
opt/strace-6.19/bin/strace \
  -tt -T -yy -s 0 \
  -e trace=openat,read,lseek,close \
  -o logs/memory_testing-<jobid>-<timestamp>.strace \
  python3 scripts/memory_testing.py
```

Meaning:

- `-tt`: timestamp each syscall
- `-T`: include syscall duration
- `-yy`: decode file descriptors to paths
- `-s 0`: do not truncate printed strings
- `-e trace=openat,read,lseek,close`: only trace the file operations relevant to this experiment

## Check the Slurm result

After the job finishes:

```bash
sacct -j <jobid> --format=JobID,JobName,State,ExitCode,Elapsed,MaxRSS,AveRSS,MaxDiskRead,AveDiskRead
```

For this experiment, `MaxRSS` is the main field of interest.

## Check the relevant syscalls

To isolate the target file access from Python startup noise:

```bash
grep 'data/input.txt' logs/memory_testing-<jobid>-<timestamp>.strace
```

You should see lines similar to:

```text
openat(..., "data/input.txt", O_RDONLY|O_CLOEXEC) = 3<.../data/input.txt>
lseek(3<.../data/input.txt>, 500, SEEK_SET) = 500
read(3<.../data/input.txt>, ..., 314572800) = 314572800
close(3<.../data/input.txt>) = 0
```

To sum the bytes returned by `read` for the target file:

```bash
awk 'match($0, /read\(.*data\/input\.txt.*\) = ([0-9]+)/, m) {sum += m[1]} END {print sum}' logs/memory_testing-<jobid>-<timestamp>.strace
```

## Notes

- `data/` and `opt/` are ignored by git on purpose.
- if the cluster disables `ptrace` for compute jobs, `strace` will fail
- if a job ends before Slurm’s accounting sample interval, `MaxRSS` may show `0`; that is why the Python script sleeps after reading
