The notation is described in [[Notation and Coordinates]]; states from [[Single Particle]], correlated wavefunctions from [[Exciton]] and [[Biexciton]].

## Interband operator

Orbital labels
$$
0\equiv\{1,0,0\},
\qquad
1\equiv\{1,0,+1\},
\qquad
\bar1\equiv\{1,0,-1\}
$$

Electron spin
$$
s_z(\uparrow,\downarrow)=\left(+\frac12,-\frac12\right)
$$

Heavy-hole pseudospin
$$
j_z(\Uparrow,\Downarrow)=\left(+\frac32,-\frac32\right)
$$

Creation operators
$$
c_{\mu s}^\dagger:
\text{ electron in orbital }\mu\text{ with spin }s,
\qquad
h_{\nu j}^\dagger:
\text{ hole in orbital }\nu\text{ with pseudospin }j
$$

For light propagating along $+z$
$$
\hat D_{\sigma^+}^{\dagger}
=
\sum_{\mu\nu}
d_{\mu\nu}\,
c_{\mu\downarrow}^{\dagger}
h_{\nu\Uparrow}^{\dagger}
$$

$$
\hat D_{\sigma^-}^{\dagger}
=
\sum_{\mu\nu}
d_{\mu\nu}\,
c_{\mu\uparrow}^{\dagger}
h_{\nu\Downarrow}^{\dagger}
$$

$$
-\frac12+\frac32=+1,
\qquad
+\frac12-\frac32=-1
$$

General polarization
$$
\boldsymbol\epsilon
=
\epsilon_+\boldsymbol\sigma^+
+
\epsilon_-\boldsymbol\sigma^-,
\qquad
\hat D_{\boldsymbol\epsilon}^{\dagger}
=
\epsilon_+\hat D_{\sigma^+}^{\dagger}
+
\epsilon_-\hat D_{\sigma^-}^{\dagger}
$$

Linear basis
$$
\hat D_H^\dagger
=
\frac{\hat D_{\sigma^+}^\dagger+\hat D_{\sigma^-}^\dagger}{\sqrt2},
\qquad
\hat D_V^\dagger
=
\frac{\hat D_{\sigma^+}^\dagger-\hat D_{\sigma^-}^\dagger}{i\sqrt2}
$$

Emission
$$
\hat D_{\boldsymbol\epsilon}
=
\left(\hat D_{\boldsymbol\epsilon}^{\dagger}\right)^\dagger
$$

## Envelope factor

At pair coincidence
$$
d_{\mu\nu}
=
\mu_{cv}M_{\mu\nu}^{(\mathrm{env})},
\qquad
M_{\mu\nu}^{(\mathrm{env})}
\propto
\int d^3r\,
\psi_{e,\mu}(\mathbf r)\,
\psi_{h,\nu}(\mathbf r)
$$

The dome is axially symmetric; $e^{-\alpha r_{eh}}$, $G$, $P$, and $Q$ depend only on interparticle distances. Hence
$$
L
=
\sum_e m_e+\sum_h m_h
$$

$$
\Delta L=0
$$

Created or annihilated pair
$$
m_e+m_h=0
$$

Therefore
$$
d_{\mu\nu}\ne0
\quad\Longrightarrow\quad
m_\mu+m_\nu=0
$$

$L$-forbidden amplitudes vanish to all orders in correlation.

## Spin factor

Bloch angular momentum
$$
F_z
=
\sum_e s_{z,e}
+
\sum_h j_{z,h}
$$

Total axial angular momentum
$$
J_z=L+F_z
$$

Circular selection rules
$$
\sigma^\pm:
\qquad
\Delta L=0,
\qquad
\Delta F_z=\pm1,
\qquad
\Delta J_z=\pm1
$$

Factorized matrix element
$$
M_{fi}^{(\boldsymbol\epsilon)}
=
M_{fi}^{(\mathrm{env})}
C_{fi}^{(\boldsymbol\epsilon)}
$$

$$
C_{fi}^{(\boldsymbol\epsilon)}
=
\left\langle\chi_f\left|
\epsilon_+c_\downarrow^\dagger h_\Uparrow^\dagger
+
\epsilon_-c_\uparrow^\dagger h_\Downarrow^\dagger
\right|\chi_i\right\rangle
$$

Orbital indices in $C_{fi}$ are fixed by $M_{fi}^{(\mathrm{env})}$.

