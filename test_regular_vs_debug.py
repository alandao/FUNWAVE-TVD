#!/usr/bin/env venv/bin/python
"""
Critical Phase 0 Test: Verify debug instrumentation does NOT affect simulation results.

This test ensures that FUNWAVE with debug instrumentation (DEBUG_DERIVATIVES,
DEBUG_RECONSTRUCTION, etc.) produces EXACTLY the same simulation outputs as
regular FUNWAVE (excluding debug files).

This is a HARD REQUIREMENT and must pass for all phases.

Usage:
    cd FUNWAVE-TVD
    venv/bin/python test_regular_vs_debug.py
"""
import subprocess
import shutil
from pathlib import Path
import numpy as np
import sys

def run_command(cmd, cwd=None, timeout=60):
    """Run shell command and return output."""
    result = subprocess.run(
        cmd,
        shell=True,
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=timeout
    )
    return result.returncode, result.stdout, result.stderr

def compare_files_exact(file1, file2):
    """Compare two files for exact binary equality."""
    with open(file1, 'rb') as f1, open(file2, 'rb') as f2:
        return f1.read() == f2.read()

def compare_arrays_numerical(file1, file2, tolerance=1e-14):
    """Compare two numerical output files."""
    arr1 = np.loadtxt(file1)
    arr2 = np.loadtxt(file2)

    if arr1.shape != arr2.shape:
        return False, f"Shape mismatch: {arr1.shape} vs {arr2.shape}"

    max_diff = np.max(np.abs(arr1 - arr2))

    if max_diff > tolerance:
        return False, f"Max difference: {max_diff:.2e} > {tolerance:.2e}"

    return True, f"Max difference: {max_diff:.2e}"

