! Earth System Modeling Framework
! Copyright 2002-2019, University Corporation for Atmospheric Research,
! Massachusetts Institute of Technology, Geophysical Fluid Dynamics
! Laboratory, University of Michigan, National Centers for Environmental
! Prediction, Los Alamos National Laboratory, Argonne National Laboratory,
! NASA Goddard Space Flight Center.
! Licensed under the University of Illinois-NCSA License.
#define FILENAME "mod_config.F90" 
!
!-----------------------------------------------------------------------
!     Module for ESM configuration file 
!-----------------------------------------------------------------------
!
module mod_config
!
!-----------------------------------------------------------------------
!     Used module declarations 
!-----------------------------------------------------------------------
!
  use ESMF
  use NUOPC
  use, intrinsic :: iso_fortran_env, only : error_unit
!
  use mod_types
!
  implicit none
  contains
!
  subroutine read_config(vm, rc)
  implicit none
!
!-----------------------------------------------------------------------
!     Imported variable declarations 
!-----------------------------------------------------------------------
!
  type(ESMF_VM), intent(in) :: vm
  integer, intent(out) :: rc 
!
!-----------------------------------------------------------------------
!     Local variable declarations 
!-----------------------------------------------------------------------
!
  integer :: localPet, petCount
  logical :: file_exists
  character(2*ESMF_MAXSTR) :: error_message
!
  type(ESMF_Config) :: cf
!
  rc = ESMF_SUCCESS
!
!-----------------------------------------------------------------------
!     Query gridded component
!-----------------------------------------------------------------------
!
  call ESMF_VMGet(vm, localPet=localPet, petCount=petCount, rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU,    &
      line=__LINE__, file=FILENAME)) return
!
!-----------------------------------------------------------------------
!     Read configuration file 
!-----------------------------------------------------------------------
!
  inquire(file=trim(config_fname), exist=file_exists)
!
  if (.not. file_exists) then
    error_message = 'Required configuration file not found: ' //         &
                    trim(config_fname)
    if (localPet == 0) write(error_unit, '(a)')                         &
      'ERROR: ' // trim(error_message)
    call ESMF_LogSetError(rcToCheck=ESMF_RC_FILE_OPEN,                 &
                          msg=trim(error_message),                      &
                          line=__LINE__, file=FILENAME, rcToReturn=rc)
    return
  end if
!
  cf = ESMF_ConfigCreate(rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU,    &
  line=__LINE__, file=FILENAME)) return
!
  call ESMF_ConfigLoadFile(cf, trim(config_fname), rc=rc)
  if (rc /= ESMF_SUCCESS) then
    if (localPet == 0) write(error_unit, '(a)')                         &
      'ERROR: Unable to load configuration file: ' // trim(config_fname)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU,    &
        line=__LINE__, file=FILENAME)) return
  end if
!
!-----------------------------------------------------------------------
!     Set debug level 
!-----------------------------------------------------------------------
!
  call ESMF_ConfigGetAttribute(cf, debugLevel,                      &
                           label='DebugLevel:', rc=rc)
  if (rc /= ESMF_SUCCESS) then
    if (localPet == 0) write(error_unit, '(a)')                         &
      'ERROR: Required integer setting DebugLevel: is missing or invalid in ' // &
      trim(config_fname)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU,    &
        line=__LINE__, file=FILENAME)) return
  end if

  if (debugLevel < 0) then
    error_message = 'DebugLevel must be a non-negative integer.'
    if (localPet == 0) write(error_unit, '(a)')                         &
      'ERROR: ' // trim(error_message)
    call ESMF_LogSetError(rcToCheck=ESMF_RC_ARG_BAD,                   &
                          msg=trim(error_message),                      &
                          line=__LINE__, file=FILENAME, rcToReturn=rc)
    return
  end if

#ifndef ESMF_PIO
  if (debugLevel >= 1) then
    error_message = 'DebugLevel >= 1 requires an ESMF build with PIO support; ' // &
                    'set DebugLevel: 0 or rebuild ESMF with PIO.'
    if (localPet == 0) write(error_unit, '(a)')                         &
      'ERROR: ' // trim(error_message)
    call ESMF_LogSetError(rcToCheck=ESMF_RC_ARG_BAD,                   &
                          msg=trim(error_message),                      &
                          line=__LINE__, file=FILENAME, rcToReturn=rc)
    return
  end if
#endif
!
!-----------------------------------------------------------------------
!     Added fields to connect
!-----------------------------------------------------------------------
!
  if (.not. allocated(connectors)) then
    allocate(connectors(2))
  end if

  connectors(1)%name = 'ATO' 
  connectors(1)%srcFields = atmExportField
  connectors(1)%dstFields = ocnImportField
  connectors(2)%name = 'OTA' 
  connectors(2)%srcFields = ocnExportField
  connectors(2)%dstFields = atmExportField

  end subroutine read_config
!
end module mod_config
