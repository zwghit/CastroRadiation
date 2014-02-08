! :::
! ::: ------------------------------------------------------------------
! :::

      subroutine ca_compute_c_v(lo, hi, &
           cv, cv_l1, cv_l2, cv_l3, cv_h1, cv_h2, cv_h3, &
           ye, ye_l1, ye_l2, ye_l3, ye_h1, ye_h2, ye_h3, &
           temp, temp_l1, temp_l2, temp_l3, temp_h1, temp_h2, temp_h3, &
           state, state_l1, state_l2, state_l3, state_h1, state_h2, state_h3)

        use eos_module
        use network, only : nspec, naux
        use meth_params_module, only : NVAR, URHO, UFS, UFX

        implicit none
        integer, intent(in)           :: lo(3), hi(3)
        integer, intent(in)           :: cv_l1, cv_l2, cv_l3, cv_h1, cv_h2, cv_h3
        integer, intent(in)           :: ye_l1, ye_l2, ye_l3, ye_h1, ye_h2, ye_h3
        integer, intent(in)           :: temp_l1, temp_l2, temp_l3, temp_h1, temp_h2, temp_h3
        integer, intent(in)           :: state_l1, state_l2, state_l3, state_h1, state_h2, state_h3
        double precision, intent(out) :: cv(cv_l1:cv_h1,cv_l2:cv_h2,cv_l3:cv_h3)
        double precision, intent(in)  :: ye(ye_l1:ye_h1,ye_l2:ye_h2,ye_l3:ye_h3)
        double precision, intent(in)  :: temp(temp_l1:temp_h1,temp_l2:temp_h2,temp_l3:temp_h3)
        double precision, intent(in)  :: state(state_l1:state_h1,state_l2:state_h2,state_l3:state_h3,NVAR)

        integer           :: i, j, k
        double precision :: rho, rhoInv
        double precision :: xn(nspec+naux)

        !$OMP PARALLEL DO PRIVATE(i,j,k,rho,rhoInv,xn)
        do k = lo(3), hi(3)
           do j = lo(2), hi(2)
              do i = lo(1), hi(1)

                 rho = state(i,j,k,URHO)
                 rhoInv = 1.d0 / rho
                 xn(1:nspec) = state(i,j,k,UFS:UFS+nspec-1) * rhoInv

                 if (naux > 0) then
                    xn(nspec+1:nspec+naux)  = state(i,j,k,UFX:UFX+naux-1) * rhoInv
                    xn(nspec+1)  = ye(i,j,k)
                 end if

                 call eos_get_cv(cv(i,j,k), rho, temp(i,j,k), xn)

              enddo
           enddo
        enddo
        !$OMP END PARALLEL DO

      end subroutine ca_compute_c_v

