!-------------------------------------------------------------------------------------
!  Debug output module for validation
!  Compile with -DDEBUG_LEVEL_X flags to enable instrumentation
!-------------------------------------------------------------------------------------
MODULE DEBUG_OUTPUT
    USE PARAM
    USE GLOBAL
#if defined(PARALLEL)
    USE MPI
#endif
    IMPLICIT NONE
    LOGICAL, SAVE :: DEBUG_DIRS_CREATED = .FALSE.

CONTAINS

SUBROUTINE CREATE_DEBUG_DIRECTORIES()
    !---------------------------------------------
    ! Create debug output directories if they don't exist
    ! Called once at initialization
    !---------------------------------------------
    CHARACTER(LEN=300) :: cmd

    IF (.NOT. DEBUG_DIRS_CREATED) THEN
        ! Create debug directory and subdirectories
        WRITE(cmd,'(A,A,A)') 'mkdir -p ',TRIM(RESULT_FOLDER),'/debug/state'
        CALL SYSTEM(TRIM(cmd))
        WRITE(cmd,'(A,A,A)') 'mkdir -p ',TRIM(RESULT_FOLDER),'/debug/derivatives'
        CALL SYSTEM(TRIM(cmd))
        WRITE(cmd,'(A,A,A)') 'mkdir -p ',TRIM(RESULT_FOLDER),'/debug/reconstruction'
        CALL SYSTEM(TRIM(cmd))
        WRITE(cmd,'(A,A,A)') 'mkdir -p ',TRIM(RESULT_FOLDER),'/debug/wavespeeds'
        CALL SYSTEM(TRIM(cmd))
        WRITE(cmd,'(A,A,A)') 'mkdir -p ',TRIM(RESULT_FOLDER),'/debug/fluxes'
        CALL SYSTEM(TRIM(cmd))
        WRITE(cmd,'(A,A,A)') 'mkdir -p ',TRIM(RESULT_FOLDER),'/debug/sources'
        CALL SYSTEM(TRIM(cmd))
        WRITE(cmd,'(A,A,A)') 'mkdir -p ',TRIM(RESULT_FOLDER),'/debug/rk_tendencies'
        CALL SYSTEM(TRIM(cmd))
        WRITE(cmd,'(A,A,A)') 'mkdir -p ',TRIM(RESULT_FOLDER),'/debug/dispersion'
        CALL SYSTEM(TRIM(cmd))
        DEBUG_DIRS_CREATED = .TRUE.
    ENDIF
END SUBROUTINE CREATE_DEBUG_DIRECTORIES

SUBROUTINE OUTPUT_DEBUG_ARRAY_2D(Ibeg,Iend,Jbeg,Jend,Array,varname,timestep,stage,subdir)
    !---------------------------------------------
    ! Output 2D array for validation (parallel version)
    ! Gathers data from all processors and writes full domain
    ! Arguments:
    !   Ibeg, Iend, Jbeg, Jend: Array bounds
    !   Array: 2D field to output
    !   varname: Variable name (e.g., 'delx_eta')
    !   timestep: Current timestep number
    !   stage: RK stage (1, 2, 3) or 0 if not applicable
    !   subdir: Subdirectory (e.g., 'derivatives', 'fluxes')
    !---------------------------------------------
    INTEGER, INTENT(IN) :: Ibeg, Iend, Jbeg, Jend, timestep, stage
    REAL(SP), DIMENSION(:,:), INTENT(IN) :: Array
    CHARACTER(LEN=*), INTENT(IN) :: varname, subdir

