!-----------------------------------------------------------------------
! Earth System Modeling Framework
! Copyright 2002-2017, University Corporation for Atmospheric Research,
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
      use, intrinsic :: iso_fortran_env, only : error_unit, int64
      use ESMF
      use NUOPC
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
      integer :: localPet, petCount, iEntry
      character(ESMF_MAXSTR) :: entryName, entryUnit
      character(2*ESMF_MAXSTR) :: error_message
      logical :: file_exists
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
!     Read and validate the configuration file before components start
!-----------------------------------------------------------------------
!
      inquire(file=trim(config_fname), exist=file_exists)
      if (.not. file_exists) then
        error_message = 'Required configuration file not found: ' //    &
                        trim(config_fname)
        call report_config_error(localPet, trim(error_message),         &
                                 ESMF_RC_FILE_OPEN, rc)
        return
      end if
!
      cf = ESMF_ConfigCreate(rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU,    &
          line=__LINE__, file=FILENAME)) return
!
      call ESMF_ConfigLoadFile(cf, trim(config_fname), rc=rc)
      if (rc /= ESMF_SUCCESS) then
        error_message = 'Unable to load configuration file: ' //       &
                        trim(config_fname)
        if (localPet == 0) write(error_unit,'(a)')                      &
          'ERROR: ' // trim(error_message)
        if (ESMF_LogFoundError(rcToCheck=rc,                            &
            msg=ESMF_LOGERR_PASSTHRU, line=__LINE__,                   &
            file=FILENAME)) return
        return
      end if