! :::
! ::: ------------------------------------------------------------------
! :::
! :::

      subroutine ca_get_rhoe(lo, hi, &
           rhoe, rhoe_l1, rhoe_l2, rhoe_l3, rhoe_h1, rhoe_h2, rhoe_h3, &
           temp, temp_l1, temp_l2, temp_l3, temp_h1, temp_h2, temp_h3, &
           ye, ye_l1, ye_l2, ye_l3, ye_h1, ye_h2, ye_h3, &
           state, state_l1, state_l2, state_l3, state_h1, state_h2, state_h3)

        use eos_module
        use network, only : nspec, naux
        use meth_params_module, only : NVAR, URHO, UMX, UMY, &
             UFS, UFX, small_temp, allow_negative_energy

        implicit none
        integer         , intent(in) :: lo(3), hi(3)
        integer         , intent(in) :: rhoe_l1, rhoe_l2, rhoe_l3, rhoe_h1, rhoe_h2, rhoe_h3
        integer         , intent(in) :: temp_l1, temp_l2, temp_l3, temp_h1, temp_h2, temp_h3
        integer         , intent(in) :: ye_l1, ye_l2, ye_l3, ye_h1, ye_h2, ye_h3
        integer         , intent(in) :: state_l1, state_l2, state_l3, state_h1, state_h2, state_h3
        double precision, intent(in) :: temp(temp_l1:temp_h1,temp_l2:temp_h2,temp_l3:temp_h3)
        double precision, intent(in) :: ye(ye_l1:ye_h1,ye_l2:ye_h2,ye_l3:ye_h3)
        double precision, intent(in) :: state(state_l1:state_h1,state_l2:state_h2,state_l3:state_h3,NVAR)
        double precision, intent(inout) :: rhoe(rhoe_l1:rhoe_h1,rhoe_l2:rhoe_h2,rhoe_l3:rhoe_h3)

        integer          :: i, j, k
        double precision :: dummy_pres
        double precision :: rho, rhoInv
        double precision :: xn(nspec+naux)

        !$OMP PARALLEL DO PRIVATE(i,j,k,rho,rhoInv,xn,dummy_pres)
        do k = lo(3), hi(3)
           do j = lo(2), hi(2)
              do i = lo(1), hi(1)

                 rho = state(i,j,k,URHO)
                 rhoInv = 1.d0 / rho
                 xn(1:nspec) = state(i,j,k,UFS:UFS+nspec-1) * rhoInv

                 if (naux > 0) then
                    xn(nspec+1:nspec+naux)  = state(i,j,k,UFX:UFX+naux-1) * rhoInv
                    xn(nspec+1)  = ye(i,j,k)
                 end if

                 call eos_given_RTX(rhoe(i,j,k), dummy_pres, rho, temp(i,j,k), xn)

                 rhoe(i,j,k) = rho * rhoe(i,j,k)

              enddo
           enddo
        enddo
        !$OMP END PARALLEL DO

      end subroutine ca_get_rhoe

! :::
! ::: ------------------------------------------------------------------
! :::
! :::

! temp enters as rhoe
      subroutine ca_compute_temp_for_rad(lo, hi, &
           temp, temp_l1, temp_l2, temp_l3, temp_h1, temp_h2, temp_h3, &
           ye, ye_l1, ye_l2, ye_l3, ye_h1, ye_h2, ye_h3, &
           tempGuess, tg_l1, tg_l2, tg_l3, tg_h1, tg_h2, tg_h3, &
           state, state_l1, state_l2, state_l3, state_h1, state_h2, state_h3)

        use network, only: nspec, naux
        use eos_module
        use meth_params_module, only : NVAR, URHO, UMX, UMY, UFS, UFX, &
             small_temp, allow_negative_energy

        implicit none
        integer         , intent(in   ) :: lo(3), hi(3)
        integer         , intent(in   ) :: temp_l1, temp_l2, temp_l3, temp_h1, temp_h2, temp_h3
        integer         , intent(in   ) :: ye_l1, ye_l2, ye_l3, ye_h1, ye_h2, ye_h3
        integer         , intent(in   ) :: tg_l1, tg_l2, tg_l3, tg_h1, tg_h2, tg_h3
        integer         , intent(in   ) :: state_l1, state_l2, state_l3, state_h1, state_h2, state_h3
        double precision, intent(in   ) :: state(state_l1:state_h1,state_l2:state_h2,state_l3:state_h3,NVAR)
        double precision, intent(in   ) :: ye(ye_l1:ye_h1,ye_l2:ye_h2,ye_l3:ye_h3)
        double precision, intent(in   ) :: tempGuess(tg_l1:tg_h1,tg_l2:tg_h2,tg_l3:tg_h3)
        double precision, intent(inout) :: temp(temp_l1:temp_h1,temp_l2:temp_h2,temp_l3:temp_h3)

        integer          :: i, j, k
        double precision :: u, v
        double precision :: rhoInv, e, xn(nspec+naux)
        double precision :: dummy_gam, dummy_pres, dummy_c, dummy_dpdr, dummy_dpde

        !$OMP PARALLEL DO PRIVATE(i,j,k,rhoInv,u,v,e,xn,dummy_gam,dummy_pres,dummy_c,dummy_dpdr,dummy_dpde)
        do k = lo(3), hi(3)
           do j = lo(2), hi(2)
              do i = lo(1), hi(1)

                 rhoInv = 1.d0 / state(i,j,k,URHO)
                 u = state(i,j,k,UMX) * rhoInv
                 v = state(i,j,k,UMY) * rhoInv