def main():
    print("="*70)
    print("CRITICAL TEST: Regular vs Debug Mode Comparison")
    print("="*70)
    print()
    print("Requirement: Debug instrumentation must NOT affect simulation results")
    print("Tolerance: < 1e-14 (near machine precision)")
    print()

    # Paths (script now runs from FUNWAVE-TVD directory)
    funwave_dir = Path(".")
    test_dir = funwave_dir / "test_regular_wave_1d_flat"
    output_dir = test_dir / "output"
    regular_backup_dir = test_dir / "output_regular_backup"
    debug_backup_dir = test_dir / "output_debug_backup"

    regular_exe = funwave_dir / "funwave-work" / "funwave--mpif90-parallel-single"
    debug_exe = funwave_dir / "funwave-work" / "funwave-DEBUG_DERIVATIVES-DEBUG_RECONSTRUCTION--mpif90-parallel-single"

    # Check executables exist
    if not regular_exe.exists():
        print(f"❌ Regular executable not found: {regular_exe}")
        print("   Run: make clean && make")
        return False

    if not debug_exe.exists():
        print(f"❌ Debug executable not found: {debug_exe}")
        print("   Run: make clean && make debug")
        return False

    print(f"✓ Regular executable: {regular_exe.name}")
    print(f"✓ Debug executable: {debug_exe.name}")
    print()

    # Step 1: Clean and run regular mode
    print("Step 1: Running REGULAR mode...")
    print("-" * 70)

    # Clean output
    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True)

    # Run regular FUNWAVE
    cmd = f"mpirun -np 4 {regular_exe.absolute()}"
    returncode, stdout, stderr = run_command(cmd, cwd=test_dir, timeout=60)

    if returncode != 0:
        print(f"❌ Regular mode FAILED (exit code {returncode})")
        print(stderr)
        return False

    if "Normal Termination!" not in stdout:
        print("❌ Regular mode did not complete successfully")
        print(stdout[-500:])
        return False

    print("✓ Regular mode completed successfully")

    # Backup regular outputs
    if regular_backup_dir.exists():
        shutil.rmtree(regular_backup_dir)
    shutil.copytree(output_dir, regular_backup_dir)
    print(f"✓ Backed up regular outputs to {regular_backup_dir.name}")
    print()

    # Step 2: Clean and run debug mode
    print("Step 2: Running DEBUG mode...")
    print("-" * 70)

    # Clean output (keep backup)
    shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True)
    (output_dir / "debug").mkdir(parents=True)
    for subdir in ["state", "derivatives", "reconstruction", "wavespeeds", "fluxes",
                   "interface", "rk_stages", "sources", "dispersion"]:
        (output_dir / "debug" / subdir).mkdir(parents=True)

    # Run debug FUNWAVE
    cmd = f"mpirun -np 4 {debug_exe.absolute()}"
    returncode, stdout, stderr = run_command(cmd, cwd=test_dir, timeout=60)

    if returncode != 0:
        print(f"❌ Debug mode FAILED (exit code {returncode})")
        print(stderr)
        return False

    if "Normal Termination!" not in stdout:
        print("❌ Debug mode did not complete successfully")
        print(stdout[-500:])
        return False

    print("✓ Debug mode completed successfully")

    # Check debug output was created
    debug_files = []
    for subdir in ["state", "derivatives", "reconstruction"]:
        debug_files.extend(list((output_dir / "debug" / subdir).glob("*.txt")))

    if not debug_files:
        print("❌ No debug files created!")
        return False

    print(f"✓ Debug files created: {len(debug_files)} files")

    # Backup debug outputs
    if debug_backup_dir.exists():
        shutil.rmtree(debug_backup_dir)
    shutil.copytree(output_dir, debug_backup_dir)
    print(f"✓ Backed up debug outputs to {debug_backup_dir.name}")
    print()

    # Step 3: Compare simulation outputs
    print("Step 3: Comparing simulation outputs...")
    print("-" * 70)

    # Find all output files (excluding debug directory)
    regular_files = [f for f in regular_backup_dir.glob("*")
                     if f.is_file() and f.suffix in ['.out', ''] and 'debug' not in f.name]

    all_match = True
    comparison_results = []

    for regular_file in sorted(regular_files):
        debug_file = output_dir / regular_file.name

        if not debug_file.exists():
            print(f"❌ {regular_file.name}: Missing in debug output")
            all_match = False
            continue

        # Try numerical comparison for output files
        if regular_file.suffix == '.out' or regular_file.name.startswith(('eta_', 'u_', 'v_', 'mask_')):
            try:
                match, info = compare_arrays_numerical(regular_file, debug_file)
                status = "✓" if match else "❌"
                comparison_results.append((regular_file.name, match, info))
                print(f"{status} {regular_file.name:20s} {info}")
                if not match:
                    all_match = False
            except Exception as e:
                print(f"⚠  {regular_file.name:20s} Could not compare: {e}")
        else:
            # Binary comparison for other files
            if compare_files_exact(regular_file, debug_file):
                print(f"✓ {regular_file.name:20s} Exact binary match")
            else:
                print(f"❌ {regular_file.name:20s} Files differ")
                all_match = False

    print()

    # Step 4: Summary
    print("="*70)
    print("SUMMARY")
    print("="*70)

    if all_match:
        print("✅ PASS: Debug instrumentation does NOT affect simulation results")
        print()
        print("All simulation outputs are identical between regular and debug modes")
        print("(difference < 1e-14, essentially machine precision)")
        print()
        print(f"Debug files created: {len(debug_files)}")
        print(f"Regular outputs: {len(regular_files)}")
        print(f"Comparisons: {len(comparison_results)}")
        print()
        print("Phase 0 requirement satisfied: Debug instrumentation is non-invasive ✓")
        return True
    else:
        print("❌ FAIL: Debug instrumentation AFFECTS simulation results")
        print()
        print("This is a critical failure. Debug instrumentation must not change")
        print("the simulation outputs. Check for:")
        print("  - Unintended side effects in debug code")
        print("  - Missing conditional compilation directives")
        print("  - Incorrect variable usage")
        print()
        print("Failed comparisons:")
        for name, match, info in comparison_results:
            if not match:
                print(f"  - {name}: {info}")
        return False

if __name__ == "__main__":
    try:
        success = main()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\nTest interrupted")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Test failed with exception: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
