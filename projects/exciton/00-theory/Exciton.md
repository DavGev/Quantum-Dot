Using notation described in [[Notation and Coordinates]] and results form [[Single Particle]].
## Total Hamiltonian

$$
H = H_{\mathrm{sp}} + V_{\mathrm{int}}
$$

$$
H_{\mathrm{sp}} = h_e(1) + h_h(a)
$$

$$
V_{\mathrm{int}} = -\kappa \frac{1}{r_{1a}}
$$

$$
\kappa = \frac{e^2}{4\pi\varepsilon_0\varepsilon_r}
$$

## Uncorrelated state

$$
\Psi_0 = \psi_e(1)\psi_h(a)
$$

$$
H_{\mathrm{sp}}\Psi_0 = E_0 \Psi_0
$$

$$
E_0 = E_e + E_h
$$

## Correlated trial wavefunction

$$
\Psi = \Psi_0 F
$$

$$
F
=
\exp\!\left(-\alpha r_{1a}\right)
$$

Variational parameter
$$
\alpha
$$

## Variational Energy

$$
E
=
\frac{\langle \Psi |H|\Psi\rangle}
{\langle \Psi|\Psi\rangle}
$$

## Decomposition

$$
\langle \Psi |H|\Psi\rangle
=
\langle \Psi_0 F |H_{\mathrm{sp}}|\Psi_0 F\rangle
+
\mathcal V
$$

$$
\mathcal V
=
\int
\Psi_0^2 F^2 V_{\mathrm{int}} \, d\tau
$$
## Single-particle contribution

$$
\langle \Psi_0 F |H_{\mathrm{sp}}|\Psi_0 F\rangle
=
E_0 \mathcal N
+
\mathcal K
$$

$$
\mathcal N
=
\int \Psi_0^2 F^2 \, d\tau
$$

$$
\mathcal K
=
\sum_{i=1,a}
\frac{\hbar^2}{2m_i}
\int
\Psi_0^2
|\nabla_i F|^2
\, d\tau
$$

Therefore
$$
E
=
E_0
+
\frac{
\mathcal K + \mathcal V
}{
\mathcal N
}
$$

# Explicit Terms

## Normalization

$$
\mathcal N
=
\int
\Psi_0^2
e^{-2\alpha r_{1a}}
\, d\tau
$$

## Interaction

$$
\mathcal V
=
-\kappa
\int
\Psi_0^2
\frac{e^{-2\alpha r_{1a}}}{r_{1a}}
\, d\tau
$$

## Kinetic term

$$
\nabla_i F
=
-\alpha F \nabla_i r_{1a}
$$

$$
|\nabla_i F|^2
=
\alpha^2 F^2 |\nabla_i r_{1a}|^2
$$

$$
|\nabla_1 r_{1a}|^2 = 1,
\qquad
|\nabla_a r_{1a}|^2 = 1
$$

$$
\mathcal K
=
\left(
\frac{\hbar^2}{2m_e}
+
\frac{\hbar^2}{2m_h}
\right)
\alpha^2
\mathcal N
$$

## Final Energy

$$
E
=
E_0
+
\left(
\frac{\hbar^2}{2m_e}
+
\frac{\hbar^2}{2m_h}
\right)
\alpha^2
+
\frac{\mathcal V}{\mathcal N}
$$