!                 e = temp(i,j,k)*rhoInv - 0.5d0*(u**2+v**2)
                 e = temp(i,j,k)*rhoInv
                 xn(1:nspec) = state(i,j,k,UFS:UFS+nspec-1)*rhoInv

                 if (naux > 0) then
                    xn(nspec+1:nspec+naux)  = state(i,j,k,UFX:UFX+naux-1) * rhoInv
                    xn(nspec+1)  = ye(i,j,k)
                 end if

                 if(allow_negative_energy.eq.0 .and. e.le.0.d0) then
                    temp(i,j,k) = small_temp
                 else
                    ! set initial guess of temperature
                    temp(i,j,k) = tempGuess(i,j,k)

                    call eos_given_ReX(dummy_gam, dummy_pres, dummy_c, temp(i,j,k), &
                         dummy_dpdr, dummy_dpde, state(i,j,k,URHO), e, xn)

                 endif

                 if(temp(i,j,k).lt.0.d0) then
                    print*,'negative temp in compute_temp_for_rad ', &
                         temp(i,j,k)
                    call bl_error("Error:: Compute_cv_3d.f90 :: ca_compute_temp_for_rad")
                 endif

              enddo
           enddo
        enddo
        !$OMP END PARALLEL DO

      end subroutine ca_compute_temp_for_rad


      subroutine ca_compute_temp_given_reye(lo, hi, &
           temp , temp_l1, temp_l2, temp_l3, temp_h1, temp_h2, temp_h3, &
           rhoe ,   re_l1,   re_l2,   re_l3,   re_h1,   re_h2,   re_h3, &
           ye   ,   ye_l1,   ye_l2,   ye_l3,   ye_h1,   ye_h2,   ye_h3, &
           state,state_l1,state_l2,state_l3,state_h1,state_h2,state_h3)

        use network, only: nspec, naux
        use eos_module
        use meth_params_module, only : NVAR, URHO, UMX, UMY, UFS, UFX, &
             small_temp, allow_negative_energy

        implicit none
        integer         , intent(in   ) :: lo(3), hi(3)
        integer         , intent(in   ) ::  temp_l1, temp_l2, temp_l3, temp_h1, temp_h2, temp_h3
        integer         , intent(in   ) ::    re_l1,   re_l2,   re_l3,   re_h1,   re_h2,   re_h3
        integer         , intent(in   ) ::    ye_l1,   ye_l2,   ye_l3,   ye_h1,   ye_h2,   ye_h3
        integer         , intent(in   ) :: state_l1,state_l2,state_l3,state_h1,state_h2,state_h3
        double precision, intent(in   ) :: state(state_l1:state_h1,state_l2:state_h2,state_l3:state_h3,NVAR)
        double precision, intent(in   ) ::  rhoe(   re_l1:   re_h1,   re_l2:   re_h2,   re_l3:   re_h3)
        double precision, intent(in   ) ::    ye(   ye_l1:   ye_h1,   ye_l2:   ye_h2,   ye_l3:   ye_h3)
        double precision, intent(inout) ::  temp( temp_l1: temp_h1, temp_l2: temp_h2, temp_l3: temp_h3)

        integer          :: i, j, k
        double precision :: rhoInv, e, xn(nspec+naux)
        double precision :: dummy_gam, dummy_pres, dummy_c, dummy_dpdr, dummy_dpde

        !$OMP PARALLEL DO PRIVATE(i,j,k,rhoInv,e,xn,dummy_gam, dummy_pres, dummy_c, dummy_dpdr, dummy_dpde)
        do k = lo(3), hi(3)
        do j = lo(2), hi(2)
        do i = lo(1), hi(1)

           rhoInv = 1.d0 / state(i,j,k,URHO)
           e = rhoe(i,j,k)*rhoInv 
           xn(1:nspec) = state(i,j,k,UFS:UFS+nspec-1)*rhoInv

           if (naux > 0) then
              xn(nspec+1:nspec+naux)  = state(i,j,k,UFX:UFX+naux-1) * rhoInv
              xn(nspec+1)  = ye(i,j,k)
           end if

           if(allow_negative_energy.eq.0 .and. e.le.0.d0) then
              temp(i,j,k) = small_temp
           else

              call eos_given_ReX(dummy_gam, dummy_pres, dummy_c, temp(i,j,k), &
                   dummy_dpdr, dummy_dpde, state(i,j,k,URHO), e, xn)

           endif

           if(temp(i,j,k).lt.0.d0) then
              print*,'negative temp in compute_temp_given_reye ', temp(i,j,k)
              call bl_error("Error:: Compute_cv_3d.f90 :: ca_compute_temp_given_reye")
           endif

        enddo
        enddo
        enddo
        !$OMP END PARALLEL DO
      end subroutine ca_compute_temp_given_reye

      subroutine ca_compute_reye_given_ty(lo, hi, &
           rhoe, re_l1, re_l2, re_l3, re_h1, re_h2, re_h3, &
           rhoY, rY_l1, rY_l2, rY_l3, rY_h1, rY_h2, rY_h3, &
           temp, temp_l1, temp_l2, temp_l3, temp_h1, temp_h2, temp_h3, &
           ye, ye_l1, ye_l2, ye_l3, ye_h1, ye_h2, ye_h3, &
           state, state_l1, state_l2, state_l3, state_h1, state_h2, state_h3)

        use network, only: nspec, naux
        use eos_module, only : eos_given_RTX
        use meth_params_module, only : NVAR, URHO, UFS, UFX

        implicit none
        integer         , intent(in   ) :: lo(3), hi(3)
        integer         , intent(in   ) :: re_l1, re_h1, re_l2, re_h2, re_l3, re_h3
        integer         , intent(in   ) :: rY_l1, rY_h1, rY_l2, rY_h2, rY_l3, rY_h3
        integer         , intent(in   ) :: temp_l1, temp_h1, temp_l2, temp_h2, temp_l3, temp_h3
        integer         , intent(in   ) :: ye_l1, ye_h1, ye_l2, ye_h2, ye_l3, ye_h3
        integer         , intent(in   ) :: state_l1, state_h1, state_l2, state_h2, state_l3, state_h3
        double precision, intent(in   ) :: state(state_l1:state_h1,state_l2:state_h2,state_l3:state_h3,NVAR)
        double precision, intent(out  ) :: rhoe(re_l1:re_h1,re_l2:re_h2,re_l3:re_h3)
        double precision, intent(inout) :: rhoY(rY_l1:rY_h1,rY_l2:rY_h2,rY_l3:rY_h3)
        double precision, intent(in   ) :: ye(ye_l1:ye_h1,ye_l2:ye_h2,ye_l3:ye_h3)
        double precision, intent(in   ) :: temp(temp_l1:temp_h1,temp_l2:temp_h2,temp_l3:temp_h3)

        integer          :: i, j, k
        double precision :: dummy_pres
        double precision :: rho, rhoInv
        double precision :: xn(nspec+naux)

        !$OMP PARALLEL DO PRIVATE(i, j, k, dummy_pres, rho, rhoInv, xn)
        do k = lo(3), hi(3)
        do j = lo(2), hi(2)
        do i = lo(1), hi(1)

           rho = state(i,j,k,URHO)
           rhoInv = 1.d0 / rho
           xn(1:nspec) = state(i,j,k,UFS:UFS+nspec-1)*rhoInv

           if (naux > 0) then
              xn(nspec+1:nspec+naux)  = state(i,j,k,UFX:UFX+naux-1) * rhoInv
              xn(nspec+1)  = ye(i,j,k)
              rhoY(i,j,k) = rho*ye(i,j,k)
           end if

           call eos_given_RTX(rhoe(i,j,k), dummy_pres, rho, temp(i,j,k), xn)

           rhoe(i,j,k) = rho * rhoe(i,j,k)

        enddo
        enddo
        enddo
        !$OMP END PARALLEL DO
      end subroutine ca_compute_reye_given_ty



