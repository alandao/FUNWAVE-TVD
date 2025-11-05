#-----------BEGIN MAKEFILE---------------------------
FUNWAVE_DIR = .
WORK_DIR    = funwave-work
COMPILER    = gnu
PARALLEL    = true
EXEC        = funwave
PRECISION   = single

#-----------DEFINE FLAGS-----------------------------
#         uncomment to choose the model
#  FLAG_1  = -DCOUPLING
# FLAG_2  = -DZALPHA
# FLAG_3  = -DMANNING
#  FLAG_4  = -DVESSEL
# FLAG_5  = -DMETEO
# FLAG_6  = -DWIND
# FLAG_7  = -DSEDIMENT
# FLAG_8  = -DCHECK_MASS_CONSERVATION
# FLAG_9  = -DTMP
# FLAG_10 = -DTRACKING
#  FLAG_11 = -DDEEP_DRAFT_VESSEL
#----------------uncommon options---------------------
DEF_FC      = mpif90
DEF_FC_FLAG =
SPHERICAL   = false
MPI         = openmpi
DEBUG       = false
INCS        = $(IOINCS) $(GOTMINCS)
LIBS        = $(PV3LIB) $(CLIB)  $(PARLIB) $(IOLIBS) $(MPILIB) $(GOTMLIB)
CLIB        =
MDEPFLAGS   = --cpp --fext=f90 --file=-
RANLIB      = ranlib

#----------debug instrumentation options--------------
# Enable specific debug outputs for validation
# Set to true to instrument that computational level
DEBUG_DERIVATIVES    = true
DEBUG_RECONSTRUCTION = false
DEBUG_WAVESPEEDS     = false
DEBUG_FLUXES         = false
DEBUG_INTERFACE      = false
DEBUG_RK_STAGES      = false
DEBUG_SOURCES        = false
DEBUG_DISPERSION     = false
DEBUG_ALL            = false

# Convert debug options to compiler flags (FLAG_12+ to avoid conflicts)
FLAG_12 =
FLAG_13 =
FLAG_14 =
FLAG_15 =
FLAG_16 =
FLAG_17 =
FLAG_18 =
FLAG_19 =
FLAG_20 =

ifeq ($(DEBUG_ALL),true)
  FLAG_12 = -DDEBUG_ALL
else
  ifeq ($(DEBUG_DERIVATIVES),true)
    FLAG_12 = -DDEBUG_DERIVATIVES
  endif
  ifeq ($(DEBUG_RECONSTRUCTION),true)
    FLAG_13 = -DDEBUG_RECONSTRUCTION
  endif
  ifeq ($(DEBUG_WAVESPEEDS),true)
    FLAG_14 = -DDEBUG_WAVESPEEDS
  endif
  ifeq ($(DEBUG_FLUXES),true)
    FLAG_15 = -DDEBUG_FLUXES
  endif
  ifeq ($(DEBUG_INTERFACE),true)
    FLAG_16 = -DDEBUG_INTERFACE
  endif
  ifeq ($(DEBUG_RK_STAGES),true)
    FLAG_17 = -DDEBUG_RK_STAGES
  endif
  ifeq ($(DEBUG_SOURCES),true)
    FLAG_18 = -DDEBUG_SOURCES
  endif
  ifeq ($(DEBUG_DISPERSION),true)
    FLAG_19 = -DDEBUG_DISPERSION
  endif
endif

#----------include the essential makefiles------------
include $(FUNWAVE_DIR)/GNUMake/Essential/Make_Essential

#----------custom build targets-----------------------
.PHONY: release debug

release:
	@echo "Building RELEASE version (no debug instrumentation)..."
	@sed -i.bak 's/^DEBUG_DERIVATIVES[[:space:]]*=.*/DEBUG_DERIVATIVES    = false/' Makefile
	@sed -i.bak 's/^DEBUG_RECONSTRUCTION[[:space:]]*=.*/DEBUG_RECONSTRUCTION = false/' Makefile
	@sed -i.bak 's/^DEBUG_WAVESPEEDS[[:space:]]*=.*/DEBUG_WAVESPEEDS     = false/' Makefile
	@sed -i.bak 's/^DEBUG_FLUXES[[:space:]]*=.*/DEBUG_FLUXES         = false/' Makefile
	@sed -i.bak 's/^DEBUG_INTERFACE[[:space:]]*=.*/DEBUG_INTERFACE      = false/' Makefile
	@sed -i.bak 's/^DEBUG_RK_STAGES[[:space:]]*=.*/DEBUG_RK_STAGES      = false/' Makefile
	@sed -i.bak 's/^DEBUG_SOURCES[[:space:]]*=.*/DEBUG_SOURCES        = false/' Makefile
	@sed -i.bak 's/^DEBUG_DISPERSION[[:space:]]*=.*/DEBUG_DISPERSION     = false/' Makefile
	@sed -i.bak 's/^DEBUG_ALL[[:space:]]*=.*/DEBUG_ALL            = false/' Makefile
	@rm -f Makefile.bak
	$(MAKE) clean
	$(MAKE)
	@echo "✓ Release executable built: $(WORK_DIR)/funwave--mpif90-parallel-single"

