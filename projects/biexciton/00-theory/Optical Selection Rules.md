The notation is described in [[Notation and Coordinates]]; states from [[Single Particle]], correlated wavefunctions from [[Exciton]] and [[Biexciton]].

## Interband operator

Light creates or annihilates an electron-hole pair at a point; in the envelope approximation the matrix element is
$$
M
\propto
p_{cv}
\int d^3r\,
\langle \text{final}|\,
\hat\psi_e^\dagger(\mathbf r)\,
\hat\psi_h^\dagger(\mathbf r)
\,|\text{initial}\rangle
$$
The photon's $\sigma^\pm$ angular momentum is carried by the Bloch/spin factor $p_{cv}$; the envelope operator is invariant under rotations about $z$.

## Exact rule: envelope angular momentum

The dome is axially symmetric, and the correlation factors ($e^{-\alpha r_{eh}}$, $G$, $P$, $Q$) depend only on interparticle distances. With every envelope written as $e^{im\varphi}$ (electron and hole alike, as in the numerics),
$$
L = \sum_e m_e + \sum_h m_h
$$
is conserved exactly, to all orders in the correlation. A created or annihilated pair must satisfy
$$
m_e + m_h = 0
$$
Transitions violating this are dark by symmetry and cannot be brightened by correlation.

## Approximate rules: orthogonality

Within a created pair, matching of $n$ (radial) and $\nu$ (axial) follows only from orthonormality of the zeroth-order orbitals,
$$
\int \psi_{n_e m}\,\psi_{n_h m}\; r\,dr = \delta_{n_e n_h}
\quad (\text{same } \omega)
$$
No symmetry protects these; the Jastrow factors relax them weakly. Dark-by-$L$ and dark-by-orthogonality must be distinguished when quoting oscillator strengths.

## Classification of the low-lying states

Bright from the ground state ($L=0$, matching pair):
$$
|00\rangle,
\qquad
|11\rangle \equiv e\,\{1,0,1\}\otimes h\,\{1,0,-1\}
$$

Exactly dark from the ground state (with the $m=+1$ labels; mirror states at $-1$):
$$
|01\rangle\ (L=+1),
\qquad
|10\rangle\ (L=+1)
$$

Two-photon-active biexcitons ($L=0$):
$$
|0000\rangle,
\qquad
|0101\rangle \equiv e\,\{100,101\}\otimes h\,\{100,10\bar1\},
\qquad
|1111\rangle \equiv e\,\{101,101\}\otimes h\,\{10\bar1,10\bar1\}
$$

Cascade-only states ($L=\mp1$): $|0001\rangle$, $|0100\rangle$; e.g.
$$
|0001\rangle \to |01\rangle
$$
by annihilating the bright $e_0h_0$ pair; $|01\rangle$ then has no radiative channel to the ground state (dark-exciton bottleneck).

## Optical channels for the paper

Each bright exciton couples to two biexcitons (add $e_0h_0$ or the bright
$e_1h_{\bar1}$ pair), so the bright states form a diamond, not two ladders:
$$
g \leftrightarrow |00\rangle \leftrightarrow |0000\rangle
$$
$$
g \leftrightarrow |00\rangle \leftrightarrow |0101\rangle
$$
$$
g \leftrightarrow |11\rangle \leftrightarrow |0101\rangle
$$
$$
g \leftrightarrow |11\rangle \leftrightarrow |1111\rangle
$$
$|0101\rangle$ is reached from both bright excitons: the two two-photon paths
interfere. $|0000\rangle$ and $|1111\rangle$ each couple to a single exciton.

Radiatively disconnected islands
$$
|0001\rangle \leftrightarrow |01\rangle, \qquad |0100\rangle \leftrightarrow |10\rangle
$$
These transitions are bidirectional like any dipole transition, but the
island has no radiative link to the ground channel ($g\leftrightarrow|01\rangle$
is $L$-forbidden). Population can only enter non-radiatively from above
(relaxation out of the pumped bright states), so in practice the island
appears as an emission cascade terminating in the dark exciton.

## Convention

Hole envelopes are labeled with the same $e^{im\varphi}$ convention as electrons (as in the numerics), so bright pairing means $m_h = -m_e$. Energies are degenerate under $m \to -m$ (the pair densities depend on $\cos[(m_1-m_2)\Delta\theta]$ only), but the sign matters for every dipole matrix element.

## Consequence for the production runs

Three configurations must be added per geometry:
$$
X11:\ e\,\{1,0,1\},\ h\,\{1,0,-1\}
$$
$$
XX0101:\ e\,\{\{1,0,0\},\{1,0,1\}\},\ h\,\{\{1,0,0\},\{1,0,-1\}\},\ \eta_e=\eta_h=+1
$$
$$
XX1111:\ e\,\{\{1,0,1\},\{1,0,1\}\},\ h\,\{\{1,0,-1\},\{1,0,-1\}\},\ \eta_e=\eta_h=+1
$$
$XX0101$ has both pairs in distinct orbitals (heaviest quadrature class);
$XX1111$ has equal-orbital pairs (cheap class). The previously planned
$|0001\rangle$, $|0100\rangle$ remain useful for the energy diagram and the
cascade discussion, but do not appear in the $\chi^{(3)}$ ladder.

Dipole matrix elements needed for the diamond: $\mu_{g,00}$, $\mu_{g,11}$,
$\mu_{00,0000}$, $\mu_{00,0101}$, $\mu_{11,0101}$, $\mu_{11,1111}$, plus the
cascade elements if radiative rates are quoted.
