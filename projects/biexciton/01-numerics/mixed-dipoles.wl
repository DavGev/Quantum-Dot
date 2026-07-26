(* ::Package:: *)

(* ============================================================================
   mixed-dipoles.wl  --  interband dipole amplitudes over correlated states
   ----------------------------------------------------------------------------
   Implements the Dipole Matrix Elements note:
     g -> X      : M = 1/Sqrt[normExciton]  (bright; exactly 0 if L-forbidden)
     X -> XX     : M = cs * Atilde / Sqrt[2 (nD + nX) normX],  cs = 2
   Atilde is the 8-dim pair-creation amplitude with the XX Jastrow evaluated
   at the coincidence point R (gauge: R at azimuth 0, factor 2 Pi).

   Exact tests:
     - all correlations zero  ->  M/cs = Sqrt[2]  (identical-pair enhancement)
     - L-forbidden configurations -> Atilde = 0 within quadrature error
       (numerical counterpart of the island statement).

   Uses the CURRENT globals bxElectronStates/bxHoleStates/bxEtaE/bxEtaH for
   the biexciton and explicit arguments for the exciton state.
   Depends on: definitions.wl, both mixed packages (exciton + biexciton).
   ============================================================================ *)

ClearAll[dpOrb, dpPairAmp, dpMaxPoints, dpIntegrate, bxPairCreationAmp,
  bxDipoleXtoXX, bxDipoleLimitTest];

dpMaxPoints = 4*10^5;

(* complex single-particle orbital: z-amp (z-Jacobian folded) x radial x phase *)
dpOrb[\[Omega]_][{\[Nu]_, n_, m_}][u_, r_, \[Theta]_] :=
  Sqrt[2] Sin[\[Nu] \[Pi] u] \[Psi]r[n, m][\[Omega], r] Exp[I m \[Theta]];

(* complex pair amplitude, conventions matching bxPairDensity:
   same orbital -> plain product; distinct -> antisymmetrized with 1/Sqrt[2] *)
dpPairAmp[\[Omega]_, \[Eta]_, s1_, s2_][u1_, r1_, \[Theta]1_, u2_, r2_, \[Theta]2_] :=
  If[s1 === s2,
   dpOrb[\[Omega]][s1][u1, r1, \[Theta]1] dpOrb[\[Omega]][s1][u2, r2, \[Theta]2],
   (dpOrb[\[Omega]][s1][u1, r1, \[Theta]1] dpOrb[\[Omega]][s2][u2, r2, \[Theta]2] +
      \[Eta] dpOrb[\[Omega]][s2][u1, r1, \[Theta]1] dpOrb[\[Omega]][s1][u2, r2, \[Theta]2])/Sqrt[2]];

