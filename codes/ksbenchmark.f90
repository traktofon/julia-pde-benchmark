 module KS
   implicit none
   save
   integer,          parameter :: Nx = 8192
   double precision, parameter :: dt = 1d0/16d0
   double precision, parameter :: T  = 200d0
   double precision, parameter :: pi = 3.14159265358979323846d0
   double precision, parameter :: Lx = (pi/16d0)*Nx
 end module KS

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
double precision function mynorm(u,Nx)
    double complex, intent(in) :: u(0:Nx-1)
    double precision :: s
    integer n;

    s = 0.0d0;
    do n = 0, Nx-1 
       s = s + (abs(u(n)))**2
    end do
    mynorm = sqrt(s/Nx)
 end function mynorm


!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 program main
   use KS
   implicit none
   integer :: i,Nt,r, Nruns=10, skip=1
   real :: tstart, tend, avgtime
   double precision :: unorm
   double precision :: x(0:Nx-1)
   double complex   :: u(0:Nx-1)
   double precision :: tmp
   double precision :: s

   !allocate(x(0:Nx-1))
   !allocate(u(0:Nx-1))
   
   Nt = floor(T/dt)
   x = Lx * (/(i,i=0,Nx-1)/) / dble(Nx)
   u = cos(x) + 0.2d0*sin(x/8d0) + 0.01d0*cos(x/16d0)

   s = 0.0d0
   do i = 0, Nx-1 
       s = s + (abs(u(i)))**2
   end do 
   unorm = sqrt(s/Nx)
   !print*, 'norm(u0) = ', unorm


   avgtime = 0.
   do r = 1, Nruns
      call cpu_time(tstart)
      call ksintegrate(Nt, u)
      call cpu_time(tend)
      if(r>skip)  avgtime = avgtime + tend-tstart
   end do
   avgtime = avgtime/(Nruns-skip)

   print*, 'avgtime (seconds) = ', avgtime

   s = 0.0d0
   do i = 0, Nx-1 
       s = s + (abs(u(i)))**2
   end do 
   unorm = sqrt(s/Nx)
   !print*, 'norm(u0) = ', unorm


   open(10, status='unknown', file='u.dat')
   write(10,'(2e20.12)') (x(i),u(i), i=0,Nx-1)
   close(10)

 end program main

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 subroutine ksintegrate(Nt, u)
   use KS
   implicit none
   integer,          intent(in)    :: Nt
   double complex,   intent(inout) :: u(0:Nx-1)
   double precision :: dt2, dt32, Nx_inv
   double precision :: A(0:Nx-1), B(0:Nx-1), L(0:Nx-1), kx(0:Nx-1)
   double complex   :: alpha(0:Nx-1), G(0:Nx-1), Nn(0:Nx-1), Nn1(0:Nx-1)
   double complex, save :: u_(0:Nx-1), uu(0:Nx-1) 
   double complex, save :: us(0:Nx-1), uus(0:Nx-1)
   logical, save :: planned=.false.
   integer*8 :: plan_u2us, plan_us2u, plan_uu2uus, plan_uus2uu
   integer :: n, fftw_patient=32, fftw_estimate=64, fftw_forward=-1, fftw_backward=1

   if(.not.planned) then
      call dfftw_plan_dft_1d(plan_u2us, Nx, u_, us, fftw_forward, fftw_estimate)
      call dfftw_plan_dft_1d(plan_us2u, Nx, us, u_, fftw_backward, fftw_estimate)
      call dfftw_plan_dft_1d(plan_uu2uus, Nx, uu, uus, fftw_forward, fftw_estimate)
      call dfftw_plan_dft_1d(plan_uus2uu, Nx, uus, uu, fftw_backward, fftw_estimate)
      planned = .true.
   end if

   do n = 0, Nx/2-1
      kx(n) = n
   end do
   kx(Nx/2) = 0d0
   do n = Nx/2+1, Nx-1
      kx(n) = -Nx + n;
   end do
   alpha = (2d0*pi/Lx)*kx
   L = alpha**2 - alpha**4
   G = -0.5d0*dcmplx(0d0,1d0)*alpha
   
   Nx_inv = 1d0/Nx
   dt2  = dt/2d0
   dt32 = 3d0*dt/2d0
   A = 1d0 + dt2*L
   B = 1d0/(1d0 - dt2*L)

   uu = u*u
   call dfftw_execute(plan_uu2uus)
   Nn  = G*uus
   Nn1 = Nn

   u_ = u
   call dfftw_execute(plan_u2us)

   do n = 1, Nt
      Nn1 = Nn
      call dfftw_execute(plan_us2u)
      u_ = u_ * Nx_inv
      uu = u_*u_
      call dfftw_execute(plan_uu2uus)
      Nn = G*uus
      us = B * (A*us + dt32*Nn - dt2*Nn1)
   end do

   call dfftw_execute(plan_us2u)
   u = u_ * Nx_inv

 end subroutine ksintegrate
