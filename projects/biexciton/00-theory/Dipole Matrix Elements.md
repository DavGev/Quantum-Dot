The notation is described in [[Notation and Coordinates]]; selection rules in [[Optical Selection Rules]]; correlated states from [[Exciton]] and [[Biexciton]].

## Amplitudes

Interband coupling creates or annihilates a pair at a point. With $\mu = \mu_{cv} M$ and spin factors absorbed into the channel constant $c_s$,
$$
M_{gX}
=
\int d^3r\,
\Psi_X(\mathbf r, \mathbf r)
$$
$$
M_{X\,XX}
=
c_s
\int d^3R\, d^3r_1\, d^3r_a\,
\Psi_{XX}(\mathbf r_1, \mathbf R;\, \mathbf r_a, \mathbf R)\,
\Psi_X^*(\mathbf r_1, \mathbf r_a)
$$
For two identical electrons and two identical holes $c_s = 2$ ($\sqrt2$ each); it is common to all diamond transitions and cancels in ratios.

## Exciton: correlation enters only through the norm

At coincidence $F_X = e^{-\alpha_X \cdot 0} = 1$, and the orbital overlap is exact:
$$
\int \psi_e(\mathbf r)\psi_h(\mathbf r)\, d^3r
=
\begin{cases}
1 & \text{bright } (m_e + m_h = 0,\ \text{same } \nu, n, |m|)\\
0 & L\text{-forbidden}
\end{cases}
$$
Hence, with $N_X = $ normExciton$(a,c,\alpha^*)$ (normalized so $N_X(\alpha=0)=1$),
$$
M_{gX} = \frac{1}{\sqrt{N_X}}
$$
$N_X < 1$: the electron-hole correlation ENHANCES the exciton oscillator
strength (excitonic coincidence enhancement).

## Biexciton amplitude

Unnormalized states $\tilde\Psi = \Psi_0 F$; the biexciton Jastrow at the
coincidence point $\mathbf R$ (created pair: second electron and hole $b$):
$$
P \to e^{-\alpha_{XX} r_{1a} - \beta_{XX}(|\mathbf r_1 - \mathbf R| + |\mathbf R - \mathbf r_a|)}
$$
$$
Q \to e^{-\alpha_{XX}(|\mathbf r_1 - \mathbf R| + |\mathbf R - \mathbf r_a|) - \beta_{XX}\, r_{1a}}
$$
$$
G \to |\mathbf r_a - \mathbf R|^{\gamma} e^{-\delta |\mathbf r_a - \mathbf R|}
$$
$$
\tilde A
=
\int
\Phi_e(\mathbf r_1, \mathbf R)\,
\Phi_h(\mathbf r_a, \mathbf R)\,
G\,(P+Q)\;
\psi_e^*(\mathbf r_1)\psi_h^*(\mathbf r_a)\,
e^{-\alpha_X r_{1a}}
\, d\tau
$$
an 8-dimensional integral (axial gauge: $\mathbf R$ at azimuth 0, factor $2\pi$). With the code's norm conventions ($N_{XX} = 2(N^{(D)}+N^{(X)})$, $N_X$ as above),
$$
M_{X\,XX}
=
\frac{c_s\,\tilde A}{\sqrt{\,2(N^{(D)}+N^{(X)})\; N_X\,}}
$$

## Exact tests

1. Zero-correlation limit ($\alpha_X = \alpha_{XX} = \beta = \delta = 0$, $\gamma = 0$): $\tilde A = 2$ (the factor from $P+Q$), $N_{XX} = 2$, $N_X = 1$, so
$$
M = c_s^{-1} M_{X\,XX} = \sqrt2
$$
the identical-pair enhancement. The numerics must reproduce this.
2. $L$-forbidden pairs (e.g. $|00\rangle \to |0010\rangle$): the azimuthal integral vanishes identically; the computed $\tilde A$ must be zero within the quadrature error. This is the numerical counterpart of the island statement in [[Optical Selection Rules]].

## Oscillator strength

Interband convention with Kane energy $E_p$:
$$
f
=
\frac{E_p}{E_T}\,|M|^2
$$
with $E_T$ the transition energy (gap included). The paper quotes $f$ normalized to the ground channel, which cancels $c_s$ and $\mu_{cv}$.
