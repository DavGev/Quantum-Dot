# Results Note: Main Exciton and Biexciton State

**Status:** Results generated from the completed raw importance-sampled pattern-search campaign and the plotting notebook, 2026-08-03.

## Scope and conventions

The results cover the ground exciton \(X\) and the main biexcitonic state \(XX\) for seven semi-ellipsoidal quantum-dot geometries. Lengths \(a\) and \(c\) are in effective Bohr radii. The two geometry scans are

- axial scan: \(a=5\), \(c=0.5,1,1.5,2\);
- lateral scan: \(c=1\), \(a=3,5,7,10\).

The plotted \(E_X\) and \(E_{XX}\) are corrected confinement energies; they do not include the material band gap. The binding-energy convention is

\[
E_{\mathrm{bind}}=2E_X-E_{XX},
\]

so a positive value denotes a bound biexciton. The optical transition energy used for the lifetime calculation is \(E_g+E_X\).

The displayed error bars are rough first-order propagations of the numerical integration error estimates. They are useful resolution diagnostics, but they are not confidence intervals and do not include covariance, systematic adaptive-QMC bias, or uncertainty in the location of the variational optimum.

## Main findings

1. **Axial confinement controls the absolute biexciton energy most strongly.** At fixed \(a=5\), increasing \(c\) from \(0.5\) to \(2\) lowers \(E_{XX}\) from \(498.81\) to \(20.44\ \mathrm{meV}\), a factor of \(24.4\). At fixed \(c=1\), increasing \(a\) from \(3\) to \(10\) lowers \(E_{XX}\) by only \(7.9\%\), from \(121.41\) to \(111.79\ \mathrm{meV}\).

2. **The central binding energy is positive at every sampled geometry, but it weakens as either dimension increases.** Along the axial scan it falls from \(1.472\) to \(0.575\ \mathrm{meV}\); along the lateral scan it falls from \(1.385\) to \(0.170\ \mathrm{meV}\).

3. **The \((10,1)\) result is marginal at the present numerical resolution.** Its value, \(0.170\pm0.109\ \mathrm{meV}\), remains positive with the plotted rough error bar, but the central value is only about \(1.6\) rough-error units from zero. It should therefore be described as weakly or marginally bound, not as a firmly resolved positive binding energy.

4. **Increasing either dot dimension increases the exciton coincidence overlap and shortens both radiative lifetimes.** The squared overlap \(|M_X|^2\) increases by a factor of \(2.05\) along the axial scan and \(2.60\) along the lateral scan. Correspondingly, \(\tau_X\) decreases from \(2.548\) to \(1.437\ \mathrm{ps}\) with increasing \(c\), and from \(2.767\) to \(1.068\ \mathrm{ps}\) with increasing \(a\).

5. **The relation \(\tau_{XX}=\tau_X/4\) is imposed by the adopted radiative-rate convention.** The factor of four is therefore not an independently fitted geometry trend; the geometry dependence of both curves comes from the same exciton transition energy and overlap.

## Numerical results

### Corrected energies and binding

| \((a,c)\) | \(\alpha_X\) | \(E_X\) (meV) | \(E_{XX}\) (meV) | \(E_{\mathrm{bind}}\) (meV) | \(E_{\mathrm{bind}}/\delta_{\mathrm{rough}}\) |
|---|---:|---:|---:|---:|---:|
| \((5,0.5)\) | 0.780939 | \(250.141\pm0.037\) | \(498.810\pm0.098\) | \(1.472\pm0.122\) | 12.0 |
| \((5,1)\) | 0.731089 | \(58.018\pm0.032\) | \(114.975\pm0.079\) | \(1.062\pm0.101\) | 10.5 |
| \((5,1.5)\) | 0.724547 | \(22.694\pm0.030\) | \(44.520\pm0.061\) | \(0.868\pm0.086\) | 10.1 |
| \((5,2)\) | 0.626090 | \(10.508\pm0.025\) | \(20.440\pm0.058\) | \(0.575\pm0.077\) | 7.5 |
| \((3,1)\) | 0.706089 | \(61.399\pm0.029\) | \(121.414\pm0.067\) | \(1.385\pm0.088\) | 15.7 |
| \((7,1)\) | 0.762339 | \(56.783\pm0.035\) | \(112.818\pm0.074\) | \(0.748\pm0.101\) | 7.4 |
| \((10,1)\) | 0.785787 | \(55.981\pm0.039\) | \(111.791\pm0.077\) | \(0.170\pm0.109\) | 1.6 |

The last column is only the ratio to the propagated rough integration error. It must not be read as a statistical significance or a number of standard deviations.

### Overlap, oscillator strength, and lifetimes