subroutine ca_compute_temp_given_rhoe(lo,hi,  &
     temp,  temp_l1, temp_l2, temp_l3, temp_h1, temp_h2, temp_h3, &
     state,state_l1,state_l2,state_l3,state_h1,state_h2,state_h3)

  use network, only : nspec, naux
  use eos_module
  use meth_params_module, only : NVAR, URHO, UFS, UFX

  implicit none
  integer         , intent(in) :: lo(3),hi(3)
  integer         , intent(in) :: temp_l1, temp_l2, temp_l3, temp_h1, temp_h2, temp_h3, &
                                 state_l1,state_l2,state_l3,state_h1,state_h2,state_h3
  double precision, intent(in) :: state(state_l1:state_h1,state_l2:state_h2,state_l3:state_h3,NVAR)
  double precision, intent(inout) :: temp(temp_l1:temp_h1,temp_l2:temp_h2,temp_l3:temp_h3) ! temp contains rhoe as input

  integer :: i, j, k
  integer          :: pt_index(3)
  double precision :: eint,xn(nspec+naux)
  double precision :: dummy_gam,dummy_pres,dummy_c,dummy_dpdr,dummy_dpde

  !$OMP PARALLEL DO PRIVATE(i,j,k,pt_index,eint,xn,dummy_gam,dummy_pres,dummy_c,dummy_dpdr,dummy_dpde)
  do k = lo(3),hi(3)
  do j = lo(2),hi(2)
  do i = lo(1),hi(1)
     
     xn(1:nspec)  = state(i,j,k,UFS:UFS+nspec-1) / state(i,j,k,URHO)
     if (naux > 0) &
          xn(nspec+1:nspec+naux) = state(i,j,k,UFX:UFX+naux-1) / state(i,j,k,URHO)
     
     eint = temp(i,j,k) / state(i,j,k,URHO) 
     
     pt_index(1) = i
     pt_index(2) = j
     pt_index(3) = k
     
     call eos_given_ReX(dummy_gam, dummy_pres , dummy_c, temp(i,j,k), &
          dummy_dpdr, dummy_dpde, state(i,j,k,URHO), eint, xn, pt_index)
     
  enddo
  enddo
  enddo
  !$OMP END PARALLEL DO

