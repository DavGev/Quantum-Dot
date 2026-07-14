(* ::Package:: *)

(* ============================================================================
   mixed-correlation.wl  --  correlation factors and kinetic gradient kernels
   ----------------------------------------------------------------------------
   Orbital-independent: copied verbatim from Biexciton.nb. These depend only on
   the Jastrow correlation factor F = G(P+Q), not on the single-particle states,
   so they are unchanged for the mixed-state computation.

   Depends on: definitions.wl  (provides w).
   Argument-order convention (must match mixed-integrals.wl):
     G/P/Q :  u1,r1,u2,r2,ua,ra,ub,rb,\[Theta]1,\[Theta]2,\[Theta]b, params
     kernels: u1,r1,\[Theta]1,u2,r2,\[Theta]2,ua,ra,ub,rb,\[Theta]b, params
   ============================================================================ *)

(* wipe any stale definitions from a previous Get (old argument patterns would
   otherwise survive a re-Get and shadow updated ones) *)
ClearAll[eps2, rPair, Gcorr, Pcorr, Qcorr, gradR, dotGrad,
  gradLogG1, gradLogP1, gradLogQ1, gradLogGa, gradLogPa, gradLogQa,
  DeP, DeQ, Xe, DhP, DhQ, Xh];

eps2 = 10^-4;

(* ---- full 3D pair distance in u-coordinates (z-Jacobian handled in density) - *)
rPair[a_, c_][ui_, ri_, \[Phi]i_, uj_, rj_, \[Phi]j_] :=
  Module[{zi = ui w[a, c][ri], zj = uj w[a, c][rj]},
   Sqrt[(zi - zj)^2 + ri^2 + rj^2 - 2 ri rj Cos[\[Phi]i - \[Phi]j] + eps2]];

(* ---- correlation factors -------------------------------------------------- *)
Gcorr[a_, c_][u1_, r1_, u2_, r2_, ua_, ra_, ub_, rb_,
    \[Theta]1_, \[Theta]2_, \[Theta]b_, \[Gamma]_, \[Delta]_] :=
  Module[{rab},
   rab = rPair[a, c][ua, ra, 0, ub, rb, \[Theta]b];
   rab^\[Gamma] Exp[-\[Delta] rab]];

Pcorr[a_, c_][u1_, r1_, u2_, r2_, ua_, ra_, ub_, rb_,
    \[Theta]1_, \[Theta]2_, \[Theta]b_, \[Alpha]_, \[Beta]_] :=
  Module[{r1a, r2b, r1b, r2a},
   r1a = rPair[a, c][u1, r1, \[Theta]1, ua, ra, 0];
   r2b = rPair[a, c][u2, r2, \[Theta]2, ub, rb, \[Theta]b];
   r1b = rPair[a, c][u1, r1, \[Theta]1, ub, rb, \[Theta]b];
   r2a = rPair[a, c][u2, r2, \[Theta]2, ua, ra, 0];
   Exp[-\[Alpha] (r1a + r2b) - \[Beta] (r1b + r2a)]];

Qcorr[a_, c_][u1_, r1_, u2_, r2_, ua_, ra_, ub_, rb_,
    \[Theta]1_, \[Theta]2_, \[Theta]b_, \[Alpha]_, \[Beta]_] :=
  Module[{r1a, r2b, r1b, r2a},
   r1a = rPair[a, c][u1, r1, \[Theta]1, ua, ra, 0];
   r2b = rPair[a, c][u2, r2, \[Theta]2, ub, rb, \[Theta]b];
   r1b = rPair[a, c][u1, r1, \[Theta]1, ub, rb, \[Theta]b];
   r2a = rPair[a, c][u2, r2, \[Theta]2, ua, ra, 0];
   Exp[-\[Beta] (r1a + r2b) - \[Alpha] (r1b + r2a)]];

(* ---- gradient of a pair distance (z, r, angular components) ---------------- *)
gradR[a_, c_][ui_, ri_, \[Phi]i_, uj_, rj_, \[Phi]j_] :=
  Module[{zi, zj, dist, dphi},
   zi = ui w[a, c][ri];
   zj = uj w[a, c][rj];
   dphi = \[Phi]i - \[Phi]j;
   dist = rPair[a, c][ui, ri, \[Phi]i, uj, rj, \[Phi]j];
   {(zi - zj)/dist,
    (ri - rj Cos[dphi])/dist,
    (rj Sin[dphi])/dist}];

dotGrad[v_, w_] := v . w;

(* ---- log-derivatives of G, P, Q for electron 1 and hole a ----------------- *)
gradLogG1[a_, c_][u1_, r1_, \[Theta]1_, u2_, r2_, \[Theta]2_, ua_, ra_, ub_, rb_,
    \[Theta]b_, \[Gamma]_, \[Delta]_] := {0, 0, 0};

gradLogP1[a_, c_][u1_, r1_, \[Theta]1_, u2_, r2_, \[Theta]2_, ua_, ra_, ub_, rb_,
    \[Theta]b_, \[Alpha]_, \[Beta]_] :=
  Module[{gr1a, gr1b},
   gr1a = gradR[a, c][u1, r1, \[Theta]1, ua, ra, 0];
   gr1b = gradR[a, c][u1, r1, \[Theta]1, ub, rb, \[Theta]b];
   -\[Alpha] gr1a - \[Beta] gr1b];

