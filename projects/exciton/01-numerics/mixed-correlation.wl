(* ::Package:: *)

(* ============================================================================
   mixed-correlation.wl  --  electron-hole distance (orbital-independent)
   ----------------------------------------------------------------------------
   Copied verbatim from the Exciton section of Biexciton.nb. The Jastrow factor
   F = Exp[-\[Alpha] rEH] depends only on the electron-hole separation, not on the
   single-particle states, so it is unchanged for the mixed-state computation.
   (The electron sits at azimuth 0 and the hole at angle \[Theta]; only the relative
   angle enters.)

   Depends on: definitions.wl  (provides w).
   ============================================================================ *)

(* wipe any stale definitions from a previous Get *)
ClearAll[eps2, rEH];

eps2 = 10^-4;

rEH[a_, c_][u1_, r1_, ua_, ra_, \[Theta]_] :=
  Module[{z1 = u1 w[a, c][r1], za = ua w[a, c][ra]},
   Sqrt[(z1 - za)^2 + r1^2 + ra^2 - 2 r1 ra Cos[\[Theta]] + eps2]];
