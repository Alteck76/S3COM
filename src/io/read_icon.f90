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

MODULE MOD_READ_ICON
   
   USE netcdf
   USE s3com_types, ONLY: wp, type_icon
   USE s3com_config, ONLY:                &
      amd, rd, rv, rholiq, epsilon,    &
      mr_co2, mr_ch4, mr_n2o, mr_co,   &
      amCO2, amCH4, amN2O, amCO, amO3, &
      a, b, mu, nu, Q_ext, grav
   USE mod_utils_fort, ONLY: s3com_error
   USE mod_regrid
   
   IMPLICIT NONE
   
   !!Types to be used as arrays of pointers
   TYPE var1d
      CHARACTER(LEN=16) :: name
      CHARACTER(LEN=16) :: units
      INTEGER :: dimsid(3)
      INTEGER :: dimssz(2)
      INTEGER :: vid
      LOGICAL :: lout
      REAL(wp), POINTER, DIMENSION(:) :: pntr
   END TYPE var1d
   
   TYPE var2d
      CHARACTER(LEN=16) :: name
      CHARACTER(LEN=16) :: units
      INTEGER :: dimsid(4)
      INTEGER :: dimssz(3)
      INTEGER :: vid
      LOGICAL :: lout
      REAL(wp), POINTER, DIMENSION(:,:) :: pntr
   END TYPE var2d
   
   TYPE var3d
      CHARACTER(LEN=16) :: name
      CHARACTER(LEN=16) :: units
      INTEGER :: dimsid(5)
      INTEGER :: dimssz(4)
      INTEGER :: vid
      LOGICAL :: lout
      REAL(wp), POINTER, DIMENSION(:,:,:) :: pntr
   END TYPE var3d
   
   CONTAINS

     SUBROUTINE icon_read(fname, icon)

       !!Parameters
       CHARACTER(LEN=64), PARAMETER :: routine_name = 'READ_ICON'
       INTEGER, PARAMETER :: NMAX_DIM = 5

       !!Inputs
       CHARACTER(LEN=256), INTENT(IN) :: fname

       !!Inputs/Outputs
       TYPE(type_icon), INTENT(INOUT) :: icon

       !!Local variables
       CHARACTER(LEN=256) :: errmsg, straux
       CHARACTER(LEN=256) :: dimname(NMAX_DIM), vname

       INTEGER(KIND=4)                    :: idim, dimsize(NMAX_DIM), vdimid(NMAX_DIM)
       INTEGER(KIND=4)                    :: ncid, ndims, nvars, ngatts, recdim, errst, vid, vrank
       INTEGER(KIND=4)                    :: Na, Nb, Nc, Nd, Ne, i, j, k
       INTEGER(KIND=4)                    :: npoints, nlevels
       INTEGER, DIMENSION(:), ALLOCATABLE :: plon, plat

       REAL(wp), DIMENSION(:), ALLOCATABLE :: lat, lon, ll, height
       REAL(wp), ALLOCATABLE               :: x1(:), x2(:,:), x3(:,:,:), x4(:,:,:,:), x5(:,:,:,:,:) ! Temporary arrays

       LOGICAL :: Llat, Llon, Lpoint

       npoints = icon%npoints; nlevels = icon%nlevels

       !!========================================================================================================================!!
       !! Checking the opening of the ICON input NetCDF file                                                                     !!
       !!========================================================================================================================!!

       errst = nf90_open(fname, nf90_nowrite, ncid)
       IF (errst/=0)  THEN
          errmsg = "Couldn't open "//trim(fname)
          CALL s3com_error(routine_name,errmsg)
       ENDIF

       !!========================================================================================================================!!

       !!========================================================================================================================!!
       !! Checking the dimensions (track or lat-lon)                                                                             !!
       !!========================================================================================================================!!

       errst = nf90_inquire(ncid, ndims, nvars, ngatts, recdim)
       IF (errst /= 0) THEN
          errmsg = "Error in nf90_inquire"
          CALL s3com_error(routine_name, errmsg, errcode=errst)
       ENDIF

       Llat = .FALSE.; Llon = .FALSE.; Lpoint = .FALSE.

       DO idim = 1,ndims
          errst = nf90_Inquire_Dimension(ncid, idim, NAME=dimname(idim), LEN=dimsize(idim))
          IF (errst /= 0) THEN
             WRITE(straux, *) idim
             errmsg = "Error in nf90_Inquire_Dimension, idim: "//trim(straux)
             CALL s3com_error(routine_name, errmsg)
          ENDIF

          IF ((trim(dimname(idim)) .EQ. 'height') .AND. (nlevels > dimsize(idim))) THEN
             errmsg = 'Number of levels selected is greater than in input file '//trim(fname)
             CALL s3com_error(routine_name, errmsg)
          ENDIF

          IF (trim(dimname(idim)) .EQ. 'point') THEN
             Lpoint = .TRUE.
             IF (npoints /= dimsize(idim)) THEN
                errmsg = 'Number of points selected is greater than in input file '//trim(fname)
                CALL s3com_error(routine_name,errmsg)
             ENDIF
          ENDIF

          IF (trim(dimname(idim)) .EQ. 'lon') THEN
             Llon = .TRUE.; icon%nlon = dimsize(idim)
          ENDIF

          IF (trim(dimname(idim)) .EQ. 'lat') THEN
             Llat = .TRUE.; icon%nlat = dimsize(idim)
          ENDIF
       ENDDO

       ALLOCATE(lon(icon%nlon), lat(icon%nlat), icon%lon_orig(icon%nlon), icon%lat_orig(icon%nlat))

       !!========================================================================================================================!!

       !!========================================================================================================================!!
       !! Extract coordinates                                                                                                    !!
       !!========================================================================================================================!!

       IF (Llon .AND. Llat) THEN ! 2D mode
          IF (npoints /= icon%nlon*icon%nlat) THEN
             errmsg = 'Number of points selected is different from indicated in input file '//trim(fname)
             CALL s3com_error(routine_name,errmsg)
          ENDIF
          lon = -1.0E30; lat = -1.0E30
          icon%mode = 2 ! Don't know yet if (lon,lat) or (lat,lon) at this point
       ELSE IF (Lpoint) THEN ! 1D mode
          icon%nlon = npoints
          icon%nlat = npoints
          icon%mode = 1
       ELSE
          errmsg = trim(fname)//' file contains wrong dimensions'
          CALL s3com_error(routine_name,errmsg)
       ENDIF

       errst = nf90_inq_varid(ncid, 'lon', vid)
       IF (errst /= 0) THEN
          errmsg = "Error in nf90_inq_varid, var: lon"
          CALL s3com_error(routine_name,errmsg,errcode=errst)
       ENDIF

       errst = nf90_get_var(ncid, vid, lon, start = (/1/), count = (/icon%nlon/))
       IF (errst /= 0) THEN
          errmsg = "Error in nf90_get_var, var: lon"
          CALL s3com_error(routine_name,errmsg,errcode=errst)
       ENDIF

       errst = nf90_inq_varid(ncid, 'lat', vid)
       IF (errst /= 0) THEN
          errmsg = "Error in nf90_inq_varid, var: lat"
          CALL s3com_error(routine_name,errmsg,errcode=errst)
       ENDIF

       errst = nf90_get_var(ncid, vid, lat, start = (/1/), count = (/icon%nlat/))
       IF (errst /= 0) THEN
          errmsg = "Error in nf90_get_var, var: lat"
          CALL s3com_error(routine_name,errmsg,errcode=errst)
       ENDIF

       errst = nf90_inq_varid(ncid, 'height', vid)
       errst = nf90_get_var(ncid, vid, icon%height, start = (/1/), count = (/icon%nlevels/))
       IF (errst /= 0) THEN
          errmsg = "Error in nf90_get_var, var: height"
          CALL s3com_error(routine_name,errmsg,errcode=errst)
       ENDIF

       icon%lon_orig = lon; icon%lat_orig = lat

       !!========================================================================================================================!!

       !!========================================================================================================================!!
       !! Extract all variables                                                                                                  !!
       !!========================================================================================================================!!

       DO vid = 1, nvars
          vdimid = 0
          errst = nf90_Inquire_Variable(ncid, vid, NAME=vname, ndims=vrank, dimids=vdimid)
          IF (errst /= 0) THEN
             WRITE(straux, *) vid
             errmsg = 'Error in nf90_Inquire_Variable, vid '//trim(straux)
             CALL s3com_error(routine_name,errmsg,errcode=errst)
          ENDIF

          !!Read in into temporary array of correct shape
          IF (vrank == 1) THEN
             Na = dimsize(vdimid(1))
             ALLOCATE(x1(Na))
             errst = nf90_get_var(ncid, vid, x1, start=(/1/), count=(/Na/))
          ENDIF
          IF (vrank == 2) THEN
             Na = dimsize(vdimid(1))
             Nb = dimsize(vdimid(2))
             ALLOCATE(x2(Na,Nb))
             errst = nf90_get_var(ncid, vid, x2, start=(/1,1/), count=(/Na,Nb/))
          ENDIF
          IF (vrank == 3) THEN
             Na = dimsize(vdimid(1))
             Nb = dimsize(vdimid(2))
             Nc = dimsize(vdimid(3))
             ALLOCATE(x3(Na,Nb,Nc))
             errst = nf90_get_var(ncid, vid, x3, start=(/1,1,1/), count=(/Na,Nb,Nc/))
             IF ((icon%mode == 2) .OR. (icon%mode == 3)) THEN
                IF ((Na == icon%nlon) .AND. (Nb == icon%nlat)) THEN
                   icon%mode = 2
                ELSE IF ((Na == icon%nlat) .AND. (Nb == icon%nlon)) THEN
                   icon%mode = 3
                ELSE
                   errmsg = 'Wrong mode for variable '//trim(vname)
                   CALL s3com_error(routine_name,errmsg)
                ENDIF
             ENDIF
          ENDIF
          IF (vrank == 4) THEN
             Na = dimsize(vdimid(1))
             Nb = dimsize(vdimid(2))
             Nc = dimsize(vdimid(3))
             Nd = dimsize(vdimid(4))
             ALLOCATE(x4(Na,Nb,Nc,Nd))
             errst = nf90_get_var(ncid, vid, x4, start=(/1,1,1,1/), count=(/Na,Nb,Nc,Nd/))
          ENDIF
          IF (vrank == 5) THEN
             Na = dimsize(vdimid(1))
             Nb = dimsize(vdimid(2))
             Nc = dimsize(vdimid(3))
             Nd = dimsize(vdimid(4))
             Ne = dimsize(vdimid(5))
             ALLOCATE(x5(Na,Nb,Nc,Nd,Ne))
             errst = nf90_get_var(ncid, vid, x5, start=(/1,1,1,1,1/), count=(/Na,Nb,Nc,Nd,Ne/))
          ENDIF
          IF (errst /= 0) THEN
             WRITE(straux, *)  vid
             errmsg = 'Error in nf90_get_var, vid '//trim(straux)
             CALL s3com_error(routine_name,errmsg,errcode=errst)
          ENDIF

          !!Map to the right input argument
          SELECT CASE (trim(vname))

             !!2D variables
          CASE ('topography_c') !Orography
             IF (Lpoint) THEN
                icon%orography(1:npoints) = x1(1:npoints)
             ELSE
                CALL map_ll_to_point(Na,Nb,npoints,x2=x2,y1=icon%orography)
             ENDIF
          CASE ('FR_LAND') !Land use class fraction
             IF (Lpoint) THEN
                icon%landmask(1:npoints) = x1(1:npoints)
             ELSE
                CALL map_ll_to_point(Na,Nb,npoints,x2=x2,y1=icon%landmask)
             ENDIF
          CASE ('ps') !Surface pressure
             IF (Lpoint) THEN
                icon%psfc(1:npoints) = x1(1:npoints)
             ELSE
                CALL map_ll_to_point(Na,Nb,npoints,x2=x2,y1=icon%psfc)
             ENDIF
          CASE ('t_s') !Skin temperature
             IF (Lpoint) THEN
                icon%skt(1:npoints) = x1(1:npoints)
             ELSE
                CALL map_ll_to_point(Na,Nb,npoints,x2=x2,y1=icon%skt)
             ENDIF
          CASE ('tas') !Temperature in 2m
             IF (Lpoint) THEN
                icon%t2m(1:npoints) = x1(1:npoints)
             ELSE
                CALL map_ll_to_point(Na,Nb,npoints,x2=x2,y1=icon%t2m)
             ENDIF
          CASE ('huss') !Specific water vapour content in 2m
             IF (Lpoint) THEN
                icon%q2m(1:npoints) = x1(1:npoints)
             ELSE
                CALL map_ll_to_point(Na,Nb,npoints,x2=x2,y1=icon%q2m)
             ENDIF
          CASE ('u_10m') !Zonal wind in 2m
             IF (Lpoint) THEN
                icon%u_wind(1:npoints) = x1(1:npoints)
             ELSE
                CALL map_ll_to_point(Na,Nb,npoints,x2=x2,y1=icon%u_wind)
             ENDIF
          CASE ('v_10m') !Meridional wind in 2m
             IF (Lpoint) THEN
                icon%v_wind(1:npoints) = x1(1:npoints)
             ELSE
                CALL map_ll_to_point(Na,Nb,npoints,x2=x2,y1=icon%v_wind)
             ENDIF

             !!3D variables
          CASE ('z_mc') !Geometric height at full level center
             IF (Lpoint) THEN
                icon%z(1:npoints,:) = x2(1:npoints,1:nlevels)
             ELSE
                call map_ll_to_point(Na,Nb,npoints,x3=x3,y2=icon%z)
             ENDIF
          CASE ('z_ifc') !Geometric height at half level center
             if (Lpoint) THEN
                icon%zh(1:npoints,1:nlevels+1) = x2(1:npoints,1:nlevels+1)
             ELSE
                CALL map_ll_to_point(Na,Nb,npoints,x3=x3,y2=icon%zh)
             ENDIF
          CASE ('pres') !Air pressure
             IF (Lpoint) THEN
                icon%p(1:npoints,:) = x2(1:npoints,1:nlevels)
             ELSE
                CALL map_ll_to_point(Na,Nb,npoints,x3=x3,y2=icon%p)
             ENDIF
          CASE ('ta') !Air temperature
             IF (Lpoint) THEN
                icon%T(1:npoints,:) = x2(1:npoints,1:nlevels)
             ELSE
                CALL map_ll_to_point(Na,Nb,npoints,x3=x3,y2=icon%T)
             ENDIF
          CASE ('hus') !Specific humidity
             IF (Lpoint) THEN
                icon%sh(1:npoints,:) = x2(1:npoints,1:nlevels)
             ELSE
                CALL map_ll_to_point(Na,Nb,npoints,x3=x3,y2=icon%sh)
             ENDIF
          CASE ('clc') !Cloud cover
             IF (Lpoint) THEN
                icon%tca(1:npoints,:) = x2(1:npoints,1:nlevels)
             ELSE
                CALL map_ll_to_point(Na,Nb,npoints,x3=x3,y2=icon%tca)
             ENDIF
          CASE ('clw') !Specific cloud water content
             IF (Lpoint) THEN
                icon%clw(1:npoints,:) = x2(1:npoints,1:nlevels)
             ELSE
                CALL map_ll_to_point(Na,Nb,npoints,x3=x3,y2=icon%clw)
             ENDIF
          CASE ('cli') !Specific cloud ice content
             IF (Lpoint) THEN
                icon%cli(1:npoints,:) = x2(1:npoints,1:nlevels)
             ELSE
                CALL map_ll_to_point(Na,Nb,npoints,x3=x3,y2=icon%cli)
             ENDIF
          CASE ('qnc') !Cloud droplet number concentration
             IF (Lpoint) THEN
                icon%qnc(1:npoints,:) = x2(1:npoints,1:nlevels)
             ELSE
                CALL map_ll_to_point(Na,Nb,npoints,x3=x3,y2=icon%qnc)
             ENDIF
          CASE ('qr') !Rain mixing ratio
              IF (Lpoint) THEN
                 icon%qr(1:npoints,:) = x2(1:npoints,1:nlevels)
              ELSE
                 CALL map_ll_to_point(Na,Nb,npoints,x3=x3,y2=icon%qr)
              ENDIF
           CASE ('qs') !Snow mixing ratio
              IF (Lpoint) THEN
                 icon%qs(1:npoints,:) = x2(1:npoints,1:nlevels)
              ELSE
                 CALL map_ll_to_point(Na,Nb,npoints,x3=x3,y2=icon%qs)
              ENDIF
              
          END SELECT

          !! Free memory
          IF(vrank == 1) DEALLOCATE(x1)
          IF(vrank == 2) DEALLOCATE(x2)
          IF(vrank == 3) DEALLOCATE(x3)
          IF(vrank == 4) DEALLOCATE(x4)
          IF(vrank == 5) DEALLOCATE(x5)

       ENDDO

       !!=======================================================================================================================!!

       !!=======================================================================================================================!!
       !! Fill in the lat/lon vectors with the right values for 2D modes                                                        !!
       !!=======================================================================================================================!!

       !This might be helpful if the inputs are 2D (gridded) and you want outputs in 1D mode
       ALLOCATE(plon(npoints),plat(npoints))
       ALLOCATE(ll(npoints))

       IF(icon%mode == 2) THEN !(lon,lat)
          ll = lat
          DO j = 1, Nb
             DO i = 1, Na
                k = (j-1)*Na + i
                plon(k) = i
                plat(k) = j
             ENDDO
          ENDDO
          icon%lon(1:npoints) = lon(plon(1:npoints))
          icon%lat(1:npoints) = ll(plat(1:npoints))
       ELSE IF (icon%mode == 3) THEN !(lat,lon)
          ll = lon
          DO j = 1, Nb
             DO i = 1, Na
                k = (j-1)*Na + i
                lon(k) = ll(j)
                lat(k) = lat(i)
             ENDDO
          ENDDO
          icon%lon(1:npoints) = ll(plon(1:npoints))
          icon%lat(1:npoints) = lat(plat(1:npoints))
       ENDIF

       DEALLOCATE(plon,plat)
       DEALLOCATE(ll)

       errst = nf90_close(ncid)
       IF (errst /= 0) THEN
          errmsg = "Error in nf90_close"
          CALL s3com_error(routine_name,errmsg,errcode=errst)
       ENDIF


     END SUBROUTINE icon_read
     

     SUBROUTINE extract_coordinates(fname, Nlevels, Npoints)

       !!Parameters
       CHARACTER(LEN=64), PARAMETER :: routine_name = 'extract_coordinates'
       INTEGER, PARAMETER :: NMAX_DIM = 5

       !!Inputs
       CHARACTER(LEN=256), INTENT(IN) :: fname

       !!Inputs/Outputs
       INTEGER(kind = 4), INTENT(INOUT) :: Nlevels, Npoints

       !!Local variables
       CHARACTER(LEN=256) :: errmsg, straux
       CHARACTER(LEN=256) :: dimname(NMAX_DIM), vname

       INTEGER(KIND=4)                    :: idim, dimsize(NMAX_DIM), vdimid(NMAX_DIM)
       INTEGER(KIND=4)                    :: ncid, ndims, nvars, ngatts, recdim, errst, vid, vrank
       INTEGER(KIND=4)                    :: nlat, nlon

       !!========================================================================================================================!!
       !! Checking the opening of the ICON input NetCDF file                                                                     !!
       !!========================================================================================================================!!

       errst = nf90_open(fname, nf90_nowrite, ncid)
       IF (errst/=0)  THEN
          errmsg = "Couldn't open "//trim(fname)
          CALL s3com_error(routine_name,errmsg)
       ENDIF

       !!========================================================================================================================!!

       !!========================================================================================================================!!
       !! Checking the dimensions (track or lat-lon)                                                                             !!
       !!========================================================================================================================!!

       errst = nf90_inquire(ncid, ndims, nvars, ngatts, recdim)
       IF (errst /= 0) THEN
          errmsg = "Error in nf90_inquire"
          CALL s3com_error(routine_name, errmsg, errcode=errst)
       ENDIF

       npoints = 0

       DO idim = 1,ndims
          errst = nf90_Inquire_Dimension(ncid, idim, NAME=dimname(idim), LEN=dimsize(idim))
          IF (errst /= 0) THEN
             WRITE(straux, *) idim
             errmsg = "Error in nf90_Inquire_Dimension, idim: "//trim(straux)
             CALL s3com_error(routine_name, errmsg)
          ENDIF

          IF (trim(dimname(idim)) .EQ. 'lon') THEN
             nlon = dimsize(idim)
          ENDIF

          IF (trim(dimname(idim)) .EQ. 'height') THEN
             nlevels = dimsize(idim)
          ENDIF

          IF (trim(dimname(idim)) .EQ. 'lat') THEN
             nlat = dimsize(idim)
          ENDIF

          IF (trim(dimname(idim)) .EQ. 'point') THEN
             npoints = dimsize(idim)
          ENDIF

       ENDDO

       !!========================================================================================================================!!

       IF(npoints .EQ. 0) npoints = nlon * nlat


     END SUBROUTINE extract_coordinates


END MODULE MOD_READ_ICON
