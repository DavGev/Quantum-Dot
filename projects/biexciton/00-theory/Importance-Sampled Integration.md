The notation is described in [[Notation and Coordinates]]. The integrals are those of [[Biexciton]]; the single-particle states and the oscillator length come from [[Single Particle]].

## Scaled axial coordinate

Per particle, at fixed $r$
$$
z = u\,z_{\max}(r),
\qquad
u\in(0,1)
$$

$$
dz = z_{\max}(r)\,du
$$

Axial density in $u$, with the $z$-Jacobian absorbed
$$
|\phi_\nu|^2\,z_{\max}
=
2\sin^2(\nu\pi u)
$$

## The sampling problem

Every matrix element has the form
$$
\mathcal I
=
\int
\Psi_0^2\,G^2\,
\{P^2,\,PQ,\,\dots\}\,
X
\,d\tau,
\qquad
d\tau_i = r_i\,dr_i\,du_i\,d\phi_i
$$

The orbital densities confine each radial coordinate to $r\lesssim\ell$, while the integration box extends to
$$
R = 0.9\,a \gg \ell
$$
A uniform (quasi-)Monte-Carlo rule therefore places only a fraction $\sim(\ell/R)^8$ of its points inside the support of the integrand. The estimates converge hopelessly slowly, and exact identities such as
$$
\int \Psi_0^2G^2P^2\,d\tau
=
\int \Psi_0^2G^2Q^2\,d\tau
$$
fail by $O(1)$ at any affordable budget.

## Reference density

Factorized single-particle reference, one factor per particle, built from the ground orbital ($\nu=1$, $n=m=0$, $B=0$)
$$
p_{\mathrm{ref}}(r,u)
=
p_r(r)\,p_u(u)
$$

$$
p_r(r)
=
\frac{1}{C}\,
\frac{2r}{\ell^2}\,
e^{-r^2/\ell^2},
\qquad
0<r<R
$$

$$
C = 1-e^{-R^2/\ell^2}
$$

$$
p_u(u)
=
2\sin^2(\pi u)
$$

## Radial map

CDF
$$
v(r)
=
\frac{1-e^{-r^2/\ell^2}}{C}
$$

Inverse (analytic)
$$
r(v)
=
\ell\sqrt{-\ln(1-Cv)}
$$

Jacobian
$$
\frac{dr}{dv}
=
\frac{1}{p_r(r)}
=
\frac{C\,\ell^2}{2r}\,
e^{r^2/\ell^2}
$$

## Axial map

CDF
$$
x(u)
=
u-\frac{\sin(2\pi u)}{2\pi}
$$

Monotone on $(0,1)$; the inverse $u(x)$ has no closed form and is tabulated once numerically.

Jacobian
$$
\frac{du}{dx}
=
\frac{1}{p_u(u)}
=
\frac{1}{2\sin^2(\pi u)}
$$

## Transformed integral

With one $(v_i,x_i)$ pair per particle, all uniform on the unit cube,
$$
\mathcal I
=
\int_{(0,1)^8}
d^4v\,d^4x
\int
d\phi_1\,d\phi_2\,d\phi_b\;
f\big(r_i(v_i),u_i(x_i),\phi\big)
\prod_{i}
\frac{dr_i}{dv_i}
\frac{du_i}{dx_i}
$$
where $f$ is the original integrand, Jacobians $r_i$ included.

## Pointwise cancellation

For a particle in the ground orbital the reference cancels its density exactly
$$
2\sin^2(\pi u)\,
\frac{du}{dx}
=
1
$$

$$
|\psi_{0,0}|^2\,
r\,
\frac{dr}{dv}
=
\mathrm{const}
$$

For excited orbitals the residue is bounded
$$
\frac{\sin^2(\nu\pi u)}{\sin^2(\pi u)}
\le
\nu^2
$$

$$
r^{2|m|}
\left[
L_n^{|m|}\!\left(\frac{r^2}{\ell^2}\right)
\right]^2
\quad
\text{bounded on }(0,R)
$$

The transformed integrand is $O(1)$ up to the Jastrow factors $G^2P^2$, $G^2PQ$, $\dots$, which remain for the adaptive rule to resolve.

## Error diagnostic

The identity $\int\Psi_0^2G^2P^2 = \int\Psi_0^2G^2Q^2$ is exact (it follows from the pointwise symmetries of $|\Psi_0|^2$, see [[Biexciton]]), so the relative spread of the two numerically evaluated halves is a lower bound on the quadrature error at the given $(\alpha,\beta,\gamma,\delta)$
$$
\epsilon
\ge
\frac{2\,|N_{P^2}-N_{Q^2}|}{N_{P^2}+N_{Q^2}}
$$

Implemented in `mixed-integrals.wl`: the transformed rule is `bxIntegrateIS` (default, flag `bxImportanceSampling`), the diagnostic is `bxQuadratureCheck`.
