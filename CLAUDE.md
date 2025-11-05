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

# Clean build and executable
make clean-exe

# Remove entire work directory
make clobber

# Check compiler and MPI versions
make check-env

# Check Makefile variable values
make print-VARIABLE_NAME
```

### Build Configuration

Edit the main `Makefile` to configure:
- `COMPILER`: intel, gnu, pgi, onyx
- `PARALLEL`: true/false (MPI support)
- `PRECISION`: single/double
- `PX`, `PY`: Processor numbers for MPI (must match mpirun -np)

Optional flags (uncomment as needed):
- `-DVESSEL`: Ship wake modeling
- `-DSEDIMENT`: Sediment transport
- `-DMANNING`: Manning friction
- `-DMETEO`: Meteorological forcing
- `-DWIND`: Wind forcing

### Running Simulations

```bash
# Serial execution
./funwave-work/funwave

# Parallel execution (adjust -np to match PX*PY in input file)
mpirun -np 4 ./funwave-work/funwave
```

The model reads configuration from `input.txt` in the working directory.

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

3. **Create input.txt with key parameters:**
```
TITLE = regular_1D
PX = 2                  # Processors in X
PY = 1                  # Processors in Y
DEPTH_TYPE = SLOPE      # Idealized slope bathymetry
DEPTH_FLAT = 10.0       # Initial depth (m)
SLP = 0.05              # Slope gradient
Xslp = 800.0            # Slope starting position (m)
Mglob = 1024            # Grid points in X
Nglob = 3               # Grid points in Y (minimal for 1D)
DX = 1.0                # Grid spacing X (m)
DY = 1.0                # Grid spacing Y (m)
TOTAL_TIME = 200.0      # Simulation time (s)
PLOT_INTV = 10.0        # Output interval (s)

# Wavemaker configuration
WAVEMAKER = WK_REG      # Regular wave generation
DEP_WK = 10.0          # Depth at wavemaker (m)
Xc_WK = 250.0          # Wavemaker X position (m)
Tperiod = 12.0         # Wave period (s)
AMP_WK = 0.5           # Wave amplitude (m)
Delta_WK = 3.0         # Width parameter (3.0 for nonlinear waves)

# Sponge layers
Sponge_west_width = 180.0  # Absorbing boundary
```

4. **Run the simulation:**
```bash
mpirun -np 2 ../funwave-work/funwave--mpif90-parallel-single
```

#### Expected Output

The simulation generates files in the output directory:
- `eta_00000` to `eta_00019`: Surface elevation at 10-second intervals
- `mask_00000` to `mask_00019`: Wet/dry masks
- `dep.out`: Bathymetry data
- Console output shows statistics including max elevation (~1.15m), velocities, and energy

#### Verification

A successful run will:
- Complete in ~40 seconds for 200s simulation time
- Show wave shoaling with increasing velocity up the slope
- Generate 20 timestep outputs
- Display "Normal Termination!" message

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

### Adding New Source Terms

1. Add variables to `mod_global.F`
2. Implement physics in new subroutine
3. Call from main time loop in `main.F`
4. Add preprocessor flag if optional feature

### Modifying Wave Makers

Wave generation logic is in `src/wavemaker.F`. Supported types:
- Solitary waves (INI_SOL, LEF_SOL)
- Regular waves (WK_REG)
- Irregular waves (WK_IRR, WK_TIME_SERIES)
- Custom time series input

### Debugging

Enable debug mode in Makefile:
```bash
DEBUG = true  # Adds debug flags, disables optimization
```

Use station output for time series at specific points.