The present Hamiltonian is spin independent:
$$
H=H_{\mathrm{env}}\otimes I_{\mathrm{spin}}
$$

## Pauli constraint

Electron exchange
$$
P_{12}\Phi_e=\eta_e\Phi_e,
\qquad
P_{12}\chi_e=-\eta_e\chi_e
$$

Hole exchange
$$
P_{ab}\Phi_h=\eta_h\Phi_h,
\qquad
P_{ab}\chi_h=-\eta_h\chi_h
$$

Therefore
$$
\eta=+1
\Longleftrightarrow
\text{spatially symmetric}\otimes\text{spin singlet}
$$

$$
\eta=-1
\Longleftrightarrow
\text{spatially antisymmetric}\otimes\text{spin triplet}
$$

Electron pair
$$
|S_e\rangle
=
\frac{
|\uparrow_0\downarrow_1\rangle
-
|\downarrow_0\uparrow_1\rangle
}{\sqrt2}
$$

$$
|T_e^0\rangle
=
\frac{
|\uparrow_0\downarrow_1\rangle
+
|\downarrow_0\uparrow_1\rangle
}{\sqrt2}
$$

$$
|T_e^{+1}\rangle=|\uparrow_0\uparrow_1\rangle,
\qquad
|T_e^{-1}\rangle=|\downarrow_0\downarrow_1\rangle
$$

Hole pair
$$
|S_h\rangle
=
\frac{
|\Uparrow_0\Downarrow_{\bar1}\rangle
-
|\Downarrow_0\Uparrow_{\bar1}\rangle
}{\sqrt2}
$$

$$
|T_h^0\rangle
=
\frac{
|\Uparrow_0\Downarrow_{\bar1}\rangle
+
|\Downarrow_0\Uparrow_{\bar1}\rangle
}{\sqrt2}
$$

$$
|T_h^{+3}\rangle=|\Uparrow_0\Uparrow_{\bar1}\rangle,
\qquad
|T_h^{-3}\rangle=|\Downarrow_0\Downarrow_{\bar1}\rangle
$$

## $XX0101$ spin manifolds

Before electron-hole exchange
$$
\begin{array}{c|c|c}
(\eta_e,\eta_h) & \text{spin} & \text{multiplicity}\\
\hline
(+,+) & S_eS_h & 1\\
(+,-) & S_eT_h & 3\\
(-,+) & T_eS_h & 3\\
(-,-) & T_eT_h & 9
\end{array}
$$

The calculated
$$
E_{++},
\qquad
E_{+-},
\qquad
E_{-+},
\qquad
E_{--}
$$
are the four spin-manifold energies.

Electron-hole exchange refinement
$$
H_{\mathrm{spin}}^{XX}
=
\sum_{i=1}^{2}
\sum_{\alpha=a,b}
\mathbf s_i\cdot
\mathsf A_{i\alpha}\cdot
\mathbf j_\alpha
$$

$$
H_{\mathrm{eff}}
=
\operatorname{diag}
\left(
E_{++},
E_{+-}I_3,
E_{-+}I_3,
E_{--}I_9
\right)
+
H_{\mathrm{spin}}^{XX}
$$

$$
I_n=\text{$n$-dimensional identity}
$$

$H_{\mathrm{spin}}^{XX}=0$ in the present energy calculation.

## Approximate envelope rules

Matching of $\nu$ and $n$ follows from zeroth-order orthogonality:
$$
\int
\psi_{n_em_e}\,
\psi_{n_hm_h}\,
r\,dr\,d\varphi
\propto
\delta_{m_e,-m_h}\,
\delta_{n_e,n_h}\,
\delta_{\nu_e,\nu_h}
\qquad
(\text{same }\omega)
$$

Correlation can relax $\nu$ and $n$ matching, but not $\Delta L=0$.

## Classification of the low-lying states

Envelope-bright pairs
$$
|X_0\rangle\equiv|00\rangle,
\qquad
|X_1\rangle\equiv|11\rangle
=
e\,\{1,0,1\}\otimes h\,\{1,0,-1\}
$$

Spin-bright components
$$
|X_\mu^+\rangle
=
c_{\mu\downarrow}^\dagger
h_{\bar\mu\Uparrow}^\dagger
|g\rangle,
\qquad
F_z=+1
$$

