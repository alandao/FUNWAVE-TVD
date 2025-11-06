# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

FUNWAVE-TVD is a Boussinesq wave model for nearshore wave dynamics, capable of simulating wave propagation, breaking, runup, and various coastal processes. The code is written in Fortran 90/95 with MPI parallelization support.

## Building and Compilation

The build system uses GNU Make with a modular configuration. Key makefiles:
- `Makefile` - Main makefile with configuration options
- `GNUMake/Essential/Make_Essential` - Core build logic

### Common Build Commands

```bash
# Basic compilation (creates executable in funwave-work/)
make

# Clean build directory
make clean

# Check compiler and MPI versions
make check-env
```

### Validation Build Targets (SurfWave-JAX Development)

For SurfWave-JAX development, use these targets to build and validate debug instrumentation:

**Setup (one-time)**:
```bash
# Create Python venv in FUNWAVE-TVD directory
python3 -m venv venv
venv/bin/pip install numpy
```

**Build commands**:
```bash
# Build RELEASE version (no debug instrumentation)
make release
# Creates: funwave-work/funwave--mpif90-parallel-single

# Build DEBUG version (with all current instrumentation)
make debug
# Creates: funwave-work/funwave-DEBUG (constant name)
```

**Important**: The debug executable always has the **constant name** `funwave-DEBUG` regardless of which debug flags are enabled. This means you never need to update test scripts when adding new instrumentation phases.

**Validation test**:
```bash
# Run instrumentation validation test
venv/bin/python test_regular_vs_debug.py
```

**What the test does:**
- Runs both regular and debug executables on the same test case (`test_regular_wave_1d_flat/`)
- Compares ALL simulation output files (eta, mask, etc.)
- Verifies max difference < 1e-14 (essentially machine precision)
- Confirms debug instrumentation is completely non-invasive
- Checks that debug files are created in `output/debug/` subdirectories

**Current instrumentation status (Phases 1-3)**:
- **Phase 1 (Level 0)**: Van Leer limited slopes - 10 files in `debug/derivatives/`
- **Phase 2 (Levels 1-2)**: MUSCL reconstruction - 24 files in `debug/reconstruction/`
- **Phase 3 (Level 3)**: Wave speeds - 4 files in `debug/wavespeeds/`
- **State snapshots**: 5 files in `debug/state/` (depth, eta, mask, u, v)
- **Total**: 43 debug files at timestep 50 (TIME ~= 0.5s)

**Validation results**: All simulation outputs identical (max difference = 0.00e+00)

**Critical requirement:** Debug instrumentation must NOT affect simulation results.

### Build Configuration

Edit the main `Makefile` to configure:
- `COMPILER`: intel, gnu, pgi, onyx
- `PARALLEL`: true/false (MPI support)
- `PRECISION`: single/double

Optional flags (uncomment as needed):
- `-DVESSEL`: Ship wake modeling
- `-DSEDIMENT`: Sediment transport
- `-DMANNING`: Manning friction
- `-DMETEO`: Meteorological forcing
- `-DWIND`: Wind forcing

**Note**: Processor numbers (`PX`, `PY`) are set in the `input.txt` file, not the Makefile. Ensure `mpirun -np` matches `PX * PY`.

### Running Simulations

```bash
# Find the executable name (varies based on compiler and configuration)
ls funwave-work/

# Run RELEASE version (parallel execution, adjust -np to match PX*PY in input file)
mpirun -np 4 ./funwave-work/funwave--mpif90-parallel-single

# Run DEBUG version (for SurfWave-JAX validation)
mpirun -np 4 ./funwave-work/funwave-DEBUG
```

The model reads configuration from `input.txt` in the working directory.

**Executable naming**:
- **Release**: `funwave--[compiler]-[mode]-[precision]` (e.g., `funwave--mpif90-parallel-single`)
  - compiler: mpif90, ifort, etc.
  - mode: parallel or serial
  - precision: single or double
- **Debug**: `funwave-DEBUG` (constant name, always the same regardless of instrumentation flags)

## Code Architecture

### Core Modules

**Main Program Flow** (`src/main.F`):
- Read input parameters
- Initialize domain and variables
- Time-stepping loop:
  - Update boundary conditions
  - Compute fluxes (momentum/mass)
  - Solve dispersion terms
  - Apply source terms
  - Output results

**Key Modules**:
- `mod_global.F`: Global variables, arrays, and MPI configuration
- `mod_param.F`: Physical and numerical parameters
- `mod_input.F`: Input file parsing and parameter setup
- `mod_vessel.F`: Ship wake generation (if -DVESSEL enabled)
- `mod_sediment.F`: Sediment transport (if -DSEDIMENT enabled)