| \((a,c)\) | \(N_X\) | \(|M_X|^2\) | \(f_X\) | \(\tau_X\) (ps) | \(\tau_{XX}\) (ps) |
|---|---:|---:|---:|---:|---:|
| \((5,0.5)\) | \(0.240007\pm0.000156\) | \(4.1665\pm0.0027\) | 53.4788 | \(2.5477\pm0.0017\) | \(0.6369\pm0.0004\) |
| \((5,1)\) | \(0.164087\pm0.000136\) | \(6.0943\pm0.0050\) | 87.7509 | \(1.9540\pm0.0016\) | \(0.4885\pm0.0004\) |
| \((5,1.5)\) | \(0.119753\pm0.000118\) | \(8.3505\pm0.0082\) | 122.9916 | \(1.4587\pm0.0014\) | \(0.3647\pm0.0004\) |
| \((5,2)\) | \(0.117059\pm0.000115\) | \(8.5427\pm0.0084\) | 126.8242 | \(1.4372\pm0.0014\) | \(0.3593\pm0.0004\) |
| \((3,1)\) | \(0.232865\pm0.000148\) | \(4.2943\pm0.0027\) | 61.7007 | \(2.7670\pm0.0018\) | \(0.6918\pm0.0004\) |
| \((7,1)\) | \(0.122686\pm0.000122\) | \(8.1509\pm0.0081\) | 117.4547 | \(1.4621\pm0.0015\) | \(0.3655\pm0.0004\) |
| \((10,1)\) | \(0.089535\pm0.000109\) | \(11.1688\pm0.0136\) | 161.0249 | \(1.0676\pm0.0013\) | \(0.2669\pm0.0003\) |

Here \(M_X=1/\sqrt{N_X}\) and \(f_X=(E_p/E_{\mathrm{opt}})|M_X|^2\), with \(E_{\mathrm{opt}}=E_g+E_X\). The lifetime uncertainties are much smaller than the plotted symbols and are therefore not visually prominent.

## Optimized variational parameters

For the biexciton ansatz

\[
G=r_{ab}^{\gamma}e^{-\delta r_{ab}},
\qquad
P=e^{-\alpha(r_{1a}+r_{2b})-\beta(r_{1b}+r_{2a})},
\]

with the exchanged term \(Q\), the final parameters are:

| \((a,c)\) | \(\alpha_X\) | \(\alpha_{XX}\) | \(\beta_{XX}\) | \(\gamma_{XX}\) | \(\delta_{XX}\) | \(\gamma/\delta\) |
|---|---:|---:|---:|---:|---:|---:|
| \((5,0.5)\) | 0.780939 | 0.755694 | 0.213328 | 2.268187 | 2.382724 | 0.952 |
| \((5,1)\) | 0.731089 | 0.679864 | 0.115335 | 2.492963 | 2.108847 | 1.182 |
| \((5,1.5)\) | 0.724547 | 0.607794 | 0.004089 | 2.858881 | 1.953280 | 1.464 |
| \((5,2)\) | 0.626090 | 0.587481 | 0.010584 | 3.020600 | 1.874374 | 1.612 |
| \((3,1)\) | 0.706089 | 0.653302 | 0.063307 | 2.542182 | 2.298690 | 1.106 |
| \((7,1)\) | 0.762339 | 0.642364 | 0.054180 | 2.604026 | 1.896347 | 1.373 |
| \((10,1)\) | 0.785787 | 0.642364 | 0.054180 | 3.056900 | 1.896347 | 1.612 |

The exciton parameter \(\alpha_X\) generally decreases as \(c\) increases, whereas it increases with \(a\) at fixed \(c=1\). For the biexciton, the optimized cross-pair exponent \(\beta\) becomes very small for \(c=1.5\) and \(2\). The ratio \(\gamma/\delta\), which gives the maximum of the isolated factor \(r_{ab}^{\gamma}e^{-\delta r_{ab}}\), grows smoothly with either dot dimension. This is consistent with the hole-hole correlation factor shifting toward larger characteristic separations in larger dots.

Individual coordinate values should nevertheless be interpreted cautiously. The parameters came from a local coordinate pattern search on a numerically rough QMC objective, and several distinct parameter combinations can yield energy differences below the practical resolution. The energies and their geometry trends are more robust outputs than small differences between neighboring optimized parameters.

## Figure-by-figure interpretation

### Figure 1: corrected biexciton energy

The axial scan shows a steep nonlinear reduction of \(E_{XX}\) as \(c\) increases. Most of the change occurs between \(c=0.5\) and \(c=1\), where \(E_{XX}\) drops by about \(384\ \mathrm{meV}\). This reflects the strong sensitivity of the confinement energy to the short semiaxis. The lateral scan is much flatter: the energy decreases monotonically with \(a\), but the total change from \(a=3\) to \(10\) is only \(9.62\ \mathrm{meV}\). Thus \(c\) is the primary geometrical control of the absolute energy scale.

### Figure 2: binding energy

The binding energy decreases monotonically in both scans. Enlarging the dot weakens confinement and reduces the net correlation advantage of the biexciton relative to two isolated excitons. The reduction is about \(61\%\) from \(c=0.5\) to \(2\), and about \(88\%\) from \(a=3\) to \(10\). The state is numerically well separated from zero according to the rough diagnostic at all points through \((7,1)\). At \((10,1)\), however, the small positive value is comparable to the present numerical resolution, so the defensible conclusion is that binding has approached the resolution limit.