end subroutine ca_compute_temp_given_rhoe


subroutine ca_compute_temp_given_cv(lo,hi,  &
     temp,  temp_l1, temp_l2, temp_l3, temp_h1, temp_h2, temp_h3, &
     state,state_l1,state_l2,state_l3,state_h1,state_h2,state_h3, &
     const_c_v, c_v_exp_m, c_v_exp_n)

  use meth_params_module, only : NVAR, URHO

  implicit none
  integer         , intent(in) :: lo(3),hi(3)
  integer         , intent(in) :: temp_l1, temp_l2, temp_l3, temp_h1, temp_h2, temp_h3, &
                                 state_l1,state_l2,state_l3,state_h1,state_h2,state_h3
  double precision, intent(in) :: state(state_l1:state_h1,state_l2:state_h2,state_l3:state_h3,NVAR)
  double precision, intent(inout) :: temp(temp_l1:temp_h1,temp_l2:temp_h2,temp_l3:temp_h3) ! temp contains rhoe as input
  double precision, intent(in) :: const_c_v, c_v_exp_m, c_v_exp_n

  integer :: i, j, k
  double precision :: ex, alpha, rhoal, teff

  ex = 1.d0 / (1.d0 - c_v_exp_n)

  !$OMP PARALLEL DO PRIVATE(i,j,k,alpha,rhoal,teff)
  do k=lo(3), hi(3)
     do j=lo(2), hi(2)
        do i=lo(1), hi(1)
           if (c_v_exp_m .eq. 0.d0) then
              alpha = const_c_v
           else
              alpha = const_c_v * state(i,j,k,URHO) ** c_v_exp_m
           endif
           rhoal = state(i,j,k,URHO) * alpha + 1.d-50
           if (c_v_exp_n .eq. 0.d0) then
              temp(i,j,k) = temp(i,j,k) / rhoal
           else
              teff = max(temp(i,j,k), 1.d-50)
              temp(i,j,k) = ((1.d0 - c_v_exp_n) * teff / rhoal) ** ex
           endif
        end do
     end do
  end do
  !$OMP END PARALLEL DO

