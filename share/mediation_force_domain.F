!
!WRF:MEDIATION_LAYER:NESTING
!
SUBROUTINE med_force_domain ( parent_grid , nested_grid )
   USE module_domain
   USE module_configure
#ifdef DM_PARALLEL
   USE module_dm, ONLY : intercomm_active, &
                         mpi_comm_to_kid, mpi_comm_to_mom, which_kid
#else
   USE module_dm, ONLY : intercomm_active
#endif

   IMPLICIT NONE
   TYPE(domain), POINTER :: parent_grid , nested_grid
   TYPE(domain), POINTER :: grid
   INTEGER nlev, msize
#if !defined(MAC_KLUDGE)
   TYPE (grid_config_rec_type)            :: config_flags
#endif

! ----------------------------------------------------------
! ------------------------------------------------------
! Interface blocks
! ------------------------------------------------------
   INTERFACE
! ------------------------------------------------------
!    Interface definitions for EM CORE
! ------------------------------------------------------
#if (EM_CORE == 1)
#if !defined(MAC_KLUDGE)
! ------------------------------------------------------
!    These routines are supplied by module_dm.F from the
!    external communication package (e.g. external/RSL)
! ------------------------------------------------------
      SUBROUTINE interp_domain_em_part1 ( grid, intermediate_grid, ngrid, config_flags   &
!
#        include "dummy_new_args.inc"
!
                 )
         USE module_domain
         USE module_configure
         TYPE(domain), POINTER :: grid          ! name of the grid being dereferenced (must be "grid")
         TYPE(domain), POINTER :: intermediate_grid
         TYPE(domain), POINTER :: ngrid
         TYPE (grid_config_rec_type)            :: config_flags
#        include "dummy_new_decl.inc"
      END SUBROUTINE interp_domain_em_part1

      SUBROUTINE force_domain_em_part2 ( grid, nested_grid, parent_grid, config_flags   &
!
#        include "dummy_new_args.inc"
!
                 )
         USE module_domain
         USE module_configure
         TYPE(domain), POINTER :: grid          ! name of the grid being dereferenced (must be "grid")
         TYPE(domain), POINTER :: nested_grid
	 TYPE(domain), POINTER :: parent_grid   ! KAL added for vertical nesting
         TYPE (grid_config_rec_type)            :: config_flags
#        include "dummy_new_decl.inc"
      END SUBROUTINE force_domain_em_part2

! ----------------------------------------------------------
!    This routine is supplied by dyn_em/couple_or_uncouple_em.F
! ----------------------------------------------------------
      SUBROUTINE couple_or_uncouple_em ( grid, config_flags , couple  &
!
#        include "dummy_new_args.inc"
!
                 )
         USE module_domain
         USE module_configure
         TYPE(domain), INTENT(INOUT)            :: grid
         TYPE (grid_config_rec_type)            :: config_flags
         LOGICAL, INTENT(   IN) :: couple
#        include "dummy_new_decl.inc"
      END SUBROUTINE couple_or_uncouple_em
#endif
#endif
   END INTERFACE
! ----------------------------------------------------------
! End of Interface blocks
! ----------------------------------------------------------
! ----------------------------------------------------------
! ----------------------------------------------------------
! Executable code
! ----------------------------------------------------------
! ----------------------------------------------------------
!    Forcing calls for EM CORE.
! ----------------------------------------------------------
#if (EM_CORE == 1 && defined( DM_PARALLEL ))
# if !defined(MAC_KLUDGE)
   CALL model_to_grid_config_rec ( nested_grid%id , model_config_rec , config_flags )

   grid => nested_grid%intermediate_grid
#  if (defined(MOVE_NESTS) || ((!defined(KEEP_INT_AROUND)) && (!defined(SGIALTIX)) && (!defined(FUJITSU_FX10))))
!   IF ( intercomm_active(grid%id) ) THEN
     CALL alloc_space_field ( grid, grid%id , 1 , 2 ,  .TRUE. , intercomm_active(grid%id),    &
                            grid%sd31, grid%ed31, grid%sd32, grid%ed32, grid%sd33, grid%ed33, &
                            grid%sm31,  grid%em31,  grid%sm32,  grid%em32,  grid%sm33,  grid%em33, &
                            grid%sp31,  grid%ep31,  grid%sp32,  grid%ep32,  grid%sp33,  grid%ep33, &
                            grid%sp31x, grid%ep31x, grid%sp32x, grid%ep32x, grid%sp33x, grid%ep33x,&
                            grid%sp31y, grid%ep31y, grid%sp32y, grid%ep32y, grid%sp33y, grid%ep33y,&
                            grid%sm31x, grid%em31x, grid%sm32x, grid%em32x, grid%sm33x, grid%em33x, &   ! x-xpose
                            grid%sm31y, grid%em31y, grid%sm32y, grid%em32y, grid%sm33y, grid%em33y  &   ! y-xpose
     )