#if defined(PARALLEL)
    ! Parallel version - gather data from all processors
    INTEGER :: irank, lenx, leny, lenxy, ireq, ier
    INTEGER, ALLOCATABLE :: iistas(:), iiends(:), jjstas(:), jjends(:)
    INTEGER :: istatus(mpi_status_size)
    REAL(SP), ALLOCATABLE :: LocalArray(:,:), xx(:,:)
    REAL(SP), DIMENSION(MGlob, NGlob) :: ArrayGlob
    CHARACTER(LEN=300) :: filename
    INTEGER :: I, J, unit_num

    unit_num = 8765

    ! Extract local data without ghost cells
    ALLOCATE(LocalArray(Iend-Ibeg+1, Jend-Jbeg+1))
    LocalArray = Array(Ibeg:Iend, Jbeg:Jend)

    ! Gather bounds from all processors
    ALLOCATE(iistas(nprocs), iiends(nprocs), jjstas(nprocs), jjends(nprocs))

    CALL MPI_Gather(iista, 1, MPI_INTEGER, iistas, 1, MPI_INTEGER, &
                    0, MPI_COMM_WORLD, ier)
    CALL MPI_Gather(iiend, 1, MPI_INTEGER, iiends, 1, MPI_INTEGER, &
                    0, MPI_COMM_WORLD, ier)
    CALL MPI_Gather(jjsta, 1, MPI_INTEGER, jjstas, 1, MPI_INTEGER, &
                    0, MPI_COMM_WORLD, ier)
    CALL MPI_Gather(jjend, 1, MPI_INTEGER, jjends, 1, MPI_INTEGER, &
                    0, MPI_COMM_WORLD, ier)

    ! Master processor collects data
    IF (myid == 0) THEN
        ArrayGlob(iista:iiend, jjsta:jjend) = LocalArray
    ENDIF

    ! Collect from other processors
    DO irank = 1, px*py-1
        IF (myid == 0) THEN
            lenx = iiends(irank+1) - iistas(irank+1) + 1
            leny = jjends(irank+1) - jjstas(irank+1) + 1
            lenxy = lenx * leny
            ALLOCATE(xx(lenx, leny))

            CALL mpi_irecv(xx, lenxy, mpi_sp, irank, 1, mpi_comm_world, ireq, ier)
            CALL mpi_wait(ireq, istatus, ier)

            ArrayGlob(iistas(irank+1):iiends(irank+1), jjstas(irank+1):jjends(irank+1)) = xx
            DEALLOCATE(xx)

        ELSEIF (myid == irank) THEN
            lenxy = (iiend-iista+1) * (jjend-jjsta+1)
            CALL mpi_isend(LocalArray, lenxy, mpi_sp, 0, 1, mpi_comm_world, ireq, ier)
            CALL mpi_wait(ireq, istatus, ier)
        ENDIF
    ENDDO

    DEALLOCATE(LocalArray, iistas, iiends, jjstas, jjends)

    ! Master processor writes the full domain
    IF (myid == 0) THEN
        ! Construct filename
        IF (stage > 0) THEN
            WRITE(filename,'(A,A,A,A,A,A,I5.5,A,I1,A)') &
                TRIM(RESULT_FOLDER),'/debug/',TRIM(subdir),'/',TRIM(varname),'_',timestep,'_s',stage,'.txt'
        ELSE
            WRITE(filename,'(A,A,A,A,A,A,I5.5,A)') &
                TRIM(RESULT_FOLDER),'/debug/',TRIM(subdir),'/',TRIM(varname),'_',timestep,'.txt'
        ENDIF

        OPEN(unit_num, FILE=TRIM(filename), STATUS='UNKNOWN')

        ! Write metadata header
        WRITE(unit_num,'(A,I6)') '# TIMESTEP: ', timestep
        IF (stage > 0) WRITE(unit_num,'(A,I1)') '# RK_STAGE: ', stage
        WRITE(unit_num,'(A,2I6)') '# GLOBAL_DIMENSIONS: ', MGlob, NGlob

        ! Write full domain data in E16.6E4 format (matches FUNWAVE output)
        DO J = 1, NGlob
            DO I = 1, MGlob
                WRITE(unit_num,'(E16.6E4)',ADVANCE='NO') ArrayGlob(I,J)
            ENDDO
            WRITE(unit_num,*)  ! Newline after each row
        ENDDO

        CLOSE(unit_num)
    ENDIF

#else
    ! Serial version - direct output
    CHARACTER(LEN=300) :: filename
    INTEGER :: I, J, unit_num

    unit_num = 8765

    ! Construct filename
    IF (stage > 0) THEN
        WRITE(filename,'(A,A,A,A,A,A,I5.5,A,I1,A)') &
            TRIM(RESULT_FOLDER),'/debug/',TRIM(subdir),'/',TRIM(varname),'_',timestep,'_s',stage,'.txt'
    ELSE
        WRITE(filename,'(A,A,A,A,A,A,I5.5,A)') &
            TRIM(RESULT_FOLDER),'/debug/',TRIM(subdir),'/',TRIM(varname),'_',timestep,'.txt'
    ENDIF

    OPEN(unit_num, FILE=TRIM(filename), STATUS='UNKNOWN')

    ! Write metadata header
    WRITE(unit_num,'(A,I6)') '# TIMESTEP: ', timestep
    IF (stage > 0) WRITE(unit_num,'(A,I1)') '# RK_STAGE: ', stage
    WRITE(unit_num,'(A,2I6)') '# DIMENSIONS: ', Iend-Ibeg+1, Jend-Jbeg+1

    ! Write data in E16.6E4 format
    DO J = Jbeg, Jend
        DO I = Ibeg, Iend
            WRITE(unit_num,'(E16.6E4)',ADVANCE='NO') Array(I,J)
        ENDDO
        WRITE(unit_num,*)  ! Newline after each row
    ENDDO

    CLOSE(unit_num)
#endif

END SUBROUTINE OUTPUT_DEBUG_ARRAY_2D