$$
|X_\mu^-\rangle
=
c_{\mu\uparrow}^\dagger
h_{\bar\mu\Downarrow}^\dagger
|g\rangle,
\qquad
F_z=-1
$$

$$
\mu=0,1,
\qquad
\bar0=0,
\quad
\bar1=-1
$$

Spin-dark components
$$
|X_\mu^{D,+2}\rangle
=
c_{\mu\uparrow}^\dagger
h_{\bar\mu\Uparrow}^\dagger
|g\rangle
$$

$$
|X_\mu^{D,-2}\rangle
=
c_{\mu\downarrow}^\dagger
h_{\bar\mu\Downarrow}^\dagger
|g\rangle
$$

Envelope-dark from $g$
$$
|01\rangle\ (L=+1),
\qquad
|10\rangle\ (L=+1)
$$

$$
\text{envelope-dark }(L\ne0)
\ne
\text{spin-dark }(|F_z|=2)
$$

Two-photon envelope sector
$$
|0000\rangle,
\qquad
|0101\rangle
\equiv
e\,\{0,1\}\otimes h\,\{0,\bar1\},
\qquad
|1111\rangle
$$

Equal-orbital Pauli constraint
$$
|0000\rangle,\ |1111\rangle:
\qquad
\eta_e=\eta_h=+1,
\qquad
S_eS_h
$$

Open-shell state
$$
|0101;\eta_e,\eta_h\rangle,
\qquad
\eta_e,\eta_h\in\{+1,-1\}
$$

## Spin-resolved driving of $XX0101$

Initial state
$$
|X_0^+\rangle
=
c_{0\downarrow}^\dagger
h_{0\Uparrow}^\dagger
|g\rangle
$$

Equal helicities
$$
\hat D_{\sigma^+}^\dagger|X_0^+\rangle
\propto
|T_e^{-1}T_h^{+3}\rangle,
\qquad
F_z=+2,
\qquad
(\eta_e,\eta_h)=(-,-)
$$

Opposite helicities
$$
\hat D_{\sigma^-}^\dagger|X_0^+\rangle
\propto
|\downarrow_0\uparrow_1\rangle_e
|\Uparrow_0\Downarrow_{\bar1}\rangle_h
$$

$$
|\downarrow_0\uparrow_1\rangle_e
=
\frac{|T_e^0\rangle-|S_e\rangle}{\sqrt2}
$$

$$
|\Uparrow_0\Downarrow_{\bar1}\rangle_h
=
\frac{|T_h^0\rangle+|S_h\rangle}{\sqrt2}
$$

Therefore
$$
\hat D_{\sigma^-}^\dagger|X_0^+\rangle
\propto
\frac12
\left(
|T_e^0T_h^0\rangle
+
|T_e^0S_h\rangle
-
|S_eT_h^0\rangle
-
|S_eS_h\rangle
\right)
$$

The second orbital path gives
$$
\hat D_{\sigma^-}^\dagger|X_1^+\rangle
\propto
\frac12
\left(
|T_e^0T_h^0\rangle
-
|T_e^0S_h\rangle
+
|S_eT_h^0\rangle
-
|S_eS_h\rangle
\right)
$$

In the ordered basis
$$
\mathcal B_0
=
\left(
S_eS_h,\,
S_eT_h^0,\,
T_e^0S_h,\,
T_e^0T_h^0
\right)
$$

spin coefficients
$$
\mathbf C_{X_0}^{(\sigma^+,\sigma^-)}
=
\frac12(-1,-1,+1,+1)
$$

$$
\mathbf C_{X_1}^{(\sigma^+,\sigma^-)}
=
\frac12(-1,+1,-1,+1)
$$

Hence
$$
\begin{array}{c|c}
\text{manifold} & \text{relative sign of }X_0,X_1\text{ paths}\\
\hline
S_eS_h & +\\
S_eT_h & -\\
T_eS_h & -\\
T_eT_h & +
\end{array}
$$

The opposite initial helicity follows by
$$
\uparrow\leftrightarrow\downarrow,
\qquad
\Uparrow\leftrightarrow\Downarrow,
\qquad
\sigma^+\leftrightarrow\sigma^-
$$

## Polarization-accessible spin sectors

From spin-bright excitons
$$
F_z(X_B)=\pm1
\quad\xrightarrow{\ \sigma^\pm\ }\quad
F_z(XX)=0,\pm2
$$

