module trace_ppm_rad_module

  implicit none

contains

  subroutine trace_ppm_rad(lam, lam_l1, lam_h1, &
       q,dq,c,cg,flatn,qd_l1,qd_h1, &
       dloga,dloga_l1,dloga_h1, &
       srcQ,src_l1,src_h1,&
       qxm,qxp,qpd_l1,qpd_h1, &
       ilo,ihi,domlo,domhi,dx,dt)

    use bl_constants_module
    use network, only : nspec, naux
    use meth_params_module, only : QVAR, QRHO, QU, QREINT, QPRES, &
         small_dens, ppm_type, fix_mass_flux, &
         ppm_type, ppm_reference, ppm_trace_sources, ppm_temp_fix, &
         ppm_tau_in_tracing, ppm_reference_eigenvectors, ppm_reference_edge_limit, &
         ppm_flatten_before_integrals, ppm_predict_gammae, &
         npassive, qpass_map
    use prob_params_module, only : physbc_lo, physbc_hi, Outflow
    use radhydro_params_module, only : QRADVAR, qrad, qradhi, qptot, qreitot
    use rad_params_module, only : ngroups
    use ppm_module, only : ppm

    implicit none

    integer ilo,ihi
    integer domlo(1),domhi(1)
    integer lam_l1, lam_h1
    integer    qd_l1,   qd_h1
    integer dloga_l1,dloga_h1
    integer   qpd_l1,  qpd_h1
    integer   src_l1,  src_h1
    double precision dx, dt
    double precision lam(lam_l1:lam_h1, 0:ngroups-1)
    double precision     q( qd_l1: qd_h1,QRADVAR)
    double precision  srcQ(src_l1:src_h1,QVAR)
    double precision flatn(qd_l1:qd_h1)
    double precision     c(qd_l1:qd_h1)
    double precision    cg(qd_l1:qd_h1)
    double precision dloga(dloga_l1:dloga_h1)

    double precision   dq( qpd_l1: qpd_h1,QRADVAR)
    double precision  qxm( qpd_l1: qpd_h1,QRADVAR)
    double precision  qxp( qpd_l1: qpd_h1,QRADVAR)

    !     Local variables
    integer i, g
    integer n, ipassive

    double precision hdt,dtdx

    double precision, dimension(0:ngroups-1) :: er,der,alphar,sourcer,qrtmp,hr
    double precision, dimension(0:ngroups-1) :: lam0, lamp, lamm
    double precision cc, csq, rho, u, p, ptot, rhoe, enth, cgassq
    double precision dum, dptotm
    double precision drho, drhoe, dptot
    double precision dup, dptotp

    double precision :: rho_ref, u_ref, p_ref, rhoe_g_ref, ptot_ref, rhoe_ref
    double precision, dimension(0:ngroups-1) :: er_ref
    
    double precision alpham, alphap, alpha0, alphae
    double precision sourcr,sourcp,source,courn,eta,dlogatmp

    double precision rhoe_g, h_g, alphae_g, drhoe_g

    double precision :: xi, xi1
    
    logical :: fix_mass_flux_lo, fix_mass_flux_hi

    double precision, allocatable :: Ip(:,:,:)
    double precision, allocatable :: Im(:,:,:)

    double precision, allocatable :: Ip_src(:,:,:)
    double precision, allocatable :: Im_src(:,:,:)    

    double precision :: er_foo

    fix_mass_flux_lo = (fix_mass_flux .eq. 1) .and. (physbc_lo(1) .eq. Outflow) &
         .and. (ilo .eq. domlo(1))
    fix_mass_flux_hi = (fix_mass_flux .eq. 1) .and. (physbc_hi(1) .eq. Outflow) &
         .and. (ihi .eq. domhi(1))

    if (ppm_type .eq. 0) then
       print *,'Oops -- shouldnt be in trace_ppm with ppm_type = 0'
       call bl_error("Error:: RadHydro_1d.f90 :: trace_ppm_rad")
    end if

    if (ppm_tau_in_tracing == 1) then
       call bl_error("ERROR: ppm_tau_in_tracing not implemented with radiation")
    endif

    if (ppm_predict_gammae == 1) then
       call bl_error("ERROR: ppm_predict_gammae not implemented with radiation")
    endif

    if (ppm_temp_fix > 0) then
       call bl_error("ERROR: ppm_temp_fix > 0 not implemented with radiation")
    endif

    if (ppm_reference_eigenvectors == 1) then
       call bl_error("ERROR: ppm_reference_eigenvectors not implemented with radiation")
    endif

    hdt = 0.5d0 * dt
    dtdx = dt/dx

    allocate(Ip(ilo-1:ihi+1,3,QRADVAR))
    allocate(Im(ilo-1:ihi+1,3,QRADVAR))

    if (ppm_trace_sources == 1) then
       allocate(Ip_src(ilo-1:ihi+1,3,QVAR))
       allocate(Im_src(ilo-1:ihi+1,3,QVAR))
    endif

    !=========================================================================
    ! PPM CODE
    !=========================================================================

    ! This does the characteristic tracing to build the interface
    ! states using the normal predictor only (no transverse terms).
    !
    ! We first fill the Im and Ip arrays -- these are the averages of
    ! the various primitive state variables under the parabolic
    ! interpolant over the region swept out by one of the 3 different
    ! characteristic waves.
    !
    ! Im is integrating to the left interface of the current zone
    ! (which will be used to build the right state at that interface)
    ! and Ip is integrating to the right interface of the current zone
    ! (which will be used to build the left state at that interface).
    !
    ! The indices are: Ip(i, wave, var)
    !
    ! The choice of reference state is designed to minimize the
    ! effects of the characteristic projection.  We subtract the I's
    ! off of the reference state, project the quantity such that it is
    ! in terms of the characteristic varaibles, and then add all the
    ! jumps that are moving toward the interface to the reference
    ! state to get the full state on that interface.


    ! Compute Ip and Im -- this does the parabolic reconstruction,
    ! limiting, and returns the integral of each profile under
    ! each wave to each interface
    
    ! Compute Ip and Im
    do n=1,QRADVAR
       call ppm(q(:,n),qd_l1,qd_h1, &
                q(:,QU),c, &
                flatn, &
                Ip(:,:,n),Im(:,:,n), &
                ilo,ihi,dx,dt)
    end do

    if (ppm_trace_sources == 1) then
       do n=1,QVAR
          call ppm(srcQ(:,n),src_l1,src_h1, &
                   q(:,QU:),c, &
                   flatn, &
                   Ip_src(:,:,n),Im_src(:,:,n), &
                   ilo,ilo,dx,dt)
       enddo
    endif

    !-------------------------------------------------------------------------
    ! x-direction
    !-------------------------------------------------------------------------
    
    ! Trace to left and right edges using upwind PPM
    do i = ilo-1, ihi+1

       do g=0, ngroups-1
          lam0(g) = lam(i,g)
          lamp(g) = lam(i,g)
          lamm(g) = lam(i,g)
       end do

       ! cgassq is the gas soundspeed **2
       ! cc is the total soundspeed **2 (gas + radiation)       
       cgassq = cg(i)**2
       cc = c(i)
       csq = cc**2

       rho = q(i,QRHO)
       u = q(i,QU)
       p = q(i,QPRES)
       rhoe_g = q(i,QREINT)
       h_g = (p+rhoe_g) / rho
       
       ptot = q(i,qptot)
       rhoe = q(i,qreitot)
       enth = ( (rhoe+ptot)/rho )/csq

       er(:) = q(i,qrad:qradhi)
       hr(:) = (lam0+1.d0)*er/rho

       !-------------------------------------------------------------------       
       ! plus state on face i
       !-------------------------------------------------------------------

       ! set the reference state
       if (ppm_reference == 0 .or. &
            (ppm_reference == 1 .and. u - cc >= ZERO .and. &
            ppm_reference_edge_limit == 0)) then
          ! original Castro way -- cc value
          rho_ref = rho
          u_ref = u

          p_ref = p
          rhoe_g_ref = rhoe_g

          ptot_ref = ptot
          rhoe_ref = rhoe

          er_ref(:) = er(:)
       else
          ! this will be the fastest moving state to the left --
          ! this is the method that Miller & Colella and Colella &
          ! Woodward use
          rho_ref = Im(i,1,QRHO)
          u_ref = Im(i,1,QU)

          p_ref = Im(i,1,QPRES)
          rhoe_g_ref = Im(i,1,QREINT)

          ptot_ref = Im(i,1,qptot)
          rhoe_ref = Im(i,1,qreitot)

          er_ref(:) = Im(i,1,qrad:qradhi)
       endif

       ! *m are the jumps carried by u-c
       ! *p are the jumps carried by u+c
       
       dum    = u_ref    - Im(i,1,QU)
       dptotm = ptot_ref - Im(i,1,qptot)

       drho    = rho_ref    - Im(i,2,QRHO)
       drhoe_g = rhoe_g_ref - Im(i,2,QREINT)
       drhoe   = rhoe_ref   - Im(i,2,qreitot)
       dptot   = ptot_ref   - Im(i,2,qptot)
       der(:)  = er_ref(:)  - Im(i,2,qrad:qradhi)

       dup    = u_ref    - Im(i,3,QU)
       dptotp = ptot_ref - Im(i,3,qptot)

       ! if we are doing source term tracing, then we add the force to
       ! the velocity here, otherwise we will deal with this later
       if (ppm_trace_sources == 1) then
          dum = dum - hdt*Im_src(i,1,QU)
          dup = dup - hdt*Im_src(i,3,QU)
       endif

       ! these are analogous to the beta's from the original
       ! PPM paper (except we work with rho instead of tau).
       ! This is simply (l . dq), where dq = qref - I(q)
       
       alpham = 0.5d0*(dptotm/(rho*cc) - dum)*rho/cc
       alphap = 0.5d0*(dptotp/(rho*cc) + dup)*rho/cc
       alpha0 = drho - dptot/csq
       alphae = drhoe - dptot*enth
       alphae_g = drhoe_g - dptot/csq*h_g
       alphar(:) = der(:) - dptot/csq*hr

       if (u-cc .gt. 0.d0) then
          alpham = 0.d0
       else if (u-cc .lt. 0.d0) then
          alpham = -alpham
       else
          alpham = -0.5d0*alpham
       endif
       if (u+cc .gt. 0.d0) then
          alphap = 0.d0
       else if (u+cc .lt. 0.d0) then
          alphap = -alphap
       else
          alphap = -0.5d0*alphap
       endif
       if (u .gt. 0.d0) then
          alpha0 = 0.d0
          alphae = 0.d0
          alphae_g = 0.d0
          alphar(:) = 0.d0
       else if (u .lt. 0.d0) then
          alpha0 = -alpha0
          alphae = -alphae
          alphae_g = -alphae_g
          alphar(:) = -alphar(:)
       else
          alpha0 = -0.5d0*alpha0
          alphae = -0.5d0*alphae
          alphae_g = -0.5d0*alphae_g
          alphar(:) = -0.5d0*alphar(:)
       endif

       ! the final interface states are just
       ! q_s = q_ref - sum (l . dq) r
       if (i .ge. ilo) then
          qxp(i,QRHO)   = rho_ref + alphap + alpham + alpha0
          qxp(i,QU)     = u_ref + (alphap - alpham)*cc/rho
          qxp(i,QREINT) = rhoe_g_ref + (alphap + alpham)*h_g + alphae_g
          qxp(i,QPRES)  = p_ref + (alphap + alpham)*cgassq - sum(lamp(:)*alphar(:))

          qrtmp = er_ref(:) + (alphap + alpham)*hr + alphar(:)
          qxp(i,qrad:qradhi) = qrtmp

          qxp(i,qptot) = ptot_ref + (alphap + alpham)*csq
          qxp(i,qreitot) = qxp(i,QREINT) + sum(qrtmp)

          ! enforce small_*
          qxp(i,QRHO) = max(small_dens,qxp(i,QRHO))
          
          ! add source terms
          qxp(i  ,QRHO  )  = qxp(i,QRHO   ) + hdt*srcQ(i,QRHO)
          qxp(i  ,QRHO  )  = max(small_dens,qxp(i,QRHO))
          qxp(i  ,QU    )  = qxp(i,QU     )
          qxp(i  ,QREINT)  = qxp(i,QREINT ) + hdt*srcQ(i,QREINT)
          qxp(i  ,QPRES )  = qxp(i,QPRES  ) + hdt*srcQ(i,QPRES)
          qxp(i  ,qptot )  = qxp(i,qptot  ) + hdt*srcQ(i,QPRES)
          qxp(i  ,qreitot) = qxp(i,qreitot) + hdt*srcQ(i,QREINT)

          ! add traced source terms as needed
          if (ppm_trace_sources == 0) then
             qxp(i  ,QU) = qxp(i,QU) + hdt*srcQ(i,QU)
          endif

          do g=0, ngroups-1
             if (qxp(i,qrad+g) < 0.d0) then
                er_foo = - qxp(i,qrad+g)
                qxp(i,qrad+g) = 0.d0
                qxp(i,qptot) = qxp(i,qptot) + lamp(g) * er_foo
                qxp(i,qreitot) = qxp(i,qreitot) + er_foo
             end if
          end do

          if ( qxp(i,QPRES) < 0.d0 ) then
             qxp(i,QPRES) = p
          end if

          ! we may have done the flattening already in the parabola
          if (ppm_flatten_before_integrals == 0) then
             xi1 = ONE-flatn(i)
             xi = flatn(i)
             
             qxp(i,QRHO)   = xi1*rho  + xi*qxp(i,QRHO)
             qxp(i,QU)     = xi1*u    + xi*qxp(i,QU)
             qxp(i,QREINT) = xi1*rhoe_g + xi*qxp(i,QREINT)
             qxp(i,QPRES)  = xi1*p    + xi*qxp(i,QPRES)
             
             qxp(i,qrad:qradhi) = xi1*er(:) + xi*qxp(i,qrad:qradhi)
             
             qxp(i,qptot)   = xi1*ptot + xi*qxp(i,qptot)
             qxp(i,qreitot) = xi1*rhoe + xi*qxp(i,qreitot)
             
          endif
          
       end if


       !-------------------------------------------------------------------
       ! minus state on face i+1
       !-------------------------------------------------------------------

       ! set the reference state
       if (ppm_reference == 0 .or. &
            (ppm_reference == 1 .and. u + cc <= ZERO .and. &
            ppm_reference_edge_limit == 0) ) then
          ! original Castro way -- cc values
          rho_ref  = rho
          u_ref    = u

          p_ref      = p
          rhoe_g_ref = rhoe_g

          ptot_ref = ptot
          rhoe_ref = rhoe

          er_ref(:) = er(:)
       else
          ! this will be the fastest moving state to the right
          rho_ref  = Ip(i,3,QRHO)
          u_ref    = Ip(i,3,QU)
          
          p_ref      = Ip(i,3,QPRES)
          rhoe_g_ref = Ip(i,3,QREINT)
          
          ptot_ref = Ip(i,3,qptot)
          rhoe_ref = Ip(i,3,qreitot)
          
          er_ref(:) = Ip(i,3,qrad:qradhi)
       endif

       !  *m are the jumps carried by u-c
       !  *p are the jumps carried by u+c

       dum    = u_ref    - Ip(i,1,QU)
       dptotm = ptot_ref - Ip(i,1,qptot)

       drho    = rho_ref    - Ip(i,2,QRHO)
       drhoe_g = rhoe_g_ref - Ip(i,2,QREINT)
       drhoe   = rhoe_ref   - Ip(i,2,qreitot)
       dptot   = ptot_ref   - Ip(i,2,qptot)
       der(:)  = er_ref(:)  - Ip(i,2,qrad:qradhi)

       dup    = u_ref    - Ip(i,3,QU)
       dptotp = ptot_ref - Ip(i,3,qptot)

       ! if we are doing source term tracing, then we add the force to
       ! the velocity here, otherwise we will deal with this in the
       ! trans_X routines
       if (ppm_trace_sources == 1) then
          dum = dum - hdt*Ip_src(i,1,QU)
          dup = dup - hdt*Ip_src(i,3,QU)
       endif

       ! these are analogous to the beta's from the original
       ! PPM paper (except we work with rho instead of tau).
       ! This is simply (l . dq), where dq = qref - I(q)
       alpham = 0.5d0*(dptotm/(rho*cc) - dum)*rho/cc
       alphap = 0.5d0*(dptotp/(rho*cc) + dup)*rho/cc
       alpha0 = drho - dptot/csq
       alphae = drhoe - dptot*enth
       alphae_g = drhoe_g - dptot/csq*h_g
       alphar(:) = der(:)- dptot/csq*hr

       if (u-cc .gt. 0.d0) then
          alpham = -alpham
       else if (u-cc .lt. 0.d0) then
          alpham = 0.d0
       else
          alpham = -0.5d0*alpham
       endif
       if (u+cc .gt. 0.d0) then
          alphap = -alphap
       else if (u+cc .lt. 0.d0) then
          alphap = 0.d0
       else
          alphap = -0.5d0*alphap
       endif
       if (u .gt. 0.d0) then
          alpha0 = -alpha0
          alphae = -alphae
          alphae_g = -alphae_g
          alphar(:) = -alphar(:)
       else if (u .lt. 0.d0) then
          alpha0 = 0.d0
          alphae = 0.d0
          alphae_g = 0.d0
          alphar(:) = 0.d0
       else
          alpha0 = -0.5d0*alpha0
          alphae = -0.5d0*alphae
          alphae_g = -0.5d0*alphae_g
          alphar(:) = -0.5d0*alphar(:)
       endif

       ! the final interface states are just
       ! q_s = q_ref - sum (l . dq) r
       if (i .le. ihi) then
          qxm(i+1,QRHO)   = rho_ref + alphap + alpham + alpha0
          qxm(i+1,QU)     = u_ref + (alphap - alpham)*cc/rho
          qxm(i+1,QREINT) = rhoe_g_ref + (alphap + alpham)*h_g + alphae_g
          qxm(i+1,QPRES)  = p_ref + (alphap + alpham)*cgassq - sum(lamm(:)*alphar(:))

          qrtmp = er_ref(:) + (alphap + alpham)*hr + alphar(:)
          qxm(i+1,qrad:qradhi) = qrtmp

          qxm(i+1,qptot) = ptot_ref + (alphap + alpham)*csq
          qxm(i+1,qreitot) = qxm(i+1,QREINT) + sum(qrtmp)

          ! enforce small_*
          qxm(i+1,QRHO) = max(qxm(i+1,QRHO),small_dens)
          
          ! add source terms
          qxm(i+1,QRHO   ) = qxm(i+1,QRHO   ) + hdt*srcQ(i,QRHO)
          qxm(i+1,QRHO   ) = max(small_dens, qxm(i+1,QRHO))
          qxm(i+1,QU     ) = qxm(i+1,QU     )
          qxm(i+1,QREINT ) = qxm(i+1,QREINT ) + hdt*srcQ(i,QREINT)
          qxm(i+1,QPRES  ) = qxm(i+1,QPRES  ) + hdt*srcQ(i,QPRES)
          qxm(i+1,qptot  ) = qxm(i+1,qptot  ) + hdt*srcQ(i,QPRES)
          qxm(i+1,qreitot) = qxm(i+1,qreitot) + hdt*srcQ(i,QREINT)

          ! add traced source terms as needed
          if (ppm_trace_sources == 0) then
             qxm(i+1,QU) = qxm(i+1,QU) + hdt*srcQ(i,QU)
          endif

          do g=0, ngroups-1
             if (qxm(i+1,qrad+g) < 0.d0) then
                er_foo = - qxm(i+1,qrad+g)
                qxm(i+1,qrad+g) = 0.d0
                qxm(i+1,qptot) = qxm(i+1,qptot) + lamm(g) * er_foo
                qxm(i+1,qreitot) = qxm(i+1,qreitot) + er_foo
             end if
          end do

          if ( qxm(i+1,QPRES) < 0.d0 ) then
             qxm(i+1,QPRES) = p
          end if

          ! we may have already done the flattening in the parabola
          if (ppm_flatten_before_integrals == 0) then
             xi1 = ONE-flatn(i)
             xi = flatn(i)
             
             qxm(i+1,QRHO)   = xi1*rho  + xi*qxm(i+1,QRHO)
             qxm(i+1,QU)     = xi1*u    + xi*qxm(i+1,QU)
             qxm(i+1,QREINT) = xi1*rhoe_g + xi*qxm(i+1,QREINT)
             qxm(i+1,QPRES)  = xi1*p    + xi*qxm(i+1,QPRES)

             qxm(i+1,qrad:qradhi) = xi1*er(:) + xi*qxm(i+1,qrad:qradhi)
             
             qxm(i+1,qptot)   = xi1*ptot + xi*qxm(i+1,qptot)
             qxm(i+1,qreitot) = xi1*rhoe + xi*qxm(i+1,qreitot)
          endif

       end if


       !-------------------------------------------------------------------
       ! geometry source terms
       !-------------------------------------------------------------------
       
       if(dloga(i).ne.0)then
          courn = dtdx*(cc+abs(u))
          eta = (1.d0-courn)/(cc*dt*abs(dloga(i)))
          dlogatmp = min(eta,1.d0)*dloga(i)
          sourcr = -0.5d0*dt*rho*dlogatmp*u
          sourcp = sourcr*cgassq
          source = sourcr*h_g
          sourcer(:) = -0.5d0*dt*dlogatmp*u*(lam0(:)+1.d0)*er(:)
          if (i .le. ihi) then
             qxm(i+1,QRHO  ) = qxm(i+1,QRHO  ) + sourcr
             qxm(i+1,QRHO  ) = max(small_dens, qxm(i+1,QRHO))
             qxm(i+1,QPRES ) = qxm(i+1,QPRES ) + sourcp
             qxm(i+1,QREINT) = qxm(i+1,QREINT) + source
             qxm(i+1,qrad:qradhi) = qxm(i+1,qrad:qradhi) + sourcer(:)
             !           qxm(i+1,qptot ) = sum(lamm(:)*qxm(i+1,qrad:qradhi)) + qxm(i+1,QPRES)
             qxm(i+1,qptot) = qxm(i+1,qptot) + sum(lamm(:)*sourcer(:)) + sourcp
             qxm(i+1,qreitot) = sum(qxm(i+1,qrad:qradhi))  + qxm(i+1,QREINT)
          end if
          if (i .ge. ilo) then
             qxp(i  ,QRHO  ) = qxp(i  ,QRHO  ) + sourcr
             qxp(i  ,QRHO  ) = max(small_dens,qxp(i,QRHO))
             qxp(i  ,QPRES ) = qxp(i  ,QPRES ) + sourcp
             qxp(i  ,QREINT) = qxp(i  ,QREINT) + source
             qxp(i  ,qrad:qradhi) = qxp(i  ,qrad:qradhi) + sourcer(:)
             !           qxp(i  ,qptot ) = sum(lamp(:)*qxp(i,qrad:qradhi)) + qxp(i,QPRES)
             qxp(i,qptot) = qxp(i,qptot) + sum(lamp(:)*sourcer(:)) + sourcp
             qxp(i  ,qreitot) = sum(qxp(i,qrad:qradhi))  + qxp(i,QREINT)
          end if
       endif

    end do

    ! Enforce constant mass flux rate if specified
    if (fix_mass_flux_lo) then
       qxm(ilo,QRHO   ) = q(domlo(1)-1,QRHO)
       qxm(ilo,QU     ) = q(domlo(1)-1,QU  )
       qxm(ilo,QPRES  ) = q(domlo(1)-1,QPRES)
       qxm(ilo,QREINT ) = q(domlo(1)-1,QREINT)
       qxm(ilo,qrad:qradhi) = q(domlo(1)-1,qrad:qradhi)
       qxm(ilo,qptot  ) = q(domlo(1)-1,qptot)
       qxm(ilo,qreitot) = q(domlo(1)-1,qreitot)
    end if

    ! Enforce constant mass flux rate if specified
    if (fix_mass_flux_hi) then
       qxp(ihi+1,QRHO   ) = q(domhi(1)+1,QRHO)
       qxp(ihi+1,QU     ) = q(domhi(1)+1,QU  )
       qxp(ihi+1,QPRES  ) = q(domhi(1)+1,QPRES)
       qxp(ihi+1,QREINT ) = q(domhi(1)+1,QREINT)
       qxp(ihi+1,qrad:qradhi) = q(domhi(1)+1,qrad:qradhi)
       qxp(ihi+1,qptot  ) = q(domhi(1)+1,qptot)
       qxp(ihi+1,qreitot) = q(domhi(1)+1,qreitot)
    end if


    !-------------------------------------------------------------------------    
    ! Now do the passively advected quantities
    !-------------------------------------------------------------------------

    ! We do all passively advected quantities in one loop
    do ipassive = 1, npassive
       n = qpass_map(ipassive)

       ! plus state on face i
       do i = ilo, ihi+1
          u = q(i,QU)

          if (ppm_flatten_before_integrals == 0) then
             xi = flatn(i)
          else
             xi = ONE
          endif

          ! the flattening here is a little confusing.  If
          ! ppm_flatten_before_integrals = 0, then we are blending
          ! the cell centered state and the edge state here through
          ! the flattening procedure.  Otherwise, we've already
          ! took care of flattening.  What we want to do is:
          !
          ! q_l*  (1-xi)*q_i + xi*q_l
          !
          ! where
          !
          ! q_l = q_ref - Proj{(q_ref - I)}
          !
          ! and Proj{} represents the characteristic projection.
          ! But for these, there is only 1-wave that matters, the u
          ! wave, so no projection is needed.  Since we are not
          ! projecting, the reference state doesn't matter, so we
          ! take it to be q_i, therefore, we reduce to
          !
          ! q_l* = (1-xi)*q_i + xi*[q_i - (q_i - I)]
          !      = q_i + xi*(I - q_i)

          if (u .gt. ZERO) then
             qxp(i,n) = q(i,n)    ! we might want to change this to
                                  ! the limit of the parabola
          else if (u .lt. ZERO) then
             qxp(i,n) = q(i,n) + xi*(Im(i,2,n) - q(i,n))
          else
             qxp(i,n) = q(i,n) + HALF*xi*(Im(i,2,n) - q(i,n))
          endif
       enddo

       ! minus state on face i+1
       do i = ilo-1, ihi
          u = q(i,QU)

          if (ppm_flatten_before_integrals == 0) then
             xi = flatn(i)
          else
             xi = ONE
          endif

          if (u .gt. ZERO) then
             qxm(i+1,n) = q(i,n) + xi*(Ip(i,2,n) - q(i,n))
          else if (u .lt. ZERO) then
             qxm(i+1,n) = q(i,n)
          else
             qxm(i+1,n) = q(i,n) + HALF*xi*(Ip(i,2,n) - q(i,n))
          endif
       enddo

       if (fix_mass_flux_hi) qxp(ihi+1,n) = q(ihi+1,n)
       if (fix_mass_flux_lo) qxm(ilo,n) = q(ilo-1,n)

    enddo

    deallocate(Ip,Im)
    if (ppm_trace_sources == 1) then
       deallocate(Ip_src,Im_src)
    endif

  end subroutine trace_ppm_rad

end module trace_ppm_rad_module