!
      call get_required_integer(cf, 'DebugLevel:', debugLevel,         &
                                localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      if (debugLevel < 0) then
        call report_config_error(localPet,                              &
          'DebugLevel must be greater than or equal to zero.',         &
          ESMF_RC_ARG_BAD, rc)
        return
      end if
      if (localPet == 0) print *, 'DebugLevel now is: ', debugLevel
!
      call get_required_string(cf, 'interpolationOption:',             &
                               interp_option, localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      if (len_trim(interp_option) == 0) then
        call report_config_error(localPet,                              &
          'interpolationOption must not be empty.',                    &
          ESMF_RC_ARG_BAD, rc)
        return
      end if
!
      call get_required_integer(cf, 'StartYear:', start_year,          &
                                localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      call get_required_integer(cf, 'StartMonth:', start_month,        &
                                localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      call get_required_integer(cf, 'StartDay:', start_day,            &
                                localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      call get_required_integer(cf, 'StartHour:', start_hour,          &
                                localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      call get_required_integer(cf, 'StartMinute:', start_minute,      &
                                localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      call get_required_integer(cf, 'StartSecond:', start_second,      &
                                localPet, rc)
      if (rc /= ESMF_SUCCESS) return
!
      call ESMF_TimeSet(esmStartTime, yy=start_year, mm=start_month,   &
                        dd=start_day, h=start_hour, m=start_minute,     &
                        s=start_second,                                &
                        calkindflag=ESMF_CALKIND_GREGORIAN, rc=rc)
      if (rc /= ESMF_SUCCESS) then
        if (localPet == 0) write(error_unit,'(a)')                      &
          'ERROR: Start date/time is not a valid Gregorian time.'
        if (ESMF_LogFoundError(rcToCheck=rc,                            &
            msg=ESMF_LOGERR_PASSTHRU, line=__LINE__,                   &
            file=FILENAME)) return
        return
      end if
!
      call get_required_integer(cf, 'StopYear:', stop_year,            &
                                localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      call get_required_integer(cf, 'StopMonth:', stop_month,          &
                                localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      call get_required_integer(cf, 'StopDay:', stop_day,              &
                                localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      call get_required_integer(cf, 'StopHour:', stop_hour,            &
                                localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      call get_required_integer(cf, 'StopMinute:', stop_minute,        &
                                localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      call get_required_integer(cf, 'StopSecond:', stop_second,        &
                                localPet, rc)
      if (rc /= ESMF_SUCCESS) return
!
      call ESMF_TimeSet(esmStopTime, yy=stop_year, mm=stop_month,      &
                        dd=stop_day, h=stop_hour, m=stop_minute,        &
                        s=stop_second,                                 &
                        calkindflag=ESMF_CALKIND_GREGORIAN, rc=rc)
      if (rc /= ESMF_SUCCESS) then
        if (localPet == 0) write(error_unit,'(a)')                      &
          'ERROR: Stop date/time is not a valid Gregorian time.'
        if (ESMF_LogFoundError(rcToCheck=rc,                            &
            msg=ESMF_LOGERR_PASSTHRU, line=__LINE__,                   &
            file=FILENAME)) return
        return
      end if
      if (esmStopTime <= esmStartTime) then
        call report_config_error(localPet,                              &
          'Stop date/time must be later than start date/time.',        &
          ESMF_RC_ARG_BAD, rc)
        return
      end if
!
      call get_required_integer(cf, 'EsmStepSeconds:',                 &
                                esm_step_seconds, localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      if (esm_step_seconds <= 0) then
        call report_config_error(localPet,                              &
          'EsmStepSeconds must be a positive integer.',                &
          ESMF_RC_ARG_BAD, rc)
        return
      end if
!
      call get_required_integer(cf, 'ATMStepSeconds:',                 &
                                atm_step_seconds, localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      if (atm_step_seconds <= 0) then
        call report_config_error(localPet,                              &
          'ATMStepSeconds must be a positive integer.',                &
          ESMF_RC_ARG_BAD, rc)
        return
      end if
!
      call get_required_integer(cf, 'OCNStepSeconds:',                 &
                                ocn_step_seconds, localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      if (ocn_step_seconds <= 0) then
        call report_config_error(localPet,                              &
          'OCNStepSeconds must be a positive integer.',                &
          ESMF_RC_ARG_BAD, rc)
        return
      end if
      if (mod(esm_step_seconds, ocn_step_seconds) /= 0) then
        call report_config_error(localPet,                              &
          'EsmStepSeconds must be an exact positive multiple of ' //   &
          'OCNStepSeconds.', ESMF_RC_ARG_BAD, rc)
        return
      end if
!
      call get_required_integer(cf, 'WAVStepSeconds:',                 &
                                wav_step_seconds, localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      if (wav_step_seconds <= 0) then
        call report_config_error(localPet,                              &
          'WAVStepSeconds must be a positive integer.',                &
          ESMF_RC_ARG_BAD, rc)
        return
      end if
!
      call ESMF_TimeIntervalSet(esmTimeStep, s=esm_step_seconds, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU,    &
          line=__LINE__, file=FILENAME)) return
      call ESMF_TimeIntervalSet(atmTimeStep, s=atm_step_seconds, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU,    &
          line=__LINE__, file=FILENAME)) return
      call ESMF_TimeIntervalSet(ocnTimeStep, s=ocn_step_seconds, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU,    &
          line=__LINE__, file=FILENAME)) return
      call ESMF_TimeIntervalSet(wavTimeStep, s=wav_step_seconds, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU,    &
          line=__LINE__, file=FILENAME)) return
!
      call get_required_integer(cf, 'coupleMode:', coupleMode,         &
                                localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      if (coupleMode /= 1 .and. coupleMode /= 2) then
        call report_config_error(localPet,                              &
          'coupleMode must be 1 (sequential) or 2 (concurrent).',      &
          ESMF_RC_ARG_BAD, rc)
        return
      end if
!
      call get_required_integer(cf, 'cpuOCN:', cpuOCN, localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      if (cpuOCN <= 0) then
        call report_config_error(localPet,                              &
          'cpuOCN must be a positive integer.', ESMF_RC_ARG_BAD, rc)
        return
      end if
      call get_required_integer(cf, 'cpuATM:', cpuATM, localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      if (cpuATM <= 0) then
        call report_config_error(localPet,                              &
          'cpuATM must be a positive integer.', ESMF_RC_ARG_BAD, rc)
        return
      end if
      call get_required_integer(cf, 'cpuWAV:', cpuWAV, localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      if (cpuWAV <= 0) then
        call report_config_error(localPet,                              &
          'cpuWAV must be a positive integer.', ESMF_RC_ARG_BAD, rc)
        return
      end if
!
      call get_required_integer(cf, 'waveNPX:', waveNPX, localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      if (waveNPX <= 0) then
        call report_config_error(localPet,                              &
          'waveNPX must be a positive integer.', ESMF_RC_ARG_BAD, rc)
        return
      end if
      call get_required_integer(cf, 'waveNPY:', waveNPY, localPet, rc)
      if (rc /= ESMF_SUCCESS) return
      if (waveNPY <= 0) then
        call report_config_error(localPet,                              &
          'waveNPY must be a positive integer.', ESMF_RC_ARG_BAD, rc)
        return
      end if
      if (int(waveNPX, int64) * int(waveNPY, int64) /=               &
          int(cpuWAV, int64)) then
        call report_config_error(localPet,                              &
          'waveNPX * waveNPY must equal cpuWAV.',                      &
          ESMF_RC_ARG_BAD, rc)
        return
      end if
!
      if (coupleMode == 1) then
        if (cpuOCN > petCount .or. cpuATM > petCount .or.              &
            cpuWAV > petCount) then
          call report_config_error(localPet,                            &
            'In sequential mode, cpuOCN, cpuATM, and cpuWAV must ' //  &
            'each be no greater than the ESMF PET count.',            &
            ESMF_RC_ARG_BAD, rc)
          return
        end if
      else
        if (int(cpuOCN, int64) + int(cpuATM, int64) +                 &
            int(cpuWAV, int64) > int(petCount, int64)) then
          call report_config_error(localPet,                            &
            'In concurrent mode, cpuOCN + cpuATM + cpuWAV must be ' // &
            'no greater than the ESMF PET count.',                    &
            ESMF_RC_ARG_BAD, rc)
          return
        end if
      end if
!
      currentTimeStep = 1
!
!-----------------------------------------------------------------------
!     Set field dictionary entries
!-----------------------------------------------------------------------
!
      do iEntry = 1, nList
        entryName = trim(nuopc_entryNameList(iEntry))
        entryUnit = trim(nuopc_entryUnitList(iEntry))
        print *, 'entry name is: ', trim(entryName)
        call NUOPC_FieldDictionaryAddEntry(entryName,                  &
                                           canonicalUnits=entryUnit,   &
                                           rc=rc)
      end do
!
      end subroutine read_config
!
      subroutine get_required_integer(cf, label, value, localPet, rc)
      implicit none
      type(ESMF_Config), intent(inout) :: cf
      character(len=*), intent(in) :: label
      integer, intent(out) :: value
      integer, intent(in) :: localPet
      integer, intent(out) :: rc
      character(2*ESMF_MAXSTR) :: error_message
!
      call ESMF_ConfigGetAttribute(cf, value, label=label, rc=rc)
      if (rc /= ESMF_SUCCESS) then
        error_message = "Required integer setting '" // trim(label) //  &
                        "' is missing or invalid in " //               &
                        trim(config_fname)
        if (localPet == 0) write(error_unit,'(a)')                      &
          'ERROR: ' // trim(error_message)
        if (ESMF_LogFoundError(rcToCheck=rc,                            &
            msg=ESMF_LOGERR_PASSTHRU, line=__LINE__,                   &
            file=FILENAME)) return
      end if
!
      end subroutine get_required_integer
!
      subroutine get_required_string(cf, label, value, localPet, rc)
      implicit none
      type(ESMF_Config), intent(inout) :: cf
      character(len=*), intent(in) :: label
      character(len=*), intent(out) :: value
      integer, intent(in) :: localPet
      integer, intent(out) :: rc
      character(2*ESMF_MAXSTR) :: error_message
!
      call ESMF_ConfigGetAttribute(cf, value, label=label, rc=rc)
      if (rc /= ESMF_SUCCESS) then
        error_message = "Required string setting '" // trim(label) //   &
                        "' is missing or invalid in " //               &
                        trim(config_fname)
        if (localPet == 0) write(error_unit,'(a)')                      &
          'ERROR: ' // trim(error_message)
        if (ESMF_LogFoundError(rcToCheck=rc,                            &
            msg=ESMF_LOGERR_PASSTHRU, line=__LINE__,                   &
            file=FILENAME)) return
      end if
!
      end subroutine get_required_string
!
      subroutine report_config_error(localPet, message, error_code, rc)
      implicit none
      integer, intent(in) :: localPet, error_code
      character(len=*), intent(in) :: message
      integer, intent(out) :: rc
!
      if (localPet == 0) write(error_unit,'(a)')                        &
        'ERROR: ' // trim(message)
      call ESMF_LogSetError(rcToCheck=error_code, msg=trim(message),    &
                            line=__LINE__, file=FILENAME,               &
                            rcToReturn=rc)
!
      end subroutine report_config_error
!
      end module mod_config