end subroutine ca_compute_temp_given_cv


subroutine reset_eint_compute_temp( lo, hi, &
     state, s_l1, s_l2, s_l3, s_h1, s_h2, s_h3, &
     resetei, rela, abso )

  use network, only: nspec, naux
  use eos_module
  use meth_params_module, only : NVAR, UEDEN, UEINT, URHO, UMX, UMY, UMZ, UTEMP, UFS, UFX, &
       allow_negative_energy

  implicit none
  integer, intent(in) :: lo(3), hi(3), resetei
  integer, intent(in) :: s_l1, s_h1, s_l2, s_h2, s_l3, s_h3
  double precision, intent(inout) :: state(s_l1:s_h1,s_l2:s_h2,s_l3:s_h3,NVAR)
  double precision, intent(inout) :: rela, abso

  integer :: i, j, k
  double precision :: xn(nspec+naux)
  double precision :: rhoInv,  ek, e1, e2, T1, T2, diff, rdiff
  double precision :: dummy_gam, dummy_pres, dummy_c, dummy_dpdr, dummy_dpde

  !$OMP PARALLEL DO PRIVATE(i,j,k,xn,rhoInv,ek,e1,e2,T1,T2,diff,rdiff) &
  !$OMP PRIVATE(dummy_gam, dummy_pres, dummy_c, dummy_dpdr, dummy_dpde)
  do k = lo(3), hi(3)
  do j = lo(2), hi(2)
  do i = lo(1), hi(1)
     rhoInv = 1.d0 / state(i,j,k,URHO)
     xn(1:nspec) = state(i,j,k,UFS:UFS+nspec-1) * rhoInv
     
     if (naux > 0) &
          xn(nspec+1:nspec+naux) = state(i,j,k,UFX:UFX+naux-1) * rhoInv
     
     ek = 0.5d0 * (state(i,j,k,UMX)**2 + state(i,j,k,UMY)**2 &
          + state(i,j,k,UMZ)**2) * rhoInv

     e1 = state(i,j,k,UEINT) * rhoInv
     T1 = state(i,j,k,UTEMP)
     call eos_given_ReX(dummy_gam, dummy_pres, dummy_c, T1, &
          dummy_dpdr, dummy_dpde, state(i,j,k,URHO), e1, xn)

     if (resetei .eq. 0) then

        state(i,j,k,UEDEN) = state(i,j,k,UEINT) + ek
        state(i,j,k,UTEMP) = T1

     else if (allow_negative_energy.eq.0 .and. state(i,j,k,UEINT).le.1.d-4*ek) then
        
        state(i,j,k,UEDEN) = state(i,j,k,UEINT) + ek
        state(i,j,k,UTEMP) = T1

     else

        e2 = (state(i,j,k,UEDEN) - ek) * rhoInv
        T2 = T1
        call eos_given_ReX(dummy_gam, dummy_pres, dummy_c, T2, &
             dummy_dpdr, dummy_dpde, state(i,j,k,URHO), e2, xn)

        diff = abs(T1-T2)
        rdiff = diff/T1
        
        abso = max(diff, abso)
        rela = max(rdiff, rela)
     
        if (rdiff .gt. 0.1d0) then             
           state(i,j,k,UEDEN) = state(i,j,k,UEINT) + ek
           state(i,j,k,UTEMP) = T1
        else
           state(i,j,k,UEINT) = state(i,j,k,UEDEN) - ek
           state(i,j,k,UTEMP) = T2
        end if
        
     end if
  end do
  end do
  end do
  !$OMP END PARALLEL DO

end subroutine reset_eint_compute_temp

