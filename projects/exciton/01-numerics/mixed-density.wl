(* ::Package:: *)

(* ============================================================================
   mixed-density.wl  --  exciton density for arbitrary electron / hole states
   ----------------------------------------------------------------------------
   Generalizes psiWeightExciton (originally hard-coded to electron and hole in
   the lowest state) to arbitrary single-particle states. The electron and hole
   are distinguishable, so there is no antisymmetrization and no exchange term:
   the density is just the product of the two one-body densities.

   Depends on: definitions.wl  (provides \[Psi]r).

   Each state is {\[Nu], n, m}. Configure the two states, then load
   mixed-integrals.wl.

       exElectronState = {\[Nu], n, m};
       exHoleState     = {\[Nu], n, m};
   ============================================================================ *)

(* wipe any stale definitions from a previous Get (old argument patterns would
   otherwise survive a re-Get and shadow updated ones).
   NOTE: this resets the state configuration to the defaults below -- set
   exElectronState/exHoleState AFTER Get-ing this file. *)
ClearAll[exElectronState, exHoleState, exZAmp, exOrbAmp,
  psiWeightExcitonMixed];

(* ---- default configuration: electron and hole in the lowest state ---------- *)
exElectronState = {1, 0, 0};
exHoleState     = {1, 0, 0};

(* ---- z amplitude in u-coordinates, z-Jacobian (dz = w du) folded in ---------
   |\[Psi]z[\[Nu]]|^2 w = 2 Sin[\[Nu] \[Pi] u]^2, hence amplitude Sqrt[2] Sin[\[Nu] \[Pi] u]. *)
exZAmp[\[Nu]_][u_] := Sqrt[2] Sin[\[Nu] \[Pi] u];

(* ---- real single-particle amplitude (phase e^{I m \[CurlyPhi]} drops in |.|^2) ---- *)
exOrbAmp[\[Omega]_][{\[Nu]_, n_, m_}][u_, r_] := exZAmp[\[Nu]][u] \[Psi]r[n, m][\[Omega], r];

(* ---- exciton weight: electron density x hole density ----------------------- *)
psiWeightExcitonMixed[a_, c_, \[Omega]_][u1_, r1_, ua_, ra_] :=
  exOrbAmp[\[Omega]][exElectronState][u1, r1]^2 *
  exOrbAmp[\[Omega]][exHoleState][ua, ra]^2;