SUBROUTINE OUTPUT_DEBUG_ARRAY_INTERFACE_X(Ibeg,Iend,Jbeg,Jend,Array,varname,timestep,stage,subdir)
    !---------------------------------------------
    ! Output 2D array at x-interfaces for validation
    ! Array dimensions: (Mloc1, Nloc) - one extra in x-direction
    !---------------------------------------------
    INTEGER, INTENT(IN) :: Ibeg, Iend, Jbeg, Jend, timestep, stage
    REAL(SP), DIMENSION(:,:), INTENT(IN) :: Array
    CHARACTER(LEN=*), INTENT(IN) :: varname, subdir

    CHARACTER(LEN=300) :: filename
    INTEGER :: I, J, unit_num

    unit_num = 8766

    ! Construct filename
    IF (stage > 0) THEN
        WRITE(filename,'(A,A,A,A,A,A,I5.5,A,I1,A)') &
            TRIM(RESULT_FOLDER),'/debug/',TRIM(subdir),'/',TRIM(varname),'_',timestep,'_s',stage,'.txt'
    ELSE
        WRITE(filename,'(A,A,A,A,A,A,I5.5,A)') &
            TRIM(RESULT_FOLDER),'/debug/',TRIM(subdir),'/',TRIM(varname),'_',timestep,'.txt'
    ENDIF

    OPEN(unit_num, FILE=TRIM(filename), STATUS='UNKNOWN')

    ! Write metadata header
    WRITE(unit_num,'(A,I6)') '# TIMESTEP: ', timestep
    IF (stage > 0) WRITE(unit_num,'(A,I1)') '# RK_STAGE: ', stage
    WRITE(unit_num,'(A,4I6)') '# BOUNDS: ', Ibeg, Iend, Jbeg, Jend
    WRITE(unit_num,'(A,2I6)') '# DIMENSIONS: ', Iend-Ibeg+1, Jend-Jbeg+1
    WRITE(unit_num,'(A)') '# TYPE: X_INTERFACE'

    ! Write data in E16.6E4 format
    DO J = Jbeg, Jend
        DO I = Ibeg, Iend
            WRITE(unit_num,'(E16.6E4)',ADVANCE='NO') Array(I,J)
        ENDDO
        WRITE(unit_num,*)  ! Newline after each row
    ENDDO

    CLOSE(unit_num)
END SUBROUTINE OUTPUT_DEBUG_ARRAY_INTERFACE_X

SUBROUTINE OUTPUT_DEBUG_ARRAY_INTERFACE_Y(Ibeg,Iend,Jbeg,Jend,Array,varname,timestep,stage,subdir)
    !---------------------------------------------
    ! Output 2D array at y-interfaces for validation
    ! Array dimensions: (Mloc, Nloc1) - one extra in y-direction
    !---------------------------------------------
    INTEGER, INTENT(IN) :: Ibeg, Iend, Jbeg, Jend, timestep, stage
    REAL(SP), DIMENSION(:,:), INTENT(IN) :: Array
    CHARACTER(LEN=*), INTENT(IN) :: varname, subdir

    CHARACTER(LEN=300) :: filename
    INTEGER :: I, J, unit_num

    unit_num = 8767

    ! Construct filename
    IF (stage > 0) THEN
        WRITE(filename,'(A,A,A,A,A,A,I5.5,A,I1,A)') &
            TRIM(RESULT_FOLDER),'/debug/',TRIM(subdir),'/',TRIM(varname),'_',timestep,'_s',stage,'.txt'
    ELSE
        WRITE(filename,'(A,A,A,A,A,A,I5.5,A)') &
            TRIM(RESULT_FOLDER),'/debug/',TRIM(subdir),'/',TRIM(varname),'_',timestep,'.txt'
    ENDIF

    OPEN(unit_num, FILE=TRIM(filename), STATUS='UNKNOWN')

    ! Write metadata header
    WRITE(unit_num,'(A,I6)') '# TIMESTEP: ', timestep
    IF (stage > 0) WRITE(unit_num,'(A,I1)') '# RK_STAGE: ', stage
    WRITE(unit_num,'(A,4I6)') '# BOUNDS: ', Ibeg, Iend, Jbeg, Jend
    WRITE(unit_num,'(A,2I6)') '# DIMENSIONS: ', Iend-Ibeg+1, Jend-Jbeg+1
    WRITE(unit_num,'(A)') '# TYPE: Y_INTERFACE'

    ! Write data in E16.6E4 format
    DO J = Jbeg, Jend
        DO I = Ibeg, Iend
            WRITE(unit_num,'(E16.6E4)',ADVANCE='NO') Array(I,J)
        ENDDO
        WRITE(unit_num,*)  ! Newline after each row
    ENDDO

    CLOSE(unit_num)
END SUBROUTINE OUTPUT_DEBUG_ARRAY_INTERFACE_Y

END MODULE DEBUG_OUTPUT