gradLogQ1[a_, c_][u1_, r1_, \[Theta]1_, u2_, r2_, \[Theta]2_, ua_, ra_, ub_, rb_,
    \[Theta]b_, \[Alpha]_, \[Beta]_] :=
  Module[{gr1a, gr1b},
   gr1a = gradR[a, c][u1, r1, \[Theta]1, ua, ra, 0];
   gr1b = gradR[a, c][u1, r1, \[Theta]1, ub, rb, \[Theta]b];
   -\[Beta] gr1a - \[Alpha] gr1b];

gradLogGa[a_, c_][u1_, r1_, \[Theta]1_, u2_, r2_, \[Theta]2_, ua_, ra_, ub_, rb_,
    \[Theta]b_, \[Gamma]_, \[Delta]_] :=
  Module[{rab, grab},
   rab = rPair[a, c][ua, ra, 0, ub, rb, \[Theta]b];
   grab = gradR[a, c][ua, ra, 0, ub, rb, \[Theta]b];
   (\[Gamma]/rab - \[Delta]) grab];

gradLogPa[a_, c_][u1_, r1_, \[Theta]1_, u2_, r2_, \[Theta]2_, ua_, ra_, ub_, rb_,
    \[Theta]b_, \[Alpha]_, \[Beta]_] :=
  Module[{gra1, gra2},
   gra1 = gradR[a, c][ua, ra, 0, u1, r1, \[Theta]1];
   gra2 = gradR[a, c][ua, ra, 0, u2, r2, \[Theta]2];
   -\[Alpha] gra1 - \[Beta] gra2];

gradLogQa[a_, c_][u1_, r1_, \[Theta]1_, u2_, r2_, \[Theta]2_, ua_, ra_, ub_, rb_,
    \[Theta]b_, \[Alpha]_, \[Beta]_] :=
  Module[{gra1, gra2},
   gra1 = gradR[a, c][ua, ra, 0, u1, r1, \[Theta]1];
   gra2 = gradR[a, c][ua, ra, 0, u2, r2, \[Theta]2];
   -\[Beta] gra1 - \[Alpha] gra2];

(* ---- kinetic kernels D^(P), D^(Q) and X for electrons and holes ----------- *)
DeP[a_, c_][u1_, r1_, \[Theta]1_, u2_, r2_, \[Theta]2_, ua_, ra_, ub_, rb_,
    \[Theta]b_, \[Alpha]_, \[Beta]_, \[Gamma]_, \[Delta]_] :=
  Module[{v},
   v = gradLogG1[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Gamma], \[Delta]] +
       gradLogP1[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Alpha], \[Beta]];
   dotGrad[v, v]];

DeQ[a_, c_][u1_, r1_, \[Theta]1_, u2_, r2_, \[Theta]2_, ua_, ra_, ub_, rb_,
    \[Theta]b_, \[Alpha]_, \[Beta]_, \[Gamma]_, \[Delta]_] :=
  Module[{v},
   v = gradLogG1[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Gamma], \[Delta]] +
       gradLogQ1[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Alpha], \[Beta]];
   dotGrad[v, v]];

Xe[a_, c_][u1_, r1_, \[Theta]1_, u2_, r2_, \[Theta]2_, ua_, ra_, ub_, rb_,
    \[Theta]b_, \[Alpha]_, \[Beta]_, \[Gamma]_, \[Delta]_] :=
  Module[{vP, vQ},
   vP = gradLogG1[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Gamma], \[Delta]] +
        gradLogP1[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Alpha], \[Beta]];
   vQ = gradLogG1[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Gamma], \[Delta]] +
        gradLogQ1[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Alpha], \[Beta]];
   dotGrad[vP, vQ]];

DhP[a_, c_][u1_, r1_, \[Theta]1_, u2_, r2_, \[Theta]2_, ua_, ra_, ub_, rb_,
    \[Theta]b_, \[Alpha]_, \[Beta]_, \[Gamma]_, \[Delta]_] :=
  Module[{v},
   v = gradLogGa[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Gamma], \[Delta]] +
       gradLogPa[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Alpha], \[Beta]];
   dotGrad[v, v]];

DhQ[a_, c_][u1_, r1_, \[Theta]1_, u2_, r2_, \[Theta]2_, ua_, ra_, ub_, rb_,
    \[Theta]b_, \[Alpha]_, \[Beta]_, \[Gamma]_, \[Delta]_] :=
  Module[{v},
   v = gradLogGa[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Gamma], \[Delta]] +
       gradLogQa[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Alpha], \[Beta]];
   dotGrad[v, v]];

Xh[a_, c_][u1_, r1_, \[Theta]1_, u2_, r2_, \[Theta]2_, ua_, ra_, ub_, rb_,
    \[Theta]b_, \[Alpha]_, \[Beta]_, \[Gamma]_, \[Delta]_] :=
  Module[{vP, vQ},
   vP = gradLogGa[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Gamma], \[Delta]] +
        gradLogPa[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Alpha], \[Beta]];
   vQ = gradLogGa[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Gamma], \[Delta]] +
        gradLogQa[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Alpha], \[Beta]];
   dotGrad[vP, vQ]];