**Core Solvers**:
- `fluxes.F`: TVD numerical fluxes for shallow water equations
- `dispersion.F`: Boussinesq dispersion terms
- `etauv_solver.F`: Eta (surface elevation) and velocity solver
- `bc.F`: Boundary condition implementations
- `wavemaker.F`: Wave generation (solitary, irregular, time series)

### Input File Structure

The model expects an `input.txt` file with parameters for:
- Domain dimensions (Mglob, Nglob)
- Grid spacing (DX, DY) or spherical coordinates
- Time control (TOTAL_TIME, PLOT_INTV)
- Depth specification (file or idealized)
- Wavemaker settings
- Physics options (dispersion, breaking, friction)
- Output controls

### Output Files

Results are written to the specified `RESULT_FOLDER`:
- `eta_XXXXX`: Surface elevation
- `u_XXXXX`, `v_XXXXX`: Velocity components
- `mask_XXXXX`: Wet/dry masks
- Station time series (if stations defined)

## Testing and Validation

### 1D Surface Wave with Regular Waves Example

This example demonstrates building and running a 1D slope simulation with regular wave generation.

#### Build Configuration (macOS)

For macOS systems, use the GNU compiler instead of Intel:

```bash
# Edit Makefile
COMPILER    = gnu       # Change from intel to gnu for Mac compatibility
PARALLEL    = true
PRECISION   = single
```

#### Build and Run Steps

1. **Clean and build the executable:**
```bash
make clean
make
# Creates executable: funwave-work/funwave--mpif90-parallel-single
```

2. **Create working directory:**
```bash
mkdir -p test_regular_wave_1d/output
cd test_regular_wave_1d
```

3. **Create input.txt (copy from simple_cases):**

Copy pre-configured file:
```bash
cp ../simple_cases/surface_wave_1d/input_files/input_reg.txt input.txt
```

4. **Run the simulation:**
```bash
# Note: -np must match PX * PY from input.txt
mpirun -np 4 ../funwave-work/funwave--mpif90-parallel-single
```

#### Expected Output

The simulation generates files in the output directory:
- `eta_00000` to `eta_00019`: Surface elevation at 10-second intervals
- `mask_00000` to `mask_00019`: Wet/dry masks
- `dep.out`: Bathymetry data
- Console output shows statistics including max elevation (~1.15m), velocities, and energy

#### Verification

A successful run will:
- Complete in ~22 seconds for 200s simulation time (with 4 processors)
- Show wave shoaling with increasing velocity up the slope (from ~0.5 m/s to ~1.7 m/s)
- Generate 20 timestep outputs (every 10 seconds)
- Display "Normal Termination!" message
- Maximum surface elevation reaches ~1.14m due to wave shoaling

### Benchmark Cases

Located in `benchmarks/`:
- `car_conical_island/`: Wave diffraction around conical island
- `car_mase_kirby/`: Wave-current interaction
- `car_osu_runup/`: Solitary wave runup
- `sph_comp_beach/`: Composite beach profile (spherical coords)

### Simple Test Cases

Located in `simple_cases/`:
- `beach_2d/`: 2D beach with wave breaking
- `inlet_shoal/`: Wave refraction over inlet
- `rip_2d/`: Rip current generation
- `single_vessel_cohesive/`: Ship wake with sediment
- `surface_wave_1d/`: Pre-configured 1D wave examples (regular, solitary, irregular)

To run a test case:
1. Copy input files to working directory
2. Adjust processor numbers if using MPI
3. Run the executable
4. Check output in result folder

## Parallel Processing

The code uses MPI domain decomposition:
- Set `PX` and `PY` in input file for processor grid
- Ensure `mpirun -np` matches `PX * PY`
- Ghost cells handle inter-processor communication
- Each processor writes its own output files

## Common Development Tasks

### Debugging

**Compiler debug mode** (for gdb/lldb debugging):
```bash
# Edit Makefile
DEBUG = true  # Adds debug flags (-g, -Wall), disables optimization
```

**Validation instrumentation** (for SurfWave-JAX development):
```bash
# Use custom build targets (see "Validation Build Targets" section above)
make debug    # Creates funwave-DEBUG with instrumentation output
```

**Note**: These are different debug modes:
- `DEBUG=true` in Makefile: Compiler debug flags for traditional debugging
- `make debug` target: Validation instrumentation for bottom-up testing (outputs arrays to files)

Use station output for time series at specific points.