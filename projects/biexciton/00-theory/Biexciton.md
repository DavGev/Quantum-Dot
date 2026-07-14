The notation is described in [[Notation and Coordinates]].

## Total Hamiltonian

$$
H = H_{\mathrm{sp}} + V_{\mathrm{int}}
$$
where $H_{sp}$ is the sum of single-particle Hamiltonians from [[Single Particle]] and $V_{\mathrm{int}}$ is the interaction potential. 
$$
H_{\mathrm{sp}}
=
h_e(1)+h_e(2)+h_h(a)+h_h(b)
$$

$$
V_{\mathrm{int}}
=
\kappa
\left(
\frac{1}{r_{12}}
+
\frac{1}{r_{ab}}
-
\frac{1}{r_{1a}}
-
\frac{1}{r_{1b}}
-
\frac{1}{r_{2a}}
-
\frac{1}{r_{2b}}
\right)
$$

$$
\kappa = \frac{e^2}{4\pi\varepsilon_0\varepsilon_r}
$$

## Uncorrelated biexciton state

Antisymmetrized product of an electron and a hole pair
$$
\Psi_0
=
\Phi_e(1,2)\,\Phi_h(a,b)
$$

$$
\Phi_e(1,2)
=
\frac{1}{\sqrt2}
\left[
\psi_{e_1}(1)\psi_{e_2}(2)
+
\eta_e\,\psi_{e_2}(1)\psi_{e_1}(2)
\right]
$$

$$
\Phi_h(a,b)
=
\frac{1}{\sqrt2}
\left[
\psi_{h_a}(a)\psi_{h_b}(b)
+
\eta_h\,\psi_{h_b}(a)\psi_{h_a}(b)
\right]
$$

$$
\eta_e,\eta_h\in\{+1,-1\}
$$
Each $\Phi$ is built from degenerate one-body eigenstates from [[Single Particle]], so $\Psi_0$ remains an eigenstate of $H_{\mathrm{sp}}$

$$
H_{\mathrm{sp}}\Psi_0 = E_0\Psi_0
$$

$$
E_0 = E_{e_1}+E_{e_2}+E_{h_a}+E_{h_b}
$$

## Correlated trial wavefunction

$$
\Psi = \Psi_0 F
$$

$$
F = G(P+Q)
$$

Hole-hole correlation
$$
G = r_{ab}^{\gamma}e^{-\delta r_{ab}}
$$

Electron-hole pairings
$$
P =
\exp\!\left[
-\alpha(r_{1a}+r_{2b})
-\beta(r_{1b}+r_{2a})
\right]
$$
$$
Q =
\exp\!\left[
-\alpha(r_{1b}+r_{2a})
-\beta(r_{1a}+r_{2b})
\right]
$$

Variational parameters
$$
\alpha,\beta,\gamma,\delta
$$

## Variational Energy
Jastrow split from [[Exciton]]

$$
E
=
\frac{\langle \Psi |H|\Psi\rangle}
{\langle \Psi|\Psi\rangle}
=
E_0
+
\frac{
\mathcal K+\mathcal V
}
{\mathcal N}
$$

## Direct-Cross Decomposition

### Square of the correlation factor

$$
F^2
=
G^2(P+Q)^2
=
G^2(P^2+Q^2+2PQ)
$$

By exchange symmetry $a\leftrightarrow b$ (or $1 \leftrightarrow 2$), under which $|\Psi_0|^2G^2$ is invariant and $P^2\leftrightarrow Q^2$
$$
\int \Psi_0^2G^2P^2\,d\tau
=
\int \Psi_0^2G^2Q^2\,d\tau
$$

### Normalization

$$
N^{(D)}
=
\int \Psi_0^2G^2P^2\,d\tau
$$

$$
N^{(X)}
=
\int \Psi_0^2G^2PQ\,d\tau
$$

$$
\mathcal N
=
2\left(N^{(D)}+N^{(X)}\right)
$$

### Interaction terms

$$
V^{(D)}
=
\int
\Psi_0^2G^2P^2V_{\mathrm{int}}
\,d\tau
$$

$$
V^{(X)}
=
\int
\Psi_0^2G^2PQV_{\mathrm{int}}
\,d\tau
$$

