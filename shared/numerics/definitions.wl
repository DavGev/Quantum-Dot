(* ::Package:: *)

(* ============================================================================
   definitions.wl  --  shared definitions for the Quantum-Dot project
   ----------------------------------------------------------------------------
   Single source of truth for the constants, confinement frequencies, energies
   and wavefunctions.

   Load from a notebook with:
       Get[FileNameJoin[{ParentDirectory[NotebookDirectory[], 3],
                         "shared", "numerics", "constants.wl"}]];

   Canonical names (use these going forward):
       \[HBar]                      reduced Planck constant   (was also "\:0127")
       m\:2080, m\:2091, m\:2095    free / electron / hole mass
       \[Eta]r                      refractive index          (was "nr")
       \[HBar]\[CapitalOmega][c]    axial confinement \[Pi]^2/c^2
                                    (was "\[CurlyEpsilon]" / "\[Alpha]")
       \[HBar]\[Omega]00[a,c]       in-plane frequency 2\[Pi]/(a c)
                                    (was "\[Omega]0"; cf. "\[Beta]" = \[Pi]/(a c))

   This file intentionally does NOT fix the geometry / run parameters
   (a, c, B, \[CapitalGamma], Intensity, \[Rho]n). Keep those in each notebook's
   own parameter block so the shared file never clobbers a notebook's setup.

   Units: energies in Rydberg (Ry = ER), lengths in effective Bohr radii (rB).
   ============================================================================ *)

(* wipe any stale definitions from a previous Get (old argument patterns would
   otherwise survive a re-Get and shadow updated ones) *)
ClearAll[\[HBar], e, \[CurlyEpsilon]0, kB, c0, m\:2080, \[CurlyEpsilon]r, \[Eta]r, m\:2091, m\:2095,
  rB, ER, ER2meV, Eg, Ep, w, \[HBar]\[CapitalOmega], \[HBar]\[Omega]00, \[HBar]\[Omega]c, \[HBar]\[Omega]0, \[HBar]\[Omega]p, \[HBar]\[Omega]m,
  Energy, EnergyFD, Ee, Eh, \[Psi]z, \[Psi]r, \[Psi]x, \[Psi], E\[Omega], l, \[HBar]f\[Omega]];

(* ---- 1. Physical constants (SI) ------------------------------------------- *)
\[HBar] = 1.054571817*^-34; (* J s *)
e = 1.602176634*^-19; (* C *)
\[CurlyEpsilon]0 = 8.8541878128*^-12; (* F m^-1 *)
kB = 1.380649*^-23; (* J K^-1 *)
c0 = 2.99792458*^8; (* m s^-1, speed of light *)
m\:2080 = 9.1093837015*^-31; (* kg, free electron mass *)

(* ---- 2. GaAs material constants ------------------------------------------- *)
\[CurlyEpsilon]r = 12.8; (* static dielectric constant *)
\[Eta]r = Sqrt[\[CurlyEpsilon]r]; (* refractive index (was nr) *)
m\:2091 = 0.067 m\:2080; (* electron effective mass *)
m\:2095 = 0.45 m\:2080; (* hole effective mass *)

(* ---- 3. Derived scales and conversions ------------------------------------ *)
rB = (4 \[Pi] \[CurlyEpsilon]0 \[CurlyEpsilon]r \[HBar]^2)/(m\:2091 e^2); (* ~10.2 nm for GaAs *)
ER = \[HBar]^2/(2 m\:2091 rB^2); (* electron Rydberg, ~5.8 meV *)
ER2meV = ER/(10^-3 e); (* Ry -> meV conversion factor *)
Eg = 1.424 (e/ER); (* gap energy in Ry, 300 K *)
Ep = 28.8 (e/ER); (* Kane energy in Ry, 300 K *)

