Using results from [[Exciton]] and [[Biexciton]].

## Three-Level Model

Levels
$$
g \;(\text{vacuum}),\quad
e \;(\text{exciton}),\quad
b \;(\text{biexciton})
$$

Transition frequencies
$$
\hbar\omega_{eg} = E_e - E_g, \qquad
\hbar\omega_{be} = E_b - E_e, \qquad
\hbar\omega_{bg} = E_b - E_g
$$

## Oscillator Strengths

$$
f_{eg} = \frac{2}{m_0\,\hbar\omega_{eg}}|\langle e|\,p\,|g\rangle|^2
$$

$$
f_{be} = \frac{2}{m_0\,\hbar\omega_{be}}|\langle b|\,p\,|e\rangle|^2
$$

$m_0$ — free electron mass, $p$ — momentum operator.

## Transition Dipole Moments

$$
\mu_{ij}^2 = \frac{\hbar e^2}{2m_0\,\omega_{ij}}\,f_{ij}
$$

## Population Decay Rate

$$
\Gamma_e = \frac{2n_r e^2\,\omega_{eg}^2}{3m_0 s^3}\,f_{eg}
$$

$n_r$ — refractive index, $s$ — speed of light.

## Third-Order Susceptibility

General expression (equal-photon limit $\hbar\omega_1=\hbar\omega_2\equiv\hbar\omega$):

$$
\chi^{(3)}(\omega)
=
-\frac{i|\mu_{eg}|^4}{2}
\frac{1}{i(\hbar\omega_{eg}-2\hbar\omega)+\hbar\Gamma_{eg}}
\frac{1}{\hbar\Gamma_e}
\left(
\frac{1}{i(\hbar\omega_{eg}-\hbar\omega)+\hbar\Gamma_{eg}}
+
\frac{1}{i(\hbar\omega-\hbar\omega_{eg})+\hbar\Gamma_{eg}}
\right)
$$

$$
+\frac{i|\mu_{eg}|^2|\mu_{be}|^2}{4}
\frac{1}{i(\hbar\omega_{be}-2\hbar\omega)+\hbar\Gamma_{be}}
\frac{1}{\hbar\Gamma_e}
\left(
\frac{1}{i(\hbar\omega_{eg}-\hbar\omega)+\hbar\Gamma_{eg}}
+
\frac{1}{i(\hbar\omega-\hbar\omega_{eg})+\hbar\Gamma_{eg}}
\right)
$$

$$
-\frac{i|\mu_{eg}|^2|\mu_{be}|^2}{4}
\frac{1}{i(\hbar\omega_{eg}-2\hbar\omega)+\hbar\Gamma_{eg}}
\frac{1}{i(\hbar\omega_{bg}-2\hbar\omega)+\hbar\Gamma_{bg}}
\frac{1}{i(\hbar\omega_{eg}-\hbar\omega)+\hbar\Gamma_{eg}}
$$

$$
+\frac{i|\mu_{eg}|^2|\mu_{be}|^2}{4}
\frac{1}{i(\hbar\omega_{be}-2\hbar\omega)+\hbar\Gamma_{be}}
\frac{1}{i(\hbar\omega_{bg}-2\hbar\omega)+\hbar\Gamma_{bg}}
\frac{1}{i(\hbar\omega_{eg}-\hbar\omega)+\hbar\Gamma_{eg}}
$$

## One-Photon Resonances

At $\omega = \omega_{eg}$

$$
\chi^{(3)}\big|_{\omega_{eg}}
\approx
-\frac{i|\mu_{eg}|^4}{2\hbar\Gamma_e}
\frac{2\hbar\Gamma_{eg}}{(\hbar\omega-\hbar\omega_{eg})^2+(\hbar\Gamma_{eg})^2}
\frac{1}{i(\hbar\omega_{eg}-\hbar\omega)+\hbar\Gamma_{eg}}
$$

At $\omega = \omega_{be}$

$$
\chi^{(3)}\big|_{\omega_{be}}
\approx
\frac{i|\mu_{eg}|^2|\mu_{be}|^2}{4\hbar\Gamma_e}
\frac{2\hbar\Gamma_{eg}}{(\hbar\omega-\hbar\omega_{eg})^2+(\hbar\Gamma_{eg})^2}
\frac{1}{i(\hbar\omega_{be}-\hbar\omega)+\hbar\Gamma_{be}}
$$

## Two-Photon Resonance

Biexciton binding energy
$$
E_{\mathrm{bind}} = 2E_e - E_b
$$

At $2\omega \approx \omega_{bg}$

$$
\chi^{(3)}\big|_{2\omega_{bg}}
\approx
\frac{i2|\mu_{eg}|^2|\mu_{be}|^2}{E_{\mathrm{bind}}^2}
\frac{1}{i(\hbar\omega_{bg}-2\hbar\omega)+\hbar\Gamma_{bg}}
$$

## Absorption Coefficients

Linear
$$
\alpha_0(\omega)
=
\frac{\hbar\Gamma_{eg}}{(\hbar\omega-\hbar\omega_{eg})^2+(\hbar\Gamma_{eg})^2}
$$

Non-linear
$$
\alpha_2(\omega)
=
\frac{32\pi^2\omega}{\varepsilon_0 c^2}\,\mathrm{Im}\,\chi^{(3)}(\omega)
$$

Total
$$
\alpha_{\mathrm{total}}(\omega)
=
\alpha_0(\omega)
+
\alpha_2(\omega)\,I(\omega)
$$

$I(\omega)$ — incident light intensity.

## Two-Photon Absorption

$$
\alpha^{(2)}(\omega)
=
\frac{4\pi\omega}{c\,\varepsilon_0^{1/2}}\,I(\omega)\,\mathrm{Im}\,\chi^{(3)}(\omega)
$$

Near two-photon resonance ($2\omega\approx\omega_{bg}$)

$$
\alpha^{(2)}(\omega)
\propto
\frac{|\mu_{eg}|^2|\mu_{be}|^2}{E_{\mathrm{bind}}^2\,\hbar\Gamma_{bg}}
$$