$$
\mathcal V
=
2\left(V^{(D)}+V^{(X)}\right)
$$

## Direct interaction

The combined swap $S_{eh}=(1\leftrightarrow2)(a\leftrightarrow b)$ leaves $P$ invariant and maps $r_{1a}\!\leftrightarrow\! r_{2b}$, $r_{1b}\!\leftrightarrow\! r_{2a}$. With $|\Psi_0|^2$ invariant under $S_{eh}$ (it is invariant under each factor separately), the four electron-hole terms collapse to $2(1/r_{1a}+1/r_{1b})$.
$$
V^{(D)}
=
\kappa
\int
\Psi_0^2G^2P^2
\left(
\frac{1}{r_{12}}
+
\frac{1}{r_{ab}}
\right)
d\tau
-
2\kappa
\int
\Psi_0^2G^2P^2
\left(
\frac{1}{r_{1a}}
+
\frac{1}{r_{1b}}
\right)
d\tau
$$

## Cross interaction

 $PQ$ is invariant under both $1\leftrightarrow2$ and $a\leftrightarrow b$. Combined with the invariance of $|\Psi_0|^2$ under each, the four electron-hole terms become equal and collapse to $4/r_{1a}$.
$$
V^{(X)}
=
\kappa
\int
\Psi_0^2G^2PQ
\left(
\frac{1}{r_{12}}
+
\frac{1}{r_{ab}}
\right)
d\tau
-
4\kappa
\int
\Psi_0^2G^2PQ
\frac{1}{r_{1a}}
\,d\tau
$$

## Gradient of the correlation factor

$$
\nabla_i F
=
G
\left[
P
\left(
\nabla_i\ln G+\nabla_i\ln P
\right)
+
Q
\left(
\nabla_i\ln G+\nabla_i\ln Q
\right)
\right]
$$

$$
|\nabla_iF|^2
=
G^2
\left[
P^2D_i^{(P)}
+
Q^2D_i^{(Q)}
+
2PQX_i
\right]
$$

$$
D_i^{(P)}
=
\left|
\nabla_i\ln G+\nabla_i\ln P
\right|^2
$$

$$
D_i^{(Q)}
=
\left|
\nabla_i\ln G+\nabla_i\ln Q
\right|^2
$$

$$
X_i
=
\left(
\nabla_i\ln G+\nabla_i\ln P
\right)
\cdot
\left(
\nabla_i\ln G+\nabla_i\ln Q
\right)
$$

## Kinetic kernels

Three reductions, each from an exchange symmetry of $|\Psi_0|^2$:
(i) $\int|\Psi_0|^2G^2Q^2D_i^{(Q)} = \int|\Psi_0|^2G^2P^2D_i^{(P)}$ via $a\leftrightarrow b$;
(ii) electron $2\equiv$ electron $1$ via $1\leftrightarrow2$;
(iii) hole $b\equiv$ hole $a$ via $a\leftrightarrow b$.
Each holds because $|\Psi_0|^2$ inherits the symmetry from the squared (anti)symmetric $\Psi_0$.

Electron kernels
$$
K_e^{(D)}
=
\int
\Psi_0^2G^2P^2D_1^{(P)}
\,d\tau
$$

$$
K_e^{(X)}
=
\int
\Psi_0^2G^2PQX_1
\,d\tau
$$

Hole kernels
$$
K_h^{(D)}
=
\int
\Psi_0^2G^2P^2D_a^{(P)}
\,d\tau
$$

$$
K_h^{(X)}
=
\int
\Psi_0^2G^2PQX_a
\,d\tau
$$

$$
\mathcal K
=
2
\left[
\frac{\hbar^2}{m_e}
\left(
K_e^{(D)}+K_e^{(X)}
\right)
+
\frac{\hbar^2}{m_h}
\left(
K_h^{(D)}+K_h^{(X)}
\right)
\right]
$$

## Final variational energy

$$
E
=
E_0
+
\frac{
\frac{\hbar^2}{m_e}
\left(
K_e^{(D)}+K_e^{(X)}
\right)
+
\frac{\hbar^2}{m_h}
\left(
K_h^{(D)}+K_h^{(X)}
\right)
+
V^{(D)}
+
V^{(X)}
}
{
N^{(D)}+N^{(X)}
}
$$
