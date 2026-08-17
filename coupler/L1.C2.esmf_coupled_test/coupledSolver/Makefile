# GNU Makefile template for user ESMF application

################################################################################
################################################################################
## This Makefile must be able to find the "esmf.mk" Makefile fragment in the  ##
## 'include' line below. Following the ESMF User's Guide, a complete ESMF     ##
## installation should ensure that a single environment variable "ESMFMKFILE" ##
## is made available on the system. This variable should point to the         ##
## "esmf.mk" file.                                                            ##
##                                                                            ##
## This example Makefile uses the "ESMFMKFILE" environment variable.          ##
##                                                                            ##
## If you notice that this Makefile cannot find variable ESMFMKFILE then      ##
## please contact the person responsible for the ESMF installation on your    ##
## system.                                                                    ##
## As a work-around you can simply hardcode the path to "esmf.mk" in the      ##
## include line below. However, doing so will render this Makefile a lot less ##
## flexible and non-portable.                                                 ##
################################################################################

ifneq ($(strip $(filter-out clean distclean,$(MAKECMDGOALS))),)
need_esmf := yes
else ifeq ($(strip $(MAKECMDGOALS)),)
need_esmf := yes
endif

ifdef need_esmf
ifndef ESMFMKFILE
$(error ESMFMKFILE was not set.)
endif
include $(ESMFMKFILE)
endif

################################################################################
################################################################################

.SUFFIXES: .f90 .F90 .c .C

%.o : %.f90
	$(ESMF_F90COMPILER)  -c $(ESMF_F90COMPILEOPTS) $(ESMF_F90COMPILEPATHS) $(ESMF_F90COMPILEFREENOCPP) $< -I$(CURDIR) -L$(CURDIR)

%.o : %.F90
	$(ESMF_F90COMPILER)  -c $(ESMF_F90COMPILEOPTS) $(ESMF_F90COMPILEPATHS) $(ESMF_F90COMPILEFREECPP) $(ESMF_F90COMPILECPPFLAGS) $< -I$(CURDIR) -L$(CURDIR)

% : %.c
	$(ESMF_CXXCOMPILER)  -c $(ESMF_CXXCOMPILEOPTS) $(ESMF_CXXCOMPILEPATHSLOCAL) $(ESMF_CXXCOMPILEPATHS) $(ESMF_CXXCOMPILECPPFLAGS) $<

% : %.C
	$(ESMF_CXXCOMPILER)  -c $(ESMF_CXXCOMPILEOPTS) $(ESMF_CXXCOMPILEPATHSLOCAL) $(ESMF_CXXCOMPILEPATHS) $(ESMF_CXXCOMPILECPPFLAGS) $<



# -----------------------------------------------------------------------------
esmf_application: mod_types.o mod_config.o mod_esmf_ocn.o mod_esmf_atm.o mod_esmf_cpl.o mod_esmf_esm.o mitgcm_wrf.o
	$(ESMF_F90LINKER) $(ESMF_F90LINKOPTS) $(ESMF_F90LINKPATHS) $(ESMF_F90LINKRPATHS) -L$(CURDIR) -o $@ $^ $(ESMF_F90ESMFLINKLIBS)

# module dependencies:
mitgcm_wrf.o: mod_esmf_esm.o mod_config.o mod_types.o
mod_esmf_esm.o: mod_esmf_ocn.o mod_esmf_atm.o mod_esmf_cpl.o mod_types.o
mod_esmf_cpl.o: 
mod_esmf_ocn.o: mod_types.o
mod_esmf_atm.o: mod_types.o
mod_config.o: mod_types.o 
mod_types.o:

# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
.PHONY: clean distclean
clean:
	rm -f esmf_application *.o 
distclean: clean
	rm -f PET*.ESMF_LogFile mod*.mod *.a mit*.mod