(* 8-fold importance-sampled measure: electron 1 (v1,x1,\[Theta]1), hole a
   (va,xa,\[Theta]a), coincidence point R (vR,xR; azimuth 0, factor 2 Pi).
   e1/ha use their pair's state-adapted maps; R uses the ground map. *)
dpIntegrate[a_, c_, integrand_] :=
  With[{\[Omega] = \[HBar]\[Omega]00[a, c], rmax = a bxRmax},
   With[{me = bxStateMaps[\[Omega], rmax, bxElectronStates],
         mh = bxStateMaps[\[Omega], rmax, bxHoleStates],
         mR = bxStateMaps[\[Omega], rmax, {{1, 0, 0}}]},
    NIntegrate[
     Module[{r1 = me["rFromV"][v1], u1 = me["uFromX"][x1],
       ra = mh["rFromV"][va], ua = mh["uFromX"][xa],
       rR = mR["rFromV"][vR], uR = mR["uFromX"][xR]},
      integrand[u1, r1, \[Theta]1, ua, ra, \[Theta]a, uR, rR] *
       me["rJac"][r1] mh["rJac"][ra] mR["rJac"][rR] *
       me["uJac"][u1] mh["uJac"][ua] mR["uJac"][uR]],
     {v1, 0, 1}, {x1, 0, 1}, {\[Theta]1, 0, 2 \[Pi]},
     {va, 0, 1}, {xa, 0, 1}, {\[Theta]a, 0, 2 \[Pi]},
     {vR, 0, 1}, {xR, 0, 1},
     Method -> {"AdaptiveQuasiMonteCarlo", "BisectionDithering" -> 0,
       "MaxPoints" -> dpMaxPoints},
     AccuracyGoal -> Infinity, PrecisionGoal -> bxPrecisionGoal,
     WorkingPrecision -> MachinePrecision]]];

(* unnormalized pair-creation amplitude Atilde.
   exE, exH: the exciton's electron/hole states; \[Alpha]X its Jastrow parameter.
   XX configuration from the globals; created pair = second slots of Phi_e,
   Phi_h evaluated at R.  Complex integrand; the result's imaginary part is a
   quadrature-noise gauge and is returned for inspection. *)
bxPairCreationAmp[a_?NumericQ, c_?NumericQ, exE_, exH_, \[Alpha]X_?NumericQ,
   {\[Alpha]_?NumericQ, \[Beta]_?NumericQ, \[Gamma]_?NumericQ, \[Delta]_?NumericQ}] :=
  With[{\[Omega] = \[HBar]\[Omega]00[a, c]},
   (2 \[Pi]) dpIntegrate[a, c,
     Function[{u1, r1, \[Theta]1, ua, ra, \[Theta]a, uR, rR},
      Module[{r1a, r1R, raR, g, p, q},
       r1a = rPair[a, c][u1, r1, \[Theta]1, ua, ra, \[Theta]a];
       r1R = rPair[a, c][u1, r1, \[Theta]1, uR, rR, 0];
       raR = rPair[a, c][ua, ra, \[Theta]a, uR, rR, 0];
       g = raR^\[Gamma] Exp[-\[Delta] raR];
       p = Exp[-\[Alpha] r1a - \[Beta] (r1R + raR)];
       q = Exp[-\[Alpha] (r1R + raR) - \[Beta] r1a];
       dpPairAmp[\[Omega], bxEtaE, bxElectronStates[[1]], bxElectronStates[[2]]][
          u1, r1, \[Theta]1, uR, rR, 0] *
        dpPairAmp[\[Omega], bxEtaH, bxHoleStates[[1]], bxHoleStates[[2]]][
          ua, ra, \[Theta]a, uR, rR, 0] *
        g (p + q) *
        Conjugate[dpOrb[\[Omega]][exE][u1, r1, \[Theta]1]] *
        Conjugate[dpOrb[\[Omega]][exH][ua, ra, \[Theta]a]] *
        Exp[-\[Alpha]X r1a] *
        r1 ra rR]]]];

(* normalized transition element M (cs = 2 included) and diagnostics.
   \[Alpha]X, exciton states -> its norm; XX params -> its norms; all consistent
   with the production conventions (N_XX = 2 (nD + nX), normExciton(0) = 1). *)
bxDipoleXtoXX[a_?NumericQ, c_?NumericQ, exE_, exH_, \[Alpha]X_?NumericQ,
   {\[Alpha]_?NumericQ, \[Beta]_?NumericQ, \[Gamma]_?NumericQ, \[Delta]_?NumericQ}] :=
  Module[{amp, nX, nD, nXX, m},
   amp = bxPairCreationAmp[a, c, exE, exH, \[Alpha]X, {\[Alpha], \[Beta], \[Gamma], \[Delta]}];
   Block[{exElectronState = exE, exHoleState = exH},
    nX = normExciton[a, c, \[Alpha]X]];
   nD = normDirectBiexciton[a, c, \[Alpha], \[Beta], \[Gamma], \[Delta]];
   nXX = normCrossBiexciton[a, c, \[Alpha], \[Beta], \[Gamma], \[Delta]];
   m = 2 Re[amp]/Sqrt[2 (nD + nXX) nX];
   <|"M" -> m, "M/cs" -> m/2, "f-factor |M|^2" -> m^2,
     "amp" -> Re[amp], "ampIm(noise gauge)" -> Im[amp],
     "normX" -> nX, "normXX" -> 2 (nD + nXX)|>];

(* exact test: all correlations off -> M/cs = Sqrt[2] for the ground config *)
bxDipoleLimitTest[a_?NumericQ, c_?NumericQ] :=
  Block[{bxElectronStates = {{1, 0, 0}, {1, 0, 0}},
    bxHoleStates = {{1, 0, 0}, {1, 0, 0}}, bxEtaE = 1, bxEtaH = 1},
   Module[{r = bxDipoleXtoXX[a, c, {1, 0, 0}, {1, 0, 0}, 0., {0., 0., 0., 0.}]},
    Append[r, <|"exact M/cs" -> Sqrt[2.],
      "relError" -> Abs[r["M/cs"]/Sqrt[2.] - 1]|>]]];
