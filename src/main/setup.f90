!
! S3COM
! Copyright (c) 2022, University of Lille
!
! Redistribution and use in source and binary forms, with or without modification,
! are permitted provided that the following conditions are met:
!  1. Redistributions of source code must retain the above copyright notice,
!     this list of conditions and the following disclaimer.
!  2. Redistributions in binary form must reproduce the above copyright notice,
!     this list of conditions and the following disclaimer in the documentation
!     and/or other materials provided with the distribution.
!  3. Neither the name of the copyright holder nor the names of its contributors
!     may be used to endorse or promote products derived from this software without
!     specific prior written permission.

! THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
! EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
! OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
! SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
! INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
! PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
! INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
! LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
! OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
!
! History
! Jan 2022 - O. Sourdeval - Original version
!

MODULE mod_atm_init

  USE s3com_types,  ONLY: type_s3com, wp, type_nml, type_icon
  USE s3com_config, ONLY: nstates, apriori_iwp

  IMPLICIT NONE

CONTAINS

  SUBROUTINE atm_update(idx_start, idx_end, atm_oe, atm_out)

    ! Input variables
    INTEGER(kind=4), INTENT(IN) :: idx_start, idx_end
    TYPE(type_s3com), INTENT(IN) :: atm_oe

    ! Output variables
    TYPE(type_s3com), INTENT(INOUT) :: atm_out

    atm_out%y_refl_total(idx_start:idx_end,:) = atm_oe%y_refl_total(:,:)
    atm_out%y_refl_clear(idx_start:idx_end,:) = atm_oe%y_refl_clear(:,:)
    atm_out%y_bt_total(idx_start:idx_end,:)   = atm_oe%y_bt_total(:,:)
    atm_out%y_bt_clear(idx_start:idx_end,:)   = atm_oe%y_bt_clear(:,:)
    atm_out%y_rad_total(idx_start:idx_end,:)  = atm_oe%y_rad_total(:,:)
    atm_out%y_rad_clear(idx_start:idx_end,:)  = atm_oe%y_rad_clear(:,:)
    atm_out%y_rad_cloudy(idx_start:idx_end,:) = atm_oe%y_rad_cloudy(:,:)
    atm_out%brdf(idx_start:idx_end,:)         = atm_oe%brdf(:,:)
    atm_out%emissivity(idx_start:idx_end,:)   = atm_oe%emissivity(:,:)
    atm_out%Xip1(idx_start:idx_end,:)         = atm_oe%Xip1(:,:)
    atm_out%iwp_model(idx_start:idx_end)      = atm_oe%iwp_model(:)
    atm_out%Gip1(idx_start:idx_end)           = atm_oe%Gip1(:)
    atm_out%t(idx_start:idx_end,:)            = atm_oe%t(:,:)
    atm_out%z(idx_start:idx_end,:)            = atm_oe%z(:,:)
    atm_out%t(idx_start:idx_end,:)            = atm_oe%t(:,:)
    atm_out%clc(idx_start:idx_end,:)          = atm_oe%clc(:,:)
    atm_out%cdnc(idx_start:idx_end,:)         = atm_oe%cdnc(:,:)
    atm_out%reff(idx_start:idx_end,:)         = atm_oe%reff(:,:)
    atm_out%lwc(idx_start:idx_end,:)          = atm_oe%lwc(:,:)

  END SUBROUTINE atm_update

  SUBROUTINE atm_init(idx_start, idx_end, nlevels, y, flag_oe, nml)

    INTEGER(kind=4) :: nchannels

    ! Input variables
    INTEGER(kind=4), INTENT(IN) :: nlevels, idx_start, idx_end
    LOGICAL :: flag_oe

    ! Output variables
    TYPE(type_s3com), INTENT(OUT)   :: y
    TYPE(type_nml), INTENT(IN)      :: nml

    ! Internal variables
    INTEGER(KIND=4) :: npoints, ipoint

    nchannels = nml%nchannels

    npoints = idx_end - idx_start + 1

    y%npoints = npoints
    y%nstates = nstates
    y%nmeas = nml%nchannels

    ALLOCATE(y%y_rad_total(npoints,nchannels)); y%y_rad_total = 0._wp
    ALLOCATE(y%f_rad_total(npoints,nchannels)); y%f_rad_total = 0._wp
    ALLOCATE(y%y_rad_clear(npoints,nchannels)); y%y_rad_clear = 0._wp
    ALLOCATE(y%f_rad_clear(npoints,nchannels)); y%f_rad_clear = 0._wp
    ALLOCATE(y%y_rad_cloudy(npoints,nchannels)); y%y_rad_cloudy = 0._wp
    ALLOCATE(y%f_rad_cloudy(npoints,nchannels)); y%f_rad_cloudy = 0._wp
    ALLOCATE(y%y_refl_total(npoints,nchannels)); y%y_refl_total = 0._wp
    ALLOCATE(y%f_refl_total(npoints,nchannels)); y%f_refl_total = 0._wp
    ALLOCATE(y%y_refl_clear(npoints,nchannels)); y%y_refl_clear = 0._wp
    ALLOCATE(y%f_refl_clear(npoints,nchannels)); y%f_refl_clear = 0._wp
    ALLOCATE(y%y_bt_total(npoints,nchannels)); y%y_bt_total = 0._wp
    ALLOCATE(y%f_bt_total(npoints,nchannels)); y%f_bt_total = 0._wp
    ALLOCATE(y%y_bt_clear(npoints,nchannels)); y%y_bt_clear = 0._wp
    ALLOCATE(y%f_bt_clear(npoints,nchannels)); y%f_bt_clear = 0._wp
    ALLOCATE(y%Xa(npoints,nstates)); y%Xa = 0._wp
    ALLOCATE(y%g(npoints)); y%g = 0._wp
    ALLOCATE(y%g_meas(npoints)); y%g_meas = 0._wp
    ALLOCATE(y%ztop_ice(npoints)); y%ztop_ice = 0._wp
    ALLOCATE(y%zbase_ice(npoints)); y%zbase_ice = 0._wp
    ALLOCATE(y%ztop_ice_idx(npoints)); y%ztop_ice_idx = 0
    ALLOCATE(y%zbase_ice_idx(npoints)); y%zbase_ice_idx = 0
    ALLOCATE(y%iwp(npoints)); y%iwp = 0._wp
    ALLOCATE(y%brdf(npoints,nchannels)); y%brdf = 0._wp
    ALLOCATE(y%emissivity(npoints,nchannels)); y%emissivity = 0._wp
    ALLOCATE(y%iwp_model(npoints)); y%iwp_model = 0._wp
    ALLOCATE(y%xip1(npoints,nstates)); y%xip1 = 0._wp
    ALLOCATE(y%gip1(npoints)); y%gip1 = 0._wp

    IF(nml%flag_output_atm) THEN
       ALLOCATE(y%t(npoints, nlevels)); y%t = 0._wp
       ALLOCATE(y%z(npoints, nlevels)); y%z = 0._wp
       ALLOCATE(y%clc(npoints, nlevels)); y%clc = 0._wp
       ALLOCATE(y%reff(npoints, nlevels)); y%reff = 0._wp
       ALLOCATE(y%cdnc(npoints, nlevels)); y%cdnc = 0._wp
       ALLOCATE(y%lwc(npoints, nlevels)); y%lwc = 0._wp
    END IF

    IF(flag_oe) THEN
       ALLOCATE(y%iwc(npoints,nlevels)); y%iwc = 0._wp
       ALLOCATE(y%cla(npoints,nlevels)); y%cla = 0._wp
       ALLOCATE(y%xi(npoints,nstates)); y%xi = 0._wp
       ALLOCATE(y%gi(npoints)); y%gi = 0._wp
       ALLOCATE(y%stepsize(npoints)); y%stepsize = 0._wp
       ALLOCATE(y%i_stepsize(npoints)); y%i_stepsize = 0
       ALLOCATE(y%n_iter(npoints)); y%n_iter = 0
       ALLOCATE(y%k(npoints,nstates,nchannels)); y%k = 0._wp
       ALLOCATE(y%kt(npoints,nstates,nchannels)); y%kt = 0._wp
       ALLOCATE(y%sy(npoints,nchannels,nchannels)); y%sy = 0._wp
       ALLOCATE(y%sf(npoints,nchannels,nchannels)); y%sf = 0._wp
       ALLOCATE(y%se(npoints,nchannels,nchannels)); y%se = 0._wp
       ALLOCATE(y%sx(npoints,nstates,nstates)); y%sx = 0._wp
       ALLOCATE(y%sa(npoints,nstates,nstates)); y%sa = 0._wp
       ALLOCATE(y%se_i(npoints,nchannels,nchannels)); y%se_i = 0._wp
       ALLOCATE(y%sx_i(npoints,nstates,nstates)); y%sx_i = 0._wp
       ALLOCATE(y%sa_i(npoints,nstates,nstates)); y%sa_i = 0._wp
       ALLOCATE(y%flag_rttov(npoints)); y%flag_rttov = .FALSE.
       ALLOCATE(y%flag_testconv(npoints)); y%flag_testconv = .FALSE.
    END IF

    y%Xa(:,1) = apriori_iwp

  END SUBROUTINE atm_init


  SUBROUTINE model_setup_init(model, npoints, nlevels)

    ! Input variables
    INTEGER(KIND = 4), INTENT(IN) :: npoints, nlevels

    ! Output variables
    TYPE(type_icon), INTENT(OUT)   :: model

    ! Internal variables

    model%nPoints   =  npoints
    model%nLevels   =  nlevels

    !! 2D fields
    ALLOCATE(model%lat(npoints)); model%lat = 0._wp
    ALLOCATE(model%lon(npoints)); model%lon = 0._wp
    ALLOCATE(model%lat_orig(npoints)); model%lat_orig = 0._wp
    ALLOCATE(model%lon_orig(npoints)); model%lon_orig = 0._wp

    ALLOCATE(model%orography(npoints)); model%orography = 0._wp
    ALLOCATE(model%u_wind(npoints)); model%u_wind = 0._wp
    ALLOCATE(model%v_wind(npoints)); model%v_wind = 0._wp
    ALLOCATE(model%skt(npoints)); model%skt = 0._wp
    ALLOCATE(model%psfc(npoints)); model%psfc = 0._wp
    ALLOCATE(model%q2m(npoints)); model%q2m = 0._wp
    ALLOCATE(model%t2m(npoints)); model%t2m = 0._wp
    ALLOCATE(model%landmask(npoints)); model%landmask = 0._wp

    !! 3D fields
    ALLOCATE(model%co2(npoints, nlevels)); model%co2 = 0._wp
    ALLOCATE(model%ch4(npoints, nlevels)); model%ch4 = 0._wp
    ALLOCATE(model%n2o(npoints, nlevels)); model%n2o = 0._wp
    ALLOCATE(model%s2o(npoints, nlevels)); model%s2o = 0._wp
    ALLOCATE(model%co(npoints, nlevels)); model%co = 0._wp
    ALLOCATE(model%p(npoints, nlevels)); model%p = 0._wp
    ALLOCATE(model%z(npoints, nlevels)); model%z = 0._wp
    ALLOCATE(model%dz(npoints, nlevels)); model%dz = 0._wp
    ALLOCATE(model%t(npoints, nlevels)); model%t = 0._wp
    ALLOCATE(model%sh(npoints, nlevels)); model%sh = 0._wp
    ALLOCATE(model%tca(npoints, nlevels)); model%tca = 0._wp
    ALLOCATE(model%reff(npoints, nlevels)); model%reff = 0._wp
    ALLOCATE(model%cdnc(npoints, nlevels)); model%cdnc = 0._wp
    ALLOCATE(model%iwc(npoints, nlevels)); model%iwc = 0._wp
    ALLOCATE(model%lwc(npoints, nlevels)); model%lwc = 0._wp


  END SUBROUTINE model_setup_init


  SUBROUTINE model_setup_icon(model, icon, nml)

    ! Input variables
    TYPE(type_icon), INTENT(IN)    :: icon
    TYPE(type_nml), INTENT(IN)      :: nml

    ! Output variables
    TYPE(type_icon), INTENT(OUT)   :: model

    ! Internal variables


    model%Nlat = icon%nlat
    model%Nlon = icon%nlon
    model%mode = icon%mode

    model%nPoints   =  icon%nPoints
    model%nLevels   =  icon%nLevels

    model%lat       =  icon%lat
    model%lon       =  icon%lon
    model%orography =  icon%orography
    model%u_wind    =  icon%u_wind
    model%v_wind    =  icon%v_wind
    model%skt       =  icon%skt
    model%psfc      =  icon%psfc
    model%q2m       =  icon%q2m
    model%t2m       =  icon%t2m
    model%landmask  =  icon%landmask

    model%co2       =  icon%co2
    model%ch4       =  icon%ch4
    model%n2o       =  icon%n2o
    model%s2o       =  icon%s2o
    model%co        =  icon%co
    model%p         =  icon%p
    model%z         =  icon%z
    model%dz        =  icon%dz
    model%t         =  icon%t
    model%sh        =  icon%sh
    model%tca       =  icon%tca
    model%iwc       =  icon%iwc
    model%lwc       =  icon%lwc
    model%reff      =  icon%reff
    model%cdnc      =  icon%cdnc

  END SUBROUTINE model_setup_icon



END MODULE mod_atm_init
