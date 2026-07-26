# Paper Outline (draft for review)

Working titles (pick/adjust):
1. *Non-Linear Optical Properties of Excitons and Biexcitons in Semi-Ellipsoidal Quantum Dots*
2. *Selection Rules and Non-Linear Optical Response of Biexcitons in Strongly Oblate Semi-Ellipsoidal Quantum Dots*

Target: Nanomaterials-class journal, structure mirroring the reference paper (Bleyan et al., Nanomaterials 12, 1412) so reviewers can compare directly, with our additions marked **[new]**.

Status tags: (ready) = data/notes exist now; (P2) = needs grid runs; (R) = needs the response-formula adaptation (chi3/absorption); the dipole machinery itself is DONE (Dipole Matrix Elements note + mixed-dipoles.wl + Oscillator-Strengths.nb).

---

## 1. Introduction

QD excitonic complexes and nonlinear optics motivation; droplet-epitaxy GaAs dots are dome-shaped -- the semi-ellipsoidal geometry is the realistic shape, contrasted with the full-ellipsoid literature (reference paper). Contribution list: (i) correlated variational energies for exciton and biexciton ground and excited states in the semi-ellipsoid; (ii) **[new]** exact selection rules from axial symmetry: the bright "diamond", exchange-split excited biexciton, dark-exciton islands -- each stated exactly and confirmed by computed dipole amplitudes (correlation-enhanced bright elements, forbidden elements bounded at noise level); (iii) chi3, oscillator strengths, one- and two-photon absorption for both optical channels; (iv) **[new]** controlled numerics with identity-based error bars. (ready)

## 2. Theory

### 2.1 Single-particle states
Semi-ellipsoidal hard-wall dot, adiabatic z/in-plane separation, spectrum E(nu, n, m); validity remarks: c/a << 1, hard wall vs band offsets (why c >= 6 nm), effective Rydberg units. Source: Single Particle note. (ready)

### 2.2 Correlated exciton and biexciton states
Trial functions Psi0 * F: exciton F = exp(-alpha r_eh); biexciton F = G(P+Q); exchange sign eta lives in Psi0 only (symmetry argument); variational parameters. Source: Exciton / Biexciton notes. (ready)

### 2.3 Optical selection rules **[new]**
Interband pair operator; exact L-conservation from axial symmetry vs orthogonality-based rules; the bright diamond g <-> {X00, X11} <-> {XX0000, XX0101, XX1111}; two interfering two-photon paths into XX0101; eta multiplet of XX0101; radiatively disconnected islands and the dark-exciton bottleneck -- stated exactly AND confirmed numerically (forbidden amplitudes bounded at noise level, quoted as |M|^2 < bound relative to the bright channel). Source: Optical Selection Rules note. Figure: transition-scheme diagram (F2 rendered as a level-and-arrows figure). (ready)

### 2.4 Dipole matrix elements and oscillator strengths **[new]**
Exciton: M = 1/sqrt(N_X) exactly -- correlation enters only through the norm and ENHANCES the strength; biexciton: 8-dim pair-creation amplitude with the Jastrow at coincidence; exact tests (sqrt(2) identical-pair limit, forbidden-amplitude bound); f = (E_p/E_T)|M|^2, ratios quoted against the ground channel. Source: Dipole Matrix Elements note. (ready)

### 2.5 Nonlinear response
chi3 around one- and two-photon resonances and absorption coefficients built on the computed M's; explicit treatment of the two-path interference into XX0101 and the eta multiplet; linewidth and temperature conventions (Gamma, Eg(T)). (R)

## 3. Computational Method

Condensed from the Computational Design Log: importance-sampled QMC with state-adapted references; exact-identity diagnostics as rigorous error bounds (norm(alpha=0)=1, P/Q and state-swap identities); symmetrized estimators; stall-guarded Nelder-Mead with per-configuration warm starts; norm-collapse guard for antisymmetric pairs; quoted error bar = worst identity spread at the optimum. Reproducibility: code + result archives on Zenodo (tagged commit). (ready; light edit after campaign ends)

## 4. Results and Discussion

### 4.1 Energy levels and diagrams
F1 at (50, 6) and (50, 10) nm: correlated levels; correlation-resolved splitting of the zeroth-order degenerate multiplets; level ordering (hole ladder ~7x finer than electron ladder); corrections (~ -20..-40 meV) exceed bare level spacings -- ordering is correlation-determined **[new]**. (P1/P3 done; ready when P2 lands)

### 4.2 Binding energies and geometry trends
F3: Ebind(XX) and diamond transition energies vs c (6-10 nm + legacy 5-5.5 nm points) and vs a (40-60 nm); comparison with the full-ellipsoid trends of the reference paper. (P2)

### 4.3 Exchange fine structure of XX0101 **[new]**
The four (etaE, etaH) energies at the base geometry; splittings J vs linewidth Gamma; consequence for the two-photon lineshape (resolved multiplet or merged). Data: runXX0101All. (ready)

### 4.4 Oscillator strengths
Exciton enhancement 1/N_X (base numbers ready); the four diamond elements including BOTH amplitudes into XX0101 (relative phase -> interference sign); eta-variant dipole weights (resolves D1: which combinations cross the grid); forbidden elements quoted as numerical bounds beside the exact statement. Base geometry (ready); vs a and c needs the cheap dipole post-pass over P2 optima. (P2)

### 4.5 Third-order susceptibility
chi3 spectra around omega_x and 2omega ~ omega_b for both channels with computed M's; **[new]** interference of the two paths into XX0101; comparison to reference paper Figs. 3-4. (R)

### 4.6 Absorption
One- and two-photon absorption for ground and excited channels, c-scan; Ebind enters the two-photon denominator -- now a genuine computed quantity. Comparison to reference Figs. 5-6. (R)

### 4.7 Dark islands and cascade
Population routing XX0001 -> X01 (trap); predicted PL-only lines; relevance for cascade efficiency. Now quantitative on the radiative side: the allowed island element X01 -> XX0010 is computed (Oscillator-Strengths.nb), so the island's radiative rate is quotable next to the exact ground-channel darkness. (ready)

## 5. Conclusions
Mirror the contribution list with numbers filled in.

## Appendices
A. Reduced-estimator derivations and exchange identities (from Biexciton note + Design Log).
B. Quadrature validation: identity-spread tables across configuration classes.

## Back matter
Data/code availability (Zenodo DOI, tagged commit); author contributions; funding; acknowledgments.

---

Open questions for review:
1. Title choice; lead with selection rules or with the optics?
2. Do the legacy points (5, 5.5 nm) appear in main-text figures or only as supplementary trend points (hard-wall caveat)?
3. Section 2.4-2.5/4.4-4.6 granularity: single "optical response" results section or split as drafted?
4. RESOLVED in principle: the cascade radiative element X01 -> XX0010 is computable with the existing machinery (already in Oscillator-Strengths.nb) -- 4.7 goes quantitative on the radiative side. Remaining choice: include nonradiative relaxation estimates (new scope) or cite generically?
5. NEW: the dipole post-pass over P2 optima (cheap, ~minutes per geometry) -- fold into the production notebook as a runner, or keep in Oscillator-Strengths.nb as a loop over geometries?
