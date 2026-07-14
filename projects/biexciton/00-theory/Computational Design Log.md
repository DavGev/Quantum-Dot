How the biexciton numerics reached their final form. Theory in [[Biexciton]], integration method in [[Importance-Sampled Integration]]; implementation in `01-numerics/mixed-integrals.wl`.

## The symptom

Swapping $\alpha\leftrightarrow\beta$ changed the energy correction (e.g. $-11.57$ vs $+5.85\ \mathrm{Ry}$) although the trial factor $F=G(P+Q)$ makes the exact energy symmetric under the swap. A 13-hour minimization had also "converged" smoothly to $-11.56\ \mathrm{Ry}$ at extreme parameters ($\alpha\approx0.06$), which later proved to be an artifact.

## Diagnosis

**Derivations were audited first and cleared.** Every symmetry-reduced integral form in [[Biexciton]] rests on two pointwise statements: the pair density is $I\leftrightarrow J$ symmetric, and $P$ with electrons relabeled equals $Q$. Both were verified numerically at random configuration points to machine precision, for arbitrary mixed states. The identities (e.g. $\int\Psi_0^2G^2P^2 = \int\Psi_0^2G^2Q^2$) are therefore exact, and any numerical violation measures quadrature error — this became the standing diagnostic.

**Two independent quadrature failures were then found.**

1. A finite `AccuracyGoal` set an absolute error tolerance ($10^{-6}$) far above the integrals themselves ($\sim10^{-8}$): NIntegrate "converged" instantly with $O(1)$ error, identically at every budget. Fixed by `AccuracyGoal -> Infinity`, so the relative goal always governs and `MaxPoints` caps the cost.
2. With honest stopping, uniform quasi-Monte-Carlo still failed: the orbitals confine each particle to $r\lesssim\ell$ while the box extends to $R=0.9a\gg\ell$, so only a fraction $\sim(\ell/R)^8$ of points land in the support. $\langle P^2\rangle$ and $\langle Q^2\rangle$ disagreed by $30\text{--}100\%$ at any affordable budget, and NIntegrate's own error estimates were $\sim10\times$ optimistic. The smooth, deterministic quadrature error created a fake variational minimum that the optimizer found reproducibly.

## Fixes, in order

1. **Symmetrized estimators.** Direct terms use $(P^2+Q^2)/2$ and $(P^2D^{(P)}+Q^2D^{(Q)})/2$; cross terms were already pointwise symmetric. The $\alpha\leftrightarrow\beta$ symmetry is now exact by construction on the fixed point set.
2. **Importance sampling.** Per-particle change of variables mapping a reference density to the uniform measure ([[Importance-Sampled Integration]]). Brought the $\langle P^2\rangle$/$\langle Q^2\rangle$ spread from $O(1)$ to the target $\sim1\%$ at $2\times10^5$ points.
3. **State-adapted reference.** For mixed configurations each particle samples the average of its pair's two orbital densities plus a $10\%$ ground floor (bounded Jacobian at orbital nodes; interference bounded by AM-GM). Maps are tabulated per configuration and rebuilt automatically when the configuration changes.
4. **Optimizer tolerance above the noise floor.** With optimizer and integration precision goals equal, NelderMead shrink-loops indefinitely inside the noise band (384 evaluations, best flat after 185). The optimizer goal is now one order looser than the integration goal.
5. **Bias-free readout.** The minimizer's best value is a minimum over hundreds of noisy draws and is biased low by roughly the noise half-width; the quoted energy is a single re-evaluation at the optimal parameters with a higher budget.
6. **Bookkeeping.** Run history is keyed by the full configuration (states, exchange signs, geometry), archived to disk, and used to warm-start only exactly matching configurations; diagnostics flag stale history.

## Final protocol

1. Configure states; `minimizeBiexciton[a, c]` at `bxPrecisionGoal = 2`, $2\times10^5$ points (warm-started if the configuration was run before).
2. Re-evaluate `totalEnergyBiexciton` at the optimum with `bxPrecisionGoal = 3`, $10^6$ points.
3. Stamp with `bxQuadratureCheckAll`: six exact identities (norm, full interaction, interaction reduction, cross attraction, electron and hole kinetic kernels); require all relative spreads $\lesssim10^{-2}$.

## Validation across configuration classes

Identity spreads from `bxQuadratureCheckAll` at $2\times10^5$ points, $a=5$, $c=0.5$, $(\alpha,\beta,\gamma,\delta)\approx(0.7,\,0.1,\,2.5,\,2.8)$; worst entry in parentheses:

| electron configuration | spreads |
|---|---|
| $\{1,0,0\},\{1,0,0\}$ (ground) | $0.1\text{--}2\%$ |
| $\{1,0,1\},\{1,0,1\}$ (excited, equal) | $0.3\text{--}3\%$ (cross attraction) |
| $\{1,0,0\},\{1,0,1\}$ singlet | $0.8\text{--}4\%$ (cross attraction) |
| $\{1,0,0\},\{1,0,1\}$ triplet | $0.9\text{--}4\%$ (electron kinetic) |

No $O(1)$ failures in any class: the mixture reference contains the interference term in both spin channels. Distinct-orbital configurations run $2\text{--}3\times$ noisier than equal-orbital ones — the interference partially cancels the plain-product density (nodal in the triplet), which a positive reference cannot mirror. Production budgets for these configurations are therefore $4\text{--}5\times$ larger ($\sim10^6$ per minimization evaluation, $2\text{--}4\times10^6$ for the final energy); the quoted per-configuration error bar is always the measured spread at the optimum, not an assumption.

## Reference result (ground configuration, $a=5$, $c=0.5$)

$$
(\alpha,\beta,\gamma,\delta) = (0.722,\ 0.105,\ 2.453,\ 2.764)
$$

$$
E_{\mathrm{corr}} = -6.621\ \mathrm{Ry},
\qquad
E_{\mathrm{tot}} = 89.866\ \mathrm{Ry}
\qquad
(E_0 = 96.488\ \mathrm{Ry})
$$

Identity spreads $0.1\text{--}2\%$ at $10^6$ points; estimated uncertainty $\pm0.03\ \mathrm{Ry}$. The earlier $-11.56\ \mathrm{Ry}$ is superseded (quadrature artifact).
