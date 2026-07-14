## Geometry

$$
\mathcal{D} =
\left\{ (x,y,z) :
\frac{x^2+y^2}{a^2} + \frac{z^2}{c^2} \le 1,\quad z \ge 0
\right\},
\qquad
\frac{c}{a} \ll 1
$$

## Hard-wall confinement

$$
V_{\text{conf}}(x,y,z) =
\begin{cases}
0, & (x,y,z)\in \mathcal{D} \\
\infty, & \text{otherwise}
\end{cases}
$$
$$
\Psi|_{\partial \mathcal{D}} = 0
$$

## Magnetic field

$$
\mathbf B = B \hat{\mathbf z}
$$

Symmetric gauge
$$
\mathbf A =
\frac{B}{2}(-y,x,0)
$$

## Effective-mass Hamiltonian

$$
H_0 =
\frac{1}{2m^*}
\left(
\mathbf p + q\mathbf A
\right)^2
+
V_{\text{conf}}(x,y,z)
$$

## Fast $z$ motion

At fixed $r = \sqrt{x^2+y^2}$
$$
z_{\max}(r)
=
c\sqrt{1-\frac{r^2}{a^2}}
$$

Longitudinal Hamiltonian
$$
H_z(r)
=
-\frac{\hbar^2}{2m^*}\frac{\partial^2}{\partial z^2}
+
V_{\text{hw}}(z;z_{\max}(r))
$$
$$
H_z(r)\phi_\nu
=
\varepsilon_\nu(r)\phi_\nu
$$

Hard-wall eigenfunctions
$$
\phi_\nu(z;r)
=
\sqrt{\frac{2}{z_{\max}}}
\sin
\!\left(
\frac{\nu\pi z}{z_{\max}}
\right)
$$

Vertical confinement scale
$$
\varepsilon_z
=
\frac{\hbar^2\pi^2}{2m^*c^2}
$$

Energy levels
$$
\varepsilon_\nu(r)
=
\nu^2\varepsilon_z
\frac{1}{1-r^2/a^2}
$$

Expansion for $r\ll a$
$$
\varepsilon_\nu(r)
\approx
\nu^2\varepsilon_z
\left(
1+\frac{r^2}{a^2}
\right)
$$

## Effective planar Hamiltonian

$$
H^{(\nu)}
=
\frac{p_x^2+p_y^2}{2m^*}
+
\frac{\omega_c}{2}L_z
+
\left(
\frac{m^*\omega_c^2}{8}
+
\frac{\nu^2\varepsilon_z}{a^2}
\right) r^2
$$

Angular momentum operator
$$
L_z = x p_y - y p_x
$$

Cyclotron frequency
$$
\omega_c = \frac{qB}{m^*}
$$

## Planar spectrum

$$
\omega_\nu
=
\sqrt{
\frac{2\nu^2\varepsilon_z}{m^*a^2}
+
\frac{\omega_c^2}{4}
}
$$

Energy spectrum
$$
E_{\nu,n,m}
=
\nu^2\varepsilon_z
+
\hbar\omega_\nu(2n+|m|+1)
-
\frac{\hbar\omega_c}{2}m
$$

Planar eigenfunctions
$$
\psi_{n,m}(r,\varphi)
=
\mathcal N
r^{|m|}
e^{-r^2/(2\ell_\nu^2)}
L_n^{|m|}
\!\left(\frac{r^2}{\ell_\nu^2}\right)
e^{im\varphi}
$$

Oscillator length
$$
\ell_\nu
=
\sqrt{\frac{\hbar}{m^*\omega_\nu}}
$$

Total wave function
$$
\Psi_{\nu,n,m}(z,r,\varphi)
=
\phi_\nu(z;r)\psi_{n,m}(r,\varphi)
$$