debug:
	@echo "Building DEBUG version (with derivative instrumentation)..."
	@sed -i.bak 's/^DEBUG_DERIVATIVES[[:space:]]*=.*/DEBUG_DERIVATIVES    = true/' Makefile
	@rm -f Makefile.bak
	$(MAKE) clean
	$(MAKE)
	@echo "✓ Debug executable built: $(WORK_DIR)/funwave-DEBUG_DERIVATIVES--mpif90-parallel-single"

##-----------------------------------------------------
##      Instructions for Makefile
##-----------------------------------------------------
 
##--------Make options (provided by Make_Essential)----
# make:
#      Create the $(WORK_DIR) directory and the exectutable
# make clean:
#      Clean the "build" directory in "$(WORK_DIR)" directory
# make clean-exe:
#      Clean the "build" directory in "$(WORK_DIR)" directory and the executable
# make clobber:
#      Clean up the whole $(WORK_DIR) directory
# make check-env:
#      Print the compier version and mpi version
# make print-foo
#      Check the value of "foo" in Makefile (Or Makefile_Essential)
#      For example, "make print $(EXEC)" and you will see the final $(EXEC) name
#
##--------Custom build targets (for validation)--------
# make release:
#      Build RELEASE version (no debug instrumentation, production mode)
# make debug:
#      Build DEBUG version (with DEBUG_DERIVATIVES=true for validation)

##---------Notes to the Makefils variables------------
# FUNWAVE_DIR: 
#      The path to FUNWAVE directory, can be either absolute path or reference path. 
#      To set to current directory, set      FUNWAVE_DIR = .
# WORK_DIR:
#      The path to the work directory. A new directory will be created named $(WORK_DIR)
#      To set to current directory, set      FUNWAVE_DIR = .
# COMPILER:
#      Support list: "gnu", "intel"
# PARALLEL:
#      eithrt "true" or "false"
# EXEC: 
#      The name for exectutable. By default, the name of the executable will be "funwave+$(SUFFIX)".
#      SUFFIX is a self-explainary string depending on the options above
# PRESICION:
#      either "single" or "double"
# 
# DEF_FC:
#      Use Defined compiler name for specific machine.
#      Left for empty for dafault.
# DEF_FC_FLAG:
#      User Defined comiler flags for $(DEF_FFC)
#      Left for empty for dafault.
# SPHIRICAL:
#      "true" or "false". set to "true" to enable SPHERICAL coordinate.
# MPI:
#      Depend on the mpi version. In the settings of Make_Essential,
#      if PARALLEL=true, MPI=openmpi or MPImpich, FC = mpif90 (For any COMPILER)
#      if PARALLEL=true, COMPILER=intel, MPI=intelmpi, FC = mpiifort
# DEBUG:
#      either "true" or "false"
#      If "true" uses some debug flags, for example -Wall for gnu compiler
#      If "false", no debug flags used. Use optimization flag (-O2 for intel, -O3 for gnu)

## To use like the 3.3 or earlier version of FUNWAVE-TVD
# Go to "src" directory and set and set both "FUNWAVE_DIR" and "WORK_DIR" as ".".
# Here is an example for vessel case (uncomment all below). and you will see
#-----------BEGIN MAKEFILE---------------------------
# FUNWAVE_DIR = .
# WORK_DIR    = .
# COMPILER    = gnu
# PARALLEL    = true
# EXEC        = funwave
# PRECISION   = double

# #-----------DEFINE FLAGS-----------------------------
# #         uncomment to choose the model
# # FLAG_1  = -DCOUPLING
# # FLAG_2  = -DZALPHA
# # FLAG_3  = -DMANNING
# # FLAG_4  = -DVESSEL
# # FLAG_5  = -DMETEO
# # FLAG_6  = -DWIND
# # FLAG_7  = -DSEDIMENT
# FLAG_8  = -DCHECK_MASS_CONSERVATION
# # FLAG_9  = -DTMP
# # FLAG_10 = -DTRACKING

# #----------------uncommon options---------------------
# SPHERICAL = false
# MPI       = openmpi
# DEBUG     = false
# MDEPFLAGS = --cpp --fext=f90 --file=-
# RANLIB = ranlib
