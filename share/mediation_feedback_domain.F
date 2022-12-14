!
!WRF:MEDIATION_LAYER:NESTING
!
SUBROUTINE med_feedback_domain ( parent_grid , nested_grid )
   USE module_timing, only: now_time
   USE module_domain
   USE module_configure
!   USE module_intermediate_nmm
#ifdef DM_PARALLEL
   USE module_dm, ONLY: local_communicator, intercomm_active
#else
   USE module_dm, ONLY: intercomm_active
#endif
   IMPLICIT NONE
   TYPE(domain), POINTER :: parent_grid , nested_grid
   TYPE(domain), POINTER :: grid
   INTEGER nlev, msize
#if !defined(MAC_KLUDGE)
   TYPE (grid_config_rec_type)            :: config_flags
#endif
!  see http://www.mmm.ucar.edu/wrf/WG2/topics/deref_kludge.htm
   INTEGER     :: sm31 , em31 , sm32 , em32 , sm33 , em33
   INTEGER     :: sm31x, em31x, sm32x, em32x, sm33x, em33x
   INTEGER     :: sm31y, em31y, sm32y, em32y, sm33y, em33y
   character*255 :: message
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
      SUBROUTINE feedback_domain_em_part1 ( grid, nested_grid, config_flags   &
!
#          include "dummy_new_args.inc"
!
                                          )
         USE module_domain
         USE module_configure
         TYPE(domain), POINTER :: grid          ! name of the grid being dereferenced (must be "grid")
         TYPE(domain), POINTER :: nested_grid
         TYPE (grid_config_rec_type)            :: config_flags
#        include "dummy_new_decl.inc"
      END SUBROUTINE feedback_domain_em_part1
      SUBROUTINE feedback_domain_em_part2 ( grid, intermediate_grid , nested_grid, config_flags   &
!
#          include "dummy_new_args.inc"
!
                                          )
         USE module_domain
         USE module_configure
         TYPE(domain), POINTER :: grid          ! name of the grid being dereferenced (must be "grid")
         TYPE(domain), POINTER :: intermediate_grid
         TYPE(domain), POINTER :: nested_grid
         TYPE (grid_config_rec_type)            :: config_flags
#        include "dummy_new_decl.inc"
      END SUBROUTINE feedback_domain_em_part2
      SUBROUTINE update_after_feedback_em ( grid  &
!
#          include "dummy_new_args.inc"
!
                                          )
         USE module_domain
         USE module_configure
         TYPE(domain), TARGET :: grid          ! name of the grid being dereferenced (must be "grid")
#        include "dummy_new_decl.inc"
      END SUBROUTINE update_after_feedback_em
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
!    Feedback calls for EM CORE.
! ----------------------------------------------------------
#if (EM_CORE == 1 && defined( DM_PARALLEL ))
# if !defined(MAC_KLUDGE)
   CALL model_to_grid_config_rec ( nested_grid%id , model_config_rec , config_flags )
   parent_grid%ht_coarse = parent_grid%ht
   grid => nested_grid%intermediate_grid
#  if (defined(MOVE_NESTS) || ((!defined(KEEP_INT_AROUND)) && (!defined(SGIALTIX)) && (!defined(FUJITSU_FX10))))
   CALL alloc_space_field ( grid, grid%id , 1 , 2 , .TRUE. , intercomm_active( grid%id ),    &
                            grid%sd31, grid%ed31, grid%sd32, grid%ed32, grid%sd33, grid%ed33, &
                            grid%sm31,  grid%em31,  grid%sm32,  grid%em32,  grid%sm33,  grid%em33, &
                            grid%sp31,  grid%ep31,  grid%sp32,  grid%ep32,  grid%sp33,  grid%ep33, &
                            grid%sp31x, grid%ep31x, grid%sp32x, grid%ep32x, grid%sp33x, grid%ep33x,&
                            grid%sp31y, grid%ep31y, grid%sp32y, grid%ep32y, grid%sp33y, grid%ep33y,&
                            grid%sm31x, grid%em31x, grid%sm32x, grid%em32x, grid%sm33x, grid%em33x, &   ! x-xpose
                            grid%sm31y, grid%em31y, grid%sm32y, grid%em32y, grid%sm33y, grid%em33y  &   ! y-xpose
     )
#  endif
   CALL wrf_dm_nestexchange_init
  IF ( nested_grid%active_this_task ) THEN
   grid => nested_grid%intermediate_grid
   CALL feedback_domain_em_part1 ( grid, nested_grid, config_flags   &
!
#      include "actual_new_args.inc"
!
                                   )
  ENDIF
   grid => parent_grid

   grid%nest_mask = 0.

   CALL feedback_domain_em_part2 ( grid , nested_grid%intermediate_grid, nested_grid , config_flags   &
!
#      include "actual_new_args.inc"

                                   )

   WHERE   ( grid%nest_pos .NE. 9021000.  ) grid%ht = grid%ht_coarse
   CALL push_communicators_for_domain(grid%id)
   CALL update_after_feedback_em ( grid  &
!
#      include "actual_new_args.inc"
!
                                   )
   CALL pop_communicators_for_domain

   grid => nested_grid%intermediate_grid
#  if (defined(MOVE_NESTS) || ((!defined(KEEP_INT_AROUND)) && (!defined(SGIALTIX)) && (!defined(FUJITSU_FX10))))
   IF ( intercomm_active( grid%id ) ) THEN
   CALL dealloc_space_field ( grid )
   ENDIF
#  endif
# endif
#endif
! ------------------------------------------------------
!    End of Feedback calls for EM CORE.
! ------------------------------------------------------
   RETURN
END SUBROUTINE med_feedback_domain


