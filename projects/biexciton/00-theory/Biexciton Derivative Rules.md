This is to support the numerical evaluation described in [[Biexciton]]
## Gradient

$$
\nabla_i f
=
\hat{\mathbf e}_{z_i}
\frac{\partial f}{\partial z_i}
+
\hat{\mathbf e}_{r_i}
\frac{\partial f}{\partial r_i}
+
\hat{\mathbf e}_{\phi_i}
\frac{1}{r_i}
\frac{\partial f}{\partial \phi_i}
$$

$$
|\nabla_i f|^2
=
\left(
\frac{\partial f}{\partial z_i}
\right)^2
+
\left(
\frac{\partial f}{\partial r_i}
\right)^2
+
\frac{1}{r_i^2}
\left(
\frac{\partial f}{\partial \phi_i}
\right)^2
$$

## Pair-distance derivatives

$$
\frac{\partial r_{ij}}{\partial z_i}
=
\frac{z_i-z_j}{r_{ij}}
$$

$$
\frac{\partial r_{ij}}{\partial r_i}
=
\frac{
r_i-r_j\cos(\phi_i-\phi_j)
}
{r_{ij}}
$$

$$
\frac{\partial r_{ij}}{\partial \phi_i}
=
\frac{
r_i r_j\sin(\phi_i-\phi_j)
}
{r_{ij}}
$$
## Logarithmic factors

$$
\ln G
=
\gamma\ln r_{ab}
-
\delta r_{ab}
$$

$$
\ln P
=
-\alpha(r_{1a}+r_{2b})
-\beta(r_{1b}+r_{2a})
$$

$$
\ln Q
=
-\beta(r_{1a}+r_{2b})
-\alpha(r_{1b}+r_{2a})
$$
