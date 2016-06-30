(******************************************************************************
 *                                                                            *
 * Package for automatized Mellin-Barnes techniques                           *
 *                                                                            *
 * M. Czakon, 10 Oct 05                                                       *
 *                                                                            *
 * Change log:                                                                *
 *                                                                            *
 *  4 Dec 05 - added numeric interface consisting of MBintegrate,             *
 *             MBshiftContours, MBfortranForm, MBmap and MBnorm               *
 *                                                                            *
 * 29 Jun 16 - switched from Fortran integration to C                         *
 *                                                                            *
 ******************************************************************************)

Print["MB 1.2"];
Print["by Michal Czakon"];
Print["improvements by Alexander Smirnov"];
Print["switched to C integration by Andrey Pikelner"];
Print["more info in hep-ph/0511200"]; 
Print["last modified 29 Jun 16"];

BeginPackage["MB`"]

(******************************************************************************
 *                                                                            *
 * Public                                                                     *
 *                                                                            *
 ******************************************************************************)

MBrules::usage = "MBrules[integrand, constraints, fixedVars] determines real
parts of fixed and integration variables such that the arguments of all Gamma
and PolyGamma functions in the integrand be positive. It is only necessary to 
specify the fixed variables, fixedVars, since the integration variables are
determined automatically. The user can also specify further constraints.\n\n
MBrules[integrand, limit, constraints, fixedVars] determines the contours such
that during analytic continuation no contour starts or ends on a pole."

MBoptimizedRules::usage = "MBoptimizedRules[integrand, limit, constraints,
fixedVars] determines optimized real parts of fixed and integration variables,
which generate the smallest number of residues. In case of a large number of
residues, one can set a limit to the number of levels, which are optimized with
the Level option. For a detailed description see MBrules and MBcontinue."

MBcorrectContours::usage = "MBcorrectContours[{fixedVarRules, intVarRules},
shift] shifts all the intVarRules by inverses of primes starting at
Prime[shift]. This can be used to avoid poles running into contours."

MBresidues::usage = "MBresidues[integrand, limit, {fixedVarRules, intVarRules}]
generates a list of residues obtained by continuing the integral given by the
integrand and the vertical integration contours in the complex plane whose real
parts are specified in intVarRules. The continuation is done to the point given
in limit. The starting point should be given in fixedVarRules. The result
contains either MBint objects where the limit has been attained, or MBitc
objects, which should be further continued. If one of the integration contours
starts or ends on a pole the process is stopped and the user has to give
different contours.\n\n
If the user is only interested in the number of integrals in the final
result, the option Skeleton -> True should be set. It might happen that there
are cancellations of the singular behaviour between the numerator and the
denominator, in which case this number will be overestimated. With the option
set, Gamma and PolyGamma functions are replaced by MBgam. With Residues -> True
two lists will be created. The first contains the details of the residues in
MBres[sign, var, val], where sign is the sign of the residue, which is taken in
var at the point val, and the second is as before."

MBresidue::usage = "MBresidue[expr, {x, x0}] replacement for the Residue
function, which is correct under the assumption that the residue is generated
by Gamma and PolyGamma functions."

MBshiftRules::usage = "MBshiftRules[dx] rules that regularize Gamma's and
PolyGamma's with argument m+a*dx, where m is a nonpositive integer."

MBexpansionRules::usage = "MBexpansionRules[dx, order] rules that expand Gamma's
and PolyGamma's with argument m+a*dx up to given order, under the assumption
that m is not a nonpositive integer."

MBcontinue::usage = "MBcontinue[integrand, limit, {fixedVarRules, intVarRules}]
analytically continues an MB integral (for a detailed description see
MBresidues). The iterative process uses at each step MBresidues and can be
stopped at a given point with the option Level."

MBmerge::usage = "MBmerge[integrals] merges integrals with the same integration
contours."

MBpreselect::usage = "MBpreselect[integrals, {x, x0, n}] rejects integrals which
vanish in the specified order n of expansion in x around x0."

MBexpand::usage = "MBexpand[integrals, norm, {x, x0, n}] expands integrals in
the specified order n of expansion in x around x0. A normalization factor norm
is applied to every integrand."

MBshiftContours::usage = "MBshiftContours[integrals] shifts the contours such
that the arguments of the Gamma and PolyGamma functions are as far away from the
poles as possible. It is assumed that the arguments contain only integration
variables, which is the case after expansion in all fixed parameters. This
function is used internally by MBintegrate.\n\n
MBshiftContours[integrals, newRules] shifts the contours such that they are at
the positions given on the newRules list."

MBshiftVars::usage = "MBshiftVars[integrals] shifts variables in all integrals
such that the exponents have just a single integration variable."

MBreplaceVar::usage = "MBreplaceVar[MBint[integrand, rules], var -> var0]
makes the replacement in the integrand and the contours, if var0 contains var."

MBfortranForm::usage = "MBfortranForm[stream, x, expression] writes an
expression of the form x = expression to the stream in Fortran form. The output
of FortranForm is corrected to have the correct syntax of double precision
constants and fit into 72 columns as required by the Fortran standard. This
function is used internally by MBintegrate."

MBcForm::usage = "MBcForm[stream, x, expression] writes an
expression of the form x = expression to the stream in C form. This
function is used internally by MBintegrate."

MBmap::usage = "MBmap[z_, x_] is a mapping transformation from the range
[z - I+Infinity, z + I*Infinity], to [0, 1], as in\n\n
1/(2*Pi*I)*Integrate[f[z + I*x], {x, -Infinity, Infinity}] =
1/(2*Pi)*Integrate[MBnorm[x]*f[MBmap[z, x]], {x, 0, 1}]\n\n
This transformation is used internally by MBintegrate."

MBnorm::usage = "MBnorm[x_] for a detailed description see MBmap."

MBintegrate::usage = "MBintegrate[integrals, kinematics] numerically integrates
a list of integrals expanded in some variable with the values of the parameters
as given on the kinematics list. The input should be as produced by MBexpand.
Multiple integrals are evaluated in Fortran with the help of the CERN library
implementation of the Gamma and PolyGamma functions and of the Cuhre and Vegas
integration routines from CUBA. The libraries libmathlib.a, libkernlib.a and
libcuba.a should be available, the compilation is performed with f77. The output
is a list containing the value of the integral and the error estimates on the
real and imaginary parts. Optionally the contributions of all the numerical
integrations can be given, if option Debug is set to True. In this case, the
numerical results are contained in MBval[value, error, probability, part],
where probability is the probability that the error is underestimated, and part
is the part number of the integral.\n\n
Option description:\n\n
NamePrefix - by default the Fortran programs are called MBpart1x0, etc. where
the last number is the power of the expansion variable x. with this option one
can change MB to become NamePrefix.\n\n
PrecisionGoal, AccuracyGoal, MaxPoints, MaxRecursion, Method, WorkingPrecision
- numerical integration options as in the NIntegrate function.\n\n
MaxNIntegrateDim - dimension threshold, above which Cuhre or Vegas will be used
for the evaluation of the integrals. Should be at least 1.\n\n
MaxCuhreDim - dimension threshold, above which Vegas will be used for the
evaluation of the integrals.\n\n
PseudoRandom - by default Vegas uses Sobol quasi-random numbers. if this
option is set to true, Mersenne Twister pseudo-random numbers will be used.\n\n
Complex - by default, only the real part of the integrals is evaluated, with
this option set to True, the imaginary part will also be given.\n\n
FixedContours - contours will not be shifted if this option is set to True\n\n
NoHigherDimensional - by default, the complete integration is performed within
MBintegrate, however with this option, 1-dimensional integrals are evaluated and
the Fortran programs are prepared, but not run. This may be used to run them in
parallel for example.\n\n
Debug - with this option set to True, the Fortran programs are kept after
evaluation and the value of every integral given in the output as described
above.\n\n
ContourDebug - with this options set to True, MBshiftContours will print contour
optimization information."

MBapplyBarnes::usage = "MBapplyBarnes[integrals] applies Barnes Lemmas
recursively."

barnes1::usage = "barnes1[z] applies the first Barnes lemma in the variable z."

barnes2::usage = "barnes2[z] applies the second Barnes lemma in the variable z."

Barnes1::usage = "Barnes1[MBint[integrand, {fixedVarRules, intVarRules}], z]
applies the first Barnes lemma to an integral, MBint, taking into account the
integration contours."

Barnes2::usage = "Barnes2[MBint[integrand, {fixedVarRules, intVarRules}], z]
applies the second Barnes lemma to an integral, MBint, taking into account the
integration contours."

FUPolynomials::usage = "FUPolynomials[integrand, momenta, kinematics] gives the
F and U polynomials, as well as the M and Q matrices for a Feynman integrand
given by a product of propagators\n\n
DS[k, m, n] = 1/(k^2-m^2)^n\n\n
The notation is the same as in\n\n
T. Binoth and G. Heinrich, Nucl. Phys. B585 (2000) 741."

a0::usage = "a0[ms, l] vacuum graph with one massive line to power l. a0[ms, l1,
l2] vacuum graph with one massive (power l1) and one massless line (power l2)."

b0::usage = "b0[ps, l1, l2] fully massless b0 function."

b0OS::usage = "b0OS[ps, l1, l2] on-shell b0 function. the power of the massive
line is l2."

c0::usage = "c0[ps, l1, l2, l3] fully massless c0 function with two massless
external lines. the power of the internal line that connects to both of them is
l3."

MBint::usage = "MBint[integrand, {fixedVarRules, intVarRules}] is a
Mellin-Barnes integral specified by the integrand and the values of the real
parts of the fixed, fixedVarRules, and integration, intVarRules, variables."

MBitc::usage = "MBitc[integrand, limit, {fixedVarRules, intVarRules}] is a
Mellin-Barnes integral specified by the integrand and the values of the real
parts of the fixed, fixedVarRules, and integration, intVarRules, variables. The
integral still requires analytic continuation to the limit."

MBres::usage = "MBres[sign, var, val] denotes a residue, which is taken in var
at the point val, with sign."

MBgam::usage = "MBgam[z] is a replacement for Gamma and PolyGamma functions used
by MBresidues, when the Skeleton option is set to True."

MBval::usage = "MBval[value, error, probability, part] is the value of a
numerical integral, generated with MBintegrate. part is the index of the
integral on the list of the integrals to evaluate."

ep::usage = "dimensional regularization parameter for the 1-loop integrals"

Options[MBoptimizedRules] = {
  Level -> Infinity
};

Options[MBresidues] = {
  Skeleton -> False,
  Residues -> False,
  Verbose -> True
};

Options[MBcontinue] = {
  Level -> Infinity,
  Skeleton -> False,
  Residues -> False,
  Verbose -> True
};

Options[MBshiftContours] = {
  Verbose -> False
};

Options[MBintegrate] = {
    CubaCores  -> 0,
    NamePrefix -> "MB",
    PrecisionGoal -> 4,
    AccuracyGoal -> 12,
    MaxPoints -> 1000000,
    MaxRecursion -> 1000,
    Method -> DoubleExponential,
    WorkingPrecision -> $MachinePrecision,
    MaxNIntegrateDim -> 1,
    MaxCuhreDim -> 4,
    PseudoRandom -> False,
    Complex -> False,
    FixedContours -> False,
    NoHigherDimensional -> False,
    Debug -> False,
    ContourDebug -> False,
    Verbose -> True
};

Begin["`Private`"]

(******************************************************************************
 *                                                                            *
 * Private                                                                    *
 *                                                                            *
 ******************************************************************************)

MBrules::norules = "no rules could be found to regulate this integral";