(* ---- 4. Geometry and confinement frequencies ------------------------------- *)
w[a_, c_][r_] := c Sqrt[1 - r^2/a^2]; (* dome half-height *)
\[HBar]\[CapitalOmega][c_] := \[Pi]^2/c^2; (* axial confinement *)
\[HBar]\[Omega]00[a_, c_] := (2 \[Pi])/(a c); (* in-plane, B = 0 *)
\[HBar]\[Omega]c[B_] := \[HBar] (e B)/m\:2091 (1/ER); (* cyclotron energy *)
\[HBar]\[Omega]0[a_, c_, B_][\[Nu]_] :=
   Sqrt[\[HBar]\[Omega]00[a, c]^2 \[Nu]^2 + \[HBar]\[Omega]c[B]^2/4];
\[HBar]\[Omega]p[a_, c_, B_][\[Nu]_] :=
   \[HBar]\[Omega]0[a, c, B][\[Nu]] - \[HBar]\[Omega]c[B]/2;
\[HBar]\[Omega]m[a_, c_, B_][\[Nu]_] :=
   \[HBar]\[Omega]0[a, c, B][\[Nu]] + \[HBar]\[Omega]c[B]/2;

(* ---- 5. Single-particle energies ------------------------------------------ *)
(* (\[Nu], n, m) parametrization *)
Energy[a_, c_, B_][\[Nu]_, n_, m_] :=
   \[HBar]\[CapitalOmega][c] \[Nu]^2 +
   \[HBar]\[Omega]0[a, c, B][\[Nu]] (2 n + Abs[m] + 1) -
   (\[HBar]\[Omega]c[B]/2) m;

(* Equivalent Fock-Darwin (n+, n-) parametrization of the same spectrum *)
EnergyFD[a_, c_, B_][{\[Nu]_, np_, nm_}] :=
   \[HBar]\[CapitalOmega][c] \[Nu]^2 +
   \[HBar]\[Omega]p[a, c, B][\[Nu]] (np + 1/2) +
   \[HBar]\[Omega]m[a, c, B][\[Nu]] (nm + 1/2);

Ee[a_, c_, B_][\[Nu]_, n_, m_] := Energy[a, c, B][\[Nu], n, m];
Eh[a_, c_, B_][\[Nu]_, n_, m_] := (m\:2091/m\:2095) Energy[a, c, B][\[Nu], n, m];

(* ---- 6. Wavefunctions ---------------------------------------------------- *)
\[Psi]z[\[Nu]_][w_, z_] := Sqrt[2/w] Sin[(\[Nu] \[Pi] z)/w];

\[Psi]r[n_, m_][\[Omega]0_, r_] :=
   Sqrt[((\[Omega]0/2)^(Abs[m] + 1) n!)/(\[Pi] (n + Abs[m])!)]*
   Piecewise[
     {{r^Abs[m] Exp[-(\[Omega]0 r^2)/4] LaguerreL[n, Abs[m], (\[Omega]0 r^2)/2],
       r > 0}},
     LaguerreL[n, Abs[m], 0]];

\[Psi]x[nx_][\[Omega]0_, x_] :=
   (\[Omega]0/\[Pi])^(1/4) (1/Sqrt[2^nx nx!])*
   HermiteH[nx, Sqrt[\[Omega]0] x] Exp[-(\[Omega]0 x^2)/2];

\[Psi][a_, c_, \[Omega]0_][\[Nu]_, n_, m_][z_, r_, \[CurlyPhi]_] :=
   Exp[I m \[CurlyPhi]]*
   \[Psi]z[\[Nu]][w[a, c][r], z]*
   \[Psi]r[n, m][\[Omega]0, r];

(* ---- 7. Field / optical helpers ------------------------------------------- *)
(* Field amplitude of a beam of given intensity (W/m^2) -> mV/nm. *)
E\[Omega][Intensity_] := Sqrt[Intensity/(2 \[Eta]r \[CurlyEpsilon]0 c0)] 10^-6;
l[c_] := Sqrt[(\[HBar]/(m\:2091 \[HBar]\[CapitalOmega][c]))(\[HBar]/(10^-3 e))];
\[HBar]f\[Omega][Intensity_, c_] :=
   (e l[c] E\[Omega][Intensity])/(2 \[HBar]) (\[HBar]/(10^-3 e));
   