From spin-dark excitons
$$
F_z(X_D)=\pm2
\quad\xrightarrow{\ \sigma^\pm\ }\quad
F_z(XX)=\pm1,\pm3
$$

Triplet-triplet endpoints
$$
T_eT_h,\quad F_z=\pm4:
\qquad
\text{one-photon dark}
$$

Two-photon polarization classes
$$
\sigma^\pm\sigma^\pm
\longrightarrow
T_eT_h,\quad F_z=\pm2
$$

$$
\sigma^\pm\sigma^\mp
\longrightarrow
\left\{
S_eS_h,\,
S_eT_h^0,\,
T_e^0S_h,\,
T_e^0T_h^0
\right\},
\quad
F_z=0
$$

## Optical diamond

$$
g
\leftrightarrow
X_0
\leftrightarrow
\left\{
XX0000,\,
XX0101_{\eta_e\eta_h}
\right\}
$$

$$
g
\leftrightarrow
X_1
\leftrightarrow
\left\{
XX0101_{\eta_e\eta_h},\,
XX1111
\right\}
$$

For a fixed final spin state $\rho$ in manifold $\eta=(\eta_e,\eta_h)$
$$
\mathcal A_{\eta\rho}^{\lambda_2\lambda_1}
=
\sum_{X=X_0,X_1}
\frac{
C_{\eta\rho,X}^{\lambda_2}\,
C_{Xg}^{\lambda_1}\,
M_{\eta\rho,X}^{(\mathrm{env})}\,
M_{Xg}^{(\mathrm{env})}
}{
E_X-\hbar\omega_1-i\hbar\Gamma_X
}
+
(1\leftrightarrow2)
$$

Within one final state
$$
X_0\text{ path}
+
X_1\text{ path}
\quad\Longrightarrow\quad
\text{coherent interference}
$$

Between orthogonal final states
$$
\langle XX_{\eta'\rho'}|XX_{\eta\rho}\rangle
=
\delta_{\eta'\eta}\delta_{\rho'\rho}
$$

$$
\alpha^{(2)}
\propto
\sum_{\eta,\rho}
\left|
\mathcal A_{\eta\rho}
\right|^2
$$

$XX0000$ and $XX1111$ each have one envelope path; $XX0101$ has two.

## Radiatively disconnected islands

$$
|0001\rangle
\leftrightarrow
|01\rangle,
\qquad
|0100\rangle
\leftrightarrow
|10\rangle
$$

$$
g
\nleftrightarrow
|01\rangle,
\qquad
g
\nleftrightarrow
|10\rangle
\qquad
(\Delta L\ne0)
$$

Example
$$
|0001\rangle
\longrightarrow
|01\rangle
\nrightarrow
g
$$

Spin selection multiplies each allowed island envelope amplitude; it cannot restore an $L$-forbidden link.

## Conventions

Hole envelopes use $e^{im\varphi}$ as in the numerics:
$$
m_h=-m_e
\qquad
\text{for a bright envelope pair}
$$

Orbital reversal
$$
m\to-m
$$
leaves energies invariant but changes dipole phases.

## Consequence for the production runs

Coordinate-space energies
$$
E(X00),
\quad
E(X11),
\quad
E(XX0000),
\quad
E(XX1111)
$$

$$
E(XX0101_{\eta_e\eta_h}),
\qquad
(\eta_e,\eta_h)
\in
\{(+,+),(+,-),(-,+),(-,-)\}
$$

Envelope dipoles
$$
\mu_{g,X_0}^{(\mathrm{env})},
\quad
\mu_{g,X_1}^{(\mathrm{env})},
\quad
\mu_{X_0,XX0000}^{(\mathrm{env})},
\quad
\mu_{X_1,XX1111}^{(\mathrm{env})}
$$

$$
\mu_{X_0,XX0101_{\eta_e\eta_h}}^{(\mathrm{env})},
\qquad
\mu_{X_1,XX0101_{\eta_e\eta_h}}^{(\mathrm{env})}
$$

Physical dipoles
$$
\mu_{fi}^{(\boldsymbol\epsilon)}
=
\mu_{fi}^{(\mathrm{env})}
C_{fi}^{(\boldsymbol\epsilon)}
$$

Spin coefficients require no additional coordinate quadrature.