### Figure 3: radiative lifetimes

Both lifetimes decrease as the dot is enlarged. Along the axial scan, \(\tau_X\) falls by \(44\%\) and begins to saturate between \(c=1.5\) and \(2\). Along the lateral scan it falls by \(61\%\) and remains monotonic through \(a=10\). Although the optical transition energy decreases as confinement is relaxed, the increase in \(|M_X|^2\) is larger and therefore dominates the radiative rate. The result is an increasing oscillator strength and a decreasing lifetime. The biexciton curve follows the same geometry dependence at one quarter of the exciton lifetime by construction.

## Manuscript-ready results text

Figure 1 shows the corrected energy of the main biexcitonic state as a function of the semi-ellipsoidal dot dimensions. At fixed lateral semiaxis \(a=5r_B\), increasing the axial semiaxis from \(c=0.5r_B\) to \(2r_B\) reduces \(E_{XX}\) from \(498.81\) to \(20.44\ \mathrm{meV}\). The corresponding lateral-size dependence at fixed \(c=r_B\) is substantially weaker: \(E_{XX}\) decreases from \(121.41\) to \(111.79\ \mathrm{meV}\) as \(a\) increases from \(3r_B\) to \(10r_B\). The absolute biexciton energy is therefore controlled predominantly by the confinement along the short axis.

The biexciton binding energy is positive at all seven calculated geometries and decreases monotonically as either semiaxis is increased (Fig. 2). Along the axial scan, \(E_{\mathrm{bind}}\) changes from \(1.472\pm0.122\) to \(0.575\pm0.077\ \mathrm{meV}\), while along the lateral scan it changes from \(1.385\pm0.088\) to \(0.170\pm0.109\ \mathrm{meV}\). The calculated state is therefore resolved as bound over most of the investigated range. The largest geometry, \((a,c)=(10,1)r_B\), is an exception: its central value remains positive, but it is close enough to the rough numerical error scale that only marginal binding can presently be claimed.

The exciton coincidence overlap increases as confinement is relaxed. Along the axial scan, \(|M_X|^2\) rises from \(4.167\) to \(8.543\), and along the lateral scan it rises from \(4.294\) to \(11.169\). This overlap enhancement outweighs the simultaneous decrease in optical transition energy, causing the oscillator strength to increase and the radiative lifetime to decrease (Fig. 3). The exciton lifetime ranges from \(2.548\) to \(1.437\ \mathrm{ps}\) in the axial scan and from \(2.767\) to \(1.068\ \mathrm{ps}\) in the lateral scan. With the adopted four-channel convention, the main-biexciton lifetime is \(\tau_{XX}=\tau_X/4\), giving values between \(0.692\) and \(0.267\ \mathrm{ps}\) over the complete geometry set.

Taken together, the calculations show that the two semiaxes control different aspects of the main biexcitonic state. The short axial dimension produces the dominant shift of the absolute energy, whereas lateral enlargement provides a particularly strong route for suppressing the small binding energy and enhancing the radiative oscillator strength. The near-zero binding found at \((10,1)\) also identifies the large-\(a\) regime as the point at which higher numerical resolution would be most valuable.

## Suggested figure captions

**Figure 1.** Corrected energy \(E_{XX}\) of the main biexcitonic state as a function of (a) the axial semiaxis \(c\) at fixed \(a=5r_B\) and (b) the lateral semiaxis \(a\) at fixed \(c=r_B\). The plotted energies exclude the material band gap. Lines are guides to the eye. Numerical error bars are smaller than the symbols on the displayed scales.

**Figure 2.** Biexciton binding energy \(E_{\mathrm{bind}}=2E_X-E_{XX}\) as a function of (a) \(c\) at fixed \(a=5r_B\) and (b) \(a\) at fixed \(c=r_B\). Positive values correspond to a bound biexciton, and the dashed line marks zero binding. Error bars are rough propagated numerical-integration estimates rather than statistical confidence intervals. Binding at \((10,1)\) is marginal at the present numerical resolution.

**Figure 3.** Exciton and main-biexciton radiative lifetimes as functions of (a) \(c\) at fixed \(a=5r_B\) and (b) \(a\) at fixed \(c=r_B\). Lifetimes were calculated from the corrected optical transition energy and the exciton coincidence overlap. The adopted rate convention gives \(\tau_{XX}=\tau_X/4\). Lines are guides to the eye; propagated numerical error bars are smaller than the symbols.

## Source files

- Numerical table: `../01-numerics/main-state-final-summary-meV.csv`
- Variational searches: `../01-numerics/main-state-raw-pattern-search-a5-c1-summary.csv` and `../01-numerics/main-state-raw-pattern-search-remaining-summary.csv`
- Plotting notebook: `../03-figures/Main-State-Plots.nb`
- Figures: `../03-figures/Main-E_XX.pdf`, `../03-figures/Main-Binding-Energy.pdf`, and `../03-figures/Main-Lifetimes.pdf`
- Numerical-method record: `../00-theory/Computational Design Log.md`