!   ENDIF
#  endif

   ! couple parent domain
   grid => parent_grid
   IF ( grid%active_this_task ) THEN
     CALL push_communicators_for_domain(grid%id)
   ! swich config_flags to point to parent rconfig info
     CALL model_to_grid_config_rec ( grid%id , model_config_rec , config_flags )
     CALL couple_or_uncouple_em ( grid , config_flags ,  .true. &
!
#         include "actual_new_args.inc"
!
                                )
     CALL pop_communicators_for_domain
   ENDIF
   ! couple nested domain
   grid => nested_grid
   IF ( grid%active_this_task ) THEN
     CALL push_communicators_for_domain(grid%id)
     CALL model_to_grid_config_rec ( grid%id , model_config_rec , config_flags )
     CALL couple_or_uncouple_em ( grid , config_flags ,  .true. &
!
#         include "actual_new_args.inc"
!
                                   )
     CALL pop_communicators_for_domain
   ENDIF
   ! perform first part: transfer data from parent to intermediate domain
   ! at the same resolution but on the same decomposition as the nest
   ! note that this will involve communication on multiple DM procs
   grid => parent_grid
   CALL model_to_grid_config_rec ( grid%id , model_config_rec , config_flags )
   !
   ! Added following line to handle adaptive time step.  This should probably
   !   go somewhere else, but I'm not sure where.
   !   
   ! T. Hutchinson, WSI  1/23/07
   !

   IF ( parent_grid%active_this_task .AND. nested_grid%active_this_task ) THEN
     nested_grid%intermediate_grid%dt = grid%dt
   ENDIF
   IF ( parent_grid%active_this_task ) THEN
     CALL BYTE_BCAST( parent_grid%dt,RWORDSIZE,mpi_comm_to_kid( which_kid( nested_grid%id ) , parent_grid%id ))
   ELSE IF ( nested_grid%active_this_task ) THEN
     CALL BYTE_BCAST( nested_grid%dt,RWORDSIZE,mpi_comm_to_mom( nested_grid%id ) )
   ENDIF

   IF ( parent_grid%active_this_task .OR. nested_grid%active_this_task ) THEN
     CALL wrf_dm_nestexchange_init

     CALL interp_domain_em_part1 ( grid , nested_grid%intermediate_grid, nested_grid, config_flags  &
!
#         include "actual_new_args.inc"
!
                                    )
   ENDIF

  IF ( nested_grid%active_this_task ) THEN
   grid => nested_grid%intermediate_grid
      ! perform 2nd part: run interpolation on the intermediate domain
      ! and compute the values for the nest boundaries
      ! note that this is all local (no communication)
   CALL model_to_grid_config_rec ( nested_grid%id , model_config_rec , config_flags )
   CALL force_domain_em_part2 ( grid, nested_grid, parent_grid, config_flags   &
!
#          include "actual_new_args.inc"
!
                                   )
  ENDIF
   ! uncouple the nest
   grid => nested_grid
   IF ( grid%active_this_task ) THEN
     CALL push_communicators_for_domain(grid%id)
     CALL model_to_grid_config_rec ( grid%id , model_config_rec , config_flags )
     CALL couple_or_uncouple_em ( grid , config_flags ,  .false.  &
!
#          include "actual_new_args.inc"
!
                                   )
     CALL pop_communicators_for_domain
   ENDIF
   ! uncouple the parent
   grid => parent_grid
   IF ( grid%active_this_task ) THEN
     CALL push_communicators_for_domain(grid%id)
     CALL model_to_grid_config_rec ( grid%id , model_config_rec , config_flags )
     CALL couple_or_uncouple_em ( grid , config_flags ,  .false.  &
!
#          include "actual_new_args.inc"
!
                                )
     CALL pop_communicators_for_domain
   ENDIF
   IF ( nested_grid%first_force ) THEN
      nested_grid%first_force = .FALSE.
   ENDIF
   nested_grid%dtbc = 0.
!
   grid => nested_grid%intermediate_grid
#  if (defined(MOVE_NESTS) || ((!defined(KEEP_INT_AROUND)) && (!defined(SGIALTIX)) && (!defined(FUJITSU_FX10))))
   IF ( intercomm_active(grid%id) ) THEN
     CALL dealloc_space_field ( grid )
   ENDIF
#  endif
# endif
#endif
! ------------------------------------------------------
!    End of Forcing calls for EM CORE.
! ------------------------------------------------------
   RETURN
END SUBROUTINE med_force_domain