MBrules[integrand_, constraints_List, fixedVars_List] := 
Block[{fixedMap, args, integrationVars, inequalities, instance}, 

  fixedMap = (# -> 0 & ) /@ fixedVars;

  args = Cases[{integrand}, (Gamma|PolyGamma)[___, x_] -> x, -1];
  integrationVars = Union[Cases[args /. fixedMap, x_Symbol, -1]];
  inequalities =
    Union[Cases[{integrand},(Gamma|PolyGamma)[___,x_] :> x > 0, -1]];

  instance = FindInstance[
    Join[constraints, inequalities],
    Join[fixedVars, integrationVars]];

  If[instance === {}, 
    Message[MBrules::norules];
    Return[{}]];

  Return[Map[(# -> (# /. First[instance])) & ,
    {fixedVars, integrationVars}, {2}]]]

(******************************************************************************)

MBrules[integrand_, limit_Rule, constraints_List, fixedVars_List] := 
Block[{const = constraints, rules, residues},

  While[True,
    rules = MBrules[integrand, const, fixedVars]; 
    If[rules === {}, Break[]];

    residues = MBcontinue[integrand, limit, rules,
      Verbose -> False, Skeleton -> True, Residues -> True]; 

    If[Head[residues] =!= List, AppendTo[const, residues], Break[]]]; 

  Return[rules]]

(******************************************************************************)

MBoptimizedRules[integrand_,
                 limit_Rule,
                 constraints_List,
                 fixedVars_List,
                 options___Rule] :=

Block[{opt = ParseOptions[MBoptimizedRules, options], level,
  const = constraints, rules, residues, additional}, 

  level = Level /. opt;

  (* first pass, modify constraints to eliminate contours which start or end
     on a pole of some Gamma or PolyGamma function *)

  While[True,
    rules = MBrules[integrand, const, fixedVars]; 
    If[rules === {}, Break[]];

    residues = MBcontinue[integrand, limit, rules,
      Level -> level, Skeleton -> True, Residues -> True, Verbose -> False];

    If[Head[residues] =!= List, AppendTo[const, residues], Break[]]]; 

  If[rules === {}, Return[{}]];

  (* second pass, find rules which eliminate as many residues as possible *)

  const = constraints;
  additional = ((#1*(#2-#3) > 0 & ) @@ #1 & ) /@ residues[[1]] /. limit;

  Do[
    If[FreeQ[Take[additional, i-1], additional[[i]]],
      rules = MBrules[integrand, Append[const, additional[[i]]], fixedVars];
      If[rules =!= {}, AppendTo[const, additional[[i]]]]],
  {i, Length[additional]}];

  (* third pass, the same as the first *)

  While[True, 
    rules = MBrules[integrand, const, fixedVars]; 

    residues = MBcontinue[integrand, limit, rules,
      Level -> level, Skeleton -> True, Residues -> True, Verbose -> False];

    If[Head[residues] =!= List, AppendTo[const, residues], Break[]]];

  Return[rules]]

(******************************************************************************)
 
MBcorrectContours[{fixedVarRules_List, intVarRules_List}, shift_Integer] :=
  {fixedVarRules, Table[intVarRules[[i,1]] -> intVarRules[[i,2]] +
    1/Prime[shift + i - 1], {i, Length[intVarRules]}]}

(******************************************************************************)
 
MBresidues::contour = "contour starts and/or ends on a pole of Gamma[`1`]";

MBresidues[integrand_, 
           limit_Rule,
	   {fixedVarRules_List, intVarRules_List},
           options___Rule] :=

Block[{opt = ParseOptions[MBresidues, options], int = Expand[integrand],
  terms, var, pos, args, integrals, residues = {}, v0, v1, dir, intVars,
  constraint = False, pole, z, resVar, resSign, resRule, res, remRules, newVal,
  newIntegrand, j},
	
  (* with the skeleton option, differences between Gamma and PolyGamma are
     ignored, and no real residues are taken *)

  If[Skeleton /. opt, int = int /. (Gamma|PolyGamma)[___, x_] -> MBgam[x]];

  terms = If[Head[int] === Plus, List @@ int, {int}];

  var = First[limit]; 
  pos = Position[fixedVarRules, var][[1,1]];

  (* poles can be generated by Gamma and PolyGamma functions in the numerator,
     as long as they have a nontrivial dependence on integration variables. *)

  args = Union[Flatten[Table[Cases[{Numerator[terms[[i]]]},
    (MBgam|Gamma|PolyGamma)[___, x_] :> x /; !NumberQ[x /. fixedVarRules], -1],
  {i, Length[terms]}]]];

  integrals = Reap[
    Do[
      v0 = args[[i]] /. fixedVarRules /. intVarRules;
      v1 = args[[i]] /. limit /. fixedVarRules /. intVarRules;
      dir = Sign[v1 - v0];
      intVars = Union[Cases[{args[[i]]} /. fixedVarRules, x_Symbol, -1]];

      (* the algorithm gives undefined results,
         if contours start or end on a pole *)

      If[(IntegerQ[v0] && v0 <= 0) || (IntegerQ[v1] && v1 <= 0),
         Message[MBresidues::contour, args[[i]]];
         constraint = First[intVars] != (First[intVars] /. intVarRules);
         Break[]];

      If[dir != 0,

        (* find the nearest non-positive integer in the direction, in which the
           contour is shifted *)

        If[dir > 0, pole = Ceiling[v0], If[v0 < 0, pole = Floor[v0], pole = 0]];

        (* loop over all crossed poles (non-positive integers) *)

        For[z = pole, dir*(v1 - z) >= 0 && z <= 0, z += dir,
	  
          (* choose an integration variable, in which to take the residue.
             try to find one with a unit coefficient *)

          resVar = 0;
          For[j = Length[intVars], j >= 1, --j,
            If[Abs[Coefficient[args[[i]], intVars[[j]]]] == 1,
              resVar = intVars[[j]];
              Break[]]];
          If[resVar === 0, resVar = Last[intVars]];
          resSign = -dir*Sign[Coefficient[args[[i]], resVar]];
          resRule = Expand /@ Solve[args[[i]] == z, resVar][[1,1]]; 
          res = MBres[resSign, Sequence @@ resRule];

          (* do not take the same residue twice *)

          If[Count[residues, res] != 0, Continue[]];

          (* the new contours will not have resVar any more *)

          remRules = DeleteCases[intVarRules, _ ? (MemberQ[#, resVar] & )];

          (* after taking the residue the continued variable is at 
             a different place *)

          newVal = Solve[
            (args[[i]] /. var -> x /. fixedVarRules /. intVarRules) == z,
            x][[1,1]] /. x -> var;

          If[Verbose /. opt,
	     Print["Taking ", If[resSign > 0, "+", "-"],
		   "residue in ", resRule[[1]], " = ", resRule[[2]]]];

          newIntegrand = If[Skeleton /. opt,

            int /. resRule /. MBgam[x_] :> MBgam[Expand[x]] 
              /. MBgam[x_Integer] -> 1,

            resSign*ExpandAll[MBresidue[int, List @@ resRule]]];

          If[newIntegrand === 0,
            If[Verbose /. opt, Print["...no contribution"]],
            AppendTo[residues, res];
            Sow[MBitc[newIntegrand, limit,
              {ReplacePart[fixedVarRules, newVal, pos], remRules}, options]]]]],

    {i, Length[args]}]];

  If[constraint =!= False, Return[constraint]];

  (* the original integral is always on the list *)

  integrals = Append[Flatten[integrals[[2]]],
    MBint[integrand,{ReplacePart[fixedVarRules, limit, pos], intVarRules}]];

  If[Residues /. opt,
     Return[{residues, integrals}],
     Return[integrals]]]

(******************************************************************************)

MBcontinue[integrand_,
           limit_Rule,
           {fixedVarRules_List, intVarRules_List},
           options___Rule] :=

Block[{opt = ParseOptions[MBcontinue, options], level,
  i = 1, pos, result, residues, integrals},

  level = Level /. opt;

  If[Verbose /. opt, Print["Level 1"]];
  result = MBresidues[integrand,limit,{fixedVarRules,intVarRules},options];
  If[Head[result] =!= List, Return[result]];

  If[Residues /. opt,

    residues = result[[1]];
    integrals = result[[2]],

    integrals = result];

  While[(++i <= level) && MemberQ[integrals, MBitc[__], -1],
    If[Verbose /. opt, Print["Level ", i]];
    pos = Position[integrals, MBitc[__], -1]; 

    Do[
      If[Verbose /. opt, Print["Integral ", pos[[j]]]];
      result = MBresidues @@ Extract[integrals, pos[[j]]];
      If[Head[result] =!= List, level = -1; Break[]];

      If[Residues /. opt,

        residues = Join[residues, result[[1]]];
        integrals = ReplacePart[integrals, result[[2]], pos[[j]]],

        integrals = ReplacePart[integrals, result, pos[[j]]]],

    {j, Length[pos]}]];

  If[Head[result] =!= List, Return[result]];

  If[Verbose /. opt, Print[Count[integrals, MBint[__], -1],
    " integral(s) found"]];

  If[Residues /. opt,
    Return[{residues, integrals}],
    Return[integrals]]]

(******************************************************************************)
 
MBmerge[integrals_] := 
Block[{ints = Cases[integrals, MBint[__], -1], cmpInts, sameInts, merged,
  lastInt, i, i1, i2, i3, i4},

  cmpInts[i1_, i2_] := OrderedQ[{i1[[2]], i2[[2]]}];
  sameInts[i1_, i2_] := SameQ[i1[[2]], i2[[2]]];

  If[ints === {}, Return[{}]];

  ints = Sort[ints, cmpInts];
  ints = Split[ints, sameInts];

  merged = MBint[Simplify[Plus @@ (First[#] & /@ #)], #[[1, 2]]] & /@ ints;
  merged = DeleteCases[merged, MBint[0, _]];  

  Return[merged]]

(******************************************************************************)
 
MBpreselect[integrals_, {x_, x0_, order_}] :=
Block[{ints = Cases[integrals, MBint[__], -1], res, terms, term, pow, minpow,
  integrand, dx, m, n, a, i, j},

  res = Table[
    terms = Expand[ints[[i,1]]];
    terms = If[Head[terms] === Plus, List @@ terms, {terms}];

    integrand = Sum[
      term = ExpandAll[pow[0]*terms[[j]] /. x -> x0 + dx] /.
        {Gamma[m_.+a_.*dx] :> 1/dx /; IntegerQ[m] && m <= 0,
        PolyGamma[n_, m_.+a_.*dx] :> 1/dx^(n+1) /; IntegerQ[m] && m <= 0} /.
        pow[0]*dx^n_. -> pow[n];

      minpow = Min[Cases[{term}, pow[n_] -> n, -1]];

      If[minpow > order, 0, terms[[j]]],
    {j, Length[terms]}];

    MBint[integrand, ints[[i,2]]],
  {i, Length[ints]}];

  res = DeleteCases[res, MBint[0, __]];

  Return[res]]

(******************************************************************************)

MBexpand[integrals_, norm_, {x_, x0_, order_}] :=
Block[{ints = Cases[integrals, MBint[__], -1], res, terms, term, pow, depth,
  integrand, dx, m, n, a, i, j},

  res = Table[
    terms = ExpandAll[pow[0]*norm*ints[[i,1]] /. x -> x0 + dx] /.
      MBshiftRules[dx] /. pow[0]*dx^n_. -> pow[n];

    terms = If[Head[terms] === Plus, List @@ terms, {terms}];

    integrand = Sum[
      depth = order - Cases[{terms[[j]]}, pow[m_] -> m, -1][[1]];
      If[depth < 0, 0,
        Normal[Series[terms[[j]] /. MBexpansionRules[dx,depth],{dx,0,depth}]] /.
        pow[m_] -> dx^m /. dx -> x-x0 // ExpandAll],
    {j, Length[terms]}];

    MBint[integrand, ints[[i,2]]],
  {i, Length[ints]}];

  res = DeleteCases[res, MBint[0, __]];

  Return[res]]

(******************************************************************************)

MBshiftContours[integrals_List, options___Rule] := 
Module[{ints = Cases[integrals, MBint[__], -1], vars, args,
  const, val, val0, del, del0 = 0, inc = 1/100, contours},

  If[$VersionNumber >= 6,
    Return[MBoptimizeContours[##, options]& /@ ints]];

  Do[
    vars = (First[#1] & ) /@ ints[[i,2,2]];

    If[Length[vars] > 0,
      args = Union[Cases[{ints[[i,1]]},
        (Gamma | PolyGamma)[___, x_] :> x, -1]];

      const = Table[val = args[[j]] /. ints[[i,2,2]];
        If[val < 0, val = Ceiling[val] - 1/2];
        If[val < 0, Abs[args[[j]] - val] <= del, args[[j]] >= 1/2 - del],
      {j, Length[args]}];

      While[(contours = FindInstance[const /. del -> del0, vars]) == {},
        del0 += inc];

      ints[[i,2,2]] = contours[[1]]],
  {i, Length[ints]}];
  Return[ints]]

VFunction[{x_,fl_}] := If[x<fl+0.5,1/(x-fl),1/(fl+1-x)]
StepFunction[{x_,0}] := If[x > 0, 0, Floor[-x] + 1]
StepFunction[{x_,n_Integer}] := If[x >= -n+1, 1000(x+n), Floor[-n+1-x]]

MBoptimizeContours[MBint[integrand_,point_],options___Rule]:=Module[{temp,args,conf,vars,newpoint,roundnewpoint,
            opt = ParseOptions[MBshiftContours, options],verbose,LimVars},
            verbose=Verbose/.opt;
            LimVars=point[[1]];
    args = Cases[{Numerator[integrand]}, (Gamma | PolyGamma)[___, x_] :> x, -1];
    vars = Union[Cases[args /. LimVars, x_Symbol, -1]];
    args = Select[args,(Complement[Variables[##],(##[[1]])&/@LimVars]=!={})&];
    conf={##/.LimVars,If[Floor[##/.Flatten[point]]>=0,0,-Floor[##/.Flatten[point]]]}&/@args;
    If[Length[vars]===0,Return[MBint[integrand,point]]];
    temp={##[[1]],(Floor[##[[1]]/.point[[2]]])}&/@conf;
    If[verbose,Print[temp]];
    Off[FindMinimum::eit];

    newpoint=FindMinimum[{Plus@@(VFunction/@temp),Join[(##[[1]]>##[[2]])&/@temp,
                    (##[[1]]<##[[2]]+1)&/@temp]},Transpose[{vars,vars/.point[[2]]}],Method->"InteriorPoint",AccuracyGoal->2];

    On[FindMinimum::eit];
    If[((StepFunction/@(conf))/.point[[2]])===((StepFunction/@(conf))/.newpoint[[2]]),
        roundnewpoint={newpoint[[1]],Rule[##[[1]],Rationalize[##[[2]],0.0001]]&/@newpoint[[2]]};
        If[((StepFunction/@(conf))/.point[[2]])===((StepFunction/@(conf))/.roundnewpoint[[2]]),
            If[verbose,Print[{"Optimized and rationalized",roundnewpoint[[2]]}]];
            MBint[integrand,{point[[1]],roundnewpoint[[2]]}]
        ,
            If[verbose,Print[{"Optimized but not rationalized",newpoint[[2]]}]];
            MBint[integrand,{point[[1]],newpoint[[2]]}]
        ]
    ,
        Print["Minimum search failed"];
        Print[MBint[integrand,{point[[1]],point[[2]]}]];
        MBint[integrand,{point[[1]],point[[2]]}]
    ]
]

MBshiftContours[integrals_List, newRules_List] := 
Block[{ints = Cases[integrals, MBint[__], -1], i, j}, 

  Do[ints = Flatten[Table[MBshiftContours[ints[[j]], newRules[[i]]],
  {j, Length[ints]}]], {i, Length[newRules]}]; 
  Return[ints]]

MBshiftContours[MBint[integrand_, rules_], var_ -> val_] := 
Block[{expanded, integrals, stripped, args, x, poles, residues, 
  correct = True, v0, v1, v, i}, 

  integrals = {MBint[integrand, rules /. (var -> _) -> var -> val]}; 
  stripped = DeleteCases[rules, var -> _, -1]; 
  args = Union[Cases[{Numerator[integrand]},
    (Gamma | PolyGamma)[___, x_] :> x /; !NumberQ[x /. Flatten[stripped]], -1]];

  poles = Union[Flatten[Table[
    v0 = args[[i]] /. Flatten[rules]; 
    v1 = args[[i]] /. var -> val /. Flatten[rules]; 
    If[IntegerQ[v0] && v0 <= 0 || IntegerQ[v1] && v1 <= 0, 
      Message[MBresidues::contour, args[[i]]]; correct = False];

    If[v0 > v1, {v0, v1} = {v1, v0}];
    v0 = Min[Ceiling[v0], 1];
    v1 = Min[Floor[v1], 0];

    Table[Solve[args[[i]] == v, var][[1]], {v, v0, v1}],
  {i, Length[args]}]]];

  If[correct,

    integrals = {MBint[integrand, rules /. (var -> _) -> var -> val]};
    expanded = Expand[integrand]; 
    residues = Simplify[Sign[(var /. rules[[2]]) - val]*
      Sum[MBresidue[expanded, {poles[[i,1]], poles[[i,2]]}],
      {i, Length[poles]}]];

    If[residues =!= 0, AppendTo[integrals, MBint[residues, stripped]]],

    integrals = {MBint[integrand, rules]}];

  Return[integrals]]

(******************************************************************************)

MBshiftVars[integrals_] :=
Block[{ints = Cases[integrals, MBint[__], -1], res, terms, i, j},

  res = Table[
    terms = Expand[ints[[i, 1]]];
    terms = If[Head[terms] === Plus, List @@ terms, {terms}];
    Table[MBshiftVars[MBint[terms[[j]], ints[[i, 2]]]], {j, Length[terms]}],
  {i, Length[ints]}];

  res = Flatten[res];

  Return[res]]

MBshiftVars[MBint[integrand_, rules_]] :=
Block[{int = integrand, rul = rules, allvars, remvars, exponents, exp,
  vars, var, coeff, currCoeff, subst, xx, n, i},

  allvars = #[[1]] & /@ rules[[2]];
  remvars = allvars;
  allvars = Alternatives @@ allvars;

  While[exponents = Cases[{int}, _^n_ :> n /; Count[n, allvars, -1] > 1, -1];
    exponents =!= {} && remvars =!= {},

    exp = DeleteCases[Expand[First[exponents]], n_ /; FreeQ[n, allvars]];
    vars = Intersection[Variables[exp], remvars];

    coeff = Infinity;
    Do[currCoeff = Abs[Coefficient[exp, vars[[i]]]];
      If[currCoeff < coeff, coeff = currCoeff; var = vars[[i]]],
    {i, Length[vars]}];

    subst = Expand[Solve[exp == Coefficient[exp, var]*xx, var][[1, 1]] /.
      xx -> var];

    {int, rul} = List @@ MBreplaceVar[MBint[int, rul], subst];
    remvars = DeleteCases[remvars, var]];

  Return[MBint[int, rul]]]

(******************************************************************************)

MBreplaceVar[MBint[integrand_, rules_], var_ -> var0_] := 
Block[{val, coeff, a, n},

  If[FreeQ[var0, var, -1], Return[MBint[integrand, rules]]];
  val = Solve[(var0 /. var -> val) == var /. Flatten[rules], {val}][[1,1,2]];
  coeff = Abs[Coefficient[var0, var]];
  Return[MBint[ExpandAll[coeff*integrand /. var -> var0],
    rules /. (var -> _) -> var -> val]]]

(******************************************************************************)

MBfortranForm[stream_, x_, expression_] :=
Block[{var = ToString[x], expr, count, float = False},

  WriteString[stream, "      ", var, " = "];
  count = StringLength[var] + 3; 

  expr = ToString[expression, FortranForm];
  expr = StringReplace[expr, {"MBxPrivatex" -> "", " " -> ""}];
  expr = Characters[expr];

  (* adapting floating-point constants to double precision *)

  Do[
    If[expr[[i]] == ".",

      float = True,

      If[float,
        Which[
          expr[[i]] == "e",
          expr[[i]] = "d"; float = False,

          !DigitQ[expr[[i]]],
          expr[[i]] = {"d", "0", expr[[i]]}; float = False]]],

  {i, Length[expr]}];
  expr = Flatten[expr];

  (* output to fit into a page width of 72 characters *)

  Do[
    If[++count > 66, WriteString[stream, "\n     & "]; count = 2];
    WriteString[stream, expr[[i]]],
  {i, Length[expr]}];

  WriteString[stream, "\n"]]



MBcForm[stream_, x_, expression_] :=
    Block[{var = ToString[x], expr, count, float = False},
          
          WriteString[stream, "      ", var, " = "];
          count = StringLength[var] + 3; 
          
          expr = ToString[expression, CForm];
          expr = StringReplace[expr, {"MB_Private_" -> "", " " -> "","LBR"->"[","RBR"->"]","Complex(0,1)"->"I","Power"->"pow","Log"->"log"}];
          
          WriteString[stream, expr];
          WriteString[stream, ";\n"]]
    
(******************************************************************************)

MBmap[z_, x_] := z - I*Log[x/(1 - x)]
    
MBnorm[x_] := 1/(x*(1 - x))
    
(******************************************************************************)

MBintegrate::vars = "too many free variables `1`";

MBintegrate[integrals_List, kinematics_List, options___Rule] :=
Block[{opt = ParseOptions[MBintegrate, options], greater, tolist,
  ints = integrals /. kinematics, intvars, allvars, x, expr, ncomp, flags,
  ints1, sum, pow, rules, ndim, integrand, gams, syms, name, exec, source,
  strm, val, result, error, i, j, NINT},

  greater[int1_, int2_] := Block[{e1, e2, n1, n2},
    e1 = Exponent[int1, x];
    e2 = Exponent[int2, x];
    If[e1 != e2, Return[e1 > e2]];
    n1 = int1 /. (_.)*MBint[_, {_, r_}] :> Length[r];
    n2 = int2 /. (_.)*MBint[_, {_, r_}] :> Length[r]; 
    Return[n1 > n2]];

  tolist[expr_] := If[Head[expr] === Plus, List @@ expr, {expr}];

  intvars = Union[Flatten[Cases[ints, MBint[_, {_, rules_}] :>
    (First[#] & /@ rules), -1]]];

  allvars = Union[Flatten[ints /. MBint[integrand_, _] :>
    Cases[N[integrand], _Symbol, -1]]];

  x = Complement[allvars, intvars];
  If[Length[x] == 0, x = {""}];
  If[Length[x] > 1, Message[MBintegrate::vars, x]; Return[{}], x = First[x]];

  ints = Sort[Flatten[ints /. MBint[integrand_, rules_] :>
    tolist[Collect[integrand, x, MBint[#1, rules] & ]]], greater];

  If[Complex /. opt, ncomp = 2, ncomp = 1];

  If[PseudoRandom /. opt, flags = 8, flags = 0];

  If[!FixedContours /. opt,
    If[Verbose /. opt, Print["Shifting contours..."]];
    ints = ints /. MBint[args__] :> First[MBshiftContours[{MBint[args]},
      Verbose -> (ContourDebug /. opt)]]];

  sum = Plus @@ Cases[ints, _.*MBint[_, {_, {}}]] /. MBint[i_, _] -> i;
  If[sum =!= 0, If[(PrecisionGoal /. opt) <= $MachinePrecision,
    sum = N[sum], sum = N[sum, PrecisionGoal /. opt]]];

  ints1 = Cases[ints, _.*i_MBint /;
    0 < Length[i[[2,2]]] <= (MaxNIntegrateDim /. opt)];
  ints = Cases[ints, _.*i_MBint /;
    (MaxNIntegrateDim /. opt) < Length[i[[2,2]]]];

  If[!Complex /. opt,
    ints1 = ints1 /. MBint[integrand_, rules_] :> MBint[Re[integrand], rules]];

  If[Verbose /. opt, WriteString[$Output, "\nPerforming ", Length[ints1],
    " lower-dimensional integrations with NIntegrate"]];

  Do[
    If[Verbose /. opt, WriteString[$Output, "...", i]];
    sum += ints1[[i]] /. MBint[integrand_, {_, rules_}] :>
      NINT[1/(2*Pi)^Length[rules]*integrand /. 
        Table[rules[[j,1]] -> rules[[j,2]]+I*MBx[j], {j, Length[rules]}],
        Sequence @@ Table[{MBx[j], -Infinity, Infinity}, {j, Length[rules]}],
        PrecisionGoal -> (PrecisionGoal /.opt),
        AccuracyGoal -> (AccuracyGoal /. opt),
        MaxPoints -> (MaxPoints /. opt),
        MaxRecursion -> (MaxRecursion /. opt),
        Method -> (Method /. opt),
        WorkingPrecision -> (WorkingPrecision /. opt)] /.
      NINT[args__] :> NIntegrate[args],
  {i, Length[ints1]}];

  If[!Complex /. opt, sum = Collect[sum, x, Re]];

  If[Verbose /. opt, Print["\nHigher-dimensional integrals"]];

  Do[
    pow = Exponent[ints[[i]], x];
    rules = ints[[i]] /. _.*MBint[_, {_, r_}] -> r;
    ndim = Length[rules];
    integrand = ints[[i]] /. _.*MBint[j_, _] -> j;
    gams = Union[Cases[integrand, (Gamma|PolyGamma)[__], -1]];
    syms = Table[ToExpression["MBg"<>ToString[j]], {j, Length[gams]}];
    Do[integrand = integrand /. gams[[j]] -> syms[[j]], {j, Length[gams]}];

    name = StringJoin[NamePrefix /. opt, "part", ToString[i]];
    exec = StringJoin[name, ToString[x], ToString[pow], ".x"];
    source = StringReplace[exec, {".x"->".c"}];
    strm = OpenWrite[source];

    If[Verbose /. opt, Print["Preparing ", exec, " (dim ", ndim, ")"]];

      (* Header *)
      WriteString[strm,
                  "#include \"stdio.h\"\n",
                  "#include \"complex.h\"\n",
                  "#include \"cgamma.h\"\n",
                  "#include \"cuba.h\"\n\n"
               ];

      (* Integrand *)

      If[(CubaCores /. opt) > 0,
         WriteString[strm,
                     "#define CUBACORES ", CubaCores /. opt, "\n"
                    ],
        ];


      WriteString[strm,
                  "#define CUBACORESMAX 10000\n",
                  "#define NDIM ", ndim, "\n",
                  "#define NCOMP ", ncomp, "\n",
                  "#define FLAGS ", flags, "\n",
                  "#define USERDATA NULL\n",
                  "#define NVEC 1\n",
                  "#define VERBOSE 0\n",
                  "#define LAST 4\n",
                  "#define SEED 0\n",
                  "#define MINEVAL 0\n",
                  "#define MAXEVAL ", MaxPoints /. opt,"\n",
                  "#define KEY 0\n",
                  "#define NSTART 1000\n",
                  "#define NINCREASE 1000\n",
                  "#define NBATCH 1000\n",
                  "#define GRIDNO 0\n",
                  "#define STATEFILE NULL\n",
                  "#define SPIN NULL\n",
                  "#define EPSREL ", CForm[10^(-PrecisionGoal) /. opt], "\n",
                  "#define EPSABS ", CForm[10^(-AccuracyGoal) /. opt], "\n\n"
                 ];
      
      WriteString[strm,
                  "static int Integrand(const int *ndim, const double MBx[], const int *ncomp, double MBf[], void *userdata)\n",
                  "      {\n\n",
                  "      double complex MBval;\n"];
      Do[WriteString[strm,
                     "      double complex ", rules[[j,1]], ";\n"], {j, ndim}];
      Do[WriteString[strm,
                     "      double complex ", syms[[j]], ";\n"], {j, Length[syms]}];
      
      WriteString[strm, "\n"];
      Do[MBcForm[strm, rules[[j,1]],
                 MBmap[rules[[j,2]], ToExpression[StringJoin["MBxLBR", ToString[j-1], "RBR"]]]],
         {j, ndim}];
      
      WriteString[strm, "// x1 \n"];
      Do[MBcForm[strm, syms[[j]],
                 N[gams[[j]]] /. {Gamma[z_] -> wgamma[z],PolyGamma[n_,z_] :>
                                  wpsipg[z,Rationalize[n,0]]}],
         {j, Length[syms]}];
      
      WriteString[strm, "// x2 \n"];
      MBcForm[strm, MBval, N[(1/(2*Pi)^ndim)*Simplify[integrand]]];
      WriteString[strm, ";\n"];
      MBcForm[strm, MBval, MBval*
              Product[MBnorm[ToExpression[StringJoin["MBxLBR", ToString[j-1], "RBR"]]],
                      {j, ndim}]];
      WriteString[strm, ";\n"];
      
      WriteString[strm,
                  "      MBf[0] = creal(MBval);\n",
                  "      if (*ncomp == 2) MBf[*ncomp-1] = cimag(MBval);\n\n",
                  
                  "      }\n"];

      (* Main program *)
            WriteString[strm,
                "int main()\n", "{\n",
                "int comp, nregions, neval, fail;\n",
                "double integral[NCOMP], error[NCOMP], prob[NCOMP];\n",

                "if(NDIM > ", MaxCuhreDim /. opt, ")\n", "{\n",
                "    Vegas(NDIM, NCOMP, Integrand, USERDATA, NVEC,\n",
                "          EPSREL, EPSABS, VERBOSE, SEED,\n",
                "          MINEVAL, MAXEVAL, NSTART, NINCREASE, NBATCH,\n",
                "          GRIDNO, STATEFILE, SPIN,\n",
                "          &neval, &fail, integral, error, prob);\n",
                "}\n",
                "else\n","{\n",
                "   Cuhre(NDIM, NCOMP, Integrand, USERDATA, NVEC,\n",
                "         EPSREL, EPSABS, VERBOSE | LAST,\n",
                "         MINEVAL, MAXEVAL, KEY,\n",
                "         STATEFILE, SPIN,\n",
                "         &nregions, &neval, &fail, integral, error, prob);\n",

                "}\n",

                "printf(\"%24.16f %24.16f %24.16f\\n\", integral[0],error[0],prob[0]);",
                "if(NCOMP == 2)\n", "{\n",
                "   printf(\"%24.16f %24.16f %24.16f\\n\", integral[1],error[1],prob[1]);",
                "}\n",
                "}\n"
               ];

      Close[strm];

    (* Run["gcc -O -o", exec, source, "-L. -lcuba -lm"], *)
    Run["make ", exec],
  {i, Length[ints]}];

  If[NoHigherDimensional /. opt,
    If[Verbose /. opt,
      Print["The result does not contain higher dimensional integrals"]];
    Return[sum]];

  Do[
    pow = Exponent[ints[[i]], x];
    name = StringJoin[NamePrefix /. opt, "part", ToString[i]];
    exec = StringJoin[name, ToString[x], ToString[pow], ".x"];
  
    If[Verbose /. opt, Print["Running ", exec]];

    val = Import[StringJoin["! ./", exec], "Table"];
    val = If[ncomp == 1, Flatten[val], Table[val[[1,j]]+I*val[[2,j]], {j,3}]];
    sum += x^pow*MBval[Sequence @@ val, i];

    If[!Debug /. opt,
      DeleteFile[StringJoin[name, ToString[x], ToString[pow], ".c"]];
      DeleteFile[exec]],
      {i, Length[ints]}];

  result = sum /. MBval[i_, __] -> i;
  error = Collect[sum, x, 
    Sqrt[Plus @@ Cases[tolist[#], MBval[_, i_, __] :> {Re[i]^2, Im[i]^2}]] &];

  If[Debug /. opt,
    Return[{result,error,sum}],
    Return[{result,error}]]]

(******************************************************************************)
 
MBapplyBarnes[integrals_] := FixedPoint[MBapplyBarnesOnce, integrals];

MBapplyBarnesOnce[integrals_] :=
Block[{ints = Cases[integrals, MBint[__], -1], res, terms, integrated, i, j},

  res = Table[
    terms = Expand[ints[[i, 1]]];
    terms = If[Head[terms] === Plus, List @@ terms, {terms}];
    Table[
      integrated = Scan[(
        tmp = Barnes1[MBint[terms[[j]], ints[[i, 2]]], #[[1]]];
        If[tmp[[1]] =!= terms[[j]], Return[tmp]];
        tmp = Barnes2[MBint[terms[[j]], ints[[i, 2]]], #[[1]]];
        If[tmp[[1]] =!= terms[[j]], Return[tmp]]) &, ints[[i, 2, 2]]];
      If[integrated === Null, MBint[terms[[j]], ints[[i, 2]]],
        integrated],
    {j, Length[terms]}],
  {i, Length[integrals]}];

  res = Flatten[res];

  Return[res]]

barnes1[z_] := Gamma[z + (l1_.)]*Gamma[z + (l2_.)]*Gamma[-z + (l3_.)]*
  Gamma[-z + (l4_.)] -> Gamma[l1 + l3]*Gamma[l1 + l4]*Gamma[l2 + l3]*
  Gamma[l2 + l4]*Global`InvGamma[l1 + l2 + l3 + l4]

barnes2[z_] := Gamma[(l1_.) + z]*Gamma[(l2_.) + z]*Gamma[(l3_.) + z]*
  Gamma[(l4_.) - z]*Gamma[(l5_.) - z]/Gamma[(l6_.) + z] :> 
  Gamma[l1 + l4]*Gamma[l2 + l4]*Gamma[l3 + l4]*Gamma[l1 + l5]*
  Gamma[l2 + l5]*Gamma[l3 + l5]*Global`InvGamma[l1 + l2 + l4 + l5]*
  Global`InvGamma[l1 + l3 + l4 + l5]*Global`InvGamma[l2 + l3 + l4 + l5] /; 
  Expand[l1 + l2 + l3 + l4 + l5 - l6] === 0

Barnes1[MBint[integrand_, {fixedVarRules_List, intVarRules_List}], z_Symbol] := 
Block[{original = MBint[integrand, {fixedVarRules, intVarRules}],
  rules = Flatten[{fixedVarRules, intVarRules}],
  x, pos, a, b, p, neg, c, d, n, xx, xx0, int, fixed, cont, ct, orig},

  pos = Cases[{Numerator[integrand]},
    Gamma[x_] :> x /; Coefficient[x, z] == +1, -1] /. z -> 0;
  If[Length[pos] == 1, pos = {First[pos], First[pos]}];
  If[Length[pos] != 2, Return[original]];
  a = First[pos];
  b = Last[pos];

  neg = Cases[{Numerator[integrand]},
    Gamma[x_] :> x /; Coefficient[x, z] == -1, -1] /. z -> 0;
  If[Length[neg] == 1, neg = {First[neg], First[neg]}];
  If[Length[neg] != 2, Return[original]];
  c = First[neg];
  d = Last[neg];

  If[MemberQ[integrand /.
    Gamma[a + z]*Gamma[b + z]*Gamma[c - z]*Gamma[d - z] -> 1, z, -1],
    Return[original]];

  p = -Min[pos /. rules];
  n = +Min[neg /. rules];
  xx0 = Max[{p - z, z - n} /. rules];

  If[xx0 < 0,
    Return[DeleteCases[original /.
      Gamma[a + z]*Gamma[b + z]*Gamma[c - z]*Gamma[d - z] ->
      Gamma[a + c]*Gamma[a + d]*Gamma[b + c]*Gamma[b + d]/Gamma[a + b + c + d],
      z -> _, -1]]];

  int = integrand /. Gamma[a + z]*Gamma[b + z]*Gamma[c - z]*Gamma[d - z] ->
    Gamma[a + xx + z]*Gamma[b + xx + z]*Gamma[c + xx - z]*Gamma[d + xx - z];

  fixed = DeleteCases[Join[fixedVarRules, intVarRules, {xx -> xx0 + 10^-10}],
    z -> _, -1];

  cont = MBmerge[MBcontinue[int, xx -> 0, {fixed, {z -> (z /. intVarRules)}},
    Verbose -> False]];

  ct = -cont[[1,1]];
  orig = integrand /. Gamma[a + z]*Gamma[b + z]*Gamma[c - z]*Gamma[d - z] ->
    Gamma[a + c + 2*xx]*Gamma[a + d + 2*xx]*
    Gamma[b + c + 2*xx]*Gamma[b + d + 2*xx]/Gamma[a + b + c + d + 4*xx];

  Return[MBexpand[{MBint[orig + ct, {fixedVarRules,
    DeleteCases[intVarRules, z -> _, -1]}]}, 1, {xx, 0, 0}][[1]]]]
 
Barnes2[MBint[integrand_, {fixedVarRules_List, intVarRules_List}], z_Symbol] := 
Block[{original = MBint[integrand, {fixedVarRules, intVarRules}], sign = +1,
  integ = integrand, rules = Flatten[{fixedVarRules, intVarRules}], x, i, j,
  tpos, pos = {}, a, b, c, p, tneg, neg = {}, d, e, n, 
  xx, xx0, int, fixed, cont, ct, orig},

  If[MemberQ[{Denominator[integrand]}, Gamma[x_.-z], -1],
    sign = -1;
    integ = integ /. z -> -z;
    rules = rules /. (z -> x_) -> (z -> -x)];

  tpos = Cases[{Numerator[integ]},
    Gamma[x_] :> x /; Coefficient[x, z] == +1, -1] /. z -> 0;

  Do[
    Do[AppendTo[pos, tpos[[i]]],
    {j, Exponent[integ, Gamma[tpos[[i]] + z]]}],
  {i, Length[tpos]}];

  If[Length[pos] != 3, Return[original]]; 

  a = pos[[1]];
  b = pos[[2]];
  c = pos[[3]];

  tneg = Cases[{Numerator[integ]},
    Gamma[x_] :> x /; Coefficient[x, z] == -1, -1] /. z -> 0;

  Do[
    Do[AppendTo[neg, tneg[[i]]],
    {j, Exponent[integ, Gamma[tneg[[i]] - z]]}],
  {i, Length[tneg]}];

  If[Length[neg] != 2, Return[original]]; 

  d = neg[[1]];
  e = neg[[2]];

  If[MemberQ[integ /.
    Gamma[a + z]*Gamma[b + z]*Gamma[c + z]*Gamma[d - z]*Gamma[e - z]/
    Gamma[Expand[a + b + c + d + e] + z] -> 1, z, -1],
    Return[original]];

  p = -Min[pos /. rules];
  n = +Min[neg /. rules];
  xx0 = Max[{p - z, z - n} /. rules];

  If[xx0 < 0,
    Return[DeleteCases[original /. z -> sign*z /.
      Gamma[a + z]*Gamma[b + z]*Gamma[c + z]*Gamma[d - z]*Gamma[e - z]/
      Gamma[Expand[a + b + c + d  + e] + z] ->
      Gamma[a + d]*Gamma[b + d]*Gamma[c + d]*
      Gamma[a + e]*Gamma[b + e]*Gamma[c + e]/
      (Gamma[a + b + d + e]*Gamma[a + c + d + e]*Gamma[b + c + d + e]),
      sign*z -> _, -1]]];

  int = integ /.
    Gamma[a + z]*Gamma[b + z]*Gamma[c + z]*Gamma[d - z]*Gamma[e - z]/
    Gamma[Expand[a + b + c + d  + e] + z] ->
    Gamma[a + xx + z]*Gamma[b + xx + z]*Gamma[c + xx + z]*
    Gamma[d + xx - z]*Gamma[e + xx - z]/
    Gamma[Expand[a + b + c + d  + e] + 5*xx + z];

  fixed = DeleteCases[Join[fixedVarRules, intVarRules, {xx -> xx0 + 10^-10}],
    z -> _, -1];

  cont = MBmerge[MBcontinue[int, xx -> 0,
    {fixed, {z -> (sign*z /. intVarRules)}}, Verbose -> False]];

  ct = -cont[[1,1]];
  orig = integ /.
    Gamma[a + z]*Gamma[b + z]*Gamma[c + z]*Gamma[d - z]*Gamma[e - z]/
    Gamma[Expand[a + b + c + d  + e] + z] ->
    Gamma[a + d + 2*xx]*Gamma[b + d + 2*xx]*Gamma[c + d + 2*xx]*
    Gamma[a + e + 2*xx]*Gamma[b + e + 2*xx]*Gamma[c + e + 2*xx]/
    (Gamma[a + b + d + e + 4*xx]*Gamma[a + c + d + e + 4*xx]*
    Gamma[b + c + d + e + 4*xx]);

  Return[MBexpand[{MBint[orig + ct, {fixedVarRules,
    DeleteCases[intVarRules, z -> _, -1]}]}, 1, {xx, 0, 0}][[1]]]]

(******************************************************************************)

MBresidue[expr_, {x_, x0_}] :=
Block[{terms, term, order, res, dx, a, n, i},

  terms = ExpandAll[expr /. x -> x0 + dx];
  terms = If[Head[terms] === Plus, List @@ terms, {terms}];

  res = Sum[
    term = terms[[i]] /. MBshiftRules[dx];
    If[Head[term] =!= Times || FreeQ[term, dx^n_., {1}],

      0,

      order = Cases[term, dx^n_. -> n][[1]];
      If[order >= 0,

        0,

        term = term/dx^order; 
        term = term /. MBexpansionRules[dx, -1-order];
        D[term, {dx, -1-order}] /. dx -> 0]/(-1-order)!],

  {i, Length[terms]}]; 

  Return[res]]

(******************************************************************************)

MBshiftRules[dx_] := {
  Gamma[m_.+a_.*dx] :> Gamma[1+a*dx]/Product[a*dx-i, {i,0,-m}] /;
  IntegerQ[m] && m <= 0,

  PolyGamma[n_, m_.+a_.*dx] :> (-a*dx)^(-n-1)*
  ((-a*dx)^(n+1)*PolyGamma[n, 1+a*dx] + n!*Sum[(a*dx/(a*dx-i))^(n+1),
  {i,0,-m}]) /; IntegerQ[m] && m <= 0};

(* the size of the precomputed expansion of Gamma is hardcoded to 20 *)

MBexpansionRules::series = "exhausted precomputed expansion of Gamma's (`1`)";

MBexpansionRules[dx_, order_] := {
  Gamma[m_+a_.*dx] :> If[order <= 20,
  Gamma[m]*Sum[(a*dx)^i/i!*MBexpGam[m, i], {i,0,order}],
  Message[MBexpansionRules::series, order];
  Normal[Series[Gamma[m+a*dx], {dx,0,order}]]] /; !IntegerQ[m] || m > 0,

  PolyGamma[n_, m_+a_.*dx] :> Sum[(a*dx)^i/i!*PolyGamma[n+i, m],
  {i,0,order}] /; !IntegerQ[m] || m > 0};

(* generated automatically with MATHEMATICA *)

MBexpGam[a_, 0] = 1;
 
MBexpGam[a_, 1] = PolyGamma[0, a];
 
MBexpGam[a_, 2] = PolyGamma[0, a]^2 + PolyGamma[1, a];
 
MBexpGam[a_, 3] = PolyGamma[0, a]^3 + 3*PolyGamma[0, a]*PolyGamma[1, a] + 
     PolyGamma[2, a];
 
MBexpGam[a_, 4] = PolyGamma[0, a]^4 + 6*PolyGamma[0, a]^2*PolyGamma[1, a] + 
     3*PolyGamma[1, a]^2 + 4*PolyGamma[0, a]*PolyGamma[2, a] + PolyGamma[3, a];
 
MBexpGam[a_, 5] = PolyGamma[0, a]^5 + 10*PolyGamma[0, a]^3*PolyGamma[1, a] + 
     15*PolyGamma[0, a]*PolyGamma[1, a]^2 + 10*PolyGamma[0, a]^2*
      PolyGamma[2, a] + 10*PolyGamma[1, a]*PolyGamma[2, a] + 
     5*PolyGamma[0, a]*PolyGamma[3, a] + PolyGamma[4, a];
 
MBexpGam[a_, 6] = PolyGamma[0, a]^6 + 15*PolyGamma[0, a]^4*PolyGamma[1, a] + 
     45*PolyGamma[0, a]^2*PolyGamma[1, a]^2 + 15*PolyGamma[1, a]^3 + 
     20*PolyGamma[0, a]^3*PolyGamma[2, a] + 60*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[2, a] + 10*PolyGamma[2, a]^2 + 
     15*PolyGamma[0, a]^2*PolyGamma[3, a] + 15*PolyGamma[1, a]*
      PolyGamma[3, a] + 6*PolyGamma[0, a]*PolyGamma[4, a] + PolyGamma[5, a];
 
MBexpGam[a_, 7] = PolyGamma[0, a]^7 + 21*PolyGamma[0, a]^5*PolyGamma[1, a] + 
     105*PolyGamma[0, a]^3*PolyGamma[1, a]^2 + 105*PolyGamma[0, a]*
      PolyGamma[1, a]^3 + 35*PolyGamma[0, a]^4*PolyGamma[2, a] + 
     210*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[2, a] + 
     105*PolyGamma[1, a]^2*PolyGamma[2, a] + 70*PolyGamma[0, a]*
      PolyGamma[2, a]^2 + 35*PolyGamma[0, a]^3*PolyGamma[3, a] + 
     105*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[3, a] + 
     35*PolyGamma[2, a]*PolyGamma[3, a] + 21*PolyGamma[0, a]^2*
      PolyGamma[4, a] + 21*PolyGamma[1, a]*PolyGamma[4, a] + 
     7*PolyGamma[0, a]*PolyGamma[5, a] + PolyGamma[6, a];
 
MBexpGam[a_, 8] = PolyGamma[0, a]^8 + 28*PolyGamma[0, a]^6*PolyGamma[1, a] + 
     210*PolyGamma[0, a]^4*PolyGamma[1, a]^2 + 420*PolyGamma[0, a]^2*
      PolyGamma[1, a]^3 + 105*PolyGamma[1, a]^4 + 56*PolyGamma[0, a]^5*
      PolyGamma[2, a] + 560*PolyGamma[0, a]^3*PolyGamma[1, a]*
      PolyGamma[2, a] + 840*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[2, a] + 280*PolyGamma[0, a]^2*PolyGamma[2, a]^2 + 
     280*PolyGamma[1, a]*PolyGamma[2, a]^2 + 70*PolyGamma[0, a]^4*
      PolyGamma[3, a] + 420*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[3, a] + 210*PolyGamma[1, a]^2*PolyGamma[3, a] + 
     280*PolyGamma[0, a]*PolyGamma[2, a]*PolyGamma[3, a] + 
     35*PolyGamma[3, a]^2 + 56*PolyGamma[0, a]^3*PolyGamma[4, a] + 
     168*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[4, a] + 
     56*PolyGamma[2, a]*PolyGamma[4, a] + 28*PolyGamma[0, a]^2*
      PolyGamma[5, a] + 28*PolyGamma[1, a]*PolyGamma[5, a] + 
     8*PolyGamma[0, a]*PolyGamma[6, a] + PolyGamma[7, a];
 
MBexpGam[a_, 9] = PolyGamma[0, a]^9 + 36*PolyGamma[0, a]^7*PolyGamma[1, a] + 
     378*PolyGamma[0, a]^5*PolyGamma[1, a]^2 + 1260*PolyGamma[0, a]^3*
      PolyGamma[1, a]^3 + 945*PolyGamma[0, a]*PolyGamma[1, a]^4 + 
     84*PolyGamma[0, a]^6*PolyGamma[2, a] + 1260*PolyGamma[0, a]^4*
      PolyGamma[1, a]*PolyGamma[2, a] + 3780*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[2, a] + 1260*PolyGamma[1, a]^3*
      PolyGamma[2, a] + 840*PolyGamma[0, a]^3*PolyGamma[2, a]^2 + 
     2520*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]^2 + 
     280*PolyGamma[2, a]^3 + 126*PolyGamma[0, a]^5*PolyGamma[3, a] + 
     1260*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[3, a] + 
     1890*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[3, a] + 
     1260*PolyGamma[0, a]^2*PolyGamma[2, a]*PolyGamma[3, a] + 
     1260*PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[3, a] + 
     315*PolyGamma[0, a]*PolyGamma[3, a]^2 + 126*PolyGamma[0, a]^4*
      PolyGamma[4, a] + 756*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[4, a] + 378*PolyGamma[1, a]^2*PolyGamma[4, a] + 
     504*PolyGamma[0, a]*PolyGamma[2, a]*PolyGamma[4, a] + 
     126*PolyGamma[3, a]*PolyGamma[4, a] + 84*PolyGamma[0, a]^3*
      PolyGamma[5, a] + 252*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[5, a] + 
     84*PolyGamma[2, a]*PolyGamma[5, a] + 36*PolyGamma[0, a]^2*
      PolyGamma[6, a] + 36*PolyGamma[1, a]*PolyGamma[6, a] + 
     9*PolyGamma[0, a]*PolyGamma[7, a] + PolyGamma[8, a];
 
MBexpGam[a_, 10] = PolyGamma[0, a]^10 + 45*PolyGamma[0, a]^8*
      PolyGamma[1, a] + 630*PolyGamma[0, a]^6*PolyGamma[1, a]^2 + 
     3150*PolyGamma[0, a]^4*PolyGamma[1, a]^3 + 4725*PolyGamma[0, a]^2*
      PolyGamma[1, a]^4 + 945*PolyGamma[1, a]^5 + 120*PolyGamma[0, a]^7*
      PolyGamma[2, a] + 2520*PolyGamma[0, a]^5*PolyGamma[1, a]*
      PolyGamma[2, a] + 12600*PolyGamma[0, a]^3*PolyGamma[1, a]^2*
      PolyGamma[2, a] + 12600*PolyGamma[0, a]*PolyGamma[1, a]^3*
      PolyGamma[2, a] + 2100*PolyGamma[0, a]^4*PolyGamma[2, a]^2 + 
     12600*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[2, a]^2 + 
     6300*PolyGamma[1, a]^2*PolyGamma[2, a]^2 + 2800*PolyGamma[0, a]*
      PolyGamma[2, a]^3 + 210*PolyGamma[0, a]^6*PolyGamma[3, a] + 
     3150*PolyGamma[0, a]^4*PolyGamma[1, a]*PolyGamma[3, a] + 
     9450*PolyGamma[0, a]^2*PolyGamma[1, a]^2*PolyGamma[3, a] + 
     3150*PolyGamma[1, a]^3*PolyGamma[3, a] + 4200*PolyGamma[0, a]^3*
      PolyGamma[2, a]*PolyGamma[3, a] + 12600*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a] + 2100*PolyGamma[2, a]^2*
      PolyGamma[3, a] + 1575*PolyGamma[0, a]^2*PolyGamma[3, a]^2 + 
     1575*PolyGamma[1, a]*PolyGamma[3, a]^2 + 252*PolyGamma[0, a]^5*
      PolyGamma[4, a] + 2520*PolyGamma[0, a]^3*PolyGamma[1, a]*
      PolyGamma[4, a] + 3780*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[4, a] + 2520*PolyGamma[0, a]^2*PolyGamma[2, a]*
      PolyGamma[4, a] + 2520*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[4, a] + 1260*PolyGamma[0, a]*PolyGamma[3, a]*
      PolyGamma[4, a] + 126*PolyGamma[4, a]^2 + 210*PolyGamma[0, a]^4*
      PolyGamma[5, a] + 1260*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[5, a] + 630*PolyGamma[1, a]^2*PolyGamma[5, a] + 
     840*PolyGamma[0, a]*PolyGamma[2, a]*PolyGamma[5, a] + 
     210*PolyGamma[3, a]*PolyGamma[5, a] + 120*PolyGamma[0, a]^3*
      PolyGamma[6, a] + 360*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[6, a] + 
     120*PolyGamma[2, a]*PolyGamma[6, a] + 45*PolyGamma[0, a]^2*
      PolyGamma[7, a] + 45*PolyGamma[1, a]*PolyGamma[7, a] + 
     10*PolyGamma[0, a]*PolyGamma[8, a] + PolyGamma[9, a];

MBexpGam[a_, 11] = PolyGamma[0, a]^11 + 55*PolyGamma[0, a]^9*
      PolyGamma[1, a] + 990*PolyGamma[0, a]^7*PolyGamma[1, a]^2 + 
     6930*PolyGamma[0, a]^5*PolyGamma[1, a]^3 + 17325*PolyGamma[0, a]^3*
      PolyGamma[1, a]^4 + 10395*PolyGamma[0, a]*PolyGamma[1, a]^5 + 
     165*PolyGamma[0, a]^8*PolyGamma[2, a] + 4620*PolyGamma[0, a]^6*
      PolyGamma[1, a]*PolyGamma[2, a] + 34650*PolyGamma[0, a]^4*
      PolyGamma[1, a]^2*PolyGamma[2, a] + 69300*PolyGamma[0, a]^2*
      PolyGamma[1, a]^3*PolyGamma[2, a] + 17325*PolyGamma[1, a]^4*
      PolyGamma[2, a] + 4620*PolyGamma[0, a]^5*PolyGamma[2, a]^2 + 
     46200*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[2, a]^2 + 
     69300*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[2, a]^2 + 
     15400*PolyGamma[0, a]^2*PolyGamma[2, a]^3 + 15400*PolyGamma[1, a]*
      PolyGamma[2, a]^3 + 330*PolyGamma[0, a]^7*PolyGamma[3, a] + 
     6930*PolyGamma[0, a]^5*PolyGamma[1, a]*PolyGamma[3, a] + 
     34650*PolyGamma[0, a]^3*PolyGamma[1, a]^2*PolyGamma[3, a] + 
     34650*PolyGamma[0, a]*PolyGamma[1, a]^3*PolyGamma[3, a] + 
     11550*PolyGamma[0, a]^4*PolyGamma[2, a]*PolyGamma[3, a] + 
     69300*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[3, a] + 34650*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[3, a] + 23100*PolyGamma[0, a]*PolyGamma[2, a]^2*
      PolyGamma[3, a] + 5775*PolyGamma[0, a]^3*PolyGamma[3, a]^2 + 
     17325*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[3, a]^2 + 
     5775*PolyGamma[2, a]*PolyGamma[3, a]^2 + 462*PolyGamma[0, a]^6*
      PolyGamma[4, a] + 6930*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[4, a] + 20790*PolyGamma[0, a]^2*PolyGamma[1, a]^2*
      PolyGamma[4, a] + 6930*PolyGamma[1, a]^3*PolyGamma[4, a] + 
     9240*PolyGamma[0, a]^3*PolyGamma[2, a]*PolyGamma[4, a] + 
     27720*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[4, a] + 
     4620*PolyGamma[2, a]^2*PolyGamma[4, a] + 6930*PolyGamma[0, a]^2*
      PolyGamma[3, a]*PolyGamma[4, a] + 6930*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[4, a] + 1386*PolyGamma[0, a]*PolyGamma[4, a]^2 + 
     462*PolyGamma[0, a]^5*PolyGamma[5, a] + 4620*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[5, a] + 6930*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[5, a] + 4620*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[5, a] + 4620*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[5, a] + 2310*PolyGamma[0, a]*PolyGamma[3, a]*
      PolyGamma[5, a] + 462*PolyGamma[4, a]*PolyGamma[5, a] + 
     330*PolyGamma[0, a]^4*PolyGamma[6, a] + 1980*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[6, a] + 990*PolyGamma[1, a]^2*
      PolyGamma[6, a] + 1320*PolyGamma[0, a]*PolyGamma[2, a]*
      PolyGamma[6, a] + 330*PolyGamma[3, a]*PolyGamma[6, a] + 
     165*PolyGamma[0, a]^3*PolyGamma[7, a] + 495*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[7, a] + 165*PolyGamma[2, a]*PolyGamma[7, a] + 
     55*PolyGamma[0, a]^2*PolyGamma[8, a] + 55*PolyGamma[1, a]*
      PolyGamma[8, a] + 11*PolyGamma[0, a]*PolyGamma[9, a] + PolyGamma[10, a]
 
MBexpGam[a_, 12] = PolyGamma[0, a]^12 + 66*PolyGamma[0, a]^10*
      PolyGamma[1, a] + 1485*PolyGamma[0, a]^8*PolyGamma[1, a]^2 + 
     13860*PolyGamma[0, a]^6*PolyGamma[1, a]^3 + 51975*PolyGamma[0, a]^4*
      PolyGamma[1, a]^4 + 62370*PolyGamma[0, a]^2*PolyGamma[1, a]^5 + 
     10395*PolyGamma[1, a]^6 + 220*PolyGamma[0, a]^9*PolyGamma[2, a] + 
     7920*PolyGamma[0, a]^7*PolyGamma[1, a]*PolyGamma[2, a] + 
     83160*PolyGamma[0, a]^5*PolyGamma[1, a]^2*PolyGamma[2, a] + 
     277200*PolyGamma[0, a]^3*PolyGamma[1, a]^3*PolyGamma[2, a] + 
     207900*PolyGamma[0, a]*PolyGamma[1, a]^4*PolyGamma[2, a] + 
     9240*PolyGamma[0, a]^6*PolyGamma[2, a]^2 + 138600*PolyGamma[0, a]^4*
      PolyGamma[1, a]*PolyGamma[2, a]^2 + 415800*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[2, a]^2 + 138600*PolyGamma[1, a]^3*
      PolyGamma[2, a]^2 + 61600*PolyGamma[0, a]^3*PolyGamma[2, a]^3 + 
     184800*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]^3 + 
     15400*PolyGamma[2, a]^4 + 495*PolyGamma[0, a]^8*PolyGamma[3, a] + 
     13860*PolyGamma[0, a]^6*PolyGamma[1, a]*PolyGamma[3, a] + 
     103950*PolyGamma[0, a]^4*PolyGamma[1, a]^2*PolyGamma[3, a] + 
     207900*PolyGamma[0, a]^2*PolyGamma[1, a]^3*PolyGamma[3, a] + 
     51975*PolyGamma[1, a]^4*PolyGamma[3, a] + 27720*PolyGamma[0, a]^5*
      PolyGamma[2, a]*PolyGamma[3, a] + 277200*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[3, a] + 
     415800*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[3, a] + 138600*PolyGamma[0, a]^2*PolyGamma[2, a]^2*
      PolyGamma[3, a] + 138600*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[3, a] + 17325*PolyGamma[0, a]^4*PolyGamma[3, a]^2 + 
     103950*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[3, a]^2 + 
     51975*PolyGamma[1, a]^2*PolyGamma[3, a]^2 + 69300*PolyGamma[0, a]*
      PolyGamma[2, a]*PolyGamma[3, a]^2 + 5775*PolyGamma[3, a]^3 + 
     792*PolyGamma[0, a]^7*PolyGamma[4, a] + 16632*PolyGamma[0, a]^5*
      PolyGamma[1, a]*PolyGamma[4, a] + 83160*PolyGamma[0, a]^3*
      PolyGamma[1, a]^2*PolyGamma[4, a] + 83160*PolyGamma[0, a]*
      PolyGamma[1, a]^3*PolyGamma[4, a] + 27720*PolyGamma[0, a]^4*
      PolyGamma[2, a]*PolyGamma[4, a] + 166320*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[4, a] + 
     83160*PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[4, a] + 
     55440*PolyGamma[0, a]*PolyGamma[2, a]^2*PolyGamma[4, a] + 
     27720*PolyGamma[0, a]^3*PolyGamma[3, a]*PolyGamma[4, a] + 
     83160*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[4, a] + 
     27720*PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a] + 
     8316*PolyGamma[0, a]^2*PolyGamma[4, a]^2 + 8316*PolyGamma[1, a]*
      PolyGamma[4, a]^2 + 924*PolyGamma[0, a]^6*PolyGamma[5, a] + 
     13860*PolyGamma[0, a]^4*PolyGamma[1, a]*PolyGamma[5, a] + 
     41580*PolyGamma[0, a]^2*PolyGamma[1, a]^2*PolyGamma[5, a] + 
     13860*PolyGamma[1, a]^3*PolyGamma[5, a] + 18480*PolyGamma[0, a]^3*
      PolyGamma[2, a]*PolyGamma[5, a] + 55440*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[5, a] + 9240*PolyGamma[2, a]^2*
      PolyGamma[5, a] + 13860*PolyGamma[0, a]^2*PolyGamma[3, a]*
      PolyGamma[5, a] + 13860*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[5, a] + 5544*PolyGamma[0, a]*PolyGamma[4, a]*
      PolyGamma[5, a] + 462*PolyGamma[5, a]^2 + 792*PolyGamma[0, a]^5*
      PolyGamma[6, a] + 7920*PolyGamma[0, a]^3*PolyGamma[1, a]*
      PolyGamma[6, a] + 11880*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[6, a] + 7920*PolyGamma[0, a]^2*PolyGamma[2, a]*
      PolyGamma[6, a] + 7920*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[6, a] + 3960*PolyGamma[0, a]*PolyGamma[3, a]*
      PolyGamma[6, a] + 792*PolyGamma[4, a]*PolyGamma[6, a] + 
     495*PolyGamma[0, a]^4*PolyGamma[7, a] + 2970*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[7, a] + 1485*PolyGamma[1, a]^2*
      PolyGamma[7, a] + 1980*PolyGamma[0, a]*PolyGamma[2, a]*
      PolyGamma[7, a] + 495*PolyGamma[3, a]*PolyGamma[7, a] + 
     220*PolyGamma[0, a]^3*PolyGamma[8, a] + 660*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[8, a] + 220*PolyGamma[2, a]*PolyGamma[8, a] + 
     66*PolyGamma[0, a]^2*PolyGamma[9, a] + 66*PolyGamma[1, a]*
      PolyGamma[9, a] + 12*PolyGamma[0, a]*PolyGamma[10, a] + PolyGamma[11, a]
 
MBexpGam[a_, 13] = PolyGamma[0, a]^13 + 78*PolyGamma[0, a]^11*
      PolyGamma[1, a] + 2145*PolyGamma[0, a]^9*PolyGamma[1, a]^2 + 
     25740*PolyGamma[0, a]^7*PolyGamma[1, a]^3 + 135135*PolyGamma[0, a]^5*
      PolyGamma[1, a]^4 + 270270*PolyGamma[0, a]^3*PolyGamma[1, a]^5 + 
     135135*PolyGamma[0, a]*PolyGamma[1, a]^6 + 286*PolyGamma[0, a]^10*
      PolyGamma[2, a] + 12870*PolyGamma[0, a]^8*PolyGamma[1, a]*
      PolyGamma[2, a] + 180180*PolyGamma[0, a]^6*PolyGamma[1, a]^2*
      PolyGamma[2, a] + 900900*PolyGamma[0, a]^4*PolyGamma[1, a]^3*
      PolyGamma[2, a] + 1351350*PolyGamma[0, a]^2*PolyGamma[1, a]^4*
      PolyGamma[2, a] + 270270*PolyGamma[1, a]^5*PolyGamma[2, a] + 
     17160*PolyGamma[0, a]^7*PolyGamma[2, a]^2 + 360360*PolyGamma[0, a]^5*
      PolyGamma[1, a]*PolyGamma[2, a]^2 + 1801800*PolyGamma[0, a]^3*
      PolyGamma[1, a]^2*PolyGamma[2, a]^2 + 1801800*PolyGamma[0, a]*
      PolyGamma[1, a]^3*PolyGamma[2, a]^2 + 200200*PolyGamma[0, a]^4*
      PolyGamma[2, a]^3 + 1201200*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[2, a]^3 + 600600*PolyGamma[1, a]^2*PolyGamma[2, a]^3 + 
     200200*PolyGamma[0, a]*PolyGamma[2, a]^4 + 715*PolyGamma[0, a]^9*
      PolyGamma[3, a] + 25740*PolyGamma[0, a]^7*PolyGamma[1, a]*
      PolyGamma[3, a] + 270270*PolyGamma[0, a]^5*PolyGamma[1, a]^2*
      PolyGamma[3, a] + 900900*PolyGamma[0, a]^3*PolyGamma[1, a]^3*
      PolyGamma[3, a] + 675675*PolyGamma[0, a]*PolyGamma[1, a]^4*
      PolyGamma[3, a] + 60060*PolyGamma[0, a]^6*PolyGamma[2, a]*
      PolyGamma[3, a] + 900900*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a] + 2702700*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[3, a] + 
     900900*PolyGamma[1, a]^3*PolyGamma[2, a]*PolyGamma[3, a] + 
     600600*PolyGamma[0, a]^3*PolyGamma[2, a]^2*PolyGamma[3, a] + 
     1801800*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[3, a] + 200200*PolyGamma[2, a]^3*PolyGamma[3, a] + 
     45045*PolyGamma[0, a]^5*PolyGamma[3, a]^2 + 450450*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[3, a]^2 + 675675*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[3, a]^2 + 450450*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[3, a]^2 + 450450*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]^2 + 75075*PolyGamma[0, a]*
      PolyGamma[3, a]^3 + 1287*PolyGamma[0, a]^8*PolyGamma[4, a] + 
     36036*PolyGamma[0, a]^6*PolyGamma[1, a]*PolyGamma[4, a] + 
     270270*PolyGamma[0, a]^4*PolyGamma[1, a]^2*PolyGamma[4, a] + 
     540540*PolyGamma[0, a]^2*PolyGamma[1, a]^3*PolyGamma[4, a] + 
     135135*PolyGamma[1, a]^4*PolyGamma[4, a] + 72072*PolyGamma[0, a]^5*
      PolyGamma[2, a]*PolyGamma[4, a] + 720720*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[4, a] + 
     1081080*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[4, a] + 360360*PolyGamma[0, a]^2*PolyGamma[2, a]^2*
      PolyGamma[4, a] + 360360*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[4, a] + 90090*PolyGamma[0, a]^4*PolyGamma[3, a]*
      PolyGamma[4, a] + 540540*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[3, a]*PolyGamma[4, a] + 270270*PolyGamma[1, a]^2*
      PolyGamma[3, a]*PolyGamma[4, a] + 360360*PolyGamma[0, a]*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a] + 
     45045*PolyGamma[3, a]^2*PolyGamma[4, a] + 36036*PolyGamma[0, a]^3*
      PolyGamma[4, a]^2 + 108108*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[4, a]^2 + 36036*PolyGamma[2, a]*PolyGamma[4, a]^2 + 
     1716*PolyGamma[0, a]^7*PolyGamma[5, a] + 36036*PolyGamma[0, a]^5*
      PolyGamma[1, a]*PolyGamma[5, a] + 180180*PolyGamma[0, a]^3*
      PolyGamma[1, a]^2*PolyGamma[5, a] + 180180*PolyGamma[0, a]*
      PolyGamma[1, a]^3*PolyGamma[5, a] + 60060*PolyGamma[0, a]^4*
      PolyGamma[2, a]*PolyGamma[5, a] + 360360*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[5, a] + 
     180180*PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[5, a] + 
     120120*PolyGamma[0, a]*PolyGamma[2, a]^2*PolyGamma[5, a] + 
     60060*PolyGamma[0, a]^3*PolyGamma[3, a]*PolyGamma[5, a] + 
     180180*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[5, a] + 
     60060*PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[5, a] + 
     36036*PolyGamma[0, a]^2*PolyGamma[4, a]*PolyGamma[5, a] + 
     36036*PolyGamma[1, a]*PolyGamma[4, a]*PolyGamma[5, a] + 
     6006*PolyGamma[0, a]*PolyGamma[5, a]^2 + 1716*PolyGamma[0, a]^6*
      PolyGamma[6, a] + 25740*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[6, a] + 77220*PolyGamma[0, a]^2*PolyGamma[1, a]^2*
      PolyGamma[6, a] + 25740*PolyGamma[1, a]^3*PolyGamma[6, a] + 
     34320*PolyGamma[0, a]^3*PolyGamma[2, a]*PolyGamma[6, a] + 
     102960*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[6, a] + 
     17160*PolyGamma[2, a]^2*PolyGamma[6, a] + 25740*PolyGamma[0, a]^2*
      PolyGamma[3, a]*PolyGamma[6, a] + 25740*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[6, a] + 10296*PolyGamma[0, a]*PolyGamma[4, a]*
      PolyGamma[6, a] + 1716*PolyGamma[5, a]*PolyGamma[6, a] + 
     1287*PolyGamma[0, a]^5*PolyGamma[7, a] + 12870*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[7, a] + 19305*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[7, a] + 12870*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[7, a] + 12870*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[7, a] + 6435*PolyGamma[0, a]*PolyGamma[3, a]*
      PolyGamma[7, a] + 1287*PolyGamma[4, a]*PolyGamma[7, a] + 
     715*PolyGamma[0, a]^4*PolyGamma[8, a] + 4290*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[8, a] + 2145*PolyGamma[1, a]^2*
      PolyGamma[8, a] + 2860*PolyGamma[0, a]*PolyGamma[2, a]*
      PolyGamma[8, a] + 715*PolyGamma[3, a]*PolyGamma[8, a] + 
     286*PolyGamma[0, a]^3*PolyGamma[9, a] + 858*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[9, a] + 286*PolyGamma[2, a]*PolyGamma[9, a] + 
     78*PolyGamma[0, a]^2*PolyGamma[10, a] + 78*PolyGamma[1, a]*
      PolyGamma[10, a] + 13*PolyGamma[0, a]*PolyGamma[11, a] + 
     PolyGamma[12, a]
 
MBexpGam[a_, 14] = PolyGamma[0, a]^14 + 91*PolyGamma[0, a]^12*
      PolyGamma[1, a] + 3003*PolyGamma[0, a]^10*PolyGamma[1, a]^2 + 
     45045*PolyGamma[0, a]^8*PolyGamma[1, a]^3 + 315315*PolyGamma[0, a]^6*
      PolyGamma[1, a]^4 + 945945*PolyGamma[0, a]^4*PolyGamma[1, a]^5 + 
     945945*PolyGamma[0, a]^2*PolyGamma[1, a]^6 + 135135*PolyGamma[1, a]^7 + 
     364*PolyGamma[0, a]^11*PolyGamma[2, a] + 20020*PolyGamma[0, a]^9*
      PolyGamma[1, a]*PolyGamma[2, a] + 360360*PolyGamma[0, a]^7*
      PolyGamma[1, a]^2*PolyGamma[2, a] + 2522520*PolyGamma[0, a]^5*
      PolyGamma[1, a]^3*PolyGamma[2, a] + 6306300*PolyGamma[0, a]^3*
      PolyGamma[1, a]^4*PolyGamma[2, a] + 3783780*PolyGamma[0, a]*
      PolyGamma[1, a]^5*PolyGamma[2, a] + 30030*PolyGamma[0, a]^8*
      PolyGamma[2, a]^2 + 840840*PolyGamma[0, a]^6*PolyGamma[1, a]*
      PolyGamma[2, a]^2 + 6306300*PolyGamma[0, a]^4*PolyGamma[1, a]^2*
      PolyGamma[2, a]^2 + 12612600*PolyGamma[0, a]^2*PolyGamma[1, a]^3*
      PolyGamma[2, a]^2 + 3153150*PolyGamma[1, a]^4*PolyGamma[2, a]^2 + 
     560560*PolyGamma[0, a]^5*PolyGamma[2, a]^3 + 5605600*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[2, a]^3 + 8408400*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[2, a]^3 + 1401400*PolyGamma[0, a]^2*
      PolyGamma[2, a]^4 + 1401400*PolyGamma[1, a]*PolyGamma[2, a]^4 + 
     1001*PolyGamma[0, a]^10*PolyGamma[3, a] + 45045*PolyGamma[0, a]^8*
      PolyGamma[1, a]*PolyGamma[3, a] + 630630*PolyGamma[0, a]^6*
      PolyGamma[1, a]^2*PolyGamma[3, a] + 3153150*PolyGamma[0, a]^4*
      PolyGamma[1, a]^3*PolyGamma[3, a] + 4729725*PolyGamma[0, a]^2*
      PolyGamma[1, a]^4*PolyGamma[3, a] + 945945*PolyGamma[1, a]^5*
      PolyGamma[3, a] + 120120*PolyGamma[0, a]^7*PolyGamma[2, a]*
      PolyGamma[3, a] + 2522520*PolyGamma[0, a]^5*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a] + 12612600*PolyGamma[0, a]^3*
      PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[3, a] + 
     12612600*PolyGamma[0, a]*PolyGamma[1, a]^3*PolyGamma[2, a]*
      PolyGamma[3, a] + 2102100*PolyGamma[0, a]^4*PolyGamma[2, a]^2*
      PolyGamma[3, a] + 12612600*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[3, a] + 6306300*PolyGamma[1, a]^2*
      PolyGamma[2, a]^2*PolyGamma[3, a] + 2802800*PolyGamma[0, a]*
      PolyGamma[2, a]^3*PolyGamma[3, a] + 105105*PolyGamma[0, a]^6*
      PolyGamma[3, a]^2 + 1576575*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[3, a]^2 + 4729725*PolyGamma[0, a]^2*PolyGamma[1, a]^2*
      PolyGamma[3, a]^2 + 1576575*PolyGamma[1, a]^3*PolyGamma[3, a]^2 + 
     2102100*PolyGamma[0, a]^3*PolyGamma[2, a]*PolyGamma[3, a]^2 + 
     6306300*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[3, a]^2 + 1051050*PolyGamma[2, a]^2*PolyGamma[3, a]^2 + 
     525525*PolyGamma[0, a]^2*PolyGamma[3, a]^3 + 525525*PolyGamma[1, a]*
      PolyGamma[3, a]^3 + 2002*PolyGamma[0, a]^9*PolyGamma[4, a] + 
     72072*PolyGamma[0, a]^7*PolyGamma[1, a]*PolyGamma[4, a] + 
     756756*PolyGamma[0, a]^5*PolyGamma[1, a]^2*PolyGamma[4, a] + 
     2522520*PolyGamma[0, a]^3*PolyGamma[1, a]^3*PolyGamma[4, a] + 
     1891890*PolyGamma[0, a]*PolyGamma[1, a]^4*PolyGamma[4, a] + 
     168168*PolyGamma[0, a]^6*PolyGamma[2, a]*PolyGamma[4, a] + 
     2522520*PolyGamma[0, a]^4*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[4, a] + 7567560*PolyGamma[0, a]^2*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[4, a] + 2522520*PolyGamma[1, a]^3*
      PolyGamma[2, a]*PolyGamma[4, a] + 1681680*PolyGamma[0, a]^3*
      PolyGamma[2, a]^2*PolyGamma[4, a] + 5045040*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[2, a]^2*PolyGamma[4, a] + 
     560560*PolyGamma[2, a]^3*PolyGamma[4, a] + 252252*PolyGamma[0, a]^5*
      PolyGamma[3, a]*PolyGamma[4, a] + 2522520*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[4, a] + 
     3783780*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[3, a]*
      PolyGamma[4, a] + 2522520*PolyGamma[0, a]^2*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[4, a] + 2522520*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a] + 
     630630*PolyGamma[0, a]*PolyGamma[3, a]^2*PolyGamma[4, a] + 
     126126*PolyGamma[0, a]^4*PolyGamma[4, a]^2 + 756756*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[4, a]^2 + 378378*PolyGamma[1, a]^2*
      PolyGamma[4, a]^2 + 504504*PolyGamma[0, a]*PolyGamma[2, a]*
      PolyGamma[4, a]^2 + 126126*PolyGamma[3, a]*PolyGamma[4, a]^2 + 
     3003*PolyGamma[0, a]^8*PolyGamma[5, a] + 84084*PolyGamma[0, a]^6*
      PolyGamma[1, a]*PolyGamma[5, a] + 630630*PolyGamma[0, a]^4*
      PolyGamma[1, a]^2*PolyGamma[5, a] + 1261260*PolyGamma[0, a]^2*
      PolyGamma[1, a]^3*PolyGamma[5, a] + 315315*PolyGamma[1, a]^4*
      PolyGamma[5, a] + 168168*PolyGamma[0, a]^5*PolyGamma[2, a]*
      PolyGamma[5, a] + 1681680*PolyGamma[0, a]^3*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[5, a] + 2522520*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[5, a] + 
     840840*PolyGamma[0, a]^2*PolyGamma[2, a]^2*PolyGamma[5, a] + 
     840840*PolyGamma[1, a]*PolyGamma[2, a]^2*PolyGamma[5, a] + 
     210210*PolyGamma[0, a]^4*PolyGamma[3, a]*PolyGamma[5, a] + 
     1261260*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[5, a] + 630630*PolyGamma[1, a]^2*PolyGamma[3, a]*
      PolyGamma[5, a] + 840840*PolyGamma[0, a]*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[5, a] + 105105*PolyGamma[3, a]^2*
      PolyGamma[5, a] + 168168*PolyGamma[0, a]^3*PolyGamma[4, a]*
      PolyGamma[5, a] + 504504*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[4, a]*PolyGamma[5, a] + 168168*PolyGamma[2, a]*
      PolyGamma[4, a]*PolyGamma[5, a] + 42042*PolyGamma[0, a]^2*
      PolyGamma[5, a]^2 + 42042*PolyGamma[1, a]*PolyGamma[5, a]^2 + 
     3432*PolyGamma[0, a]^7*PolyGamma[6, a] + 72072*PolyGamma[0, a]^5*
      PolyGamma[1, a]*PolyGamma[6, a] + 360360*PolyGamma[0, a]^3*
      PolyGamma[1, a]^2*PolyGamma[6, a] + 360360*PolyGamma[0, a]*
      PolyGamma[1, a]^3*PolyGamma[6, a] + 120120*PolyGamma[0, a]^4*
      PolyGamma[2, a]*PolyGamma[6, a] + 720720*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[6, a] + 
     360360*PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[6, a] + 
     240240*PolyGamma[0, a]*PolyGamma[2, a]^2*PolyGamma[6, a] + 
     120120*PolyGamma[0, a]^3*PolyGamma[3, a]*PolyGamma[6, a] + 
     360360*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[6, a] + 
     120120*PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[6, a] + 
     72072*PolyGamma[0, a]^2*PolyGamma[4, a]*PolyGamma[6, a] + 
     72072*PolyGamma[1, a]*PolyGamma[4, a]*PolyGamma[6, a] + 
     24024*PolyGamma[0, a]*PolyGamma[5, a]*PolyGamma[6, a] + 
     1716*PolyGamma[6, a]^2 + 3003*PolyGamma[0, a]^6*PolyGamma[7, a] + 
     45045*PolyGamma[0, a]^4*PolyGamma[1, a]*PolyGamma[7, a] + 
     135135*PolyGamma[0, a]^2*PolyGamma[1, a]^2*PolyGamma[7, a] + 
     45045*PolyGamma[1, a]^3*PolyGamma[7, a] + 60060*PolyGamma[0, a]^3*
      PolyGamma[2, a]*PolyGamma[7, a] + 180180*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[7, a] + 
     30030*PolyGamma[2, a]^2*PolyGamma[7, a] + 45045*PolyGamma[0, a]^2*
      PolyGamma[3, a]*PolyGamma[7, a] + 45045*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[7, a] + 18018*PolyGamma[0, a]*PolyGamma[4, a]*
      PolyGamma[7, a] + 3003*PolyGamma[5, a]*PolyGamma[7, a] + 
     2002*PolyGamma[0, a]^5*PolyGamma[8, a] + 20020*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[8, a] + 30030*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[8, a] + 20020*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[8, a] + 20020*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[8, a] + 10010*PolyGamma[0, a]*PolyGamma[3, a]*
      PolyGamma[8, a] + 2002*PolyGamma[4, a]*PolyGamma[8, a] + 
     1001*PolyGamma[0, a]^4*PolyGamma[9, a] + 6006*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[9, a] + 3003*PolyGamma[1, a]^2*
      PolyGamma[9, a] + 4004*PolyGamma[0, a]*PolyGamma[2, a]*
      PolyGamma[9, a] + 1001*PolyGamma[3, a]*PolyGamma[9, a] + 
     364*PolyGamma[0, a]^3*PolyGamma[10, a] + 1092*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[10, a] + 364*PolyGamma[2, a]*
      PolyGamma[10, a] + 91*PolyGamma[0, a]^2*PolyGamma[11, a] + 
     91*PolyGamma[1, a]*PolyGamma[11, a] + 14*PolyGamma[0, a]*
      PolyGamma[12, a] + PolyGamma[13, a]
 
MBexpGam[a_, 15] = PolyGamma[0, a]^15 + 105*PolyGamma[0, a]^13*
      PolyGamma[1, a] + 4095*PolyGamma[0, a]^11*PolyGamma[1, a]^2 + 
     75075*PolyGamma[0, a]^9*PolyGamma[1, a]^3 + 675675*PolyGamma[0, a]^7*
      PolyGamma[1, a]^4 + 2837835*PolyGamma[0, a]^5*PolyGamma[1, a]^5 + 
     4729725*PolyGamma[0, a]^3*PolyGamma[1, a]^6 + 2027025*PolyGamma[0, a]*
      PolyGamma[1, a]^7 + 455*PolyGamma[0, a]^12*PolyGamma[2, a] + 
     30030*PolyGamma[0, a]^10*PolyGamma[1, a]*PolyGamma[2, a] + 
     675675*PolyGamma[0, a]^8*PolyGamma[1, a]^2*PolyGamma[2, a] + 
     6306300*PolyGamma[0, a]^6*PolyGamma[1, a]^3*PolyGamma[2, a] + 
     23648625*PolyGamma[0, a]^4*PolyGamma[1, a]^4*PolyGamma[2, a] + 
     28378350*PolyGamma[0, a]^2*PolyGamma[1, a]^5*PolyGamma[2, a] + 
     4729725*PolyGamma[1, a]^6*PolyGamma[2, a] + 50050*PolyGamma[0, a]^9*
      PolyGamma[2, a]^2 + 1801800*PolyGamma[0, a]^7*PolyGamma[1, a]*
      PolyGamma[2, a]^2 + 18918900*PolyGamma[0, a]^5*PolyGamma[1, a]^2*
      PolyGamma[2, a]^2 + 63063000*PolyGamma[0, a]^3*PolyGamma[1, a]^3*
      PolyGamma[2, a]^2 + 47297250*PolyGamma[0, a]*PolyGamma[1, a]^4*
      PolyGamma[2, a]^2 + 1401400*PolyGamma[0, a]^6*PolyGamma[2, a]^3 + 
     21021000*PolyGamma[0, a]^4*PolyGamma[1, a]*PolyGamma[2, a]^3 + 
     63063000*PolyGamma[0, a]^2*PolyGamma[1, a]^2*PolyGamma[2, a]^3 + 
     21021000*PolyGamma[1, a]^3*PolyGamma[2, a]^3 + 
     7007000*PolyGamma[0, a]^3*PolyGamma[2, a]^4 + 21021000*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[2, a]^4 + 1401400*PolyGamma[2, a]^5 + 
     1365*PolyGamma[0, a]^11*PolyGamma[3, a] + 75075*PolyGamma[0, a]^9*
      PolyGamma[1, a]*PolyGamma[3, a] + 1351350*PolyGamma[0, a]^7*
      PolyGamma[1, a]^2*PolyGamma[3, a] + 9459450*PolyGamma[0, a]^5*
      PolyGamma[1, a]^3*PolyGamma[3, a] + 23648625*PolyGamma[0, a]^3*
      PolyGamma[1, a]^4*PolyGamma[3, a] + 14189175*PolyGamma[0, a]*
      PolyGamma[1, a]^5*PolyGamma[3, a] + 225225*PolyGamma[0, a]^8*
      PolyGamma[2, a]*PolyGamma[3, a] + 6306300*PolyGamma[0, a]^6*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[3, a] + 
     47297250*PolyGamma[0, a]^4*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[3, a] + 94594500*PolyGamma[0, a]^2*PolyGamma[1, a]^3*
      PolyGamma[2, a]*PolyGamma[3, a] + 23648625*PolyGamma[1, a]^4*
      PolyGamma[2, a]*PolyGamma[3, a] + 6306300*PolyGamma[0, a]^5*
      PolyGamma[2, a]^2*PolyGamma[3, a] + 63063000*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[2, a]^2*PolyGamma[3, a] + 
     94594500*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[2, a]^2*
      PolyGamma[3, a] + 21021000*PolyGamma[0, a]^2*PolyGamma[2, a]^3*
      PolyGamma[3, a] + 21021000*PolyGamma[1, a]*PolyGamma[2, a]^3*
      PolyGamma[3, a] + 225225*PolyGamma[0, a]^7*PolyGamma[3, a]^2 + 
     4729725*PolyGamma[0, a]^5*PolyGamma[1, a]*PolyGamma[3, a]^2 + 
     23648625*PolyGamma[0, a]^3*PolyGamma[1, a]^2*PolyGamma[3, a]^2 + 
     23648625*PolyGamma[0, a]*PolyGamma[1, a]^3*PolyGamma[3, a]^2 + 
     7882875*PolyGamma[0, a]^4*PolyGamma[2, a]*PolyGamma[3, a]^2 + 
     47297250*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[3, a]^2 + 23648625*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[3, a]^2 + 15765750*PolyGamma[0, a]*PolyGamma[2, a]^2*
      PolyGamma[3, a]^2 + 2627625*PolyGamma[0, a]^3*PolyGamma[3, a]^3 + 
     7882875*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[3, a]^3 + 
     2627625*PolyGamma[2, a]*PolyGamma[3, a]^3 + 3003*PolyGamma[0, a]^10*
      PolyGamma[4, a] + 135135*PolyGamma[0, a]^8*PolyGamma[1, a]*
      PolyGamma[4, a] + 1891890*PolyGamma[0, a]^6*PolyGamma[1, a]^2*
      PolyGamma[4, a] + 9459450*PolyGamma[0, a]^4*PolyGamma[1, a]^3*
      PolyGamma[4, a] + 14189175*PolyGamma[0, a]^2*PolyGamma[1, a]^4*
      PolyGamma[4, a] + 2837835*PolyGamma[1, a]^5*PolyGamma[4, a] + 
     360360*PolyGamma[0, a]^7*PolyGamma[2, a]*PolyGamma[4, a] + 
     7567560*PolyGamma[0, a]^5*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[4, a] + 37837800*PolyGamma[0, a]^3*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[4, a] + 37837800*PolyGamma[0, a]*
      PolyGamma[1, a]^3*PolyGamma[2, a]*PolyGamma[4, a] + 
     6306300*PolyGamma[0, a]^4*PolyGamma[2, a]^2*PolyGamma[4, a] + 
     37837800*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[4, a] + 18918900*PolyGamma[1, a]^2*PolyGamma[2, a]^2*
      PolyGamma[4, a] + 8408400*PolyGamma[0, a]*PolyGamma[2, a]^3*
      PolyGamma[4, a] + 630630*PolyGamma[0, a]^6*PolyGamma[3, a]*
      PolyGamma[4, a] + 9459450*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[3, a]*PolyGamma[4, a] + 28378350*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[3, a]*PolyGamma[4, a] + 
     9459450*PolyGamma[1, a]^3*PolyGamma[3, a]*PolyGamma[4, a] + 
     12612600*PolyGamma[0, a]^3*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[4, a] + 37837800*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a] + 
     6306300*PolyGamma[2, a]^2*PolyGamma[3, a]*PolyGamma[4, a] + 
     4729725*PolyGamma[0, a]^2*PolyGamma[3, a]^2*PolyGamma[4, a] + 
     4729725*PolyGamma[1, a]*PolyGamma[3, a]^2*PolyGamma[4, a] + 
     378378*PolyGamma[0, a]^5*PolyGamma[4, a]^2 + 3783780*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[4, a]^2 + 5675670*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[4, a]^2 + 3783780*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[4, a]^2 + 3783780*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[4, a]^2 + 1891890*PolyGamma[0, a]*
      PolyGamma[3, a]*PolyGamma[4, a]^2 + 126126*PolyGamma[4, a]^3 + 
     5005*PolyGamma[0, a]^9*PolyGamma[5, a] + 180180*PolyGamma[0, a]^7*
      PolyGamma[1, a]*PolyGamma[5, a] + 1891890*PolyGamma[0, a]^5*
      PolyGamma[1, a]^2*PolyGamma[5, a] + 6306300*PolyGamma[0, a]^3*
      PolyGamma[1, a]^3*PolyGamma[5, a] + 4729725*PolyGamma[0, a]*
      PolyGamma[1, a]^4*PolyGamma[5, a] + 420420*PolyGamma[0, a]^6*
      PolyGamma[2, a]*PolyGamma[5, a] + 6306300*PolyGamma[0, a]^4*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[5, a] + 
     18918900*PolyGamma[0, a]^2*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[5, a] + 6306300*PolyGamma[1, a]^3*PolyGamma[2, a]*
      PolyGamma[5, a] + 4204200*PolyGamma[0, a]^3*PolyGamma[2, a]^2*
      PolyGamma[5, a] + 12612600*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[5, a] + 1401400*PolyGamma[2, a]^3*
      PolyGamma[5, a] + 630630*PolyGamma[0, a]^5*PolyGamma[3, a]*
      PolyGamma[5, a] + 6306300*PolyGamma[0, a]^3*PolyGamma[1, a]*
      PolyGamma[3, a]*PolyGamma[5, a] + 9459450*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[3, a]*PolyGamma[5, a] + 
     6306300*PolyGamma[0, a]^2*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[5, a] + 6306300*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[5, a] + 1576575*PolyGamma[0, a]*
      PolyGamma[3, a]^2*PolyGamma[5, a] + 630630*PolyGamma[0, a]^4*
      PolyGamma[4, a]*PolyGamma[5, a] + 3783780*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[4, a]*PolyGamma[5, a] + 
     1891890*PolyGamma[1, a]^2*PolyGamma[4, a]*PolyGamma[5, a] + 
     2522520*PolyGamma[0, a]*PolyGamma[2, a]*PolyGamma[4, a]*
      PolyGamma[5, a] + 630630*PolyGamma[3, a]*PolyGamma[4, a]*
      PolyGamma[5, a] + 210210*PolyGamma[0, a]^3*PolyGamma[5, a]^2 + 
     630630*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[5, a]^2 + 
     210210*PolyGamma[2, a]*PolyGamma[5, a]^2 + 6435*PolyGamma[0, a]^8*
      PolyGamma[6, a] + 180180*PolyGamma[0, a]^6*PolyGamma[1, a]*
      PolyGamma[6, a] + 1351350*PolyGamma[0, a]^4*PolyGamma[1, a]^2*
      PolyGamma[6, a] + 2702700*PolyGamma[0, a]^2*PolyGamma[1, a]^3*
      PolyGamma[6, a] + 675675*PolyGamma[1, a]^4*PolyGamma[6, a] + 
     360360*PolyGamma[0, a]^5*PolyGamma[2, a]*PolyGamma[6, a] + 
     3603600*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[6, a] + 5405400*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[6, a] + 1801800*PolyGamma[0, a]^2*
      PolyGamma[2, a]^2*PolyGamma[6, a] + 1801800*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[6, a] + 450450*PolyGamma[0, a]^4*
      PolyGamma[3, a]*PolyGamma[6, a] + 2702700*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[6, a] + 
     1351350*PolyGamma[1, a]^2*PolyGamma[3, a]*PolyGamma[6, a] + 
     1801800*PolyGamma[0, a]*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[6, a] + 225225*PolyGamma[3, a]^2*PolyGamma[6, a] + 
     360360*PolyGamma[0, a]^3*PolyGamma[4, a]*PolyGamma[6, a] + 
     1081080*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[6, a] + 360360*PolyGamma[2, a]*PolyGamma[4, a]*
      PolyGamma[6, a] + 180180*PolyGamma[0, a]^2*PolyGamma[5, a]*
      PolyGamma[6, a] + 180180*PolyGamma[1, a]*PolyGamma[5, a]*
      PolyGamma[6, a] + 25740*PolyGamma[0, a]*PolyGamma[6, a]^2 + 
     6435*PolyGamma[0, a]^7*PolyGamma[7, a] + 135135*PolyGamma[0, a]^5*
      PolyGamma[1, a]*PolyGamma[7, a] + 675675*PolyGamma[0, a]^3*
      PolyGamma[1, a]^2*PolyGamma[7, a] + 675675*PolyGamma[0, a]*
      PolyGamma[1, a]^3*PolyGamma[7, a] + 225225*PolyGamma[0, a]^4*
      PolyGamma[2, a]*PolyGamma[7, a] + 1351350*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[7, a] + 
     675675*PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[7, a] + 
     450450*PolyGamma[0, a]*PolyGamma[2, a]^2*PolyGamma[7, a] + 
     225225*PolyGamma[0, a]^3*PolyGamma[3, a]*PolyGamma[7, a] + 
     675675*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[7, a] + 
     225225*PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[7, a] + 
     135135*PolyGamma[0, a]^2*PolyGamma[4, a]*PolyGamma[7, a] + 
     135135*PolyGamma[1, a]*PolyGamma[4, a]*PolyGamma[7, a] + 
     45045*PolyGamma[0, a]*PolyGamma[5, a]*PolyGamma[7, a] + 
     6435*PolyGamma[6, a]*PolyGamma[7, a] + 5005*PolyGamma[0, a]^6*
      PolyGamma[8, a] + 75075*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[8, a] + 225225*PolyGamma[0, a]^2*PolyGamma[1, a]^2*
      PolyGamma[8, a] + 75075*PolyGamma[1, a]^3*PolyGamma[8, a] + 
     100100*PolyGamma[0, a]^3*PolyGamma[2, a]*PolyGamma[8, a] + 
     300300*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[8, a] + 
     50050*PolyGamma[2, a]^2*PolyGamma[8, a] + 75075*PolyGamma[0, a]^2*
      PolyGamma[3, a]*PolyGamma[8, a] + 75075*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[8, a] + 30030*PolyGamma[0, a]*PolyGamma[4, a]*
      PolyGamma[8, a] + 5005*PolyGamma[5, a]*PolyGamma[8, a] + 
     3003*PolyGamma[0, a]^5*PolyGamma[9, a] + 30030*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[9, a] + 45045*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[9, a] + 30030*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[9, a] + 30030*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[9, a] + 15015*PolyGamma[0, a]*PolyGamma[3, a]*
      PolyGamma[9, a] + 3003*PolyGamma[4, a]*PolyGamma[9, a] + 
     1365*PolyGamma[0, a]^4*PolyGamma[10, a] + 8190*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[10, a] + 4095*PolyGamma[1, a]^2*
      PolyGamma[10, a] + 5460*PolyGamma[0, a]*PolyGamma[2, a]*
      PolyGamma[10, a] + 1365*PolyGamma[3, a]*PolyGamma[10, a] + 
     455*PolyGamma[0, a]^3*PolyGamma[11, a] + 1365*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[11, a] + 455*PolyGamma[2, a]*
      PolyGamma[11, a] + 105*PolyGamma[0, a]^2*PolyGamma[12, a] + 
     105*PolyGamma[1, a]*PolyGamma[12, a] + 15*PolyGamma[0, a]*
      PolyGamma[13, a] + PolyGamma[14, a]
 
MBexpGam[a_, 16] = PolyGamma[0, a]^16 + 120*PolyGamma[0, a]^14*
      PolyGamma[1, a] + 5460*PolyGamma[0, a]^12*PolyGamma[1, a]^2 + 
     120120*PolyGamma[0, a]^10*PolyGamma[1, a]^3 + 1351350*PolyGamma[0, a]^8*
      PolyGamma[1, a]^4 + 7567560*PolyGamma[0, a]^6*PolyGamma[1, a]^5 + 
     18918900*PolyGamma[0, a]^4*PolyGamma[1, a]^6 + 
     16216200*PolyGamma[0, a]^2*PolyGamma[1, a]^7 + 
     2027025*PolyGamma[1, a]^8 + 560*PolyGamma[0, a]^13*PolyGamma[2, a] + 
     43680*PolyGamma[0, a]^11*PolyGamma[1, a]*PolyGamma[2, a] + 
     1201200*PolyGamma[0, a]^9*PolyGamma[1, a]^2*PolyGamma[2, a] + 
     14414400*PolyGamma[0, a]^7*PolyGamma[1, a]^3*PolyGamma[2, a] + 
     75675600*PolyGamma[0, a]^5*PolyGamma[1, a]^4*PolyGamma[2, a] + 
     151351200*PolyGamma[0, a]^3*PolyGamma[1, a]^5*PolyGamma[2, a] + 
     75675600*PolyGamma[0, a]*PolyGamma[1, a]^6*PolyGamma[2, a] + 
     80080*PolyGamma[0, a]^10*PolyGamma[2, a]^2 + 3603600*PolyGamma[0, a]^8*
      PolyGamma[1, a]*PolyGamma[2, a]^2 + 50450400*PolyGamma[0, a]^6*
      PolyGamma[1, a]^2*PolyGamma[2, a]^2 + 252252000*PolyGamma[0, a]^4*
      PolyGamma[1, a]^3*PolyGamma[2, a]^2 + 378378000*PolyGamma[0, a]^2*
      PolyGamma[1, a]^4*PolyGamma[2, a]^2 + 75675600*PolyGamma[1, a]^5*
      PolyGamma[2, a]^2 + 3203200*PolyGamma[0, a]^7*PolyGamma[2, a]^3 + 
     67267200*PolyGamma[0, a]^5*PolyGamma[1, a]*PolyGamma[2, a]^3 + 
     336336000*PolyGamma[0, a]^3*PolyGamma[1, a]^2*PolyGamma[2, a]^3 + 
     336336000*PolyGamma[0, a]*PolyGamma[1, a]^3*PolyGamma[2, a]^3 + 
     28028000*PolyGamma[0, a]^4*PolyGamma[2, a]^4 + 
     168168000*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[2, a]^4 + 
     84084000*PolyGamma[1, a]^2*PolyGamma[2, a]^4 + 
     22422400*PolyGamma[0, a]*PolyGamma[2, a]^5 + 1820*PolyGamma[0, a]^12*
      PolyGamma[3, a] + 120120*PolyGamma[0, a]^10*PolyGamma[1, a]*
      PolyGamma[3, a] + 2702700*PolyGamma[0, a]^8*PolyGamma[1, a]^2*
      PolyGamma[3, a] + 25225200*PolyGamma[0, a]^6*PolyGamma[1, a]^3*
      PolyGamma[3, a] + 94594500*PolyGamma[0, a]^4*PolyGamma[1, a]^4*
      PolyGamma[3, a] + 113513400*PolyGamma[0, a]^2*PolyGamma[1, a]^5*
      PolyGamma[3, a] + 18918900*PolyGamma[1, a]^6*PolyGamma[3, a] + 
     400400*PolyGamma[0, a]^9*PolyGamma[2, a]*PolyGamma[3, a] + 
     14414400*PolyGamma[0, a]^7*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[3, a] + 151351200*PolyGamma[0, a]^5*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[3, a] + 504504000*PolyGamma[0, a]^3*
      PolyGamma[1, a]^3*PolyGamma[2, a]*PolyGamma[3, a] + 
     378378000*PolyGamma[0, a]*PolyGamma[1, a]^4*PolyGamma[2, a]*
      PolyGamma[3, a] + 16816800*PolyGamma[0, a]^6*PolyGamma[2, a]^2*
      PolyGamma[3, a] + 252252000*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[3, a] + 756756000*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[2, a]^2*PolyGamma[3, a] + 
     252252000*PolyGamma[1, a]^3*PolyGamma[2, a]^2*PolyGamma[3, a] + 
     112112000*PolyGamma[0, a]^3*PolyGamma[2, a]^3*PolyGamma[3, a] + 
     336336000*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]^3*
      PolyGamma[3, a] + 28028000*PolyGamma[2, a]^4*PolyGamma[3, a] + 
     450450*PolyGamma[0, a]^8*PolyGamma[3, a]^2 + 12612600*PolyGamma[0, a]^6*
      PolyGamma[1, a]*PolyGamma[3, a]^2 + 94594500*PolyGamma[0, a]^4*
      PolyGamma[1, a]^2*PolyGamma[3, a]^2 + 189189000*PolyGamma[0, a]^2*
      PolyGamma[1, a]^3*PolyGamma[3, a]^2 + 47297250*PolyGamma[1, a]^4*
      PolyGamma[3, a]^2 + 25225200*PolyGamma[0, a]^5*PolyGamma[2, a]*
      PolyGamma[3, a]^2 + 252252000*PolyGamma[0, a]^3*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]^2 + 378378000*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[3, a]^2 + 
     126126000*PolyGamma[0, a]^2*PolyGamma[2, a]^2*PolyGamma[3, a]^2 + 
     126126000*PolyGamma[1, a]*PolyGamma[2, a]^2*PolyGamma[3, a]^2 + 
     10510500*PolyGamma[0, a]^4*PolyGamma[3, a]^3 + 
     63063000*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[3, a]^3 + 
     31531500*PolyGamma[1, a]^2*PolyGamma[3, a]^3 + 
     42042000*PolyGamma[0, a]*PolyGamma[2, a]*PolyGamma[3, a]^3 + 
     2627625*PolyGamma[3, a]^4 + 4368*PolyGamma[0, a]^11*PolyGamma[4, a] + 
     240240*PolyGamma[0, a]^9*PolyGamma[1, a]*PolyGamma[4, a] + 
     4324320*PolyGamma[0, a]^7*PolyGamma[1, a]^2*PolyGamma[4, a] + 
     30270240*PolyGamma[0, a]^5*PolyGamma[1, a]^3*PolyGamma[4, a] + 
     75675600*PolyGamma[0, a]^3*PolyGamma[1, a]^4*PolyGamma[4, a] + 
     45405360*PolyGamma[0, a]*PolyGamma[1, a]^5*PolyGamma[4, a] + 
     720720*PolyGamma[0, a]^8*PolyGamma[2, a]*PolyGamma[4, a] + 
     20180160*PolyGamma[0, a]^6*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[4, a] + 151351200*PolyGamma[0, a]^4*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[4, a] + 302702400*PolyGamma[0, a]^2*
      PolyGamma[1, a]^3*PolyGamma[2, a]*PolyGamma[4, a] + 
     75675600*PolyGamma[1, a]^4*PolyGamma[2, a]*PolyGamma[4, a] + 
     20180160*PolyGamma[0, a]^5*PolyGamma[2, a]^2*PolyGamma[4, a] + 
     201801600*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[4, a] + 302702400*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[2, a]^2*PolyGamma[4, a] + 67267200*PolyGamma[0, a]^2*
      PolyGamma[2, a]^3*PolyGamma[4, a] + 67267200*PolyGamma[1, a]*
      PolyGamma[2, a]^3*PolyGamma[4, a] + 1441440*PolyGamma[0, a]^7*
      PolyGamma[3, a]*PolyGamma[4, a] + 30270240*PolyGamma[0, a]^5*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[4, a] + 
     151351200*PolyGamma[0, a]^3*PolyGamma[1, a]^2*PolyGamma[3, a]*
      PolyGamma[4, a] + 151351200*PolyGamma[0, a]*PolyGamma[1, a]^3*
      PolyGamma[3, a]*PolyGamma[4, a] + 50450400*PolyGamma[0, a]^4*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a] + 
     302702400*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[4, a] + 151351200*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a] + 
     100900800*PolyGamma[0, a]*PolyGamma[2, a]^2*PolyGamma[3, a]*
      PolyGamma[4, a] + 25225200*PolyGamma[0, a]^3*PolyGamma[3, a]^2*
      PolyGamma[4, a] + 75675600*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[3, a]^2*PolyGamma[4, a] + 25225200*PolyGamma[2, a]*
      PolyGamma[3, a]^2*PolyGamma[4, a] + 1009008*PolyGamma[0, a]^6*
      PolyGamma[4, a]^2 + 15135120*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[4, a]^2 + 45405360*PolyGamma[0, a]^2*PolyGamma[1, a]^2*
      PolyGamma[4, a]^2 + 15135120*PolyGamma[1, a]^3*PolyGamma[4, a]^2 + 
     20180160*PolyGamma[0, a]^3*PolyGamma[2, a]*PolyGamma[4, a]^2 + 
     60540480*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[4, a]^2 + 10090080*PolyGamma[2, a]^2*PolyGamma[4, a]^2 + 
     15135120*PolyGamma[0, a]^2*PolyGamma[3, a]*PolyGamma[4, a]^2 + 
     15135120*PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[4, a]^2 + 
     2018016*PolyGamma[0, a]*PolyGamma[4, a]^3 + 8008*PolyGamma[0, a]^10*
      PolyGamma[5, a] + 360360*PolyGamma[0, a]^8*PolyGamma[1, a]*
      PolyGamma[5, a] + 5045040*PolyGamma[0, a]^6*PolyGamma[1, a]^2*
      PolyGamma[5, a] + 25225200*PolyGamma[0, a]^4*PolyGamma[1, a]^3*
      PolyGamma[5, a] + 37837800*PolyGamma[0, a]^2*PolyGamma[1, a]^4*
      PolyGamma[5, a] + 7567560*PolyGamma[1, a]^5*PolyGamma[5, a] + 
     960960*PolyGamma[0, a]^7*PolyGamma[2, a]*PolyGamma[5, a] + 
     20180160*PolyGamma[0, a]^5*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[5, a] + 100900800*PolyGamma[0, a]^3*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[5, a] + 100900800*PolyGamma[0, a]*
      PolyGamma[1, a]^3*PolyGamma[2, a]*PolyGamma[5, a] + 
     16816800*PolyGamma[0, a]^4*PolyGamma[2, a]^2*PolyGamma[5, a] + 
     100900800*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[5, a] + 50450400*PolyGamma[1, a]^2*PolyGamma[2, a]^2*
      PolyGamma[5, a] + 22422400*PolyGamma[0, a]*PolyGamma[2, a]^3*
      PolyGamma[5, a] + 1681680*PolyGamma[0, a]^6*PolyGamma[3, a]*
      PolyGamma[5, a] + 25225200*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[3, a]*PolyGamma[5, a] + 75675600*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[3, a]*PolyGamma[5, a] + 
     25225200*PolyGamma[1, a]^3*PolyGamma[3, a]*PolyGamma[5, a] + 
     33633600*PolyGamma[0, a]^3*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[5, a] + 100900800*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[5, a] + 
     16816800*PolyGamma[2, a]^2*PolyGamma[3, a]*PolyGamma[5, a] + 
     12612600*PolyGamma[0, a]^2*PolyGamma[3, a]^2*PolyGamma[5, a] + 
     12612600*PolyGamma[1, a]*PolyGamma[3, a]^2*PolyGamma[5, a] + 
     2018016*PolyGamma[0, a]^5*PolyGamma[4, a]*PolyGamma[5, a] + 
     20180160*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[5, a] + 30270240*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[4, a]*PolyGamma[5, a] + 20180160*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[5, a] + 
     20180160*PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[4, a]*
      PolyGamma[5, a] + 10090080*PolyGamma[0, a]*PolyGamma[3, a]*
      PolyGamma[4, a]*PolyGamma[5, a] + 1009008*PolyGamma[4, a]^2*
      PolyGamma[5, a] + 840840*PolyGamma[0, a]^4*PolyGamma[5, a]^2 + 
     5045040*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[5, a]^2 + 
     2522520*PolyGamma[1, a]^2*PolyGamma[5, a]^2 + 3363360*PolyGamma[0, a]*
      PolyGamma[2, a]*PolyGamma[5, a]^2 + 840840*PolyGamma[3, a]*
      PolyGamma[5, a]^2 + 11440*PolyGamma[0, a]^9*PolyGamma[6, a] + 
     411840*PolyGamma[0, a]^7*PolyGamma[1, a]*PolyGamma[6, a] + 
     4324320*PolyGamma[0, a]^5*PolyGamma[1, a]^2*PolyGamma[6, a] + 
     14414400*PolyGamma[0, a]^3*PolyGamma[1, a]^3*PolyGamma[6, a] + 
     10810800*PolyGamma[0, a]*PolyGamma[1, a]^4*PolyGamma[6, a] + 
     960960*PolyGamma[0, a]^6*PolyGamma[2, a]*PolyGamma[6, a] + 
     14414400*PolyGamma[0, a]^4*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[6, a] + 43243200*PolyGamma[0, a]^2*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[6, a] + 14414400*PolyGamma[1, a]^3*
      PolyGamma[2, a]*PolyGamma[6, a] + 9609600*PolyGamma[0, a]^3*
      PolyGamma[2, a]^2*PolyGamma[6, a] + 28828800*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[2, a]^2*PolyGamma[6, a] + 
     3203200*PolyGamma[2, a]^3*PolyGamma[6, a] + 1441440*PolyGamma[0, a]^5*
      PolyGamma[3, a]*PolyGamma[6, a] + 14414400*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[6, a] + 
     21621600*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[3, a]*
      PolyGamma[6, a] + 14414400*PolyGamma[0, a]^2*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[6, a] + 14414400*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[6, a] + 
     3603600*PolyGamma[0, a]*PolyGamma[3, a]^2*PolyGamma[6, a] + 
     1441440*PolyGamma[0, a]^4*PolyGamma[4, a]*PolyGamma[6, a] + 
     8648640*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[6, a] + 4324320*PolyGamma[1, a]^2*PolyGamma[4, a]*
      PolyGamma[6, a] + 5765760*PolyGamma[0, a]*PolyGamma[2, a]*
      PolyGamma[4, a]*PolyGamma[6, a] + 1441440*PolyGamma[3, a]*
      PolyGamma[4, a]*PolyGamma[6, a] + 960960*PolyGamma[0, a]^3*
      PolyGamma[5, a]*PolyGamma[6, a] + 2882880*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[5, a]*PolyGamma[6, a] + 
     960960*PolyGamma[2, a]*PolyGamma[5, a]*PolyGamma[6, a] + 
     205920*PolyGamma[0, a]^2*PolyGamma[6, a]^2 + 205920*PolyGamma[1, a]*
      PolyGamma[6, a]^2 + 12870*PolyGamma[0, a]^8*PolyGamma[7, a] + 
     360360*PolyGamma[0, a]^6*PolyGamma[1, a]*PolyGamma[7, a] + 
     2702700*PolyGamma[0, a]^4*PolyGamma[1, a]^2*PolyGamma[7, a] + 
     5405400*PolyGamma[0, a]^2*PolyGamma[1, a]^3*PolyGamma[7, a] + 
     1351350*PolyGamma[1, a]^4*PolyGamma[7, a] + 720720*PolyGamma[0, a]^5*
      PolyGamma[2, a]*PolyGamma[7, a] + 7207200*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[7, a] + 
     10810800*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[7, a] + 3603600*PolyGamma[0, a]^2*PolyGamma[2, a]^2*
      PolyGamma[7, a] + 3603600*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[7, a] + 900900*PolyGamma[0, a]^4*PolyGamma[3, a]*
      PolyGamma[7, a] + 5405400*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[3, a]*PolyGamma[7, a] + 2702700*PolyGamma[1, a]^2*
      PolyGamma[3, a]*PolyGamma[7, a] + 3603600*PolyGamma[0, a]*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[7, a] + 
     450450*PolyGamma[3, a]^2*PolyGamma[7, a] + 720720*PolyGamma[0, a]^3*
      PolyGamma[4, a]*PolyGamma[7, a] + 2162160*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[4, a]*PolyGamma[7, a] + 
     720720*PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[7, a] + 
     360360*PolyGamma[0, a]^2*PolyGamma[5, a]*PolyGamma[7, a] + 
     360360*PolyGamma[1, a]*PolyGamma[5, a]*PolyGamma[7, a] + 
     102960*PolyGamma[0, a]*PolyGamma[6, a]*PolyGamma[7, a] + 
     6435*PolyGamma[7, a]^2 + 11440*PolyGamma[0, a]^7*PolyGamma[8, a] + 
     240240*PolyGamma[0, a]^5*PolyGamma[1, a]*PolyGamma[8, a] + 
     1201200*PolyGamma[0, a]^3*PolyGamma[1, a]^2*PolyGamma[8, a] + 
     1201200*PolyGamma[0, a]*PolyGamma[1, a]^3*PolyGamma[8, a] + 
     400400*PolyGamma[0, a]^4*PolyGamma[2, a]*PolyGamma[8, a] + 
     2402400*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[8, a] + 1201200*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[8, a] + 800800*PolyGamma[0, a]*PolyGamma[2, a]^2*
      PolyGamma[8, a] + 400400*PolyGamma[0, a]^3*PolyGamma[3, a]*
      PolyGamma[8, a] + 1201200*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[3, a]*PolyGamma[8, a] + 400400*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[8, a] + 240240*PolyGamma[0, a]^2*
      PolyGamma[4, a]*PolyGamma[8, a] + 240240*PolyGamma[1, a]*
      PolyGamma[4, a]*PolyGamma[8, a] + 80080*PolyGamma[0, a]*PolyGamma[5, a]*
      PolyGamma[8, a] + 11440*PolyGamma[6, a]*PolyGamma[8, a] + 
     8008*PolyGamma[0, a]^6*PolyGamma[9, a] + 120120*PolyGamma[0, a]^4*
      PolyGamma[1, a]*PolyGamma[9, a] + 360360*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[9, a] + 120120*PolyGamma[1, a]^3*
      PolyGamma[9, a] + 160160*PolyGamma[0, a]^3*PolyGamma[2, a]*
      PolyGamma[9, a] + 480480*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[9, a] + 80080*PolyGamma[2, a]^2*
      PolyGamma[9, a] + 120120*PolyGamma[0, a]^2*PolyGamma[3, a]*
      PolyGamma[9, a] + 120120*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[9, a] + 48048*PolyGamma[0, a]*PolyGamma[4, a]*
      PolyGamma[9, a] + 8008*PolyGamma[5, a]*PolyGamma[9, a] + 
     4368*PolyGamma[0, a]^5*PolyGamma[10, a] + 43680*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[10, a] + 65520*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[10, a] + 43680*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[10, a] + 43680*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[10, a] + 21840*PolyGamma[0, a]*
      PolyGamma[3, a]*PolyGamma[10, a] + 4368*PolyGamma[4, a]*
      PolyGamma[10, a] + 1820*PolyGamma[0, a]^4*PolyGamma[11, a] + 
     10920*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[11, a] + 
     5460*PolyGamma[1, a]^2*PolyGamma[11, a] + 7280*PolyGamma[0, a]*
      PolyGamma[2, a]*PolyGamma[11, a] + 1820*PolyGamma[3, a]*
      PolyGamma[11, a] + 560*PolyGamma[0, a]^3*PolyGamma[12, a] + 
     1680*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[12, a] + 
     560*PolyGamma[2, a]*PolyGamma[12, a] + 120*PolyGamma[0, a]^2*
      PolyGamma[13, a] + 120*PolyGamma[1, a]*PolyGamma[13, a] + 
     16*PolyGamma[0, a]*PolyGamma[14, a] + PolyGamma[15, a]
 
MBexpGam[a_, 17] = PolyGamma[0, a]^17 + 136*PolyGamma[0, a]^15*
      PolyGamma[1, a] + 7140*PolyGamma[0, a]^13*PolyGamma[1, a]^2 + 
     185640*PolyGamma[0, a]^11*PolyGamma[1, a]^3 + 2552550*PolyGamma[0, a]^9*
      PolyGamma[1, a]^4 + 18378360*PolyGamma[0, a]^7*PolyGamma[1, a]^5 + 
     64324260*PolyGamma[0, a]^5*PolyGamma[1, a]^6 + 
     91891800*PolyGamma[0, a]^3*PolyGamma[1, a]^7 + 
     34459425*PolyGamma[0, a]*PolyGamma[1, a]^8 + 680*PolyGamma[0, a]^14*
      PolyGamma[2, a] + 61880*PolyGamma[0, a]^12*PolyGamma[1, a]*
      PolyGamma[2, a] + 2042040*PolyGamma[0, a]^10*PolyGamma[1, a]^2*
      PolyGamma[2, a] + 30630600*PolyGamma[0, a]^8*PolyGamma[1, a]^3*
      PolyGamma[2, a] + 214414200*PolyGamma[0, a]^6*PolyGamma[1, a]^4*
      PolyGamma[2, a] + 643242600*PolyGamma[0, a]^4*PolyGamma[1, a]^5*
      PolyGamma[2, a] + 643242600*PolyGamma[0, a]^2*PolyGamma[1, a]^6*
      PolyGamma[2, a] + 91891800*PolyGamma[1, a]^7*PolyGamma[2, a] + 
     123760*PolyGamma[0, a]^11*PolyGamma[2, a]^2 + 6806800*PolyGamma[0, a]^9*
      PolyGamma[1, a]*PolyGamma[2, a]^2 + 122522400*PolyGamma[0, a]^7*
      PolyGamma[1, a]^2*PolyGamma[2, a]^2 + 857656800*PolyGamma[0, a]^5*
      PolyGamma[1, a]^3*PolyGamma[2, a]^2 + 2144142000*PolyGamma[0, a]^3*
      PolyGamma[1, a]^4*PolyGamma[2, a]^2 + 1286485200*PolyGamma[0, a]*
      PolyGamma[1, a]^5*PolyGamma[2, a]^2 + 6806800*PolyGamma[0, a]^8*
      PolyGamma[2, a]^3 + 190590400*PolyGamma[0, a]^6*PolyGamma[1, a]*
      PolyGamma[2, a]^3 + 1429428000*PolyGamma[0, a]^4*PolyGamma[1, a]^2*
      PolyGamma[2, a]^3 + 2858856000*PolyGamma[0, a]^2*PolyGamma[1, a]^3*
      PolyGamma[2, a]^3 + 714714000*PolyGamma[1, a]^4*PolyGamma[2, a]^3 + 
     95295200*PolyGamma[0, a]^5*PolyGamma[2, a]^4 + 
     952952000*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[2, a]^4 + 
     1429428000*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[2, a]^4 + 
     190590400*PolyGamma[0, a]^2*PolyGamma[2, a]^5 + 
     190590400*PolyGamma[1, a]*PolyGamma[2, a]^5 + 2380*PolyGamma[0, a]^13*
      PolyGamma[3, a] + 185640*PolyGamma[0, a]^11*PolyGamma[1, a]*
      PolyGamma[3, a] + 5105100*PolyGamma[0, a]^9*PolyGamma[1, a]^2*
      PolyGamma[3, a] + 61261200*PolyGamma[0, a]^7*PolyGamma[1, a]^3*
      PolyGamma[3, a] + 321621300*PolyGamma[0, a]^5*PolyGamma[1, a]^4*
      PolyGamma[3, a] + 643242600*PolyGamma[0, a]^3*PolyGamma[1, a]^5*
      PolyGamma[3, a] + 321621300*PolyGamma[0, a]*PolyGamma[1, a]^6*
      PolyGamma[3, a] + 680680*PolyGamma[0, a]^10*PolyGamma[2, a]*
      PolyGamma[3, a] + 30630600*PolyGamma[0, a]^8*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a] + 428828400*PolyGamma[0, a]^6*
      PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[3, a] + 
     2144142000*PolyGamma[0, a]^4*PolyGamma[1, a]^3*PolyGamma[2, a]*
      PolyGamma[3, a] + 3216213000*PolyGamma[0, a]^2*PolyGamma[1, a]^4*
      PolyGamma[2, a]*PolyGamma[3, a] + 643242600*PolyGamma[1, a]^5*
      PolyGamma[2, a]*PolyGamma[3, a] + 40840800*PolyGamma[0, a]^7*
      PolyGamma[2, a]^2*PolyGamma[3, a] + 857656800*PolyGamma[0, a]^5*
      PolyGamma[1, a]*PolyGamma[2, a]^2*PolyGamma[3, a] + 
     4288284000*PolyGamma[0, a]^3*PolyGamma[1, a]^2*PolyGamma[2, a]^2*
      PolyGamma[3, a] + 4288284000*PolyGamma[0, a]*PolyGamma[1, a]^3*
      PolyGamma[2, a]^2*PolyGamma[3, a] + 476476000*PolyGamma[0, a]^4*
      PolyGamma[2, a]^3*PolyGamma[3, a] + 2858856000*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[2, a]^3*PolyGamma[3, a] + 
     1429428000*PolyGamma[1, a]^2*PolyGamma[2, a]^3*PolyGamma[3, a] + 
     476476000*PolyGamma[0, a]*PolyGamma[2, a]^4*PolyGamma[3, a] + 
     850850*PolyGamma[0, a]^9*PolyGamma[3, a]^2 + 30630600*PolyGamma[0, a]^7*
      PolyGamma[1, a]*PolyGamma[3, a]^2 + 321621300*PolyGamma[0, a]^5*
      PolyGamma[1, a]^2*PolyGamma[3, a]^2 + 1072071000*PolyGamma[0, a]^3*
      PolyGamma[1, a]^3*PolyGamma[3, a]^2 + 804053250*PolyGamma[0, a]*
      PolyGamma[1, a]^4*PolyGamma[3, a]^2 + 71471400*PolyGamma[0, a]^6*
      PolyGamma[2, a]*PolyGamma[3, a]^2 + 1072071000*PolyGamma[0, a]^4*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[3, a]^2 + 
     3216213000*PolyGamma[0, a]^2*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[3, a]^2 + 1072071000*PolyGamma[1, a]^3*PolyGamma[2, a]*
      PolyGamma[3, a]^2 + 714714000*PolyGamma[0, a]^3*PolyGamma[2, a]^2*
      PolyGamma[3, a]^2 + 2144142000*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[3, a]^2 + 238238000*PolyGamma[2, a]^3*
      PolyGamma[3, a]^2 + 35735700*PolyGamma[0, a]^5*PolyGamma[3, a]^3 + 
     357357000*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[3, a]^3 + 
     536035500*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[3, a]^3 + 
     357357000*PolyGamma[0, a]^2*PolyGamma[2, a]*PolyGamma[3, a]^3 + 
     357357000*PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[3, a]^3 + 
     44669625*PolyGamma[0, a]*PolyGamma[3, a]^4 + 6188*PolyGamma[0, a]^12*
      PolyGamma[4, a] + 408408*PolyGamma[0, a]^10*PolyGamma[1, a]*
      PolyGamma[4, a] + 9189180*PolyGamma[0, a]^8*PolyGamma[1, a]^2*
      PolyGamma[4, a] + 85765680*PolyGamma[0, a]^6*PolyGamma[1, a]^3*
      PolyGamma[4, a] + 321621300*PolyGamma[0, a]^4*PolyGamma[1, a]^4*
      PolyGamma[4, a] + 385945560*PolyGamma[0, a]^2*PolyGamma[1, a]^5*
      PolyGamma[4, a] + 64324260*PolyGamma[1, a]^6*PolyGamma[4, a] + 
     1361360*PolyGamma[0, a]^9*PolyGamma[2, a]*PolyGamma[4, a] + 
     49008960*PolyGamma[0, a]^7*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[4, a] + 514594080*PolyGamma[0, a]^5*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[4, a] + 1715313600*PolyGamma[0, a]^3*
      PolyGamma[1, a]^3*PolyGamma[2, a]*PolyGamma[4, a] + 
     1286485200*PolyGamma[0, a]*PolyGamma[1, a]^4*PolyGamma[2, a]*
      PolyGamma[4, a] + 57177120*PolyGamma[0, a]^6*PolyGamma[2, a]^2*
      PolyGamma[4, a] + 857656800*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[4, a] + 2572970400*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[2, a]^2*PolyGamma[4, a] + 
     857656800*PolyGamma[1, a]^3*PolyGamma[2, a]^2*PolyGamma[4, a] + 
     381180800*PolyGamma[0, a]^3*PolyGamma[2, a]^3*PolyGamma[4, a] + 
     1143542400*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]^3*
      PolyGamma[4, a] + 95295200*PolyGamma[2, a]^4*PolyGamma[4, a] + 
     3063060*PolyGamma[0, a]^8*PolyGamma[3, a]*PolyGamma[4, a] + 
     85765680*PolyGamma[0, a]^6*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[4, a] + 643242600*PolyGamma[0, a]^4*PolyGamma[1, a]^2*
      PolyGamma[3, a]*PolyGamma[4, a] + 1286485200*PolyGamma[0, a]^2*
      PolyGamma[1, a]^3*PolyGamma[3, a]*PolyGamma[4, a] + 
     321621300*PolyGamma[1, a]^4*PolyGamma[3, a]*PolyGamma[4, a] + 
     171531360*PolyGamma[0, a]^5*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[4, a] + 1715313600*PolyGamma[0, a]^3*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a] + 
     2572970400*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[4, a] + 857656800*PolyGamma[0, a]^2*
      PolyGamma[2, a]^2*PolyGamma[3, a]*PolyGamma[4, a] + 
     857656800*PolyGamma[1, a]*PolyGamma[2, a]^2*PolyGamma[3, a]*
      PolyGamma[4, a] + 107207100*PolyGamma[0, a]^4*PolyGamma[3, a]^2*
      PolyGamma[4, a] + 643242600*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[3, a]^2*PolyGamma[4, a] + 321621300*PolyGamma[1, a]^2*
      PolyGamma[3, a]^2*PolyGamma[4, a] + 428828400*PolyGamma[0, a]*
      PolyGamma[2, a]*PolyGamma[3, a]^2*PolyGamma[4, a] + 
     35735700*PolyGamma[3, a]^3*PolyGamma[4, a] + 2450448*PolyGamma[0, a]^7*
      PolyGamma[4, a]^2 + 51459408*PolyGamma[0, a]^5*PolyGamma[1, a]*
      PolyGamma[4, a]^2 + 257297040*PolyGamma[0, a]^3*PolyGamma[1, a]^2*
      PolyGamma[4, a]^2 + 257297040*PolyGamma[0, a]*PolyGamma[1, a]^3*
      PolyGamma[4, a]^2 + 85765680*PolyGamma[0, a]^4*PolyGamma[2, a]*
      PolyGamma[4, a]^2 + 514594080*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[4, a]^2 + 257297040*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[4, a]^2 + 171531360*PolyGamma[0, a]*
      PolyGamma[2, a]^2*PolyGamma[4, a]^2 + 85765680*PolyGamma[0, a]^3*
      PolyGamma[3, a]*PolyGamma[4, a]^2 + 257297040*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[4, a]^2 + 
     85765680*PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a]^2 + 
     17153136*PolyGamma[0, a]^2*PolyGamma[4, a]^3 + 
     17153136*PolyGamma[1, a]*PolyGamma[4, a]^3 + 12376*PolyGamma[0, a]^11*
      PolyGamma[5, a] + 680680*PolyGamma[0, a]^9*PolyGamma[1, a]*
      PolyGamma[5, a] + 12252240*PolyGamma[0, a]^7*PolyGamma[1, a]^2*
      PolyGamma[5, a] + 85765680*PolyGamma[0, a]^5*PolyGamma[1, a]^3*
      PolyGamma[5, a] + 214414200*PolyGamma[0, a]^3*PolyGamma[1, a]^4*
      PolyGamma[5, a] + 128648520*PolyGamma[0, a]*PolyGamma[1, a]^5*
      PolyGamma[5, a] + 2042040*PolyGamma[0, a]^8*PolyGamma[2, a]*
      PolyGamma[5, a] + 57177120*PolyGamma[0, a]^6*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[5, a] + 428828400*PolyGamma[0, a]^4*
      PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[5, a] + 
     857656800*PolyGamma[0, a]^2*PolyGamma[1, a]^3*PolyGamma[2, a]*
      PolyGamma[5, a] + 214414200*PolyGamma[1, a]^4*PolyGamma[2, a]*
      PolyGamma[5, a] + 57177120*PolyGamma[0, a]^5*PolyGamma[2, a]^2*
      PolyGamma[5, a] + 571771200*PolyGamma[0, a]^3*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[5, a] + 857656800*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[2, a]^2*PolyGamma[5, a] + 
     190590400*PolyGamma[0, a]^2*PolyGamma[2, a]^3*PolyGamma[5, a] + 
     190590400*PolyGamma[1, a]*PolyGamma[2, a]^3*PolyGamma[5, a] + 
     4084080*PolyGamma[0, a]^7*PolyGamma[3, a]*PolyGamma[5, a] + 
     85765680*PolyGamma[0, a]^5*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[5, a] + 428828400*PolyGamma[0, a]^3*PolyGamma[1, a]^2*
      PolyGamma[3, a]*PolyGamma[5, a] + 428828400*PolyGamma[0, a]*
      PolyGamma[1, a]^3*PolyGamma[3, a]*PolyGamma[5, a] + 
     142942800*PolyGamma[0, a]^4*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[5, a] + 857656800*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[5, a] + 
     428828400*PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[5, a] + 285885600*PolyGamma[0, a]*PolyGamma[2, a]^2*
      PolyGamma[3, a]*PolyGamma[5, a] + 71471400*PolyGamma[0, a]^3*
      PolyGamma[3, a]^2*PolyGamma[5, a] + 214414200*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[3, a]^2*PolyGamma[5, a] + 
     71471400*PolyGamma[2, a]*PolyGamma[3, a]^2*PolyGamma[5, a] + 
     5717712*PolyGamma[0, a]^6*PolyGamma[4, a]*PolyGamma[5, a] + 
     85765680*PolyGamma[0, a]^4*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[5, a] + 257297040*PolyGamma[0, a]^2*PolyGamma[1, a]^2*
      PolyGamma[4, a]*PolyGamma[5, a] + 85765680*PolyGamma[1, a]^3*
      PolyGamma[4, a]*PolyGamma[5, a] + 114354240*PolyGamma[0, a]^3*
      PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[5, a] + 
     343062720*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[4, a]*PolyGamma[5, a] + 57177120*PolyGamma[2, a]^2*
      PolyGamma[4, a]*PolyGamma[5, a] + 85765680*PolyGamma[0, a]^2*
      PolyGamma[3, a]*PolyGamma[4, a]*PolyGamma[5, a] + 
     85765680*PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[4, a]*
      PolyGamma[5, a] + 17153136*PolyGamma[0, a]*PolyGamma[4, a]^2*
      PolyGamma[5, a] + 2858856*PolyGamma[0, a]^5*PolyGamma[5, a]^2 + 
     28588560*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[5, a]^2 + 
     42882840*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[5, a]^2 + 
     28588560*PolyGamma[0, a]^2*PolyGamma[2, a]*PolyGamma[5, a]^2 + 
     28588560*PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[5, a]^2 + 
     14294280*PolyGamma[0, a]*PolyGamma[3, a]*PolyGamma[5, a]^2 + 
     2858856*PolyGamma[4, a]*PolyGamma[5, a]^2 + 19448*PolyGamma[0, a]^10*
      PolyGamma[6, a] + 875160*PolyGamma[0, a]^8*PolyGamma[1, a]*
      PolyGamma[6, a] + 12252240*PolyGamma[0, a]^6*PolyGamma[1, a]^2*
      PolyGamma[6, a] + 61261200*PolyGamma[0, a]^4*PolyGamma[1, a]^3*
      PolyGamma[6, a] + 91891800*PolyGamma[0, a]^2*PolyGamma[1, a]^4*
      PolyGamma[6, a] + 18378360*PolyGamma[1, a]^5*PolyGamma[6, a] + 
     2333760*PolyGamma[0, a]^7*PolyGamma[2, a]*PolyGamma[6, a] + 
     49008960*PolyGamma[0, a]^5*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[6, a] + 245044800*PolyGamma[0, a]^3*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[6, a] + 245044800*PolyGamma[0, a]*
      PolyGamma[1, a]^3*PolyGamma[2, a]*PolyGamma[6, a] + 
     40840800*PolyGamma[0, a]^4*PolyGamma[2, a]^2*PolyGamma[6, a] + 
     245044800*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[6, a] + 122522400*PolyGamma[1, a]^2*PolyGamma[2, a]^2*
      PolyGamma[6, a] + 54454400*PolyGamma[0, a]*PolyGamma[2, a]^3*
      PolyGamma[6, a] + 4084080*PolyGamma[0, a]^6*PolyGamma[3, a]*
      PolyGamma[6, a] + 61261200*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[3, a]*PolyGamma[6, a] + 183783600*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[3, a]*PolyGamma[6, a] + 
     61261200*PolyGamma[1, a]^3*PolyGamma[3, a]*PolyGamma[6, a] + 
     81681600*PolyGamma[0, a]^3*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[6, a] + 245044800*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[6, a] + 
     40840800*PolyGamma[2, a]^2*PolyGamma[3, a]*PolyGamma[6, a] + 
     30630600*PolyGamma[0, a]^2*PolyGamma[3, a]^2*PolyGamma[6, a] + 
     30630600*PolyGamma[1, a]*PolyGamma[3, a]^2*PolyGamma[6, a] + 
     4900896*PolyGamma[0, a]^5*PolyGamma[4, a]*PolyGamma[6, a] + 
     49008960*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[6, a] + 73513440*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[4, a]*PolyGamma[6, a] + 49008960*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[6, a] + 
     49008960*PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[4, a]*
      PolyGamma[6, a] + 24504480*PolyGamma[0, a]*PolyGamma[3, a]*
      PolyGamma[4, a]*PolyGamma[6, a] + 2450448*PolyGamma[4, a]^2*
      PolyGamma[6, a] + 4084080*PolyGamma[0, a]^4*PolyGamma[5, a]*
      PolyGamma[6, a] + 24504480*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[5, a]*PolyGamma[6, a] + 12252240*PolyGamma[1, a]^2*
      PolyGamma[5, a]*PolyGamma[6, a] + 16336320*PolyGamma[0, a]*
      PolyGamma[2, a]*PolyGamma[5, a]*PolyGamma[6, a] + 
     4084080*PolyGamma[3, a]*PolyGamma[5, a]*PolyGamma[6, a] + 
     1166880*PolyGamma[0, a]^3*PolyGamma[6, a]^2 + 3500640*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[6, a]^2 + 1166880*PolyGamma[2, a]*
      PolyGamma[6, a]^2 + 24310*PolyGamma[0, a]^9*PolyGamma[7, a] + 
     875160*PolyGamma[0, a]^7*PolyGamma[1, a]*PolyGamma[7, a] + 
     9189180*PolyGamma[0, a]^5*PolyGamma[1, a]^2*PolyGamma[7, a] + 
     30630600*PolyGamma[0, a]^3*PolyGamma[1, a]^3*PolyGamma[7, a] + 
     22972950*PolyGamma[0, a]*PolyGamma[1, a]^4*PolyGamma[7, a] + 
     2042040*PolyGamma[0, a]^6*PolyGamma[2, a]*PolyGamma[7, a] + 
     30630600*PolyGamma[0, a]^4*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[7, a] + 91891800*PolyGamma[0, a]^2*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[7, a] + 30630600*PolyGamma[1, a]^3*
      PolyGamma[2, a]*PolyGamma[7, a] + 20420400*PolyGamma[0, a]^3*
      PolyGamma[2, a]^2*PolyGamma[7, a] + 61261200*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[2, a]^2*PolyGamma[7, a] + 
     6806800*PolyGamma[2, a]^3*PolyGamma[7, a] + 3063060*PolyGamma[0, a]^5*
      PolyGamma[3, a]*PolyGamma[7, a] + 30630600*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[7, a] + 
     45945900*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[3, a]*
      PolyGamma[7, a] + 30630600*PolyGamma[0, a]^2*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[7, a] + 30630600*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[7, a] + 
     7657650*PolyGamma[0, a]*PolyGamma[3, a]^2*PolyGamma[7, a] + 
     3063060*PolyGamma[0, a]^4*PolyGamma[4, a]*PolyGamma[7, a] + 
     18378360*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[7, a] + 9189180*PolyGamma[1, a]^2*PolyGamma[4, a]*
      PolyGamma[7, a] + 12252240*PolyGamma[0, a]*PolyGamma[2, a]*
      PolyGamma[4, a]*PolyGamma[7, a] + 3063060*PolyGamma[3, a]*
      PolyGamma[4, a]*PolyGamma[7, a] + 2042040*PolyGamma[0, a]^3*
      PolyGamma[5, a]*PolyGamma[7, a] + 6126120*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[5, a]*PolyGamma[7, a] + 
     2042040*PolyGamma[2, a]*PolyGamma[5, a]*PolyGamma[7, a] + 
     875160*PolyGamma[0, a]^2*PolyGamma[6, a]*PolyGamma[7, a] + 
     875160*PolyGamma[1, a]*PolyGamma[6, a]*PolyGamma[7, a] + 
     109395*PolyGamma[0, a]*PolyGamma[7, a]^2 + 24310*PolyGamma[0, a]^8*
      PolyGamma[8, a] + 680680*PolyGamma[0, a]^6*PolyGamma[1, a]*
      PolyGamma[8, a] + 5105100*PolyGamma[0, a]^4*PolyGamma[1, a]^2*
      PolyGamma[8, a] + 10210200*PolyGamma[0, a]^2*PolyGamma[1, a]^3*
      PolyGamma[8, a] + 2552550*PolyGamma[1, a]^4*PolyGamma[8, a] + 
     1361360*PolyGamma[0, a]^5*PolyGamma[2, a]*PolyGamma[8, a] + 
     13613600*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[8, a] + 20420400*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[8, a] + 6806800*PolyGamma[0, a]^2*
      PolyGamma[2, a]^2*PolyGamma[8, a] + 6806800*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[8, a] + 1701700*PolyGamma[0, a]^4*
      PolyGamma[3, a]*PolyGamma[8, a] + 10210200*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[8, a] + 
     5105100*PolyGamma[1, a]^2*PolyGamma[3, a]*PolyGamma[8, a] + 
     6806800*PolyGamma[0, a]*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[8, a] + 850850*PolyGamma[3, a]^2*PolyGamma[8, a] + 
     1361360*PolyGamma[0, a]^3*PolyGamma[4, a]*PolyGamma[8, a] + 
     4084080*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[8, a] + 1361360*PolyGamma[2, a]*PolyGamma[4, a]*
      PolyGamma[8, a] + 680680*PolyGamma[0, a]^2*PolyGamma[5, a]*
      PolyGamma[8, a] + 680680*PolyGamma[1, a]*PolyGamma[5, a]*
      PolyGamma[8, a] + 194480*PolyGamma[0, a]*PolyGamma[6, a]*
      PolyGamma[8, a] + 24310*PolyGamma[7, a]*PolyGamma[8, a] + 
     19448*PolyGamma[0, a]^7*PolyGamma[9, a] + 408408*PolyGamma[0, a]^5*
      PolyGamma[1, a]*PolyGamma[9, a] + 2042040*PolyGamma[0, a]^3*
      PolyGamma[1, a]^2*PolyGamma[9, a] + 2042040*PolyGamma[0, a]*
      PolyGamma[1, a]^3*PolyGamma[9, a] + 680680*PolyGamma[0, a]^4*
      PolyGamma[2, a]*PolyGamma[9, a] + 4084080*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[9, a] + 
     2042040*PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[9, a] + 
     1361360*PolyGamma[0, a]*PolyGamma[2, a]^2*PolyGamma[9, a] + 
     680680*PolyGamma[0, a]^3*PolyGamma[3, a]*PolyGamma[9, a] + 
     2042040*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[9, a] + 680680*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[9, a] + 408408*PolyGamma[0, a]^2*PolyGamma[4, a]*
      PolyGamma[9, a] + 408408*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[9, a] + 136136*PolyGamma[0, a]*PolyGamma[5, a]*
      PolyGamma[9, a] + 19448*PolyGamma[6, a]*PolyGamma[9, a] + 
     12376*PolyGamma[0, a]^6*PolyGamma[10, a] + 185640*PolyGamma[0, a]^4*
      PolyGamma[1, a]*PolyGamma[10, a] + 556920*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[10, a] + 185640*PolyGamma[1, a]^3*
      PolyGamma[10, a] + 247520*PolyGamma[0, a]^3*PolyGamma[2, a]*
      PolyGamma[10, a] + 742560*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[10, a] + 123760*PolyGamma[2, a]^2*
      PolyGamma[10, a] + 185640*PolyGamma[0, a]^2*PolyGamma[3, a]*
      PolyGamma[10, a] + 185640*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[10, a] + 74256*PolyGamma[0, a]*PolyGamma[4, a]*
      PolyGamma[10, a] + 12376*PolyGamma[5, a]*PolyGamma[10, a] + 
     6188*PolyGamma[0, a]^5*PolyGamma[11, a] + 61880*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[11, a] + 92820*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[11, a] + 61880*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[11, a] + 61880*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[11, a] + 30940*PolyGamma[0, a]*
      PolyGamma[3, a]*PolyGamma[11, a] + 6188*PolyGamma[4, a]*
      PolyGamma[11, a] + 2380*PolyGamma[0, a]^4*PolyGamma[12, a] + 
     14280*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[12, a] + 
     7140*PolyGamma[1, a]^2*PolyGamma[12, a] + 9520*PolyGamma[0, a]*
      PolyGamma[2, a]*PolyGamma[12, a] + 2380*PolyGamma[3, a]*
      PolyGamma[12, a] + 680*PolyGamma[0, a]^3*PolyGamma[13, a] + 
     2040*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[13, a] + 
     680*PolyGamma[2, a]*PolyGamma[13, a] + 136*PolyGamma[0, a]^2*
      PolyGamma[14, a] + 136*PolyGamma[1, a]*PolyGamma[14, a] + 
     17*PolyGamma[0, a]*PolyGamma[15, a] + PolyGamma[16, a]
 
MBexpGam[a_, 18] = PolyGamma[0, a]^18 + 153*PolyGamma[0, a]^16*
      PolyGamma[1, a] + 9180*PolyGamma[0, a]^14*PolyGamma[1, a]^2 + 
     278460*PolyGamma[0, a]^12*PolyGamma[1, a]^3 + 4594590*PolyGamma[0, a]^10*
      PolyGamma[1, a]^4 + 41351310*PolyGamma[0, a]^8*PolyGamma[1, a]^5 + 
     192972780*PolyGamma[0, a]^6*PolyGamma[1, a]^6 + 
     413513100*PolyGamma[0, a]^4*PolyGamma[1, a]^7 + 
     310134825*PolyGamma[0, a]^2*PolyGamma[1, a]^8 + 
     34459425*PolyGamma[1, a]^9 + 816*PolyGamma[0, a]^15*PolyGamma[2, a] + 
     85680*PolyGamma[0, a]^13*PolyGamma[1, a]*PolyGamma[2, a] + 
     3341520*PolyGamma[0, a]^11*PolyGamma[1, a]^2*PolyGamma[2, a] + 
     61261200*PolyGamma[0, a]^9*PolyGamma[1, a]^3*PolyGamma[2, a] + 
     551350800*PolyGamma[0, a]^7*PolyGamma[1, a]^4*PolyGamma[2, a] + 
     2315673360*PolyGamma[0, a]^5*PolyGamma[1, a]^5*PolyGamma[2, a] + 
     3859455600*PolyGamma[0, a]^3*PolyGamma[1, a]^6*PolyGamma[2, a] + 
     1654052400*PolyGamma[0, a]*PolyGamma[1, a]^7*PolyGamma[2, a] + 
     185640*PolyGamma[0, a]^12*PolyGamma[2, a]^2 + 
     12252240*PolyGamma[0, a]^10*PolyGamma[1, a]*PolyGamma[2, a]^2 + 
     275675400*PolyGamma[0, a]^8*PolyGamma[1, a]^2*PolyGamma[2, a]^2 + 
     2572970400*PolyGamma[0, a]^6*PolyGamma[1, a]^3*PolyGamma[2, a]^2 + 
     9648639000*PolyGamma[0, a]^4*PolyGamma[1, a]^4*PolyGamma[2, a]^2 + 
     11578366800*PolyGamma[0, a]^2*PolyGamma[1, a]^5*PolyGamma[2, a]^2 + 
     1929727800*PolyGamma[1, a]^6*PolyGamma[2, a]^2 + 
     13613600*PolyGamma[0, a]^9*PolyGamma[2, a]^3 + 
     490089600*PolyGamma[0, a]^7*PolyGamma[1, a]*PolyGamma[2, a]^3 + 
     5145940800*PolyGamma[0, a]^5*PolyGamma[1, a]^2*PolyGamma[2, a]^3 + 
     17153136000*PolyGamma[0, a]^3*PolyGamma[1, a]^3*PolyGamma[2, a]^3 + 
     12864852000*PolyGamma[0, a]*PolyGamma[1, a]^4*PolyGamma[2, a]^3 + 
     285885600*PolyGamma[0, a]^6*PolyGamma[2, a]^4 + 
     4288284000*PolyGamma[0, a]^4*PolyGamma[1, a]*PolyGamma[2, a]^4 + 
     12864852000*PolyGamma[0, a]^2*PolyGamma[1, a]^2*PolyGamma[2, a]^4 + 
     4288284000*PolyGamma[1, a]^3*PolyGamma[2, a]^4 + 
     1143542400*PolyGamma[0, a]^3*PolyGamma[2, a]^5 + 
     3430627200*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]^5 + 
     190590400*PolyGamma[2, a]^6 + 3060*PolyGamma[0, a]^14*PolyGamma[3, a] + 
     278460*PolyGamma[0, a]^12*PolyGamma[1, a]*PolyGamma[3, a] + 
     9189180*PolyGamma[0, a]^10*PolyGamma[1, a]^2*PolyGamma[3, a] + 
     137837700*PolyGamma[0, a]^8*PolyGamma[1, a]^3*PolyGamma[3, a] + 
     964863900*PolyGamma[0, a]^6*PolyGamma[1, a]^4*PolyGamma[3, a] + 
     2894591700*PolyGamma[0, a]^4*PolyGamma[1, a]^5*PolyGamma[3, a] + 
     2894591700*PolyGamma[0, a]^2*PolyGamma[1, a]^6*PolyGamma[3, a] + 
     413513100*PolyGamma[1, a]^7*PolyGamma[3, a] + 1113840*PolyGamma[0, a]^11*
      PolyGamma[2, a]*PolyGamma[3, a] + 61261200*PolyGamma[0, a]^9*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[3, a] + 
     1102701600*PolyGamma[0, a]^7*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[3, a] + 7718911200*PolyGamma[0, a]^5*PolyGamma[1, a]^3*
      PolyGamma[2, a]*PolyGamma[3, a] + 19297278000*PolyGamma[0, a]^3*
      PolyGamma[1, a]^4*PolyGamma[2, a]*PolyGamma[3, a] + 
     11578366800*PolyGamma[0, a]*PolyGamma[1, a]^5*PolyGamma[2, a]*
      PolyGamma[3, a] + 91891800*PolyGamma[0, a]^8*PolyGamma[2, a]^2*
      PolyGamma[3, a] + 2572970400*PolyGamma[0, a]^6*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[3, a] + 19297278000*PolyGamma[0, a]^4*
      PolyGamma[1, a]^2*PolyGamma[2, a]^2*PolyGamma[3, a] + 
     38594556000*PolyGamma[0, a]^2*PolyGamma[1, a]^3*PolyGamma[2, a]^2*
      PolyGamma[3, a] + 9648639000*PolyGamma[1, a]^4*PolyGamma[2, a]^2*
      PolyGamma[3, a] + 1715313600*PolyGamma[0, a]^5*PolyGamma[2, a]^3*
      PolyGamma[3, a] + 17153136000*PolyGamma[0, a]^3*PolyGamma[1, a]*
      PolyGamma[2, a]^3*PolyGamma[3, a] + 25729704000*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[2, a]^3*PolyGamma[3, a] + 
     4288284000*PolyGamma[0, a]^2*PolyGamma[2, a]^4*PolyGamma[3, a] + 
     4288284000*PolyGamma[1, a]*PolyGamma[2, a]^4*PolyGamma[3, a] + 
     1531530*PolyGamma[0, a]^10*PolyGamma[3, a]^2 + 
     68918850*PolyGamma[0, a]^8*PolyGamma[1, a]*PolyGamma[3, a]^2 + 
     964863900*PolyGamma[0, a]^6*PolyGamma[1, a]^2*PolyGamma[3, a]^2 + 
     4824319500*PolyGamma[0, a]^4*PolyGamma[1, a]^3*PolyGamma[3, a]^2 + 
     7236479250*PolyGamma[0, a]^2*PolyGamma[1, a]^4*PolyGamma[3, a]^2 + 
     1447295850*PolyGamma[1, a]^5*PolyGamma[3, a]^2 + 
     183783600*PolyGamma[0, a]^7*PolyGamma[2, a]*PolyGamma[3, a]^2 + 
     3859455600*PolyGamma[0, a]^5*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[3, a]^2 + 19297278000*PolyGamma[0, a]^3*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[3, a]^2 + 19297278000*PolyGamma[0, a]*
      PolyGamma[1, a]^3*PolyGamma[2, a]*PolyGamma[3, a]^2 + 
     3216213000*PolyGamma[0, a]^4*PolyGamma[2, a]^2*PolyGamma[3, a]^2 + 
     19297278000*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[3, a]^2 + 9648639000*PolyGamma[1, a]^2*PolyGamma[2, a]^2*
      PolyGamma[3, a]^2 + 4288284000*PolyGamma[0, a]*PolyGamma[2, a]^3*
      PolyGamma[3, a]^2 + 107207100*PolyGamma[0, a]^6*PolyGamma[3, a]^3 + 
     1608106500*PolyGamma[0, a]^4*PolyGamma[1, a]*PolyGamma[3, a]^3 + 
     4824319500*PolyGamma[0, a]^2*PolyGamma[1, a]^2*PolyGamma[3, a]^3 + 
     1608106500*PolyGamma[1, a]^3*PolyGamma[3, a]^3 + 
     2144142000*PolyGamma[0, a]^3*PolyGamma[2, a]*PolyGamma[3, a]^3 + 
     6432426000*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[3, a]^3 + 1072071000*PolyGamma[2, a]^2*PolyGamma[3, a]^3 + 
     402026625*PolyGamma[0, a]^2*PolyGamma[3, a]^4 + 
     402026625*PolyGamma[1, a]*PolyGamma[3, a]^4 + 8568*PolyGamma[0, a]^13*
      PolyGamma[4, a] + 668304*PolyGamma[0, a]^11*PolyGamma[1, a]*
      PolyGamma[4, a] + 18378360*PolyGamma[0, a]^9*PolyGamma[1, a]^2*
      PolyGamma[4, a] + 220540320*PolyGamma[0, a]^7*PolyGamma[1, a]^3*
      PolyGamma[4, a] + 1157836680*PolyGamma[0, a]^5*PolyGamma[1, a]^4*
      PolyGamma[4, a] + 2315673360*PolyGamma[0, a]^3*PolyGamma[1, a]^5*
      PolyGamma[4, a] + 1157836680*PolyGamma[0, a]*PolyGamma[1, a]^6*
      PolyGamma[4, a] + 2450448*PolyGamma[0, a]^10*PolyGamma[2, a]*
      PolyGamma[4, a] + 110270160*PolyGamma[0, a]^8*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[4, a] + 1543782240*PolyGamma[0, a]^6*
      PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[4, a] + 
     7718911200*PolyGamma[0, a]^4*PolyGamma[1, a]^3*PolyGamma[2, a]*
      PolyGamma[4, a] + 11578366800*PolyGamma[0, a]^2*PolyGamma[1, a]^4*
      PolyGamma[2, a]*PolyGamma[4, a] + 2315673360*PolyGamma[1, a]^5*
      PolyGamma[2, a]*PolyGamma[4, a] + 147026880*PolyGamma[0, a]^7*
      PolyGamma[2, a]^2*PolyGamma[4, a] + 3087564480*PolyGamma[0, a]^5*
      PolyGamma[1, a]*PolyGamma[2, a]^2*PolyGamma[4, a] + 
     15437822400*PolyGamma[0, a]^3*PolyGamma[1, a]^2*PolyGamma[2, a]^2*
      PolyGamma[4, a] + 15437822400*PolyGamma[0, a]*PolyGamma[1, a]^3*
      PolyGamma[2, a]^2*PolyGamma[4, a] + 1715313600*PolyGamma[0, a]^4*
      PolyGamma[2, a]^3*PolyGamma[4, a] + 10291881600*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[2, a]^3*PolyGamma[4, a] + 
     5145940800*PolyGamma[1, a]^2*PolyGamma[2, a]^3*PolyGamma[4, a] + 
     1715313600*PolyGamma[0, a]*PolyGamma[2, a]^4*PolyGamma[4, a] + 
     6126120*PolyGamma[0, a]^9*PolyGamma[3, a]*PolyGamma[4, a] + 
     220540320*PolyGamma[0, a]^7*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[4, a] + 2315673360*PolyGamma[0, a]^5*PolyGamma[1, a]^2*
      PolyGamma[3, a]*PolyGamma[4, a] + 7718911200*PolyGamma[0, a]^3*
      PolyGamma[1, a]^3*PolyGamma[3, a]*PolyGamma[4, a] + 
     5789183400*PolyGamma[0, a]*PolyGamma[1, a]^4*PolyGamma[3, a]*
      PolyGamma[4, a] + 514594080*PolyGamma[0, a]^6*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[4, a] + 7718911200*PolyGamma[0, a]^4*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a] + 
     23156733600*PolyGamma[0, a]^2*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[4, a] + 7718911200*PolyGamma[1, a]^3*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a] + 
     5145940800*PolyGamma[0, a]^3*PolyGamma[2, a]^2*PolyGamma[3, a]*
      PolyGamma[4, a] + 15437822400*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[3, a]*PolyGamma[4, a] + 
     1715313600*PolyGamma[2, a]^3*PolyGamma[3, a]*PolyGamma[4, a] + 
     385945560*PolyGamma[0, a]^5*PolyGamma[3, a]^2*PolyGamma[4, a] + 
     3859455600*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[3, a]^2*
      PolyGamma[4, a] + 5789183400*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[3, a]^2*PolyGamma[4, a] + 3859455600*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[3, a]^2*PolyGamma[4, a] + 
     3859455600*PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[3, a]^2*
      PolyGamma[4, a] + 643242600*PolyGamma[0, a]*PolyGamma[3, a]^3*
      PolyGamma[4, a] + 5513508*PolyGamma[0, a]^8*PolyGamma[4, a]^2 + 
     154378224*PolyGamma[0, a]^6*PolyGamma[1, a]*PolyGamma[4, a]^2 + 
     1157836680*PolyGamma[0, a]^4*PolyGamma[1, a]^2*PolyGamma[4, a]^2 + 
     2315673360*PolyGamma[0, a]^2*PolyGamma[1, a]^3*PolyGamma[4, a]^2 + 
     578918340*PolyGamma[1, a]^4*PolyGamma[4, a]^2 + 
     308756448*PolyGamma[0, a]^5*PolyGamma[2, a]*PolyGamma[4, a]^2 + 
     3087564480*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[4, a]^2 + 4631346720*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[4, a]^2 + 1543782240*PolyGamma[0, a]^2*
      PolyGamma[2, a]^2*PolyGamma[4, a]^2 + 1543782240*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[4, a]^2 + 385945560*PolyGamma[0, a]^4*
      PolyGamma[3, a]*PolyGamma[4, a]^2 + 2315673360*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[4, a]^2 + 
     1157836680*PolyGamma[1, a]^2*PolyGamma[3, a]*PolyGamma[4, a]^2 + 
     1543782240*PolyGamma[0, a]*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[4, a]^2 + 192972780*PolyGamma[3, a]^2*PolyGamma[4, a]^2 + 
     102918816*PolyGamma[0, a]^3*PolyGamma[4, a]^3 + 
     308756448*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[4, a]^3 + 
     102918816*PolyGamma[2, a]*PolyGamma[4, a]^3 + 18564*PolyGamma[0, a]^12*
      PolyGamma[5, a] + 1225224*PolyGamma[0, a]^10*PolyGamma[1, a]*
      PolyGamma[5, a] + 27567540*PolyGamma[0, a]^8*PolyGamma[1, a]^2*
      PolyGamma[5, a] + 257297040*PolyGamma[0, a]^6*PolyGamma[1, a]^3*
      PolyGamma[5, a] + 964863900*PolyGamma[0, a]^4*PolyGamma[1, a]^4*
      PolyGamma[5, a] + 1157836680*PolyGamma[0, a]^2*PolyGamma[1, a]^5*
      PolyGamma[5, a] + 192972780*PolyGamma[1, a]^6*PolyGamma[5, a] + 
     4084080*PolyGamma[0, a]^9*PolyGamma[2, a]*PolyGamma[5, a] + 
     147026880*PolyGamma[0, a]^7*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[5, a] + 1543782240*PolyGamma[0, a]^5*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[5, a] + 5145940800*PolyGamma[0, a]^3*
      PolyGamma[1, a]^3*PolyGamma[2, a]*PolyGamma[5, a] + 
     3859455600*PolyGamma[0, a]*PolyGamma[1, a]^4*PolyGamma[2, a]*
      PolyGamma[5, a] + 171531360*PolyGamma[0, a]^6*PolyGamma[2, a]^2*
      PolyGamma[5, a] + 2572970400*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[5, a] + 7718911200*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[2, a]^2*PolyGamma[5, a] + 
     2572970400*PolyGamma[1, a]^3*PolyGamma[2, a]^2*PolyGamma[5, a] + 
     1143542400*PolyGamma[0, a]^3*PolyGamma[2, a]^3*PolyGamma[5, a] + 
     3430627200*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]^3*
      PolyGamma[5, a] + 285885600*PolyGamma[2, a]^4*PolyGamma[5, a] + 
     9189180*PolyGamma[0, a]^8*PolyGamma[3, a]*PolyGamma[5, a] + 
     257297040*PolyGamma[0, a]^6*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[5, a] + 1929727800*PolyGamma[0, a]^4*PolyGamma[1, a]^2*
      PolyGamma[3, a]*PolyGamma[5, a] + 3859455600*PolyGamma[0, a]^2*
      PolyGamma[1, a]^3*PolyGamma[3, a]*PolyGamma[5, a] + 
     964863900*PolyGamma[1, a]^4*PolyGamma[3, a]*PolyGamma[5, a] + 
     514594080*PolyGamma[0, a]^5*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[5, a] + 5145940800*PolyGamma[0, a]^3*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[5, a] + 
     7718911200*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[5, a] + 2572970400*PolyGamma[0, a]^2*
      PolyGamma[2, a]^2*PolyGamma[3, a]*PolyGamma[5, a] + 
     2572970400*PolyGamma[1, a]*PolyGamma[2, a]^2*PolyGamma[3, a]*
      PolyGamma[5, a] + 321621300*PolyGamma[0, a]^4*PolyGamma[3, a]^2*
      PolyGamma[5, a] + 1929727800*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[3, a]^2*PolyGamma[5, a] + 964863900*PolyGamma[1, a]^2*
      PolyGamma[3, a]^2*PolyGamma[5, a] + 1286485200*PolyGamma[0, a]*
      PolyGamma[2, a]*PolyGamma[3, a]^2*PolyGamma[5, a] + 
     107207100*PolyGamma[3, a]^3*PolyGamma[5, a] + 14702688*PolyGamma[0, a]^7*
      PolyGamma[4, a]*PolyGamma[5, a] + 308756448*PolyGamma[0, a]^5*
      PolyGamma[1, a]*PolyGamma[4, a]*PolyGamma[5, a] + 
     1543782240*PolyGamma[0, a]^3*PolyGamma[1, a]^2*PolyGamma[4, a]*
      PolyGamma[5, a] + 1543782240*PolyGamma[0, a]*PolyGamma[1, a]^3*
      PolyGamma[4, a]*PolyGamma[5, a] + 514594080*PolyGamma[0, a]^4*
      PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[5, a] + 
     3087564480*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[4, a]*PolyGamma[5, a] + 1543782240*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[5, a] + 
     1029188160*PolyGamma[0, a]*PolyGamma[2, a]^2*PolyGamma[4, a]*
      PolyGamma[5, a] + 514594080*PolyGamma[0, a]^3*PolyGamma[3, a]*
      PolyGamma[4, a]*PolyGamma[5, a] + 1543782240*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[4, a]*PolyGamma[5, a] + 
     514594080*PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a]*
      PolyGamma[5, a] + 154378224*PolyGamma[0, a]^2*PolyGamma[4, a]^2*
      PolyGamma[5, a] + 154378224*PolyGamma[1, a]*PolyGamma[4, a]^2*
      PolyGamma[5, a] + 8576568*PolyGamma[0, a]^6*PolyGamma[5, a]^2 + 
     128648520*PolyGamma[0, a]^4*PolyGamma[1, a]*PolyGamma[5, a]^2 + 
     385945560*PolyGamma[0, a]^2*PolyGamma[1, a]^2*PolyGamma[5, a]^2 + 
     128648520*PolyGamma[1, a]^3*PolyGamma[5, a]^2 + 
     171531360*PolyGamma[0, a]^3*PolyGamma[2, a]*PolyGamma[5, a]^2 + 
     514594080*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[5, a]^2 + 85765680*PolyGamma[2, a]^2*PolyGamma[5, a]^2 + 
     128648520*PolyGamma[0, a]^2*PolyGamma[3, a]*PolyGamma[5, a]^2 + 
     128648520*PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[5, a]^2 + 
     51459408*PolyGamma[0, a]*PolyGamma[4, a]*PolyGamma[5, a]^2 + 
     2858856*PolyGamma[5, a]^3 + 31824*PolyGamma[0, a]^11*PolyGamma[6, a] + 
     1750320*PolyGamma[0, a]^9*PolyGamma[1, a]*PolyGamma[6, a] + 
     31505760*PolyGamma[0, a]^7*PolyGamma[1, a]^2*PolyGamma[6, a] + 
     220540320*PolyGamma[0, a]^5*PolyGamma[1, a]^3*PolyGamma[6, a] + 
     551350800*PolyGamma[0, a]^3*PolyGamma[1, a]^4*PolyGamma[6, a] + 
     330810480*PolyGamma[0, a]*PolyGamma[1, a]^5*PolyGamma[6, a] + 
     5250960*PolyGamma[0, a]^8*PolyGamma[2, a]*PolyGamma[6, a] + 
     147026880*PolyGamma[0, a]^6*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[6, a] + 1102701600*PolyGamma[0, a]^4*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[6, a] + 2205403200*PolyGamma[0, a]^2*
      PolyGamma[1, a]^3*PolyGamma[2, a]*PolyGamma[6, a] + 
     551350800*PolyGamma[1, a]^4*PolyGamma[2, a]*PolyGamma[6, a] + 
     147026880*PolyGamma[0, a]^5*PolyGamma[2, a]^2*PolyGamma[6, a] + 
     1470268800*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[6, a] + 2205403200*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[2, a]^2*PolyGamma[6, a] + 490089600*PolyGamma[0, a]^2*
      PolyGamma[2, a]^3*PolyGamma[6, a] + 490089600*PolyGamma[1, a]*
      PolyGamma[2, a]^3*PolyGamma[6, a] + 10501920*PolyGamma[0, a]^7*
      PolyGamma[3, a]*PolyGamma[6, a] + 220540320*PolyGamma[0, a]^5*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[6, a] + 
     1102701600*PolyGamma[0, a]^3*PolyGamma[1, a]^2*PolyGamma[3, a]*
      PolyGamma[6, a] + 1102701600*PolyGamma[0, a]*PolyGamma[1, a]^3*
      PolyGamma[3, a]*PolyGamma[6, a] + 367567200*PolyGamma[0, a]^4*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[6, a] + 
     2205403200*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[6, a] + 1102701600*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[6, a] + 
     735134400*PolyGamma[0, a]*PolyGamma[2, a]^2*PolyGamma[3, a]*
      PolyGamma[6, a] + 183783600*PolyGamma[0, a]^3*PolyGamma[3, a]^2*
      PolyGamma[6, a] + 551350800*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[3, a]^2*PolyGamma[6, a] + 183783600*PolyGamma[2, a]*
      PolyGamma[3, a]^2*PolyGamma[6, a] + 14702688*PolyGamma[0, a]^6*
      PolyGamma[4, a]*PolyGamma[6, a] + 220540320*PolyGamma[0, a]^4*
      PolyGamma[1, a]*PolyGamma[4, a]*PolyGamma[6, a] + 
     661620960*PolyGamma[0, a]^2*PolyGamma[1, a]^2*PolyGamma[4, a]*
      PolyGamma[6, a] + 220540320*PolyGamma[1, a]^3*PolyGamma[4, a]*
      PolyGamma[6, a] + 294053760*PolyGamma[0, a]^3*PolyGamma[2, a]*
      PolyGamma[4, a]*PolyGamma[6, a] + 882161280*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[6, a] + 
     147026880*PolyGamma[2, a]^2*PolyGamma[4, a]*PolyGamma[6, a] + 
     220540320*PolyGamma[0, a]^2*PolyGamma[3, a]*PolyGamma[4, a]*
      PolyGamma[6, a] + 220540320*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[4, a]*PolyGamma[6, a] + 44108064*PolyGamma[0, a]*
      PolyGamma[4, a]^2*PolyGamma[6, a] + 14702688*PolyGamma[0, a]^5*
      PolyGamma[5, a]*PolyGamma[6, a] + 147026880*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[5, a]*PolyGamma[6, a] + 
     220540320*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[5, a]*
      PolyGamma[6, a] + 147026880*PolyGamma[0, a]^2*PolyGamma[2, a]*
      PolyGamma[5, a]*PolyGamma[6, a] + 147026880*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[5, a]*PolyGamma[6, a] + 
     73513440*PolyGamma[0, a]*PolyGamma[3, a]*PolyGamma[5, a]*
      PolyGamma[6, a] + 14702688*PolyGamma[4, a]*PolyGamma[5, a]*
      PolyGamma[6, a] + 5250960*PolyGamma[0, a]^4*PolyGamma[6, a]^2 + 
     31505760*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[6, a]^2 + 
     15752880*PolyGamma[1, a]^2*PolyGamma[6, a]^2 + 
     21003840*PolyGamma[0, a]*PolyGamma[2, a]*PolyGamma[6, a]^2 + 
     5250960*PolyGamma[3, a]*PolyGamma[6, a]^2 + 43758*PolyGamma[0, a]^10*
      PolyGamma[7, a] + 1969110*PolyGamma[0, a]^8*PolyGamma[1, a]*
      PolyGamma[7, a] + 27567540*PolyGamma[0, a]^6*PolyGamma[1, a]^2*
      PolyGamma[7, a] + 137837700*PolyGamma[0, a]^4*PolyGamma[1, a]^3*
      PolyGamma[7, a] + 206756550*PolyGamma[0, a]^2*PolyGamma[1, a]^4*
      PolyGamma[7, a] + 41351310*PolyGamma[1, a]^5*PolyGamma[7, a] + 
     5250960*PolyGamma[0, a]^7*PolyGamma[2, a]*PolyGamma[7, a] + 
     110270160*PolyGamma[0, a]^5*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[7, a] + 551350800*PolyGamma[0, a]^3*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[7, a] + 551350800*PolyGamma[0, a]*
      PolyGamma[1, a]^3*PolyGamma[2, a]*PolyGamma[7, a] + 
     91891800*PolyGamma[0, a]^4*PolyGamma[2, a]^2*PolyGamma[7, a] + 
     551350800*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[7, a] + 275675400*PolyGamma[1, a]^2*PolyGamma[2, a]^2*
      PolyGamma[7, a] + 122522400*PolyGamma[0, a]*PolyGamma[2, a]^3*
      PolyGamma[7, a] + 9189180*PolyGamma[0, a]^6*PolyGamma[3, a]*
      PolyGamma[7, a] + 137837700*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[3, a]*PolyGamma[7, a] + 413513100*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[3, a]*PolyGamma[7, a] + 
     137837700*PolyGamma[1, a]^3*PolyGamma[3, a]*PolyGamma[7, a] + 
     183783600*PolyGamma[0, a]^3*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[7, a] + 551350800*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[7, a] + 
     91891800*PolyGamma[2, a]^2*PolyGamma[3, a]*PolyGamma[7, a] + 
     68918850*PolyGamma[0, a]^2*PolyGamma[3, a]^2*PolyGamma[7, a] + 
     68918850*PolyGamma[1, a]*PolyGamma[3, a]^2*PolyGamma[7, a] + 
     11027016*PolyGamma[0, a]^5*PolyGamma[4, a]*PolyGamma[7, a] + 
     110270160*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[7, a] + 165405240*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[4, a]*PolyGamma[7, a] + 110270160*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[7, a] + 
     110270160*PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[4, a]*
      PolyGamma[7, a] + 55135080*PolyGamma[0, a]*PolyGamma[3, a]*
      PolyGamma[4, a]*PolyGamma[7, a] + 5513508*PolyGamma[4, a]^2*
      PolyGamma[7, a] + 9189180*PolyGamma[0, a]^4*PolyGamma[5, a]*
      PolyGamma[7, a] + 55135080*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[5, a]*PolyGamma[7, a] + 27567540*PolyGamma[1, a]^2*
      PolyGamma[5, a]*PolyGamma[7, a] + 36756720*PolyGamma[0, a]*
      PolyGamma[2, a]*PolyGamma[5, a]*PolyGamma[7, a] + 
     9189180*PolyGamma[3, a]*PolyGamma[5, a]*PolyGamma[7, a] + 
     5250960*PolyGamma[0, a]^3*PolyGamma[6, a]*PolyGamma[7, a] + 
     15752880*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[6, a]*
      PolyGamma[7, a] + 5250960*PolyGamma[2, a]*PolyGamma[6, a]*
      PolyGamma[7, a] + 984555*PolyGamma[0, a]^2*PolyGamma[7, a]^2 + 
     984555*PolyGamma[1, a]*PolyGamma[7, a]^2 + 48620*PolyGamma[0, a]^9*
      PolyGamma[8, a] + 1750320*PolyGamma[0, a]^7*PolyGamma[1, a]*
      PolyGamma[8, a] + 18378360*PolyGamma[0, a]^5*PolyGamma[1, a]^2*
      PolyGamma[8, a] + 61261200*PolyGamma[0, a]^3*PolyGamma[1, a]^3*
      PolyGamma[8, a] + 45945900*PolyGamma[0, a]*PolyGamma[1, a]^4*
      PolyGamma[8, a] + 4084080*PolyGamma[0, a]^6*PolyGamma[2, a]*
      PolyGamma[8, a] + 61261200*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[8, a] + 183783600*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[8, a] + 
     61261200*PolyGamma[1, a]^3*PolyGamma[2, a]*PolyGamma[8, a] + 
     40840800*PolyGamma[0, a]^3*PolyGamma[2, a]^2*PolyGamma[8, a] + 
     122522400*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[8, a] + 13613600*PolyGamma[2, a]^3*PolyGamma[8, a] + 
     6126120*PolyGamma[0, a]^5*PolyGamma[3, a]*PolyGamma[8, a] + 
     61261200*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[8, a] + 91891800*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[3, a]*PolyGamma[8, a] + 61261200*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[8, a] + 
     61261200*PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[8, a] + 15315300*PolyGamma[0, a]*PolyGamma[3, a]^2*
      PolyGamma[8, a] + 6126120*PolyGamma[0, a]^4*PolyGamma[4, a]*
      PolyGamma[8, a] + 36756720*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[4, a]*PolyGamma[8, a] + 18378360*PolyGamma[1, a]^2*
      PolyGamma[4, a]*PolyGamma[8, a] + 24504480*PolyGamma[0, a]*
      PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[8, a] + 
     6126120*PolyGamma[3, a]*PolyGamma[4, a]*PolyGamma[8, a] + 
     4084080*PolyGamma[0, a]^3*PolyGamma[5, a]*PolyGamma[8, a] + 
     12252240*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[5, a]*
      PolyGamma[8, a] + 4084080*PolyGamma[2, a]*PolyGamma[5, a]*
      PolyGamma[8, a] + 1750320*PolyGamma[0, a]^2*PolyGamma[6, a]*
      PolyGamma[8, a] + 1750320*PolyGamma[1, a]*PolyGamma[6, a]*
      PolyGamma[8, a] + 437580*PolyGamma[0, a]*PolyGamma[7, a]*
      PolyGamma[8, a] + 24310*PolyGamma[8, a]^2 + 43758*PolyGamma[0, a]^8*
      PolyGamma[9, a] + 1225224*PolyGamma[0, a]^6*PolyGamma[1, a]*
      PolyGamma[9, a] + 9189180*PolyGamma[0, a]^4*PolyGamma[1, a]^2*
      PolyGamma[9, a] + 18378360*PolyGamma[0, a]^2*PolyGamma[1, a]^3*
      PolyGamma[9, a] + 4594590*PolyGamma[1, a]^4*PolyGamma[9, a] + 
     2450448*PolyGamma[0, a]^5*PolyGamma[2, a]*PolyGamma[9, a] + 
     24504480*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[9, a] + 36756720*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[9, a] + 12252240*PolyGamma[0, a]^2*
      PolyGamma[2, a]^2*PolyGamma[9, a] + 12252240*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[9, a] + 3063060*PolyGamma[0, a]^4*
      PolyGamma[3, a]*PolyGamma[9, a] + 18378360*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[9, a] + 
     9189180*PolyGamma[1, a]^2*PolyGamma[3, a]*PolyGamma[9, a] + 
     12252240*PolyGamma[0, a]*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[9, a] + 1531530*PolyGamma[3, a]^2*PolyGamma[9, a] + 
     2450448*PolyGamma[0, a]^3*PolyGamma[4, a]*PolyGamma[9, a] + 
     7351344*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[9, a] + 2450448*PolyGamma[2, a]*PolyGamma[4, a]*
      PolyGamma[9, a] + 1225224*PolyGamma[0, a]^2*PolyGamma[5, a]*
      PolyGamma[9, a] + 1225224*PolyGamma[1, a]*PolyGamma[5, a]*
      PolyGamma[9, a] + 350064*PolyGamma[0, a]*PolyGamma[6, a]*
      PolyGamma[9, a] + 43758*PolyGamma[7, a]*PolyGamma[9, a] + 
     31824*PolyGamma[0, a]^7*PolyGamma[10, a] + 668304*PolyGamma[0, a]^5*
      PolyGamma[1, a]*PolyGamma[10, a] + 3341520*PolyGamma[0, a]^3*
      PolyGamma[1, a]^2*PolyGamma[10, a] + 3341520*PolyGamma[0, a]*
      PolyGamma[1, a]^3*PolyGamma[10, a] + 1113840*PolyGamma[0, a]^4*
      PolyGamma[2, a]*PolyGamma[10, a] + 6683040*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[10, a] + 
     3341520*PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[10, a] + 
     2227680*PolyGamma[0, a]*PolyGamma[2, a]^2*PolyGamma[10, a] + 
     1113840*PolyGamma[0, a]^3*PolyGamma[3, a]*PolyGamma[10, a] + 
     3341520*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[10, a] + 1113840*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[10, a] + 668304*PolyGamma[0, a]^2*PolyGamma[4, a]*
      PolyGamma[10, a] + 668304*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[10, a] + 222768*PolyGamma[0, a]*PolyGamma[5, a]*
      PolyGamma[10, a] + 31824*PolyGamma[6, a]*PolyGamma[10, a] + 
     18564*PolyGamma[0, a]^6*PolyGamma[11, a] + 278460*PolyGamma[0, a]^4*
      PolyGamma[1, a]*PolyGamma[11, a] + 835380*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[11, a] + 278460*PolyGamma[1, a]^3*
      PolyGamma[11, a] + 371280*PolyGamma[0, a]^3*PolyGamma[2, a]*
      PolyGamma[11, a] + 1113840*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[11, a] + 185640*PolyGamma[2, a]^2*
      PolyGamma[11, a] + 278460*PolyGamma[0, a]^2*PolyGamma[3, a]*
      PolyGamma[11, a] + 278460*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[11, a] + 111384*PolyGamma[0, a]*PolyGamma[4, a]*
      PolyGamma[11, a] + 18564*PolyGamma[5, a]*PolyGamma[11, a] + 
     8568*PolyGamma[0, a]^5*PolyGamma[12, a] + 85680*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[12, a] + 128520*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[12, a] + 85680*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[12, a] + 85680*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[12, a] + 42840*PolyGamma[0, a]*
      PolyGamma[3, a]*PolyGamma[12, a] + 8568*PolyGamma[4, a]*
      PolyGamma[12, a] + 3060*PolyGamma[0, a]^4*PolyGamma[13, a] + 
     18360*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[13, a] + 
     9180*PolyGamma[1, a]^2*PolyGamma[13, a] + 12240*PolyGamma[0, a]*
      PolyGamma[2, a]*PolyGamma[13, a] + 3060*PolyGamma[3, a]*
      PolyGamma[13, a] + 816*PolyGamma[0, a]^3*PolyGamma[14, a] + 
     2448*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[14, a] + 
     816*PolyGamma[2, a]*PolyGamma[14, a] + 153*PolyGamma[0, a]^2*
      PolyGamma[15, a] + 153*PolyGamma[1, a]*PolyGamma[15, a] + 
     18*PolyGamma[0, a]*PolyGamma[16, a] + PolyGamma[17, a]
 
MBexpGam[a_, 19] = PolyGamma[0, a]^19 + 171*PolyGamma[0, a]^17*
      PolyGamma[1, a] + 11628*PolyGamma[0, a]^15*PolyGamma[1, a]^2 + 
     406980*PolyGamma[0, a]^13*PolyGamma[1, a]^3 + 7936110*PolyGamma[0, a]^11*
      PolyGamma[1, a]^4 + 87297210*PolyGamma[0, a]^9*PolyGamma[1, a]^5 + 
     523783260*PolyGamma[0, a]^7*PolyGamma[1, a]^6 + 
     1571349780*PolyGamma[0, a]^5*PolyGamma[1, a]^7 + 
     1964187225*PolyGamma[0, a]^3*PolyGamma[1, a]^8 + 
     654729075*PolyGamma[0, a]*PolyGamma[1, a]^9 + 969*PolyGamma[0, a]^16*
      PolyGamma[2, a] + 116280*PolyGamma[0, a]^14*PolyGamma[1, a]*
      PolyGamma[2, a] + 5290740*PolyGamma[0, a]^12*PolyGamma[1, a]^2*
      PolyGamma[2, a] + 116396280*PolyGamma[0, a]^10*PolyGamma[1, a]^3*
      PolyGamma[2, a] + 1309458150*PolyGamma[0, a]^8*PolyGamma[1, a]^4*
      PolyGamma[2, a] + 7332965640*PolyGamma[0, a]^6*PolyGamma[1, a]^5*
      PolyGamma[2, a] + 18332414100*PolyGamma[0, a]^4*PolyGamma[1, a]^6*
      PolyGamma[2, a] + 15713497800*PolyGamma[0, a]^2*PolyGamma[1, a]^7*
      PolyGamma[2, a] + 1964187225*PolyGamma[1, a]^8*PolyGamma[2, a] + 
     271320*PolyGamma[0, a]^13*PolyGamma[2, a]^2 + 
     21162960*PolyGamma[0, a]^11*PolyGamma[1, a]*PolyGamma[2, a]^2 + 
     581981400*PolyGamma[0, a]^9*PolyGamma[1, a]^2*PolyGamma[2, a]^2 + 
     6983776800*PolyGamma[0, a]^7*PolyGamma[1, a]^3*PolyGamma[2, a]^2 + 
     36664828200*PolyGamma[0, a]^5*PolyGamma[1, a]^4*PolyGamma[2, a]^2 + 
     73329656400*PolyGamma[0, a]^3*PolyGamma[1, a]^5*PolyGamma[2, a]^2 + 
     36664828200*PolyGamma[0, a]*PolyGamma[1, a]^6*PolyGamma[2, a]^2 + 
     25865840*PolyGamma[0, a]^10*PolyGamma[2, a]^3 + 
     1163962800*PolyGamma[0, a]^8*PolyGamma[1, a]*PolyGamma[2, a]^3 + 
     16295479200*PolyGamma[0, a]^6*PolyGamma[1, a]^2*PolyGamma[2, a]^3 + 
     81477396000*PolyGamma[0, a]^4*PolyGamma[1, a]^3*PolyGamma[2, a]^3 + 
     122216094000*PolyGamma[0, a]^2*PolyGamma[1, a]^4*PolyGamma[2, a]^3 + 
     24443218800*PolyGamma[1, a]^5*PolyGamma[2, a]^3 + 
     775975200*PolyGamma[0, a]^7*PolyGamma[2, a]^4 + 
     16295479200*PolyGamma[0, a]^5*PolyGamma[1, a]*PolyGamma[2, a]^4 + 
     81477396000*PolyGamma[0, a]^3*PolyGamma[1, a]^2*PolyGamma[2, a]^4 + 
     81477396000*PolyGamma[0, a]*PolyGamma[1, a]^3*PolyGamma[2, a]^4 + 
     5431826400*PolyGamma[0, a]^4*PolyGamma[2, a]^5 + 
     32590958400*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[2, a]^5 + 
     16295479200*PolyGamma[1, a]^2*PolyGamma[2, a]^5 + 
     3621217600*PolyGamma[0, a]*PolyGamma[2, a]^6 + 
     3876*PolyGamma[0, a]^15*PolyGamma[3, a] + 406980*PolyGamma[0, a]^13*
      PolyGamma[1, a]*PolyGamma[3, a] + 15872220*PolyGamma[0, a]^11*
      PolyGamma[1, a]^2*PolyGamma[3, a] + 290990700*PolyGamma[0, a]^9*
      PolyGamma[1, a]^3*PolyGamma[3, a] + 2618916300*PolyGamma[0, a]^7*
      PolyGamma[1, a]^4*PolyGamma[3, a] + 10999448460*PolyGamma[0, a]^5*
      PolyGamma[1, a]^5*PolyGamma[3, a] + 18332414100*PolyGamma[0, a]^3*
      PolyGamma[1, a]^6*PolyGamma[3, a] + 7856748900*PolyGamma[0, a]*
      PolyGamma[1, a]^7*PolyGamma[3, a] + 1763580*PolyGamma[0, a]^12*
      PolyGamma[2, a]*PolyGamma[3, a] + 116396280*PolyGamma[0, a]^10*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[3, a] + 
     2618916300*PolyGamma[0, a]^8*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[3, a] + 24443218800*PolyGamma[0, a]^6*PolyGamma[1, a]^3*
      PolyGamma[2, a]*PolyGamma[3, a] + 91662070500*PolyGamma[0, a]^4*
      PolyGamma[1, a]^4*PolyGamma[2, a]*PolyGamma[3, a] + 
     109994484600*PolyGamma[0, a]^2*PolyGamma[1, a]^5*PolyGamma[2, a]*
      PolyGamma[3, a] + 18332414100*PolyGamma[1, a]^6*PolyGamma[2, a]*
      PolyGamma[3, a] + 193993800*PolyGamma[0, a]^9*PolyGamma[2, a]^2*
      PolyGamma[3, a] + 6983776800*PolyGamma[0, a]^7*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[3, a] + 73329656400*PolyGamma[0, a]^5*
      PolyGamma[1, a]^2*PolyGamma[2, a]^2*PolyGamma[3, a] + 
     244432188000*PolyGamma[0, a]^3*PolyGamma[1, a]^3*PolyGamma[2, a]^2*
      PolyGamma[3, a] + 183324141000*PolyGamma[0, a]*PolyGamma[1, a]^4*
      PolyGamma[2, a]^2*PolyGamma[3, a] + 5431826400*PolyGamma[0, a]^6*
      PolyGamma[2, a]^3*PolyGamma[3, a] + 81477396000*PolyGamma[0, a]^4*
      PolyGamma[1, a]*PolyGamma[2, a]^3*PolyGamma[3, a] + 
     244432188000*PolyGamma[0, a]^2*PolyGamma[1, a]^2*PolyGamma[2, a]^3*
      PolyGamma[3, a] + 81477396000*PolyGamma[1, a]^3*PolyGamma[2, a]^3*
      PolyGamma[3, a] + 27159132000*PolyGamma[0, a]^3*PolyGamma[2, a]^4*
      PolyGamma[3, a] + 81477396000*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]^4*PolyGamma[3, a] + 5431826400*PolyGamma[2, a]^5*
      PolyGamma[3, a] + 2645370*PolyGamma[0, a]^11*PolyGamma[3, a]^2 + 
     145495350*PolyGamma[0, a]^9*PolyGamma[1, a]*PolyGamma[3, a]^2 + 
     2618916300*PolyGamma[0, a]^7*PolyGamma[1, a]^2*PolyGamma[3, a]^2 + 
     18332414100*PolyGamma[0, a]^5*PolyGamma[1, a]^3*PolyGamma[3, a]^2 + 
     45831035250*PolyGamma[0, a]^3*PolyGamma[1, a]^4*PolyGamma[3, a]^2 + 
     27498621150*PolyGamma[0, a]*PolyGamma[1, a]^5*PolyGamma[3, a]^2 + 
     436486050*PolyGamma[0, a]^8*PolyGamma[2, a]*PolyGamma[3, a]^2 + 
     12221609400*PolyGamma[0, a]^6*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[3, a]^2 + 91662070500*PolyGamma[0, a]^4*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[3, a]^2 + 183324141000*PolyGamma[0, a]^2*
      PolyGamma[1, a]^3*PolyGamma[2, a]*PolyGamma[3, a]^2 + 
     45831035250*PolyGamma[1, a]^4*PolyGamma[2, a]*PolyGamma[3, a]^2 + 
     12221609400*PolyGamma[0, a]^5*PolyGamma[2, a]^2*PolyGamma[3, a]^2 + 
     122216094000*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[3, a]^2 + 183324141000*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[2, a]^2*PolyGamma[3, a]^2 + 40738698000*PolyGamma[0, a]^2*
      PolyGamma[2, a]^3*PolyGamma[3, a]^2 + 40738698000*PolyGamma[1, a]*
      PolyGamma[2, a]^3*PolyGamma[3, a]^2 + 290990700*PolyGamma[0, a]^7*
      PolyGamma[3, a]^3 + 6110804700*PolyGamma[0, a]^5*PolyGamma[1, a]*
      PolyGamma[3, a]^3 + 30554023500*PolyGamma[0, a]^3*PolyGamma[1, a]^2*
      PolyGamma[3, a]^3 + 30554023500*PolyGamma[0, a]*PolyGamma[1, a]^3*
      PolyGamma[3, a]^3 + 10184674500*PolyGamma[0, a]^4*PolyGamma[2, a]*
      PolyGamma[3, a]^3 + 61108047000*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]^3 + 30554023500*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[3, a]^3 + 20369349000*PolyGamma[0, a]*
      PolyGamma[2, a]^2*PolyGamma[3, a]^3 + 2546168625*PolyGamma[0, a]^3*
      PolyGamma[3, a]^4 + 7638505875*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[3, a]^4 + 2546168625*PolyGamma[2, a]*PolyGamma[3, a]^4 + 
     11628*PolyGamma[0, a]^14*PolyGamma[4, a] + 1058148*PolyGamma[0, a]^12*
      PolyGamma[1, a]*PolyGamma[4, a] + 34918884*PolyGamma[0, a]^10*
      PolyGamma[1, a]^2*PolyGamma[4, a] + 523783260*PolyGamma[0, a]^8*
      PolyGamma[1, a]^3*PolyGamma[4, a] + 3666482820*PolyGamma[0, a]^6*
      PolyGamma[1, a]^4*PolyGamma[4, a] + 10999448460*PolyGamma[0, a]^4*
      PolyGamma[1, a]^5*PolyGamma[4, a] + 10999448460*PolyGamma[0, a]^2*
      PolyGamma[1, a]^6*PolyGamma[4, a] + 1571349780*PolyGamma[1, a]^7*
      PolyGamma[4, a] + 4232592*PolyGamma[0, a]^11*PolyGamma[2, a]*
      PolyGamma[4, a] + 232792560*PolyGamma[0, a]^9*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[4, a] + 4190266080*PolyGamma[0, a]^7*
      PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[4, a] + 
     29331862560*PolyGamma[0, a]^5*PolyGamma[1, a]^3*PolyGamma[2, a]*
      PolyGamma[4, a] + 73329656400*PolyGamma[0, a]^3*PolyGamma[1, a]^4*
      PolyGamma[2, a]*PolyGamma[4, a] + 43997793840*PolyGamma[0, a]*
      PolyGamma[1, a]^5*PolyGamma[2, a]*PolyGamma[4, a] + 
     349188840*PolyGamma[0, a]^8*PolyGamma[2, a]^2*PolyGamma[4, a] + 
     9777287520*PolyGamma[0, a]^6*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[4, a] + 73329656400*PolyGamma[0, a]^4*PolyGamma[1, a]^2*
      PolyGamma[2, a]^2*PolyGamma[4, a] + 146659312800*PolyGamma[0, a]^2*
      PolyGamma[1, a]^3*PolyGamma[2, a]^2*PolyGamma[4, a] + 
     36664828200*PolyGamma[1, a]^4*PolyGamma[2, a]^2*PolyGamma[4, a] + 
     6518191680*PolyGamma[0, a]^5*PolyGamma[2, a]^3*PolyGamma[4, a] + 
     65181916800*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[2, a]^3*
      PolyGamma[4, a] + 97772875200*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[2, a]^3*PolyGamma[4, a] + 16295479200*PolyGamma[0, a]^2*
      PolyGamma[2, a]^4*PolyGamma[4, a] + 16295479200*PolyGamma[1, a]*
      PolyGamma[2, a]^4*PolyGamma[4, a] + 11639628*PolyGamma[0, a]^10*
      PolyGamma[3, a]*PolyGamma[4, a] + 523783260*PolyGamma[0, a]^8*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[4, a] + 
     7332965640*PolyGamma[0, a]^6*PolyGamma[1, a]^2*PolyGamma[3, a]*
      PolyGamma[4, a] + 36664828200*PolyGamma[0, a]^4*PolyGamma[1, a]^3*
      PolyGamma[3, a]*PolyGamma[4, a] + 54997242300*PolyGamma[0, a]^2*
      PolyGamma[1, a]^4*PolyGamma[3, a]*PolyGamma[4, a] + 
     10999448460*PolyGamma[1, a]^5*PolyGamma[3, a]*PolyGamma[4, a] + 
     1396755360*PolyGamma[0, a]^7*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[4, a] + 29331862560*PolyGamma[0, a]^5*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a] + 
     146659312800*PolyGamma[0, a]^3*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[4, a] + 146659312800*PolyGamma[0, a]*
      PolyGamma[1, a]^3*PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a] + 
     24443218800*PolyGamma[0, a]^4*PolyGamma[2, a]^2*PolyGamma[3, a]*
      PolyGamma[4, a] + 146659312800*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[3, a]*PolyGamma[4, a] + 
     73329656400*PolyGamma[1, a]^2*PolyGamma[2, a]^2*PolyGamma[3, a]*
      PolyGamma[4, a] + 32590958400*PolyGamma[0, a]*PolyGamma[2, a]^3*
      PolyGamma[3, a]*PolyGamma[4, a] + 1222160940*PolyGamma[0, a]^6*
      PolyGamma[3, a]^2*PolyGamma[4, a] + 18332414100*PolyGamma[0, a]^4*
      PolyGamma[1, a]*PolyGamma[3, a]^2*PolyGamma[4, a] + 
     54997242300*PolyGamma[0, a]^2*PolyGamma[1, a]^2*PolyGamma[3, a]^2*
      PolyGamma[4, a] + 18332414100*PolyGamma[1, a]^3*PolyGamma[3, a]^2*
      PolyGamma[4, a] + 24443218800*PolyGamma[0, a]^3*PolyGamma[2, a]*
      PolyGamma[3, a]^2*PolyGamma[4, a] + 73329656400*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[3, a]^2*PolyGamma[4, a] + 
     12221609400*PolyGamma[2, a]^2*PolyGamma[3, a]^2*PolyGamma[4, a] + 
     6110804700*PolyGamma[0, a]^2*PolyGamma[3, a]^3*PolyGamma[4, a] + 
     6110804700*PolyGamma[1, a]*PolyGamma[3, a]^3*PolyGamma[4, a] + 
     11639628*PolyGamma[0, a]^9*PolyGamma[4, a]^2 + 
     419026608*PolyGamma[0, a]^7*PolyGamma[1, a]*PolyGamma[4, a]^2 + 
     4399779384*PolyGamma[0, a]^5*PolyGamma[1, a]^2*PolyGamma[4, a]^2 + 
     14665931280*PolyGamma[0, a]^3*PolyGamma[1, a]^3*PolyGamma[4, a]^2 + 
     10999448460*PolyGamma[0, a]*PolyGamma[1, a]^4*PolyGamma[4, a]^2 + 
     977728752*PolyGamma[0, a]^6*PolyGamma[2, a]*PolyGamma[4, a]^2 + 
     14665931280*PolyGamma[0, a]^4*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[4, a]^2 + 43997793840*PolyGamma[0, a]^2*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[4, a]^2 + 14665931280*PolyGamma[1, a]^3*
      PolyGamma[2, a]*PolyGamma[4, a]^2 + 9777287520*PolyGamma[0, a]^3*
      PolyGamma[2, a]^2*PolyGamma[4, a]^2 + 29331862560*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[2, a]^2*PolyGamma[4, a]^2 + 
     3259095840*PolyGamma[2, a]^3*PolyGamma[4, a]^2 + 
     1466593128*PolyGamma[0, a]^5*PolyGamma[3, a]*PolyGamma[4, a]^2 + 
     14665931280*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[4, a]^2 + 21998896920*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[3, a]*PolyGamma[4, a]^2 + 14665931280*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a]^2 + 
     14665931280*PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[4, a]^2 + 3666482820*PolyGamma[0, a]*PolyGamma[3, a]^2*
      PolyGamma[4, a]^2 + 488864376*PolyGamma[0, a]^4*PolyGamma[4, a]^3 + 
     2933186256*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[4, a]^3 + 
     1466593128*PolyGamma[1, a]^2*PolyGamma[4, a]^3 + 
     1955457504*PolyGamma[0, a]*PolyGamma[2, a]*PolyGamma[4, a]^3 + 
     488864376*PolyGamma[3, a]*PolyGamma[4, a]^3 + 27132*PolyGamma[0, a]^13*
      PolyGamma[5, a] + 2116296*PolyGamma[0, a]^11*PolyGamma[1, a]*
      PolyGamma[5, a] + 58198140*PolyGamma[0, a]^9*PolyGamma[1, a]^2*
      PolyGamma[5, a] + 698377680*PolyGamma[0, a]^7*PolyGamma[1, a]^3*
      PolyGamma[5, a] + 3666482820*PolyGamma[0, a]^5*PolyGamma[1, a]^4*
      PolyGamma[5, a] + 7332965640*PolyGamma[0, a]^3*PolyGamma[1, a]^5*
      PolyGamma[5, a] + 3666482820*PolyGamma[0, a]*PolyGamma[1, a]^6*
      PolyGamma[5, a] + 7759752*PolyGamma[0, a]^10*PolyGamma[2, a]*
      PolyGamma[5, a] + 349188840*PolyGamma[0, a]^8*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[5, a] + 4888643760*PolyGamma[0, a]^6*
      PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[5, a] + 
     24443218800*PolyGamma[0, a]^4*PolyGamma[1, a]^3*PolyGamma[2, a]*
      PolyGamma[5, a] + 36664828200*PolyGamma[0, a]^2*PolyGamma[1, a]^4*
      PolyGamma[2, a]*PolyGamma[5, a] + 7332965640*PolyGamma[1, a]^5*
      PolyGamma[2, a]*PolyGamma[5, a] + 465585120*PolyGamma[0, a]^7*
      PolyGamma[2, a]^2*PolyGamma[5, a] + 9777287520*PolyGamma[0, a]^5*
      PolyGamma[1, a]*PolyGamma[2, a]^2*PolyGamma[5, a] + 
     48886437600*PolyGamma[0, a]^3*PolyGamma[1, a]^2*PolyGamma[2, a]^2*
      PolyGamma[5, a] + 48886437600*PolyGamma[0, a]*PolyGamma[1, a]^3*
      PolyGamma[2, a]^2*PolyGamma[5, a] + 5431826400*PolyGamma[0, a]^4*
      PolyGamma[2, a]^3*PolyGamma[5, a] + 32590958400*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[2, a]^3*PolyGamma[5, a] + 
     16295479200*PolyGamma[1, a]^2*PolyGamma[2, a]^3*PolyGamma[5, a] + 
     5431826400*PolyGamma[0, a]*PolyGamma[2, a]^4*PolyGamma[5, a] + 
     19399380*PolyGamma[0, a]^9*PolyGamma[3, a]*PolyGamma[5, a] + 
     698377680*PolyGamma[0, a]^7*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[5, a] + 7332965640*PolyGamma[0, a]^5*PolyGamma[1, a]^2*
      PolyGamma[3, a]*PolyGamma[5, a] + 24443218800*PolyGamma[0, a]^3*
      PolyGamma[1, a]^3*PolyGamma[3, a]*PolyGamma[5, a] + 
     18332414100*PolyGamma[0, a]*PolyGamma[1, a]^4*PolyGamma[3, a]*
      PolyGamma[5, a] + 1629547920*PolyGamma[0, a]^6*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[5, a] + 24443218800*PolyGamma[0, a]^4*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[5, a] + 
     73329656400*PolyGamma[0, a]^2*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[5, a] + 24443218800*PolyGamma[1, a]^3*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[5, a] + 
     16295479200*PolyGamma[0, a]^3*PolyGamma[2, a]^2*PolyGamma[3, a]*
      PolyGamma[5, a] + 48886437600*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[3, a]*PolyGamma[5, a] + 
     5431826400*PolyGamma[2, a]^3*PolyGamma[3, a]*PolyGamma[5, a] + 
     1222160940*PolyGamma[0, a]^5*PolyGamma[3, a]^2*PolyGamma[5, a] + 
     12221609400*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[3, a]^2*
      PolyGamma[5, a] + 18332414100*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[3, a]^2*PolyGamma[5, a] + 12221609400*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[3, a]^2*PolyGamma[5, a] + 
     12221609400*PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[3, a]^2*
      PolyGamma[5, a] + 2036934900*PolyGamma[0, a]*PolyGamma[3, a]^3*
      PolyGamma[5, a] + 34918884*PolyGamma[0, a]^8*PolyGamma[4, a]*
      PolyGamma[5, a] + 977728752*PolyGamma[0, a]^6*PolyGamma[1, a]*
      PolyGamma[4, a]*PolyGamma[5, a] + 7332965640*PolyGamma[0, a]^4*
      PolyGamma[1, a]^2*PolyGamma[4, a]*PolyGamma[5, a] + 
     14665931280*PolyGamma[0, a]^2*PolyGamma[1, a]^3*PolyGamma[4, a]*
      PolyGamma[5, a] + 3666482820*PolyGamma[1, a]^4*PolyGamma[4, a]*
      PolyGamma[5, a] + 1955457504*PolyGamma[0, a]^5*PolyGamma[2, a]*
      PolyGamma[4, a]*PolyGamma[5, a] + 19554575040*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[5, a] + 
     29331862560*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[4, a]*PolyGamma[5, a] + 9777287520*PolyGamma[0, a]^2*
      PolyGamma[2, a]^2*PolyGamma[4, a]*PolyGamma[5, a] + 
     9777287520*PolyGamma[1, a]*PolyGamma[2, a]^2*PolyGamma[4, a]*
      PolyGamma[5, a] + 2444321880*PolyGamma[0, a]^4*PolyGamma[3, a]*
      PolyGamma[4, a]*PolyGamma[5, a] + 14665931280*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[4, a]*PolyGamma[5, a] + 
     7332965640*PolyGamma[1, a]^2*PolyGamma[3, a]*PolyGamma[4, a]*
      PolyGamma[5, a] + 9777287520*PolyGamma[0, a]*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[4, a]*PolyGamma[5, a] + 
     1222160940*PolyGamma[3, a]^2*PolyGamma[4, a]*PolyGamma[5, a] + 
     977728752*PolyGamma[0, a]^3*PolyGamma[4, a]^2*PolyGamma[5, a] + 
     2933186256*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[4, a]^2*
      PolyGamma[5, a] + 977728752*PolyGamma[2, a]*PolyGamma[4, a]^2*
      PolyGamma[5, a] + 23279256*PolyGamma[0, a]^7*PolyGamma[5, a]^2 + 
     488864376*PolyGamma[0, a]^5*PolyGamma[1, a]*PolyGamma[5, a]^2 + 
     2444321880*PolyGamma[0, a]^3*PolyGamma[1, a]^2*PolyGamma[5, a]^2 + 
     2444321880*PolyGamma[0, a]*PolyGamma[1, a]^3*PolyGamma[5, a]^2 + 
     814773960*PolyGamma[0, a]^4*PolyGamma[2, a]*PolyGamma[5, a]^2 + 
     4888643760*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[5, a]^2 + 2444321880*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[5, a]^2 + 1629547920*PolyGamma[0, a]*PolyGamma[2, a]^2*
      PolyGamma[5, a]^2 + 814773960*PolyGamma[0, a]^3*PolyGamma[3, a]*
      PolyGamma[5, a]^2 + 2444321880*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[3, a]*PolyGamma[5, a]^2 + 814773960*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[5, a]^2 + 488864376*PolyGamma[0, a]^2*
      PolyGamma[4, a]*PolyGamma[5, a]^2 + 488864376*PolyGamma[1, a]*
      PolyGamma[4, a]*PolyGamma[5, a]^2 + 54318264*PolyGamma[0, a]*
      PolyGamma[5, a]^3 + 50388*PolyGamma[0, a]^12*PolyGamma[6, a] + 
     3325608*PolyGamma[0, a]^10*PolyGamma[1, a]*PolyGamma[6, a] + 
     74826180*PolyGamma[0, a]^8*PolyGamma[1, a]^2*PolyGamma[6, a] + 
     698377680*PolyGamma[0, a]^6*PolyGamma[1, a]^3*PolyGamma[6, a] + 
     2618916300*PolyGamma[0, a]^4*PolyGamma[1, a]^4*PolyGamma[6, a] + 
     3142699560*PolyGamma[0, a]^2*PolyGamma[1, a]^5*PolyGamma[6, a] + 
     523783260*PolyGamma[1, a]^6*PolyGamma[6, a] + 11085360*PolyGamma[0, a]^9*
      PolyGamma[2, a]*PolyGamma[6, a] + 399072960*PolyGamma[0, a]^7*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[6, a] + 
     4190266080*PolyGamma[0, a]^5*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[6, a] + 13967553600*PolyGamma[0, a]^3*PolyGamma[1, a]^3*
      PolyGamma[2, a]*PolyGamma[6, a] + 10475665200*PolyGamma[0, a]*
      PolyGamma[1, a]^4*PolyGamma[2, a]*PolyGamma[6, a] + 
     465585120*PolyGamma[0, a]^6*PolyGamma[2, a]^2*PolyGamma[6, a] + 
     6983776800*PolyGamma[0, a]^4*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[6, a] + 20951330400*PolyGamma[0, a]^2*PolyGamma[1, a]^2*
      PolyGamma[2, a]^2*PolyGamma[6, a] + 6983776800*PolyGamma[1, a]^3*
      PolyGamma[2, a]^2*PolyGamma[6, a] + 3103900800*PolyGamma[0, a]^3*
      PolyGamma[2, a]^3*PolyGamma[6, a] + 9311702400*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[2, a]^3*PolyGamma[6, a] + 
     775975200*PolyGamma[2, a]^4*PolyGamma[6, a] + 24942060*PolyGamma[0, a]^8*
      PolyGamma[3, a]*PolyGamma[6, a] + 698377680*PolyGamma[0, a]^6*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[6, a] + 
     5237832600*PolyGamma[0, a]^4*PolyGamma[1, a]^2*PolyGamma[3, a]*
      PolyGamma[6, a] + 10475665200*PolyGamma[0, a]^2*PolyGamma[1, a]^3*
      PolyGamma[3, a]*PolyGamma[6, a] + 2618916300*PolyGamma[1, a]^4*
      PolyGamma[3, a]*PolyGamma[6, a] + 1396755360*PolyGamma[0, a]^5*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[6, a] + 
     13967553600*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[6, a] + 20951330400*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[6, a] + 
     6983776800*PolyGamma[0, a]^2*PolyGamma[2, a]^2*PolyGamma[3, a]*
      PolyGamma[6, a] + 6983776800*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[3, a]*PolyGamma[6, a] + 872972100*PolyGamma[0, a]^4*
      PolyGamma[3, a]^2*PolyGamma[6, a] + 5237832600*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[3, a]^2*PolyGamma[6, a] + 
     2618916300*PolyGamma[1, a]^2*PolyGamma[3, a]^2*PolyGamma[6, a] + 
     3491888400*PolyGamma[0, a]*PolyGamma[2, a]*PolyGamma[3, a]^2*
      PolyGamma[6, a] + 290990700*PolyGamma[3, a]^3*PolyGamma[6, a] + 
     39907296*PolyGamma[0, a]^7*PolyGamma[4, a]*PolyGamma[6, a] + 
     838053216*PolyGamma[0, a]^5*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[6, a] + 4190266080*PolyGamma[0, a]^3*PolyGamma[1, a]^2*
      PolyGamma[4, a]*PolyGamma[6, a] + 4190266080*PolyGamma[0, a]*
      PolyGamma[1, a]^3*PolyGamma[4, a]*PolyGamma[6, a] + 
     1396755360*PolyGamma[0, a]^4*PolyGamma[2, a]*PolyGamma[4, a]*
      PolyGamma[6, a] + 8380532160*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[6, a] + 
     4190266080*PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[4, a]*
      PolyGamma[6, a] + 2793510720*PolyGamma[0, a]*PolyGamma[2, a]^2*
      PolyGamma[4, a]*PolyGamma[6, a] + 1396755360*PolyGamma[0, a]^3*
      PolyGamma[3, a]*PolyGamma[4, a]*PolyGamma[6, a] + 
     4190266080*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[4, a]*PolyGamma[6, a] + 1396755360*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[4, a]*PolyGamma[6, a] + 
     419026608*PolyGamma[0, a]^2*PolyGamma[4, a]^2*PolyGamma[6, a] + 
     419026608*PolyGamma[1, a]*PolyGamma[4, a]^2*PolyGamma[6, a] + 
     46558512*PolyGamma[0, a]^6*PolyGamma[5, a]*PolyGamma[6, a] + 
     698377680*PolyGamma[0, a]^4*PolyGamma[1, a]*PolyGamma[5, a]*
      PolyGamma[6, a] + 2095133040*PolyGamma[0, a]^2*PolyGamma[1, a]^2*
      PolyGamma[5, a]*PolyGamma[6, a] + 698377680*PolyGamma[1, a]^3*
      PolyGamma[5, a]*PolyGamma[6, a] + 931170240*PolyGamma[0, a]^3*
      PolyGamma[2, a]*PolyGamma[5, a]*PolyGamma[6, a] + 
     2793510720*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[5, a]*PolyGamma[6, a] + 465585120*PolyGamma[2, a]^2*
      PolyGamma[5, a]*PolyGamma[6, a] + 698377680*PolyGamma[0, a]^2*
      PolyGamma[3, a]*PolyGamma[5, a]*PolyGamma[6, a] + 
     698377680*PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[5, a]*
      PolyGamma[6, a] + 279351072*PolyGamma[0, a]*PolyGamma[4, a]*
      PolyGamma[5, a]*PolyGamma[6, a] + 23279256*PolyGamma[5, a]^2*
      PolyGamma[6, a] + 19953648*PolyGamma[0, a]^5*PolyGamma[6, a]^2 + 
     199536480*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[6, a]^2 + 
     299304720*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[6, a]^2 + 
     199536480*PolyGamma[0, a]^2*PolyGamma[2, a]*PolyGamma[6, a]^2 + 
     199536480*PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[6, a]^2 + 
     99768240*PolyGamma[0, a]*PolyGamma[3, a]*PolyGamma[6, a]^2 + 
     19953648*PolyGamma[4, a]*PolyGamma[6, a]^2 + 75582*PolyGamma[0, a]^11*
      PolyGamma[7, a] + 4157010*PolyGamma[0, a]^9*PolyGamma[1, a]*
      PolyGamma[7, a] + 74826180*PolyGamma[0, a]^7*PolyGamma[1, a]^2*
      PolyGamma[7, a] + 523783260*PolyGamma[0, a]^5*PolyGamma[1, a]^3*
      PolyGamma[7, a] + 1309458150*PolyGamma[0, a]^3*PolyGamma[1, a]^4*
      PolyGamma[7, a] + 785674890*PolyGamma[0, a]*PolyGamma[1, a]^5*
      PolyGamma[7, a] + 12471030*PolyGamma[0, a]^8*PolyGamma[2, a]*
      PolyGamma[7, a] + 349188840*PolyGamma[0, a]^6*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[7, a] + 2618916300*PolyGamma[0, a]^4*
      PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[7, a] + 
     5237832600*PolyGamma[0, a]^2*PolyGamma[1, a]^3*PolyGamma[2, a]*
      PolyGamma[7, a] + 1309458150*PolyGamma[1, a]^4*PolyGamma[2, a]*
      PolyGamma[7, a] + 349188840*PolyGamma[0, a]^5*PolyGamma[2, a]^2*
      PolyGamma[7, a] + 3491888400*PolyGamma[0, a]^3*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[7, a] + 5237832600*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[2, a]^2*PolyGamma[7, a] + 
     1163962800*PolyGamma[0, a]^2*PolyGamma[2, a]^3*PolyGamma[7, a] + 
     1163962800*PolyGamma[1, a]*PolyGamma[2, a]^3*PolyGamma[7, a] + 
     24942060*PolyGamma[0, a]^7*PolyGamma[3, a]*PolyGamma[7, a] + 
     523783260*PolyGamma[0, a]^5*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[7, a] + 2618916300*PolyGamma[0, a]^3*PolyGamma[1, a]^2*
      PolyGamma[3, a]*PolyGamma[7, a] + 2618916300*PolyGamma[0, a]*
      PolyGamma[1, a]^3*PolyGamma[3, a]*PolyGamma[7, a] + 
     872972100*PolyGamma[0, a]^4*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[7, a] + 5237832600*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[7, a] + 
     2618916300*PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[7, a] + 1745944200*PolyGamma[0, a]*PolyGamma[2, a]^2*
      PolyGamma[3, a]*PolyGamma[7, a] + 436486050*PolyGamma[0, a]^3*
      PolyGamma[3, a]^2*PolyGamma[7, a] + 1309458150*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[3, a]^2*PolyGamma[7, a] + 
     436486050*PolyGamma[2, a]*PolyGamma[3, a]^2*PolyGamma[7, a] + 
     34918884*PolyGamma[0, a]^6*PolyGamma[4, a]*PolyGamma[7, a] + 
     523783260*PolyGamma[0, a]^4*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[7, a] + 1571349780*PolyGamma[0, a]^2*PolyGamma[1, a]^2*
      PolyGamma[4, a]*PolyGamma[7, a] + 523783260*PolyGamma[1, a]^3*
      PolyGamma[4, a]*PolyGamma[7, a] + 698377680*PolyGamma[0, a]^3*
      PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[7, a] + 
     2095133040*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[4, a]*PolyGamma[7, a] + 349188840*PolyGamma[2, a]^2*
      PolyGamma[4, a]*PolyGamma[7, a] + 523783260*PolyGamma[0, a]^2*
      PolyGamma[3, a]*PolyGamma[4, a]*PolyGamma[7, a] + 
     523783260*PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[4, a]*
      PolyGamma[7, a] + 104756652*PolyGamma[0, a]*PolyGamma[4, a]^2*
      PolyGamma[7, a] + 34918884*PolyGamma[0, a]^5*PolyGamma[5, a]*
      PolyGamma[7, a] + 349188840*PolyGamma[0, a]^3*PolyGamma[1, a]*
      PolyGamma[5, a]*PolyGamma[7, a] + 523783260*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[5, a]*PolyGamma[7, a] + 
     349188840*PolyGamma[0, a]^2*PolyGamma[2, a]*PolyGamma[5, a]*
      PolyGamma[7, a] + 349188840*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[5, a]*PolyGamma[7, a] + 174594420*PolyGamma[0, a]*
      PolyGamma[3, a]*PolyGamma[5, a]*PolyGamma[7, a] + 
     34918884*PolyGamma[4, a]*PolyGamma[5, a]*PolyGamma[7, a] + 
     24942060*PolyGamma[0, a]^4*PolyGamma[6, a]*PolyGamma[7, a] + 
     149652360*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[6, a]*
      PolyGamma[7, a] + 74826180*PolyGamma[1, a]^2*PolyGamma[6, a]*
      PolyGamma[7, a] + 99768240*PolyGamma[0, a]*PolyGamma[2, a]*
      PolyGamma[6, a]*PolyGamma[7, a] + 24942060*PolyGamma[3, a]*
      PolyGamma[6, a]*PolyGamma[7, a] + 6235515*PolyGamma[0, a]^3*
      PolyGamma[7, a]^2 + 18706545*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[7, a]^2 + 6235515*PolyGamma[2, a]*PolyGamma[7, a]^2 + 
     92378*PolyGamma[0, a]^10*PolyGamma[8, a] + 4157010*PolyGamma[0, a]^8*
      PolyGamma[1, a]*PolyGamma[8, a] + 58198140*PolyGamma[0, a]^6*
      PolyGamma[1, a]^2*PolyGamma[8, a] + 290990700*PolyGamma[0, a]^4*
      PolyGamma[1, a]^3*PolyGamma[8, a] + 436486050*PolyGamma[0, a]^2*
      PolyGamma[1, a]^4*PolyGamma[8, a] + 87297210*PolyGamma[1, a]^5*
      PolyGamma[8, a] + 11085360*PolyGamma[0, a]^7*PolyGamma[2, a]*
      PolyGamma[8, a] + 232792560*PolyGamma[0, a]^5*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[8, a] + 1163962800*PolyGamma[0, a]^3*
      PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[8, a] + 
     1163962800*PolyGamma[0, a]*PolyGamma[1, a]^3*PolyGamma[2, a]*
      PolyGamma[8, a] + 193993800*PolyGamma[0, a]^4*PolyGamma[2, a]^2*
      PolyGamma[8, a] + 1163962800*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[8, a] + 581981400*PolyGamma[1, a]^2*
      PolyGamma[2, a]^2*PolyGamma[8, a] + 258658400*PolyGamma[0, a]*
      PolyGamma[2, a]^3*PolyGamma[8, a] + 19399380*PolyGamma[0, a]^6*
      PolyGamma[3, a]*PolyGamma[8, a] + 290990700*PolyGamma[0, a]^4*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[8, a] + 
     872972100*PolyGamma[0, a]^2*PolyGamma[1, a]^2*PolyGamma[3, a]*
      PolyGamma[8, a] + 290990700*PolyGamma[1, a]^3*PolyGamma[3, a]*
      PolyGamma[8, a] + 387987600*PolyGamma[0, a]^3*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[8, a] + 1163962800*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[8, a] + 
     193993800*PolyGamma[2, a]^2*PolyGamma[3, a]*PolyGamma[8, a] + 
     145495350*PolyGamma[0, a]^2*PolyGamma[3, a]^2*PolyGamma[8, a] + 
     145495350*PolyGamma[1, a]*PolyGamma[3, a]^2*PolyGamma[8, a] + 
     23279256*PolyGamma[0, a]^5*PolyGamma[4, a]*PolyGamma[8, a] + 
     232792560*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[8, a] + 349188840*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[4, a]*PolyGamma[8, a] + 232792560*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[8, a] + 
     232792560*PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[4, a]*
      PolyGamma[8, a] + 116396280*PolyGamma[0, a]*PolyGamma[3, a]*
      PolyGamma[4, a]*PolyGamma[8, a] + 11639628*PolyGamma[4, a]^2*
      PolyGamma[8, a] + 19399380*PolyGamma[0, a]^4*PolyGamma[5, a]*
      PolyGamma[8, a] + 116396280*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[5, a]*PolyGamma[8, a] + 58198140*PolyGamma[1, a]^2*
      PolyGamma[5, a]*PolyGamma[8, a] + 77597520*PolyGamma[0, a]*
      PolyGamma[2, a]*PolyGamma[5, a]*PolyGamma[8, a] + 
     19399380*PolyGamma[3, a]*PolyGamma[5, a]*PolyGamma[8, a] + 
     11085360*PolyGamma[0, a]^3*PolyGamma[6, a]*PolyGamma[8, a] + 
     33256080*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[6, a]*
      PolyGamma[8, a] + 11085360*PolyGamma[2, a]*PolyGamma[6, a]*
      PolyGamma[8, a] + 4157010*PolyGamma[0, a]^2*PolyGamma[7, a]*
      PolyGamma[8, a] + 4157010*PolyGamma[1, a]*PolyGamma[7, a]*
      PolyGamma[8, a] + 461890*PolyGamma[0, a]*PolyGamma[8, a]^2 + 
     92378*PolyGamma[0, a]^9*PolyGamma[9, a] + 3325608*PolyGamma[0, a]^7*
      PolyGamma[1, a]*PolyGamma[9, a] + 34918884*PolyGamma[0, a]^5*
      PolyGamma[1, a]^2*PolyGamma[9, a] + 116396280*PolyGamma[0, a]^3*
      PolyGamma[1, a]^3*PolyGamma[9, a] + 87297210*PolyGamma[0, a]*
      PolyGamma[1, a]^4*PolyGamma[9, a] + 7759752*PolyGamma[0, a]^6*
      PolyGamma[2, a]*PolyGamma[9, a] + 116396280*PolyGamma[0, a]^4*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[9, a] + 
     349188840*PolyGamma[0, a]^2*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[9, a] + 116396280*PolyGamma[1, a]^3*PolyGamma[2, a]*
      PolyGamma[9, a] + 77597520*PolyGamma[0, a]^3*PolyGamma[2, a]^2*
      PolyGamma[9, a] + 232792560*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[9, a] + 25865840*PolyGamma[2, a]^3*
      PolyGamma[9, a] + 11639628*PolyGamma[0, a]^5*PolyGamma[3, a]*
      PolyGamma[9, a] + 116396280*PolyGamma[0, a]^3*PolyGamma[1, a]*
      PolyGamma[3, a]*PolyGamma[9, a] + 174594420*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[3, a]*PolyGamma[9, a] + 
     116396280*PolyGamma[0, a]^2*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[9, a] + 116396280*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[9, a] + 29099070*PolyGamma[0, a]*
      PolyGamma[3, a]^2*PolyGamma[9, a] + 11639628*PolyGamma[0, a]^4*
      PolyGamma[4, a]*PolyGamma[9, a] + 69837768*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[4, a]*PolyGamma[9, a] + 
     34918884*PolyGamma[1, a]^2*PolyGamma[4, a]*PolyGamma[9, a] + 
     46558512*PolyGamma[0, a]*PolyGamma[2, a]*PolyGamma[4, a]*
      PolyGamma[9, a] + 11639628*PolyGamma[3, a]*PolyGamma[4, a]*
      PolyGamma[9, a] + 7759752*PolyGamma[0, a]^3*PolyGamma[5, a]*
      PolyGamma[9, a] + 23279256*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[5, a]*PolyGamma[9, a] + 7759752*PolyGamma[2, a]*
      PolyGamma[5, a]*PolyGamma[9, a] + 3325608*PolyGamma[0, a]^2*
      PolyGamma[6, a]*PolyGamma[9, a] + 3325608*PolyGamma[1, a]*
      PolyGamma[6, a]*PolyGamma[9, a] + 831402*PolyGamma[0, a]*
      PolyGamma[7, a]*PolyGamma[9, a] + 92378*PolyGamma[8, a]*
      PolyGamma[9, a] + 75582*PolyGamma[0, a]^8*PolyGamma[10, a] + 
     2116296*PolyGamma[0, a]^6*PolyGamma[1, a]*PolyGamma[10, a] + 
     15872220*PolyGamma[0, a]^4*PolyGamma[1, a]^2*PolyGamma[10, a] + 
     31744440*PolyGamma[0, a]^2*PolyGamma[1, a]^3*PolyGamma[10, a] + 
     7936110*PolyGamma[1, a]^4*PolyGamma[10, a] + 4232592*PolyGamma[0, a]^5*
      PolyGamma[2, a]*PolyGamma[10, a] + 42325920*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[10, a] + 
     63488880*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[10, a] + 21162960*PolyGamma[0, a]^2*PolyGamma[2, a]^2*
      PolyGamma[10, a] + 21162960*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[10, a] + 5290740*PolyGamma[0, a]^4*PolyGamma[3, a]*
      PolyGamma[10, a] + 31744440*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[3, a]*PolyGamma[10, a] + 15872220*PolyGamma[1, a]^2*
      PolyGamma[3, a]*PolyGamma[10, a] + 21162960*PolyGamma[0, a]*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[10, a] + 
     2645370*PolyGamma[3, a]^2*PolyGamma[10, a] + 4232592*PolyGamma[0, a]^3*
      PolyGamma[4, a]*PolyGamma[10, a] + 12697776*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[4, a]*PolyGamma[10, a] + 
     4232592*PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[10, a] + 
     2116296*PolyGamma[0, a]^2*PolyGamma[5, a]*PolyGamma[10, a] + 
     2116296*PolyGamma[1, a]*PolyGamma[5, a]*PolyGamma[10, a] + 
     604656*PolyGamma[0, a]*PolyGamma[6, a]*PolyGamma[10, a] + 
     75582*PolyGamma[7, a]*PolyGamma[10, a] + 50388*PolyGamma[0, a]^7*
      PolyGamma[11, a] + 1058148*PolyGamma[0, a]^5*PolyGamma[1, a]*
      PolyGamma[11, a] + 5290740*PolyGamma[0, a]^3*PolyGamma[1, a]^2*
      PolyGamma[11, a] + 5290740*PolyGamma[0, a]*PolyGamma[1, a]^3*
      PolyGamma[11, a] + 1763580*PolyGamma[0, a]^4*PolyGamma[2, a]*
      PolyGamma[11, a] + 10581480*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[11, a] + 5290740*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[11, a] + 3527160*PolyGamma[0, a]*
      PolyGamma[2, a]^2*PolyGamma[11, a] + 1763580*PolyGamma[0, a]^3*
      PolyGamma[3, a]*PolyGamma[11, a] + 5290740*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[11, a] + 
     1763580*PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[11, a] + 
     1058148*PolyGamma[0, a]^2*PolyGamma[4, a]*PolyGamma[11, a] + 
     1058148*PolyGamma[1, a]*PolyGamma[4, a]*PolyGamma[11, a] + 
     352716*PolyGamma[0, a]*PolyGamma[5, a]*PolyGamma[11, a] + 
     50388*PolyGamma[6, a]*PolyGamma[11, a] + 27132*PolyGamma[0, a]^6*
      PolyGamma[12, a] + 406980*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[12, a] + 1220940*PolyGamma[0, a]^2*PolyGamma[1, a]^2*
      PolyGamma[12, a] + 406980*PolyGamma[1, a]^3*PolyGamma[12, a] + 
     542640*PolyGamma[0, a]^3*PolyGamma[2, a]*PolyGamma[12, a] + 
     1627920*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[12, a] + 271320*PolyGamma[2, a]^2*PolyGamma[12, a] + 
     406980*PolyGamma[0, a]^2*PolyGamma[3, a]*PolyGamma[12, a] + 
     406980*PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[12, a] + 
     162792*PolyGamma[0, a]*PolyGamma[4, a]*PolyGamma[12, a] + 
     27132*PolyGamma[5, a]*PolyGamma[12, a] + 11628*PolyGamma[0, a]^5*
      PolyGamma[13, a] + 116280*PolyGamma[0, a]^3*PolyGamma[1, a]*
      PolyGamma[13, a] + 174420*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[13, a] + 116280*PolyGamma[0, a]^2*PolyGamma[2, a]*
      PolyGamma[13, a] + 116280*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[13, a] + 58140*PolyGamma[0, a]*PolyGamma[3, a]*
      PolyGamma[13, a] + 11628*PolyGamma[4, a]*PolyGamma[13, a] + 
     3876*PolyGamma[0, a]^4*PolyGamma[14, a] + 23256*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[14, a] + 11628*PolyGamma[1, a]^2*
      PolyGamma[14, a] + 15504*PolyGamma[0, a]*PolyGamma[2, a]*
      PolyGamma[14, a] + 3876*PolyGamma[3, a]*PolyGamma[14, a] + 
     969*PolyGamma[0, a]^3*PolyGamma[15, a] + 2907*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[15, a] + 969*PolyGamma[2, a]*
      PolyGamma[15, a] + 171*PolyGamma[0, a]^2*PolyGamma[16, a] + 
     171*PolyGamma[1, a]*PolyGamma[16, a] + 19*PolyGamma[0, a]*
      PolyGamma[17, a] + PolyGamma[18, a]
 
MBexpGam[a_, 20] = PolyGamma[0, a]^20 + 190*PolyGamma[0, a]^18*
      PolyGamma[1, a] + 14535*PolyGamma[0, a]^16*PolyGamma[1, a]^2 + 
     581400*PolyGamma[0, a]^14*PolyGamma[1, a]^3 + 
     13226850*PolyGamma[0, a]^12*PolyGamma[1, a]^4 + 
     174594420*PolyGamma[0, a]^10*PolyGamma[1, a]^5 + 
     1309458150*PolyGamma[0, a]^8*PolyGamma[1, a]^6 + 
     5237832600*PolyGamma[0, a]^6*PolyGamma[1, a]^7 + 
     9820936125*PolyGamma[0, a]^4*PolyGamma[1, a]^8 + 
     6547290750*PolyGamma[0, a]^2*PolyGamma[1, a]^9 + 
     654729075*PolyGamma[1, a]^10 + 1140*PolyGamma[0, a]^17*PolyGamma[2, a] + 
     155040*PolyGamma[0, a]^15*PolyGamma[1, a]*PolyGamma[2, a] + 
     8139600*PolyGamma[0, a]^13*PolyGamma[1, a]^2*PolyGamma[2, a] + 
     211629600*PolyGamma[0, a]^11*PolyGamma[1, a]^3*PolyGamma[2, a] + 
     2909907000*PolyGamma[0, a]^9*PolyGamma[1, a]^4*PolyGamma[2, a] + 
     20951330400*PolyGamma[0, a]^7*PolyGamma[1, a]^5*PolyGamma[2, a] + 
     73329656400*PolyGamma[0, a]^5*PolyGamma[1, a]^6*PolyGamma[2, a] + 
     104756652000*PolyGamma[0, a]^3*PolyGamma[1, a]^7*PolyGamma[2, a] + 
     39283744500*PolyGamma[0, a]*PolyGamma[1, a]^8*PolyGamma[2, a] + 
     387600*PolyGamma[0, a]^14*PolyGamma[2, a]^2 + 
     35271600*PolyGamma[0, a]^12*PolyGamma[1, a]*PolyGamma[2, a]^2 + 
     1163962800*PolyGamma[0, a]^10*PolyGamma[1, a]^2*PolyGamma[2, a]^2 + 
     17459442000*PolyGamma[0, a]^8*PolyGamma[1, a]^3*PolyGamma[2, a]^2 + 
     122216094000*PolyGamma[0, a]^6*PolyGamma[1, a]^4*PolyGamma[2, a]^2 + 
     366648282000*PolyGamma[0, a]^4*PolyGamma[1, a]^5*PolyGamma[2, a]^2 + 
     366648282000*PolyGamma[0, a]^2*PolyGamma[1, a]^6*PolyGamma[2, a]^2 + 
     52378326000*PolyGamma[1, a]^7*PolyGamma[2, a]^2 + 
     47028800*PolyGamma[0, a]^11*PolyGamma[2, a]^3 + 
     2586584000*PolyGamma[0, a]^9*PolyGamma[1, a]*PolyGamma[2, a]^3 + 
     46558512000*PolyGamma[0, a]^7*PolyGamma[1, a]^2*PolyGamma[2, a]^3 + 
     325909584000*PolyGamma[0, a]^5*PolyGamma[1, a]^3*PolyGamma[2, a]^3 + 
     814773960000*PolyGamma[0, a]^3*PolyGamma[1, a]^4*PolyGamma[2, a]^3 + 
     488864376000*PolyGamma[0, a]*PolyGamma[1, a]^5*PolyGamma[2, a]^3 + 
     1939938000*PolyGamma[0, a]^8*PolyGamma[2, a]^4 + 
     54318264000*PolyGamma[0, a]^6*PolyGamma[1, a]*PolyGamma[2, a]^4 + 
     407386980000*PolyGamma[0, a]^4*PolyGamma[1, a]^2*PolyGamma[2, a]^4 + 
     814773960000*PolyGamma[0, a]^2*PolyGamma[1, a]^3*PolyGamma[2, a]^4 + 
     203693490000*PolyGamma[1, a]^4*PolyGamma[2, a]^4 + 
     21727305600*PolyGamma[0, a]^5*PolyGamma[2, a]^5 + 
     217273056000*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[2, a]^5 + 
     325909584000*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[2, a]^5 + 
     36212176000*PolyGamma[0, a]^2*PolyGamma[2, a]^6 + 
     36212176000*PolyGamma[1, a]*PolyGamma[2, a]^6 + 
     4845*PolyGamma[0, a]^16*PolyGamma[3, a] + 581400*PolyGamma[0, a]^14*
      PolyGamma[1, a]*PolyGamma[3, a] + 26453700*PolyGamma[0, a]^12*
      PolyGamma[1, a]^2*PolyGamma[3, a] + 581981400*PolyGamma[0, a]^10*
      PolyGamma[1, a]^3*PolyGamma[3, a] + 6547290750*PolyGamma[0, a]^8*
      PolyGamma[1, a]^4*PolyGamma[3, a] + 36664828200*PolyGamma[0, a]^6*
      PolyGamma[1, a]^5*PolyGamma[3, a] + 91662070500*PolyGamma[0, a]^4*
      PolyGamma[1, a]^6*PolyGamma[3, a] + 78567489000*PolyGamma[0, a]^2*
      PolyGamma[1, a]^7*PolyGamma[3, a] + 9820936125*PolyGamma[1, a]^8*
      PolyGamma[3, a] + 2713200*PolyGamma[0, a]^13*PolyGamma[2, a]*
      PolyGamma[3, a] + 211629600*PolyGamma[0, a]^11*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a] + 5819814000*PolyGamma[0, a]^9*
      PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[3, a] + 
     69837768000*PolyGamma[0, a]^7*PolyGamma[1, a]^3*PolyGamma[2, a]*
      PolyGamma[3, a] + 366648282000*PolyGamma[0, a]^5*PolyGamma[1, a]^4*
      PolyGamma[2, a]*PolyGamma[3, a] + 733296564000*PolyGamma[0, a]^3*
      PolyGamma[1, a]^5*PolyGamma[2, a]*PolyGamma[3, a] + 
     366648282000*PolyGamma[0, a]*PolyGamma[1, a]^6*PolyGamma[2, a]*
      PolyGamma[3, a] + 387987600*PolyGamma[0, a]^10*PolyGamma[2, a]^2*
      PolyGamma[3, a] + 17459442000*PolyGamma[0, a]^8*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[3, a] + 244432188000*PolyGamma[0, a]^6*
      PolyGamma[1, a]^2*PolyGamma[2, a]^2*PolyGamma[3, a] + 
     1222160940000*PolyGamma[0, a]^4*PolyGamma[1, a]^3*PolyGamma[2, a]^2*
      PolyGamma[3, a] + 1833241410000*PolyGamma[0, a]^2*PolyGamma[1, a]^4*
      PolyGamma[2, a]^2*PolyGamma[3, a] + 366648282000*PolyGamma[1, a]^5*
      PolyGamma[2, a]^2*PolyGamma[3, a] + 15519504000*PolyGamma[0, a]^7*
      PolyGamma[2, a]^3*PolyGamma[3, a] + 325909584000*PolyGamma[0, a]^5*
      PolyGamma[1, a]*PolyGamma[2, a]^3*PolyGamma[3, a] + 
     1629547920000*PolyGamma[0, a]^3*PolyGamma[1, a]^2*PolyGamma[2, a]^3*
      PolyGamma[3, a] + 1629547920000*PolyGamma[0, a]*PolyGamma[1, a]^3*
      PolyGamma[2, a]^3*PolyGamma[3, a] + 135795660000*PolyGamma[0, a]^4*
      PolyGamma[2, a]^4*PolyGamma[3, a] + 814773960000*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[2, a]^4*PolyGamma[3, a] + 
     407386980000*PolyGamma[1, a]^2*PolyGamma[2, a]^4*PolyGamma[3, a] + 
     108636528000*PolyGamma[0, a]*PolyGamma[2, a]^5*PolyGamma[3, a] + 
     4408950*PolyGamma[0, a]^12*PolyGamma[3, a]^2 + 
     290990700*PolyGamma[0, a]^10*PolyGamma[1, a]*PolyGamma[3, a]^2 + 
     6547290750*PolyGamma[0, a]^8*PolyGamma[1, a]^2*PolyGamma[3, a]^2 + 
     61108047000*PolyGamma[0, a]^6*PolyGamma[1, a]^3*PolyGamma[3, a]^2 + 
     229155176250*PolyGamma[0, a]^4*PolyGamma[1, a]^4*PolyGamma[3, a]^2 + 
     274986211500*PolyGamma[0, a]^2*PolyGamma[1, a]^5*PolyGamma[3, a]^2 + 
     45831035250*PolyGamma[1, a]^6*PolyGamma[3, a]^2 + 
     969969000*PolyGamma[0, a]^9*PolyGamma[2, a]*PolyGamma[3, a]^2 + 
     34918884000*PolyGamma[0, a]^7*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[3, a]^2 + 366648282000*PolyGamma[0, a]^5*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[3, a]^2 + 1222160940000*PolyGamma[0, a]^3*
      PolyGamma[1, a]^3*PolyGamma[2, a]*PolyGamma[3, a]^2 + 
     916620705000*PolyGamma[0, a]*PolyGamma[1, a]^4*PolyGamma[2, a]*
      PolyGamma[3, a]^2 + 40738698000*PolyGamma[0, a]^6*PolyGamma[2, a]^2*
      PolyGamma[3, a]^2 + 611080470000*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[3, a]^2 + 1833241410000*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[2, a]^2*PolyGamma[3, a]^2 + 
     611080470000*PolyGamma[1, a]^3*PolyGamma[2, a]^2*PolyGamma[3, a]^2 + 
     271591320000*PolyGamma[0, a]^3*PolyGamma[2, a]^3*PolyGamma[3, a]^2 + 
     814773960000*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]^3*
      PolyGamma[3, a]^2 + 67897830000*PolyGamma[2, a]^4*PolyGamma[3, a]^2 + 
     727476750*PolyGamma[0, a]^8*PolyGamma[3, a]^3 + 
     20369349000*PolyGamma[0, a]^6*PolyGamma[1, a]*PolyGamma[3, a]^3 + 
     152770117500*PolyGamma[0, a]^4*PolyGamma[1, a]^2*PolyGamma[3, a]^3 + 
     305540235000*PolyGamma[0, a]^2*PolyGamma[1, a]^3*PolyGamma[3, a]^3 + 
     76385058750*PolyGamma[1, a]^4*PolyGamma[3, a]^3 + 
     40738698000*PolyGamma[0, a]^5*PolyGamma[2, a]*PolyGamma[3, a]^3 + 
     407386980000*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[3, a]^3 + 611080470000*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[3, a]^3 + 203693490000*PolyGamma[0, a]^2*
      PolyGamma[2, a]^2*PolyGamma[3, a]^3 + 203693490000*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[3, a]^3 + 12730843125*PolyGamma[0, a]^4*
      PolyGamma[3, a]^4 + 76385058750*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[3, a]^4 + 38192529375*PolyGamma[1, a]^2*PolyGamma[3, a]^4 + 
     50923372500*PolyGamma[0, a]*PolyGamma[2, a]*PolyGamma[3, a]^4 + 
     2546168625*PolyGamma[3, a]^5 + 15504*PolyGamma[0, a]^15*
      PolyGamma[4, a] + 1627920*PolyGamma[0, a]^13*PolyGamma[1, a]*
      PolyGamma[4, a] + 63488880*PolyGamma[0, a]^11*PolyGamma[1, a]^2*
      PolyGamma[4, a] + 1163962800*PolyGamma[0, a]^9*PolyGamma[1, a]^3*
      PolyGamma[4, a] + 10475665200*PolyGamma[0, a]^7*PolyGamma[1, a]^4*
      PolyGamma[4, a] + 43997793840*PolyGamma[0, a]^5*PolyGamma[1, a]^5*
      PolyGamma[4, a] + 73329656400*PolyGamma[0, a]^3*PolyGamma[1, a]^6*
      PolyGamma[4, a] + 31426995600*PolyGamma[0, a]*PolyGamma[1, a]^7*
      PolyGamma[4, a] + 7054320*PolyGamma[0, a]^12*PolyGamma[2, a]*
      PolyGamma[4, a] + 465585120*PolyGamma[0, a]^10*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[4, a] + 10475665200*PolyGamma[0, a]^8*
      PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[4, a] + 
     97772875200*PolyGamma[0, a]^6*PolyGamma[1, a]^3*PolyGamma[2, a]*
      PolyGamma[4, a] + 366648282000*PolyGamma[0, a]^4*PolyGamma[1, a]^4*
      PolyGamma[2, a]*PolyGamma[4, a] + 439977938400*PolyGamma[0, a]^2*
      PolyGamma[1, a]^5*PolyGamma[2, a]*PolyGamma[4, a] + 
     73329656400*PolyGamma[1, a]^6*PolyGamma[2, a]*PolyGamma[4, a] + 
     775975200*PolyGamma[0, a]^9*PolyGamma[2, a]^2*PolyGamma[4, a] + 
     27935107200*PolyGamma[0, a]^7*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[4, a] + 293318625600*PolyGamma[0, a]^5*PolyGamma[1, a]^2*
      PolyGamma[2, a]^2*PolyGamma[4, a] + 977728752000*PolyGamma[0, a]^3*
      PolyGamma[1, a]^3*PolyGamma[2, a]^2*PolyGamma[4, a] + 
     733296564000*PolyGamma[0, a]*PolyGamma[1, a]^4*PolyGamma[2, a]^2*
      PolyGamma[4, a] + 21727305600*PolyGamma[0, a]^6*PolyGamma[2, a]^3*
      PolyGamma[4, a] + 325909584000*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[2, a]^3*PolyGamma[4, a] + 977728752000*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[2, a]^3*PolyGamma[4, a] + 
     325909584000*PolyGamma[1, a]^3*PolyGamma[2, a]^3*PolyGamma[4, a] + 
     108636528000*PolyGamma[0, a]^3*PolyGamma[2, a]^4*PolyGamma[4, a] + 
     325909584000*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]^4*
      PolyGamma[4, a] + 21727305600*PolyGamma[2, a]^5*PolyGamma[4, a] + 
     21162960*PolyGamma[0, a]^11*PolyGamma[3, a]*PolyGamma[4, a] + 
     1163962800*PolyGamma[0, a]^9*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[4, a] + 20951330400*PolyGamma[0, a]^7*PolyGamma[1, a]^2*
      PolyGamma[3, a]*PolyGamma[4, a] + 146659312800*PolyGamma[0, a]^5*
      PolyGamma[1, a]^3*PolyGamma[3, a]*PolyGamma[4, a] + 
     366648282000*PolyGamma[0, a]^3*PolyGamma[1, a]^4*PolyGamma[3, a]*
      PolyGamma[4, a] + 219988969200*PolyGamma[0, a]*PolyGamma[1, a]^5*
      PolyGamma[3, a]*PolyGamma[4, a] + 3491888400*PolyGamma[0, a]^8*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a] + 
     97772875200*PolyGamma[0, a]^6*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[4, a] + 733296564000*PolyGamma[0, a]^4*
      PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a] + 
     1466593128000*PolyGamma[0, a]^2*PolyGamma[1, a]^3*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[4, a] + 366648282000*PolyGamma[1, a]^4*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a] + 
     97772875200*PolyGamma[0, a]^5*PolyGamma[2, a]^2*PolyGamma[3, a]*
      PolyGamma[4, a] + 977728752000*PolyGamma[0, a]^3*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[3, a]*PolyGamma[4, a] + 
     1466593128000*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[2, a]^2*
      PolyGamma[3, a]*PolyGamma[4, a] + 325909584000*PolyGamma[0, a]^2*
      PolyGamma[2, a]^3*PolyGamma[3, a]*PolyGamma[4, a] + 
     325909584000*PolyGamma[1, a]*PolyGamma[2, a]^3*PolyGamma[3, a]*
      PolyGamma[4, a] + 3491888400*PolyGamma[0, a]^7*PolyGamma[3, a]^2*
      PolyGamma[4, a] + 73329656400*PolyGamma[0, a]^5*PolyGamma[1, a]*
      PolyGamma[3, a]^2*PolyGamma[4, a] + 366648282000*PolyGamma[0, a]^3*
      PolyGamma[1, a]^2*PolyGamma[3, a]^2*PolyGamma[4, a] + 
     366648282000*PolyGamma[0, a]*PolyGamma[1, a]^3*PolyGamma[3, a]^2*
      PolyGamma[4, a] + 122216094000*PolyGamma[0, a]^4*PolyGamma[2, a]*
      PolyGamma[3, a]^2*PolyGamma[4, a] + 733296564000*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[3, a]^2*PolyGamma[4, a] + 
     366648282000*PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[3, a]^2*
      PolyGamma[4, a] + 244432188000*PolyGamma[0, a]*PolyGamma[2, a]^2*
      PolyGamma[3, a]^2*PolyGamma[4, a] + 40738698000*PolyGamma[0, a]^3*
      PolyGamma[3, a]^3*PolyGamma[4, a] + 122216094000*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[3, a]^3*PolyGamma[4, a] + 
     40738698000*PolyGamma[2, a]*PolyGamma[3, a]^3*PolyGamma[4, a] + 
     23279256*PolyGamma[0, a]^10*PolyGamma[4, a]^2 + 
     1047566520*PolyGamma[0, a]^8*PolyGamma[1, a]*PolyGamma[4, a]^2 + 
     14665931280*PolyGamma[0, a]^6*PolyGamma[1, a]^2*PolyGamma[4, a]^2 + 
     73329656400*PolyGamma[0, a]^4*PolyGamma[1, a]^3*PolyGamma[4, a]^2 + 
     109994484600*PolyGamma[0, a]^2*PolyGamma[1, a]^4*PolyGamma[4, a]^2 + 
     21998896920*PolyGamma[1, a]^5*PolyGamma[4, a]^2 + 
     2793510720*PolyGamma[0, a]^7*PolyGamma[2, a]*PolyGamma[4, a]^2 + 
     58663725120*PolyGamma[0, a]^5*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[4, a]^2 + 293318625600*PolyGamma[0, a]^3*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[4, a]^2 + 293318625600*PolyGamma[0, a]*
      PolyGamma[1, a]^3*PolyGamma[2, a]*PolyGamma[4, a]^2 + 
     48886437600*PolyGamma[0, a]^4*PolyGamma[2, a]^2*PolyGamma[4, a]^2 + 
     293318625600*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[4, a]^2 + 146659312800*PolyGamma[1, a]^2*PolyGamma[2, a]^2*
      PolyGamma[4, a]^2 + 65181916800*PolyGamma[0, a]*PolyGamma[2, a]^3*
      PolyGamma[4, a]^2 + 4888643760*PolyGamma[0, a]^6*PolyGamma[3, a]*
      PolyGamma[4, a]^2 + 73329656400*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[3, a]*PolyGamma[4, a]^2 + 219988969200*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[3, a]*PolyGamma[4, a]^2 + 
     73329656400*PolyGamma[1, a]^3*PolyGamma[3, a]*PolyGamma[4, a]^2 + 
     97772875200*PolyGamma[0, a]^3*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[4, a]^2 + 293318625600*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a]^2 + 
     48886437600*PolyGamma[2, a]^2*PolyGamma[3, a]*PolyGamma[4, a]^2 + 
     36664828200*PolyGamma[0, a]^2*PolyGamma[3, a]^2*PolyGamma[4, a]^2 + 
     36664828200*PolyGamma[1, a]*PolyGamma[3, a]^2*PolyGamma[4, a]^2 + 
     1955457504*PolyGamma[0, a]^5*PolyGamma[4, a]^3 + 
     19554575040*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[4, a]^3 + 
     29331862560*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[4, a]^3 + 
     19554575040*PolyGamma[0, a]^2*PolyGamma[2, a]*PolyGamma[4, a]^3 + 
     19554575040*PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[4, a]^3 + 
     9777287520*PolyGamma[0, a]*PolyGamma[3, a]*PolyGamma[4, a]^3 + 
     488864376*PolyGamma[4, a]^4 + 38760*PolyGamma[0, a]^14*PolyGamma[5, a] + 
     3527160*PolyGamma[0, a]^12*PolyGamma[1, a]*PolyGamma[5, a] + 
     116396280*PolyGamma[0, a]^10*PolyGamma[1, a]^2*PolyGamma[5, a] + 
     1745944200*PolyGamma[0, a]^8*PolyGamma[1, a]^3*PolyGamma[5, a] + 
     12221609400*PolyGamma[0, a]^6*PolyGamma[1, a]^4*PolyGamma[5, a] + 
     36664828200*PolyGamma[0, a]^4*PolyGamma[1, a]^5*PolyGamma[5, a] + 
     36664828200*PolyGamma[0, a]^2*PolyGamma[1, a]^6*PolyGamma[5, a] + 
     5237832600*PolyGamma[1, a]^7*PolyGamma[5, a] + 
     14108640*PolyGamma[0, a]^11*PolyGamma[2, a]*PolyGamma[5, a] + 
     775975200*PolyGamma[0, a]^9*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[5, a] + 13967553600*PolyGamma[0, a]^7*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[5, a] + 97772875200*PolyGamma[0, a]^5*
      PolyGamma[1, a]^3*PolyGamma[2, a]*PolyGamma[5, a] + 
     244432188000*PolyGamma[0, a]^3*PolyGamma[1, a]^4*PolyGamma[2, a]*
      PolyGamma[5, a] + 146659312800*PolyGamma[0, a]*PolyGamma[1, a]^5*
      PolyGamma[2, a]*PolyGamma[5, a] + 1163962800*PolyGamma[0, a]^8*
      PolyGamma[2, a]^2*PolyGamma[5, a] + 32590958400*PolyGamma[0, a]^6*
      PolyGamma[1, a]*PolyGamma[2, a]^2*PolyGamma[5, a] + 
     244432188000*PolyGamma[0, a]^4*PolyGamma[1, a]^2*PolyGamma[2, a]^2*
      PolyGamma[5, a] + 488864376000*PolyGamma[0, a]^2*PolyGamma[1, a]^3*
      PolyGamma[2, a]^2*PolyGamma[5, a] + 122216094000*PolyGamma[1, a]^4*
      PolyGamma[2, a]^2*PolyGamma[5, a] + 21727305600*PolyGamma[0, a]^5*
      PolyGamma[2, a]^3*PolyGamma[5, a] + 217273056000*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[2, a]^3*PolyGamma[5, a] + 
     325909584000*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[2, a]^3*
      PolyGamma[5, a] + 54318264000*PolyGamma[0, a]^2*PolyGamma[2, a]^4*
      PolyGamma[5, a] + 54318264000*PolyGamma[1, a]*PolyGamma[2, a]^4*
      PolyGamma[5, a] + 38798760*PolyGamma[0, a]^10*PolyGamma[3, a]*
      PolyGamma[5, a] + 1745944200*PolyGamma[0, a]^8*PolyGamma[1, a]*
      PolyGamma[3, a]*PolyGamma[5, a] + 24443218800*PolyGamma[0, a]^6*
      PolyGamma[1, a]^2*PolyGamma[3, a]*PolyGamma[5, a] + 
     122216094000*PolyGamma[0, a]^4*PolyGamma[1, a]^3*PolyGamma[3, a]*
      PolyGamma[5, a] + 183324141000*PolyGamma[0, a]^2*PolyGamma[1, a]^4*
      PolyGamma[3, a]*PolyGamma[5, a] + 36664828200*PolyGamma[1, a]^5*
      PolyGamma[3, a]*PolyGamma[5, a] + 4655851200*PolyGamma[0, a]^7*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[5, a] + 
     97772875200*PolyGamma[0, a]^5*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[5, a] + 488864376000*PolyGamma[0, a]^3*
      PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[5, a] + 
     488864376000*PolyGamma[0, a]*PolyGamma[1, a]^3*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[5, a] + 81477396000*PolyGamma[0, a]^4*
      PolyGamma[2, a]^2*PolyGamma[3, a]*PolyGamma[5, a] + 
     488864376000*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[2, a]^2*
      PolyGamma[3, a]*PolyGamma[5, a] + 244432188000*PolyGamma[1, a]^2*
      PolyGamma[2, a]^2*PolyGamma[3, a]*PolyGamma[5, a] + 
     108636528000*PolyGamma[0, a]*PolyGamma[2, a]^3*PolyGamma[3, a]*
      PolyGamma[5, a] + 4073869800*PolyGamma[0, a]^6*PolyGamma[3, a]^2*
      PolyGamma[5, a] + 61108047000*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[3, a]^2*PolyGamma[5, a] + 183324141000*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[3, a]^2*PolyGamma[5, a] + 
     61108047000*PolyGamma[1, a]^3*PolyGamma[3, a]^2*PolyGamma[5, a] + 
     81477396000*PolyGamma[0, a]^3*PolyGamma[2, a]*PolyGamma[3, a]^2*
      PolyGamma[5, a] + 244432188000*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]^2*PolyGamma[5, a] + 
     40738698000*PolyGamma[2, a]^2*PolyGamma[3, a]^2*PolyGamma[5, a] + 
     20369349000*PolyGamma[0, a]^2*PolyGamma[3, a]^3*PolyGamma[5, a] + 
     20369349000*PolyGamma[1, a]*PolyGamma[3, a]^3*PolyGamma[5, a] + 
     77597520*PolyGamma[0, a]^9*PolyGamma[4, a]*PolyGamma[5, a] + 
     2793510720*PolyGamma[0, a]^7*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[5, a] + 29331862560*PolyGamma[0, a]^5*PolyGamma[1, a]^2*
      PolyGamma[4, a]*PolyGamma[5, a] + 97772875200*PolyGamma[0, a]^3*
      PolyGamma[1, a]^3*PolyGamma[4, a]*PolyGamma[5, a] + 
     73329656400*PolyGamma[0, a]*PolyGamma[1, a]^4*PolyGamma[4, a]*
      PolyGamma[5, a] + 6518191680*PolyGamma[0, a]^6*PolyGamma[2, a]*
      PolyGamma[4, a]*PolyGamma[5, a] + 97772875200*PolyGamma[0, a]^4*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[5, a] + 
     293318625600*PolyGamma[0, a]^2*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[4, a]*PolyGamma[5, a] + 97772875200*PolyGamma[1, a]^3*
      PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[5, a] + 
     65181916800*PolyGamma[0, a]^3*PolyGamma[2, a]^2*PolyGamma[4, a]*
      PolyGamma[5, a] + 195545750400*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[4, a]*PolyGamma[5, a] + 
     21727305600*PolyGamma[2, a]^3*PolyGamma[4, a]*PolyGamma[5, a] + 
     9777287520*PolyGamma[0, a]^5*PolyGamma[3, a]*PolyGamma[4, a]*
      PolyGamma[5, a] + 97772875200*PolyGamma[0, a]^3*PolyGamma[1, a]*
      PolyGamma[3, a]*PolyGamma[4, a]*PolyGamma[5, a] + 
     146659312800*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[3, a]*
      PolyGamma[4, a]*PolyGamma[5, a] + 97772875200*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a]*PolyGamma[5, a] + 
     97772875200*PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[4, a]*PolyGamma[5, a] + 24443218800*PolyGamma[0, a]*
      PolyGamma[3, a]^2*PolyGamma[4, a]*PolyGamma[5, a] + 
     4888643760*PolyGamma[0, a]^4*PolyGamma[4, a]^2*PolyGamma[5, a] + 
     29331862560*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[4, a]^2*
      PolyGamma[5, a] + 14665931280*PolyGamma[1, a]^2*PolyGamma[4, a]^2*
      PolyGamma[5, a] + 19554575040*PolyGamma[0, a]*PolyGamma[2, a]*
      PolyGamma[4, a]^2*PolyGamma[5, a] + 4888643760*PolyGamma[3, a]*
      PolyGamma[4, a]^2*PolyGamma[5, a] + 58198140*PolyGamma[0, a]^8*
      PolyGamma[5, a]^2 + 1629547920*PolyGamma[0, a]^6*PolyGamma[1, a]*
      PolyGamma[5, a]^2 + 12221609400*PolyGamma[0, a]^4*PolyGamma[1, a]^2*
      PolyGamma[5, a]^2 + 24443218800*PolyGamma[0, a]^2*PolyGamma[1, a]^3*
      PolyGamma[5, a]^2 + 6110804700*PolyGamma[1, a]^4*PolyGamma[5, a]^2 + 
     3259095840*PolyGamma[0, a]^5*PolyGamma[2, a]*PolyGamma[5, a]^2 + 
     32590958400*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[5, a]^2 + 48886437600*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[5, a]^2 + 16295479200*PolyGamma[0, a]^2*
      PolyGamma[2, a]^2*PolyGamma[5, a]^2 + 16295479200*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[5, a]^2 + 4073869800*PolyGamma[0, a]^4*
      PolyGamma[3, a]*PolyGamma[5, a]^2 + 24443218800*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[5, a]^2 + 
     12221609400*PolyGamma[1, a]^2*PolyGamma[3, a]*PolyGamma[5, a]^2 + 
     16295479200*PolyGamma[0, a]*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[5, a]^2 + 2036934900*PolyGamma[3, a]^2*PolyGamma[5, a]^2 + 
     3259095840*PolyGamma[0, a]^3*PolyGamma[4, a]*PolyGamma[5, a]^2 + 
     9777287520*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[5, a]^2 + 3259095840*PolyGamma[2, a]*PolyGamma[4, a]*
      PolyGamma[5, a]^2 + 543182640*PolyGamma[0, a]^2*PolyGamma[5, a]^3 + 
     543182640*PolyGamma[1, a]*PolyGamma[5, a]^3 + 77520*PolyGamma[0, a]^13*
      PolyGamma[6, a] + 6046560*PolyGamma[0, a]^11*PolyGamma[1, a]*
      PolyGamma[6, a] + 166280400*PolyGamma[0, a]^9*PolyGamma[1, a]^2*
      PolyGamma[6, a] + 1995364800*PolyGamma[0, a]^7*PolyGamma[1, a]^3*
      PolyGamma[6, a] + 10475665200*PolyGamma[0, a]^5*PolyGamma[1, a]^4*
      PolyGamma[6, a] + 20951330400*PolyGamma[0, a]^3*PolyGamma[1, a]^5*
      PolyGamma[6, a] + 10475665200*PolyGamma[0, a]*PolyGamma[1, a]^6*
      PolyGamma[6, a] + 22170720*PolyGamma[0, a]^10*PolyGamma[2, a]*
      PolyGamma[6, a] + 997682400*PolyGamma[0, a]^8*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[6, a] + 13967553600*PolyGamma[0, a]^6*
      PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[6, a] + 
     69837768000*PolyGamma[0, a]^4*PolyGamma[1, a]^3*PolyGamma[2, a]*
      PolyGamma[6, a] + 104756652000*PolyGamma[0, a]^2*PolyGamma[1, a]^4*
      PolyGamma[2, a]*PolyGamma[6, a] + 20951330400*PolyGamma[1, a]^5*
      PolyGamma[2, a]*PolyGamma[6, a] + 1330243200*PolyGamma[0, a]^7*
      PolyGamma[2, a]^2*PolyGamma[6, a] + 27935107200*PolyGamma[0, a]^5*
      PolyGamma[1, a]*PolyGamma[2, a]^2*PolyGamma[6, a] + 
     139675536000*PolyGamma[0, a]^3*PolyGamma[1, a]^2*PolyGamma[2, a]^2*
      PolyGamma[6, a] + 139675536000*PolyGamma[0, a]*PolyGamma[1, a]^3*
      PolyGamma[2, a]^2*PolyGamma[6, a] + 15519504000*PolyGamma[0, a]^4*
      PolyGamma[2, a]^3*PolyGamma[6, a] + 93117024000*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[2, a]^3*PolyGamma[6, a] + 
     46558512000*PolyGamma[1, a]^2*PolyGamma[2, a]^3*PolyGamma[6, a] + 
     15519504000*PolyGamma[0, a]*PolyGamma[2, a]^4*PolyGamma[6, a] + 
     55426800*PolyGamma[0, a]^9*PolyGamma[3, a]*PolyGamma[6, a] + 
     1995364800*PolyGamma[0, a]^7*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[6, a] + 20951330400*PolyGamma[0, a]^5*PolyGamma[1, a]^2*
      PolyGamma[3, a]*PolyGamma[6, a] + 69837768000*PolyGamma[0, a]^3*
      PolyGamma[1, a]^3*PolyGamma[3, a]*PolyGamma[6, a] + 
     52378326000*PolyGamma[0, a]*PolyGamma[1, a]^4*PolyGamma[3, a]*
      PolyGamma[6, a] + 4655851200*PolyGamma[0, a]^6*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[6, a] + 69837768000*PolyGamma[0, a]^4*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[6, a] + 
     209513304000*PolyGamma[0, a]^2*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[6, a] + 69837768000*PolyGamma[1, a]^3*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[6, a] + 
     46558512000*PolyGamma[0, a]^3*PolyGamma[2, a]^2*PolyGamma[3, a]*
      PolyGamma[6, a] + 139675536000*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[3, a]*PolyGamma[6, a] + 
     15519504000*PolyGamma[2, a]^3*PolyGamma[3, a]*PolyGamma[6, a] + 
     3491888400*PolyGamma[0, a]^5*PolyGamma[3, a]^2*PolyGamma[6, a] + 
     34918884000*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[3, a]^2*
      PolyGamma[6, a] + 52378326000*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[3, a]^2*PolyGamma[6, a] + 34918884000*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[3, a]^2*PolyGamma[6, a] + 
     34918884000*PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[3, a]^2*
      PolyGamma[6, a] + 5819814000*PolyGamma[0, a]*PolyGamma[3, a]^3*
      PolyGamma[6, a] + 99768240*PolyGamma[0, a]^8*PolyGamma[4, a]*
      PolyGamma[6, a] + 2793510720*PolyGamma[0, a]^6*PolyGamma[1, a]*
      PolyGamma[4, a]*PolyGamma[6, a] + 20951330400*PolyGamma[0, a]^4*
      PolyGamma[1, a]^2*PolyGamma[4, a]*PolyGamma[6, a] + 
     41902660800*PolyGamma[0, a]^2*PolyGamma[1, a]^3*PolyGamma[4, a]*
      PolyGamma[6, a] + 10475665200*PolyGamma[1, a]^4*PolyGamma[4, a]*
      PolyGamma[6, a] + 5587021440*PolyGamma[0, a]^5*PolyGamma[2, a]*
      PolyGamma[4, a]*PolyGamma[6, a] + 55870214400*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[6, a] + 
     83805321600*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[4, a]*PolyGamma[6, a] + 27935107200*PolyGamma[0, a]^2*
      PolyGamma[2, a]^2*PolyGamma[4, a]*PolyGamma[6, a] + 
     27935107200*PolyGamma[1, a]*PolyGamma[2, a]^2*PolyGamma[4, a]*
      PolyGamma[6, a] + 6983776800*PolyGamma[0, a]^4*PolyGamma[3, a]*
      PolyGamma[4, a]*PolyGamma[6, a] + 41902660800*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[4, a]*PolyGamma[6, a] + 
     20951330400*PolyGamma[1, a]^2*PolyGamma[3, a]*PolyGamma[4, a]*
      PolyGamma[6, a] + 27935107200*PolyGamma[0, a]*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[4, a]*PolyGamma[6, a] + 
     3491888400*PolyGamma[3, a]^2*PolyGamma[4, a]*PolyGamma[6, a] + 
     2793510720*PolyGamma[0, a]^3*PolyGamma[4, a]^2*PolyGamma[6, a] + 
     8380532160*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[4, a]^2*
      PolyGamma[6, a] + 2793510720*PolyGamma[2, a]*PolyGamma[4, a]^2*
      PolyGamma[6, a] + 133024320*PolyGamma[0, a]^7*PolyGamma[5, a]*
      PolyGamma[6, a] + 2793510720*PolyGamma[0, a]^5*PolyGamma[1, a]*
      PolyGamma[5, a]*PolyGamma[6, a] + 13967553600*PolyGamma[0, a]^3*
      PolyGamma[1, a]^2*PolyGamma[5, a]*PolyGamma[6, a] + 
     13967553600*PolyGamma[0, a]*PolyGamma[1, a]^3*PolyGamma[5, a]*
      PolyGamma[6, a] + 4655851200*PolyGamma[0, a]^4*PolyGamma[2, a]*
      PolyGamma[5, a]*PolyGamma[6, a] + 27935107200*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[5, a]*PolyGamma[6, a] + 
     13967553600*PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[5, a]*
      PolyGamma[6, a] + 9311702400*PolyGamma[0, a]*PolyGamma[2, a]^2*
      PolyGamma[5, a]*PolyGamma[6, a] + 4655851200*PolyGamma[0, a]^3*
      PolyGamma[3, a]*PolyGamma[5, a]*PolyGamma[6, a] + 
     13967553600*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[5, a]*PolyGamma[6, a] + 4655851200*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[5, a]*PolyGamma[6, a] + 
     2793510720*PolyGamma[0, a]^2*PolyGamma[4, a]*PolyGamma[5, a]*
      PolyGamma[6, a] + 2793510720*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[5, a]*PolyGamma[6, a] + 465585120*PolyGamma[0, a]*
      PolyGamma[5, a]^2*PolyGamma[6, a] + 66512160*PolyGamma[0, a]^6*
      PolyGamma[6, a]^2 + 997682400*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[6, a]^2 + 2993047200*PolyGamma[0, a]^2*PolyGamma[1, a]^2*
      PolyGamma[6, a]^2 + 997682400*PolyGamma[1, a]^3*PolyGamma[6, a]^2 + 
     1330243200*PolyGamma[0, a]^3*PolyGamma[2, a]*PolyGamma[6, a]^2 + 
     3990729600*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[6, a]^2 + 665121600*PolyGamma[2, a]^2*PolyGamma[6, a]^2 + 
     997682400*PolyGamma[0, a]^2*PolyGamma[3, a]*PolyGamma[6, a]^2 + 
     997682400*PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[6, a]^2 + 
     399072960*PolyGamma[0, a]*PolyGamma[4, a]*PolyGamma[6, a]^2 + 
     66512160*PolyGamma[5, a]*PolyGamma[6, a]^2 + 125970*PolyGamma[0, a]^12*
      PolyGamma[7, a] + 8314020*PolyGamma[0, a]^10*PolyGamma[1, a]*
      PolyGamma[7, a] + 187065450*PolyGamma[0, a]^8*PolyGamma[1, a]^2*
      PolyGamma[7, a] + 1745944200*PolyGamma[0, a]^6*PolyGamma[1, a]^3*
      PolyGamma[7, a] + 6547290750*PolyGamma[0, a]^4*PolyGamma[1, a]^4*
      PolyGamma[7, a] + 7856748900*PolyGamma[0, a]^2*PolyGamma[1, a]^5*
      PolyGamma[7, a] + 1309458150*PolyGamma[1, a]^6*PolyGamma[7, a] + 
     27713400*PolyGamma[0, a]^9*PolyGamma[2, a]*PolyGamma[7, a] + 
     997682400*PolyGamma[0, a]^7*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[7, a] + 10475665200*PolyGamma[0, a]^5*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[7, a] + 34918884000*PolyGamma[0, a]^3*
      PolyGamma[1, a]^3*PolyGamma[2, a]*PolyGamma[7, a] + 
     26189163000*PolyGamma[0, a]*PolyGamma[1, a]^4*PolyGamma[2, a]*
      PolyGamma[7, a] + 1163962800*PolyGamma[0, a]^6*PolyGamma[2, a]^2*
      PolyGamma[7, a] + 17459442000*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[7, a] + 52378326000*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[2, a]^2*PolyGamma[7, a] + 
     17459442000*PolyGamma[1, a]^3*PolyGamma[2, a]^2*PolyGamma[7, a] + 
     7759752000*PolyGamma[0, a]^3*PolyGamma[2, a]^3*PolyGamma[7, a] + 
     23279256000*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]^3*
      PolyGamma[7, a] + 1939938000*PolyGamma[2, a]^4*PolyGamma[7, a] + 
     62355150*PolyGamma[0, a]^8*PolyGamma[3, a]*PolyGamma[7, a] + 
     1745944200*PolyGamma[0, a]^6*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[7, a] + 13094581500*PolyGamma[0, a]^4*PolyGamma[1, a]^2*
      PolyGamma[3, a]*PolyGamma[7, a] + 26189163000*PolyGamma[0, a]^2*
      PolyGamma[1, a]^3*PolyGamma[3, a]*PolyGamma[7, a] + 
     6547290750*PolyGamma[1, a]^4*PolyGamma[3, a]*PolyGamma[7, a] + 
     3491888400*PolyGamma[0, a]^5*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[7, a] + 34918884000*PolyGamma[0, a]^3*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[7, a] + 
     52378326000*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[7, a] + 17459442000*PolyGamma[0, a]^2*
      PolyGamma[2, a]^2*PolyGamma[3, a]*PolyGamma[7, a] + 
     17459442000*PolyGamma[1, a]*PolyGamma[2, a]^2*PolyGamma[3, a]*
      PolyGamma[7, a] + 2182430250*PolyGamma[0, a]^4*PolyGamma[3, a]^2*
      PolyGamma[7, a] + 13094581500*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[3, a]^2*PolyGamma[7, a] + 6547290750*PolyGamma[1, a]^2*
      PolyGamma[3, a]^2*PolyGamma[7, a] + 8729721000*PolyGamma[0, a]*
      PolyGamma[2, a]*PolyGamma[3, a]^2*PolyGamma[7, a] + 
     727476750*PolyGamma[3, a]^3*PolyGamma[7, a] + 99768240*PolyGamma[0, a]^7*
      PolyGamma[4, a]*PolyGamma[7, a] + 2095133040*PolyGamma[0, a]^5*
      PolyGamma[1, a]*PolyGamma[4, a]*PolyGamma[7, a] + 
     10475665200*PolyGamma[0, a]^3*PolyGamma[1, a]^2*PolyGamma[4, a]*
      PolyGamma[7, a] + 10475665200*PolyGamma[0, a]*PolyGamma[1, a]^3*
      PolyGamma[4, a]*PolyGamma[7, a] + 3491888400*PolyGamma[0, a]^4*
      PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[7, a] + 
     20951330400*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[4, a]*PolyGamma[7, a] + 10475665200*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[7, a] + 
     6983776800*PolyGamma[0, a]*PolyGamma[2, a]^2*PolyGamma[4, a]*
      PolyGamma[7, a] + 3491888400*PolyGamma[0, a]^3*PolyGamma[3, a]*
      PolyGamma[4, a]*PolyGamma[7, a] + 10475665200*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[4, a]*PolyGamma[7, a] + 
     3491888400*PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[4, a]*
      PolyGamma[7, a] + 1047566520*PolyGamma[0, a]^2*PolyGamma[4, a]^2*
      PolyGamma[7, a] + 1047566520*PolyGamma[1, a]*PolyGamma[4, a]^2*
      PolyGamma[7, a] + 116396280*PolyGamma[0, a]^6*PolyGamma[5, a]*
      PolyGamma[7, a] + 1745944200*PolyGamma[0, a]^4*PolyGamma[1, a]*
      PolyGamma[5, a]*PolyGamma[7, a] + 5237832600*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[5, a]*PolyGamma[7, a] + 
     1745944200*PolyGamma[1, a]^3*PolyGamma[5, a]*PolyGamma[7, a] + 
     2327925600*PolyGamma[0, a]^3*PolyGamma[2, a]*PolyGamma[5, a]*
      PolyGamma[7, a] + 6983776800*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[5, a]*PolyGamma[7, a] + 
     1163962800*PolyGamma[2, a]^2*PolyGamma[5, a]*PolyGamma[7, a] + 
     1745944200*PolyGamma[0, a]^2*PolyGamma[3, a]*PolyGamma[5, a]*
      PolyGamma[7, a] + 1745944200*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[5, a]*PolyGamma[7, a] + 698377680*PolyGamma[0, a]*
      PolyGamma[4, a]*PolyGamma[5, a]*PolyGamma[7, a] + 
     58198140*PolyGamma[5, a]^2*PolyGamma[7, a] + 99768240*PolyGamma[0, a]^5*
      PolyGamma[6, a]*PolyGamma[7, a] + 997682400*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[6, a]*PolyGamma[7, a] + 
     1496523600*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[6, a]*
      PolyGamma[7, a] + 997682400*PolyGamma[0, a]^2*PolyGamma[2, a]*
      PolyGamma[6, a]*PolyGamma[7, a] + 997682400*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[6, a]*PolyGamma[7, a] + 
     498841200*PolyGamma[0, a]*PolyGamma[3, a]*PolyGamma[6, a]*
      PolyGamma[7, a] + 99768240*PolyGamma[4, a]*PolyGamma[6, a]*
      PolyGamma[7, a] + 31177575*PolyGamma[0, a]^4*PolyGamma[7, a]^2 + 
     187065450*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[7, a]^2 + 
     93532725*PolyGamma[1, a]^2*PolyGamma[7, a]^2 + 
     124710300*PolyGamma[0, a]*PolyGamma[2, a]*PolyGamma[7, a]^2 + 
     31177575*PolyGamma[3, a]*PolyGamma[7, a]^2 + 167960*PolyGamma[0, a]^11*
      PolyGamma[8, a] + 9237800*PolyGamma[0, a]^9*PolyGamma[1, a]*
      PolyGamma[8, a] + 166280400*PolyGamma[0, a]^7*PolyGamma[1, a]^2*
      PolyGamma[8, a] + 1163962800*PolyGamma[0, a]^5*PolyGamma[1, a]^3*
      PolyGamma[8, a] + 2909907000*PolyGamma[0, a]^3*PolyGamma[1, a]^4*
      PolyGamma[8, a] + 1745944200*PolyGamma[0, a]*PolyGamma[1, a]^5*
      PolyGamma[8, a] + 27713400*PolyGamma[0, a]^8*PolyGamma[2, a]*
      PolyGamma[8, a] + 775975200*PolyGamma[0, a]^6*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[8, a] + 5819814000*PolyGamma[0, a]^4*
      PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[8, a] + 
     11639628000*PolyGamma[0, a]^2*PolyGamma[1, a]^3*PolyGamma[2, a]*
      PolyGamma[8, a] + 2909907000*PolyGamma[1, a]^4*PolyGamma[2, a]*
      PolyGamma[8, a] + 775975200*PolyGamma[0, a]^5*PolyGamma[2, a]^2*
      PolyGamma[8, a] + 7759752000*PolyGamma[0, a]^3*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[8, a] + 11639628000*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[2, a]^2*PolyGamma[8, a] + 
     2586584000*PolyGamma[0, a]^2*PolyGamma[2, a]^3*PolyGamma[8, a] + 
     2586584000*PolyGamma[1, a]*PolyGamma[2, a]^3*PolyGamma[8, a] + 
     55426800*PolyGamma[0, a]^7*PolyGamma[3, a]*PolyGamma[8, a] + 
     1163962800*PolyGamma[0, a]^5*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[8, a] + 5819814000*PolyGamma[0, a]^3*PolyGamma[1, a]^2*
      PolyGamma[3, a]*PolyGamma[8, a] + 5819814000*PolyGamma[0, a]*
      PolyGamma[1, a]^3*PolyGamma[3, a]*PolyGamma[8, a] + 
     1939938000*PolyGamma[0, a]^4*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[8, a] + 11639628000*PolyGamma[0, a]^2*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[8, a] + 
     5819814000*PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[8, a] + 3879876000*PolyGamma[0, a]*PolyGamma[2, a]^2*
      PolyGamma[3, a]*PolyGamma[8, a] + 969969000*PolyGamma[0, a]^3*
      PolyGamma[3, a]^2*PolyGamma[8, a] + 2909907000*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[3, a]^2*PolyGamma[8, a] + 
     969969000*PolyGamma[2, a]*PolyGamma[3, a]^2*PolyGamma[8, a] + 
     77597520*PolyGamma[0, a]^6*PolyGamma[4, a]*PolyGamma[8, a] + 
     1163962800*PolyGamma[0, a]^4*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[8, a] + 3491888400*PolyGamma[0, a]^2*PolyGamma[1, a]^2*
      PolyGamma[4, a]*PolyGamma[8, a] + 1163962800*PolyGamma[1, a]^3*
      PolyGamma[4, a]*PolyGamma[8, a] + 1551950400*PolyGamma[0, a]^3*
      PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[8, a] + 
     4655851200*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[4, a]*PolyGamma[8, a] + 775975200*PolyGamma[2, a]^2*
      PolyGamma[4, a]*PolyGamma[8, a] + 1163962800*PolyGamma[0, a]^2*
      PolyGamma[3, a]*PolyGamma[4, a]*PolyGamma[8, a] + 
     1163962800*PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[4, a]*
      PolyGamma[8, a] + 232792560*PolyGamma[0, a]*PolyGamma[4, a]^2*
      PolyGamma[8, a] + 77597520*PolyGamma[0, a]^5*PolyGamma[5, a]*
      PolyGamma[8, a] + 775975200*PolyGamma[0, a]^3*PolyGamma[1, a]*
      PolyGamma[5, a]*PolyGamma[8, a] + 1163962800*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[5, a]*PolyGamma[8, a] + 
     775975200*PolyGamma[0, a]^2*PolyGamma[2, a]*PolyGamma[5, a]*
      PolyGamma[8, a] + 775975200*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[5, a]*PolyGamma[8, a] + 387987600*PolyGamma[0, a]*
      PolyGamma[3, a]*PolyGamma[5, a]*PolyGamma[8, a] + 
     77597520*PolyGamma[4, a]*PolyGamma[5, a]*PolyGamma[8, a] + 
     55426800*PolyGamma[0, a]^4*PolyGamma[6, a]*PolyGamma[8, a] + 
     332560800*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[6, a]*
      PolyGamma[8, a] + 166280400*PolyGamma[1, a]^2*PolyGamma[6, a]*
      PolyGamma[8, a] + 221707200*PolyGamma[0, a]*PolyGamma[2, a]*
      PolyGamma[6, a]*PolyGamma[8, a] + 55426800*PolyGamma[3, a]*
      PolyGamma[6, a]*PolyGamma[8, a] + 27713400*PolyGamma[0, a]^3*
      PolyGamma[7, a]*PolyGamma[8, a] + 83140200*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[7, a]*PolyGamma[8, a] + 
     27713400*PolyGamma[2, a]*PolyGamma[7, a]*PolyGamma[8, a] + 
     4618900*PolyGamma[0, a]^2*PolyGamma[8, a]^2 + 4618900*PolyGamma[1, a]*
      PolyGamma[8, a]^2 + 184756*PolyGamma[0, a]^10*PolyGamma[9, a] + 
     8314020*PolyGamma[0, a]^8*PolyGamma[1, a]*PolyGamma[9, a] + 
     116396280*PolyGamma[0, a]^6*PolyGamma[1, a]^2*PolyGamma[9, a] + 
     581981400*PolyGamma[0, a]^4*PolyGamma[1, a]^3*PolyGamma[9, a] + 
     872972100*PolyGamma[0, a]^2*PolyGamma[1, a]^4*PolyGamma[9, a] + 
     174594420*PolyGamma[1, a]^5*PolyGamma[9, a] + 22170720*PolyGamma[0, a]^7*
      PolyGamma[2, a]*PolyGamma[9, a] + 465585120*PolyGamma[0, a]^5*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[9, a] + 
     2327925600*PolyGamma[0, a]^3*PolyGamma[1, a]^2*PolyGamma[2, a]*
      PolyGamma[9, a] + 2327925600*PolyGamma[0, a]*PolyGamma[1, a]^3*
      PolyGamma[2, a]*PolyGamma[9, a] + 387987600*PolyGamma[0, a]^4*
      PolyGamma[2, a]^2*PolyGamma[9, a] + 2327925600*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[2, a]^2*PolyGamma[9, a] + 
     1163962800*PolyGamma[1, a]^2*PolyGamma[2, a]^2*PolyGamma[9, a] + 
     517316800*PolyGamma[0, a]*PolyGamma[2, a]^3*PolyGamma[9, a] + 
     38798760*PolyGamma[0, a]^6*PolyGamma[3, a]*PolyGamma[9, a] + 
     581981400*PolyGamma[0, a]^4*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[9, a] + 1745944200*PolyGamma[0, a]^2*PolyGamma[1, a]^2*
      PolyGamma[3, a]*PolyGamma[9, a] + 581981400*PolyGamma[1, a]^3*
      PolyGamma[3, a]*PolyGamma[9, a] + 775975200*PolyGamma[0, a]^3*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[9, a] + 
     2327925600*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[9, a] + 387987600*PolyGamma[2, a]^2*
      PolyGamma[3, a]*PolyGamma[9, a] + 290990700*PolyGamma[0, a]^2*
      PolyGamma[3, a]^2*PolyGamma[9, a] + 290990700*PolyGamma[1, a]*
      PolyGamma[3, a]^2*PolyGamma[9, a] + 46558512*PolyGamma[0, a]^5*
      PolyGamma[4, a]*PolyGamma[9, a] + 465585120*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[4, a]*PolyGamma[9, a] + 
     698377680*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[4, a]*
      PolyGamma[9, a] + 465585120*PolyGamma[0, a]^2*PolyGamma[2, a]*
      PolyGamma[4, a]*PolyGamma[9, a] + 465585120*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[4, a]*PolyGamma[9, a] + 
     232792560*PolyGamma[0, a]*PolyGamma[3, a]*PolyGamma[4, a]*
      PolyGamma[9, a] + 23279256*PolyGamma[4, a]^2*PolyGamma[9, a] + 
     38798760*PolyGamma[0, a]^4*PolyGamma[5, a]*PolyGamma[9, a] + 
     232792560*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[5, a]*
      PolyGamma[9, a] + 116396280*PolyGamma[1, a]^2*PolyGamma[5, a]*
      PolyGamma[9, a] + 155195040*PolyGamma[0, a]*PolyGamma[2, a]*
      PolyGamma[5, a]*PolyGamma[9, a] + 38798760*PolyGamma[3, a]*
      PolyGamma[5, a]*PolyGamma[9, a] + 22170720*PolyGamma[0, a]^3*
      PolyGamma[6, a]*PolyGamma[9, a] + 66512160*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[6, a]*PolyGamma[9, a] + 
     22170720*PolyGamma[2, a]*PolyGamma[6, a]*PolyGamma[9, a] + 
     8314020*PolyGamma[0, a]^2*PolyGamma[7, a]*PolyGamma[9, a] + 
     8314020*PolyGamma[1, a]*PolyGamma[7, a]*PolyGamma[9, a] + 
     1847560*PolyGamma[0, a]*PolyGamma[8, a]*PolyGamma[9, a] + 
     92378*PolyGamma[9, a]^2 + 167960*PolyGamma[0, a]^9*PolyGamma[10, a] + 
     6046560*PolyGamma[0, a]^7*PolyGamma[1, a]*PolyGamma[10, a] + 
     63488880*PolyGamma[0, a]^5*PolyGamma[1, a]^2*PolyGamma[10, a] + 
     211629600*PolyGamma[0, a]^3*PolyGamma[1, a]^3*PolyGamma[10, a] + 
     158722200*PolyGamma[0, a]*PolyGamma[1, a]^4*PolyGamma[10, a] + 
     14108640*PolyGamma[0, a]^6*PolyGamma[2, a]*PolyGamma[10, a] + 
     211629600*PolyGamma[0, a]^4*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[10, a] + 634888800*PolyGamma[0, a]^2*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[10, a] + 211629600*PolyGamma[1, a]^3*
      PolyGamma[2, a]*PolyGamma[10, a] + 141086400*PolyGamma[0, a]^3*
      PolyGamma[2, a]^2*PolyGamma[10, a] + 423259200*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[2, a]^2*PolyGamma[10, a] + 
     47028800*PolyGamma[2, a]^3*PolyGamma[10, a] + 21162960*PolyGamma[0, a]^5*
      PolyGamma[3, a]*PolyGamma[10, a] + 211629600*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[10, a] + 
     317444400*PolyGamma[0, a]*PolyGamma[1, a]^2*PolyGamma[3, a]*
      PolyGamma[10, a] + 211629600*PolyGamma[0, a]^2*PolyGamma[2, a]*
      PolyGamma[3, a]*PolyGamma[10, a] + 211629600*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[3, a]*PolyGamma[10, a] + 
     52907400*PolyGamma[0, a]*PolyGamma[3, a]^2*PolyGamma[10, a] + 
     21162960*PolyGamma[0, a]^4*PolyGamma[4, a]*PolyGamma[10, a] + 
     126977760*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[10, a] + 63488880*PolyGamma[1, a]^2*PolyGamma[4, a]*
      PolyGamma[10, a] + 84651840*PolyGamma[0, a]*PolyGamma[2, a]*
      PolyGamma[4, a]*PolyGamma[10, a] + 21162960*PolyGamma[3, a]*
      PolyGamma[4, a]*PolyGamma[10, a] + 14108640*PolyGamma[0, a]^3*
      PolyGamma[5, a]*PolyGamma[10, a] + 42325920*PolyGamma[0, a]*
      PolyGamma[1, a]*PolyGamma[5, a]*PolyGamma[10, a] + 
     14108640*PolyGamma[2, a]*PolyGamma[5, a]*PolyGamma[10, a] + 
     6046560*PolyGamma[0, a]^2*PolyGamma[6, a]*PolyGamma[10, a] + 
     6046560*PolyGamma[1, a]*PolyGamma[6, a]*PolyGamma[10, a] + 
     1511640*PolyGamma[0, a]*PolyGamma[7, a]*PolyGamma[10, a] + 
     167960*PolyGamma[8, a]*PolyGamma[10, a] + 125970*PolyGamma[0, a]^8*
      PolyGamma[11, a] + 3527160*PolyGamma[0, a]^6*PolyGamma[1, a]*
      PolyGamma[11, a] + 26453700*PolyGamma[0, a]^4*PolyGamma[1, a]^2*
      PolyGamma[11, a] + 52907400*PolyGamma[0, a]^2*PolyGamma[1, a]^3*
      PolyGamma[11, a] + 13226850*PolyGamma[1, a]^4*PolyGamma[11, a] + 
     7054320*PolyGamma[0, a]^5*PolyGamma[2, a]*PolyGamma[11, a] + 
     70543200*PolyGamma[0, a]^3*PolyGamma[1, a]*PolyGamma[2, a]*
      PolyGamma[11, a] + 105814800*PolyGamma[0, a]*PolyGamma[1, a]^2*
      PolyGamma[2, a]*PolyGamma[11, a] + 35271600*PolyGamma[0, a]^2*
      PolyGamma[2, a]^2*PolyGamma[11, a] + 35271600*PolyGamma[1, a]*
      PolyGamma[2, a]^2*PolyGamma[11, a] + 8817900*PolyGamma[0, a]^4*
      PolyGamma[3, a]*PolyGamma[11, a] + 52907400*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[3, a]*PolyGamma[11, a] + 
     26453700*PolyGamma[1, a]^2*PolyGamma[3, a]*PolyGamma[11, a] + 
     35271600*PolyGamma[0, a]*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[11, a] + 4408950*PolyGamma[3, a]^2*PolyGamma[11, a] + 
     7054320*PolyGamma[0, a]^3*PolyGamma[4, a]*PolyGamma[11, a] + 
     21162960*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[11, a] + 7054320*PolyGamma[2, a]*PolyGamma[4, a]*
      PolyGamma[11, a] + 3527160*PolyGamma[0, a]^2*PolyGamma[5, a]*
      PolyGamma[11, a] + 3527160*PolyGamma[1, a]*PolyGamma[5, a]*
      PolyGamma[11, a] + 1007760*PolyGamma[0, a]*PolyGamma[6, a]*
      PolyGamma[11, a] + 125970*PolyGamma[7, a]*PolyGamma[11, a] + 
     77520*PolyGamma[0, a]^7*PolyGamma[12, a] + 1627920*PolyGamma[0, a]^5*
      PolyGamma[1, a]*PolyGamma[12, a] + 8139600*PolyGamma[0, a]^3*
      PolyGamma[1, a]^2*PolyGamma[12, a] + 8139600*PolyGamma[0, a]*
      PolyGamma[1, a]^3*PolyGamma[12, a] + 2713200*PolyGamma[0, a]^4*
      PolyGamma[2, a]*PolyGamma[12, a] + 16279200*PolyGamma[0, a]^2*
      PolyGamma[1, a]*PolyGamma[2, a]*PolyGamma[12, a] + 
     8139600*PolyGamma[1, a]^2*PolyGamma[2, a]*PolyGamma[12, a] + 
     5426400*PolyGamma[0, a]*PolyGamma[2, a]^2*PolyGamma[12, a] + 
     2713200*PolyGamma[0, a]^3*PolyGamma[3, a]*PolyGamma[12, a] + 
     8139600*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[12, a] + 2713200*PolyGamma[2, a]*PolyGamma[3, a]*
      PolyGamma[12, a] + 1627920*PolyGamma[0, a]^2*PolyGamma[4, a]*
      PolyGamma[12, a] + 1627920*PolyGamma[1, a]*PolyGamma[4, a]*
      PolyGamma[12, a] + 542640*PolyGamma[0, a]*PolyGamma[5, a]*
      PolyGamma[12, a] + 77520*PolyGamma[6, a]*PolyGamma[12, a] + 
     38760*PolyGamma[0, a]^6*PolyGamma[13, a] + 581400*PolyGamma[0, a]^4*
      PolyGamma[1, a]*PolyGamma[13, a] + 1744200*PolyGamma[0, a]^2*
      PolyGamma[1, a]^2*PolyGamma[13, a] + 581400*PolyGamma[1, a]^3*
      PolyGamma[13, a] + 775200*PolyGamma[0, a]^3*PolyGamma[2, a]*
      PolyGamma[13, a] + 2325600*PolyGamma[0, a]*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[13, a] + 387600*PolyGamma[2, a]^2*
      PolyGamma[13, a] + 581400*PolyGamma[0, a]^2*PolyGamma[3, a]*
      PolyGamma[13, a] + 581400*PolyGamma[1, a]*PolyGamma[3, a]*
      PolyGamma[13, a] + 232560*PolyGamma[0, a]*PolyGamma[4, a]*
      PolyGamma[13, a] + 38760*PolyGamma[5, a]*PolyGamma[13, a] + 
     15504*PolyGamma[0, a]^5*PolyGamma[14, a] + 155040*PolyGamma[0, a]^3*
      PolyGamma[1, a]*PolyGamma[14, a] + 232560*PolyGamma[0, a]*
      PolyGamma[1, a]^2*PolyGamma[14, a] + 155040*PolyGamma[0, a]^2*
      PolyGamma[2, a]*PolyGamma[14, a] + 155040*PolyGamma[1, a]*
      PolyGamma[2, a]*PolyGamma[14, a] + 77520*PolyGamma[0, a]*
      PolyGamma[3, a]*PolyGamma[14, a] + 15504*PolyGamma[4, a]*
      PolyGamma[14, a] + 4845*PolyGamma[0, a]^4*PolyGamma[15, a] + 
     29070*PolyGamma[0, a]^2*PolyGamma[1, a]*PolyGamma[15, a] + 
     14535*PolyGamma[1, a]^2*PolyGamma[15, a] + 19380*PolyGamma[0, a]*
      PolyGamma[2, a]*PolyGamma[15, a] + 4845*PolyGamma[3, a]*
      PolyGamma[15, a] + 1140*PolyGamma[0, a]^3*PolyGamma[16, a] + 
     3420*PolyGamma[0, a]*PolyGamma[1, a]*PolyGamma[16, a] + 
     1140*PolyGamma[2, a]*PolyGamma[16, a] + 190*PolyGamma[0, a]^2*
      PolyGamma[17, a] + 190*PolyGamma[1, a]*PolyGamma[17, a] + 
     20*PolyGamma[0, a]*PolyGamma[18, a] + PolyGamma[19, a]

(******************************************************************************)

FUPolynomials[integrand_, momenta_, kinematics_] :=
Block[{denom= List @@ integrand, int, l = Length[momenta], m, j, q, f, u, vars},

  int = Sum[Global`x[i]*denom[[i]] /. Global`DS[k_, m_, _] -> k^2 - m^2,
    {i, Length[denom]}];
  m = Table[If[i != j, 1/2, 1]*
    Coefficient[int, momenta[[i]]*momenta[[j]]], {i, l}, {j, l}];
  j = int - momenta.m.momenta;
  q = Table[Expand[-1/2*Coefficient[j, momenta[[i]]]], {i, l}] ;
  j = Expand[j + 2*momenta.q] /. kinematics;
  u = Det[m];
  f = Expand[u*(q.Inverse[m].q - j)] /. kinematics;
  vars = DeleteCases[Variables[f], Global`x[_]];
  f = Collect[f, vars, Simplify];
  Return[{f, u, m, q}]]

(******************************************************************************)
 
a0[ms_, l_] := Gamma[l + ep - 2]/(Gamma[l]*ms^(l + ep - 2))

a0[ms_, l1_, l2_] := Gamma[l1 + l2 + ep - 2]*(Gamma[-l2 - ep + 2]/
      (Gamma[l1]*Gamma[2 - ep]*ms^(l1 + l2 + ep - 2)))

b0[ps_, l1_, l2_] := Gamma[2 - ep - l1]*Gamma[2 - ep - l2]*
     (Gamma[l1 + l2 + ep - 2]/(Gamma[l1]*Gamma[l2]*Gamma[4 - l1 - l2 - 2*ep]*
       (-ps)^(l1 + l2 + ep - 2)))

b0OS[ps_, l1_, l2_] := Gamma[l1 + l2 + ep - 2]*(Gamma[-2*l1 - l2 - 2*ep + 4]/
      (Gamma[l2]*Gamma[-l1 - l2 - 2*ep + 4]*ps^(l1 + l2 + ep - 2)))

c0[ps_, l1_, l2_, l3_] := Gamma[-l1 - l3 - ep + 2]*Gamma[-l2 - l3 - ep + 2]*
     (Gamma[l1 + l2 + l3 + ep - 2]/(Gamma[l1]*Gamma[l2]*
       Gamma[-l1 - l2 - l3 - 2*ep + 4]*(-ps)^(l1 + l2 + l3 + ep - 2)))

(******************************************************************************
 *                                                                            *
 * Return a list, where all the options are set, either as on the default     *
 * option list, or as specified by the user.                                  *
 *                                                                            *
 ******************************************************************************)

ParseOptions[f_, options___Rule] :=
Block[{pos},
  If[Length[pos = Position[{options}, First[#] -> _, 1, 1] ] === 0, #,
    {options}[[ Sequence @@ First[pos]]]] & /@ Options[f]]

End[]

EndPackage[]