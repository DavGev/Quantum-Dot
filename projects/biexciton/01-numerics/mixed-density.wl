(* ::Package:: *)

(* ============================================================================
   mixed-density.wl  --  antisymmetrized uncorrelated biexciton density
   ----------------------------------------------------------------------------
   Generalizes psiWeightBiexciton (originally hard-coded to all four particles
   in the lowest state) to arbitrary single-particle states.

   Depends on: definitions.wl  (provides \[Psi]r, w, \[HBar]\[Omega]00, ...)

   Each particle state is {\[Nu], n, m}. Configure the four states and the two
   spatial exchange signs, then load mixed-integrals.wl.

       bxElectronStates = {{\[Nu],n,m}, {\[Nu],n,m}};   (* electrons 1, 2 *)
       bxHoleStates     = {{\[Nu],n,m}, {\[Nu],n,m}};   (* holes a, b     *)
       bxEtaE, bxEtaH \[Element] {+1,-1}   (* +1 spin-singlet (spatially symmetric),
                                 -1 spin-triplet (spatially antisymmetric) *)

   Density:  |\[CapitalPsi]0|^2 = \[Rho]e(1,2) \[Rho]h(a,b)  with the two-fermion exchange density
       \[Rho](I,J) = 1/2 [n1(I) n2(J) + n2(I) n1(J)] + \[Eta] Re[\[Chi](I) Conjugate[\[Chi](J)]] ,
       n_k(X) = |amp_k(X)|^2,  \[Chi](X) = amp_1(X) amp_2(X) e^{I (m1-m2) \[Theta]X}.
   \[Rho](I,J) is invariant under I<->J, so the symmetry-reduced integral forms
   inherited from the all-ground-state code stay valid.

   For a pair sharing one orbital the antisymmetrized form carries a harmless
   overall constant; that case is detected and the plain product is used, so the
   all-ground-state configuration reproduces the original notebook exactly.
   ============================================================================ *)

(* wipe any stale definitions from a previous Get (old argument patterns would
   otherwise survive a re-Get and shadow updated ones).
   NOTE: this resets the state configuration to the defaults below -- set
   bxElectronStates/bxHoleStates/bxEtaE/bxEtaH AFTER Get-ing this file. *)
ClearAll[bxElectronStates, bxHoleStates, bxEtaE, bxEtaH,
  bxZAmp, bxOrbAmp, bxPairDensity, psiWeightBiexcitonMixed];

(* ---- default configuration: all four particles in the lowest state --------- *)
bxElectronStates = {{1, 0, 0}, {1, 0, 0}};
bxHoleStates     = {{1, 0, 0}, {1, 0, 0}};
bxEtaE = 1;
bxEtaH = 1;

(* ---- z amplitude in u-coordinates, z-Jacobian (dz = w du) folded in ---------
   |\[Psi]z[\[Nu]]|^2 w = 2 Sin[\[Nu] \[Pi] u]^2, hence amplitude Sqrt[2] Sin[\[Nu] \[Pi] u]. *)
bxZAmp[\[Nu]_][u_] := Sqrt[2] Sin[\[Nu] \[Pi] u];

(* ---- real single-particle amplitude (phase e^{I m \[CurlyPhi]} handled via Cos below) ---- *)
bxOrbAmp[\[Omega]_][{\[Nu]_, n_, m_}][u_, r_] := bxZAmp[\[Nu]][u] \[Psi]r[n, m][\[Omega], r];

(* ---- two-fermion exchange density for a pair in states s1, s2 ---------------
   evaluated at points (uI,rI,\[Theta]I) and (uJ,rJ,\[Theta]J). *)
bxPairDensity[\[Omega]_, \[Eta]_, s1_, s2_][uI_, rI_, \[Theta]I_, uJ_, rJ_, \[Theta]J_] :=
  If[s1 === s2,
   (* same orbital: plain product (no double counting) *)
   bxOrbAmp[\[Omega]][s1][uI, rI]^2 bxOrbAmp[\[Omega]][s1][uJ, rJ]^2,
   (* distinct orbitals: full antisymmetrized density *)
   Module[{a1I, a2I, a1J, a2J, m1 = s1[[3]], m2 = s2[[3]], direct, exch},
    a1I = bxOrbAmp[\[Omega]][s1][uI, rI]; a2I = bxOrbAmp[\[Omega]][s2][uI, rI];
    a1J = bxOrbAmp[\[Omega]][s1][uJ, rJ]; a2J = bxOrbAmp[\[Omega]][s2][uJ, rJ];
    direct = (1/2) (a1I^2 a2J^2 + a2I^2 a1J^2);
    exch   = \[Eta] (a1I a2I) (a1J a2J) Cos[(m1 - m2) (\[Theta]I - \[Theta]J)];
    direct + exch]];

(* ---- full biexciton weight: electron pair (1,2) x hole pair (a,b) -----------
   hole a is fixed at \[CurlyPhi]=0, so its angle argument is 0. *)
psiWeightBiexcitonMixed[a_, c_, \[Omega]_][
   u1_, r1_, \[Theta]1_, u2_, r2_, \[Theta]2_, ua_, ra_, ub_, rb_, \[Theta]b_] :=
  bxPairDensity[\[Omega], bxEtaE, bxElectronStates[[1]], bxElectronStates[[2]]][
     u1, r1, \[Theta]1, u2, r2, \[Theta]2] *
  bxPairDensity[\[Omega], bxEtaH, bxHoleStates[[1]], bxHoleStates[[2]]][
     ua, ra, 0, ub, rb, \[Theta]b];
