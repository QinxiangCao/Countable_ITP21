Require Import Coq.micromega.Psatz.
Require Import Omega.
Require Import Coq.Lists.List.

(*********************************************************************)
(*                                                                   *)
(* Part A.                                                           *)
(*   Def "constr_type": the syntax of an inductive definition.       *)
(*   Tac "get_rect" t: fill the proof goal with t_rect.              *)
(*   Tac "gen_constrs" t t_rect: fill the proof goal with t's        *)
(*     constr_type.                                                  *)
(*                                                                   *)
(*********************************************************************)

Definition constr_type (arg: list (option Type)) (T: Type): Type :=
  (fix constr_type arg :=
    match arg with
    | nil => T
    | Some T0 :: arg0 => T0 -> constr_type arg0
    | None :: arg0 => T -> constr_type arg0
    end) arg.

Notation "'_[' arg , constr ']_'" :=
  (existT (fun arg0: list (option Type) => constr_type arg0 _) arg constr)
  (at level 20, no associativity).

Definition ConstrsType T: Type := list (sigT (fun arg => constr_type arg T)).

Ltac gen H :=
  let x := eval cbv zeta beta in ltac:(H) in exact x.

Module Test01.

Ltac foo :=
  assert (5 = 5) by reflexivity; exact 5.

Definition Five := ltac:(foo).

Print Five.

Definition Five' := ltac:(gen foo).

Print Five'.

End Test01.

Ltac get_head a :=
  match a with
  | ?a _ => get_head a
  | _ => constr:(a)
  end.

Ltac get_head' t a:=
  match t with
  | _ ?x => match a with
              | ?a0 x => constr:(a)
              | ?a0 _ => get_head' t a0
              | _ => constr:(a)
             end 
  | _ => get_head a
  end.

Ltac gen_ind_aux t :=
  let tac := (
    let x := fresh "x" in
    let H := fresh in
    assert (H: forall x: t, True) by (induction 1; exact I);
    exact H) in
  gen tac.

Ltac gen_ind t :=
  let tac := (
    let thm := eval hnf in ltac:(gen_ind_aux t) in
    let x := fresh "x" in
    let rect_type := fresh "rect_type" in
    evar (rect_type: Type);
    let H := fresh in
    assert (t -> rect_type) as H;
    [ intros x;
      let thm' := eval cbv beta in (thm x) in
      let rect := get_head' t thm' in
      exact rect | exact H]) in
  let rect' := eval hnf in ltac:(gen tac) in
  match rect' with
  | (fun _ => ?rect) => exact rect
  end.

Ltac gen_rect_aux t :=
  let tac := (
    let x := fresh "x" in
    let H := fresh in
    assert (H: forall x: t, Set * list t) by (induction 1; exact (bool, nil));
    exact H) in
  gen tac.

Ltac gen_rect t :=
  let tac := (
    let thm := eval hnf in ltac:(gen_rect_aux t) in
    let x := fresh "x" in
    let rect_type := fresh "rect_type" in
    evar (rect_type: Type);
    let H := fresh in
    assert (t -> rect_type) as H;
    [ intros x;
      let thm' := eval cbv beta in (thm x) in
      let rect := get_head' t thm' in
      exact rect | exact H]) in
  let rect' := eval hnf in ltac:(gen tac) in
  match rect' with
  | (fun _ => ?rect) => exact rect
  end.

Module Test02.

Inductive Nat :=
| SNat : bool -> Nat -> Nat
| ONat: Nat.

Definition P := ltac:(gen_rect Nat).

Print P.

End Test02.

Ltac analyze_rect_clause t P arg constr :=
  match goal with
  | |- forall (x: t) (H: P x), _ =>
         intros ? ?;
         analyze_rect_clause t P arg constr;
         let arg' := eval cbv delta [arg] in (None :: arg) in
         clear arg;
         set (arg := arg')
  | |- forall (x: ?A), _ =>
         intros ?;
         analyze_rect_clause t P arg constr;
         let arg' := eval cbv delta [arg] in (Some (A: Type) :: arg) in
         clear arg;
         set (arg := arg')
  | |- P ?a =>
         clear constr;
         let constr' := get_head' t a in
         set (constr := constr')
  end.

Ltac analyze_rect rect_type t P := idtac;
  match rect_type with
  | ?rect_clause_type -> ?rect_type0 =>
      let H := fresh in
      let arg_constr := fresh "arg_constr" in
      evar (arg_constr : sigT (fun arg => constr_type arg t));
      assert (False -> rect_clause_type);
        [ intros H;
          let arg := fresh "arg" in
          let constr := fresh "constr" in
          set (arg := @nil (option Type));
          set (constr := 0);
          analyze_rect_clause t P arg constr;
          let real_arg_constr := eval cbv delta [arg_constr] in arg_constr in
          unify
            real_arg_constr
            (@existT _ (fun arg => constr_type arg t) arg constr);
          inversion H
        | let arg_constr' := eval cbv delta [arg_constr] in arg_constr in
          refine (cons arg_constr' _);
          analyze_rect rect_type0 t P
        ]
  | _ =>
      idtac
  end.

Ltac gen_constrs t rect :=
  let tac := (
    let P := fresh "P" in
    let x := fresh "x" in
    set (P:= fun x: t => Type%type);
    match type of (rect P) with
    | ?rect_type =>
        analyze_rect rect_type t P;
        exact (@nil (sigT (fun arg => constr_type arg t)))
    end) in
  gen tac.
  
Module Test03.
Import Test02.

Definition constrs_Nat := ltac:(gen_constrs Nat Nat_rect).

Print constrs_Nat.

Inductive Tree :=
| TT3 : nat -> Tree -> Tree -> Tree -> Tree
| TT2 : Tree -> bool -> Tree -> Tree
| TT1 : Tree -> Tree
| TT0: Tree.

Definition ind_Tree := ltac:(gen_ind Tree).
Definition rect_Tree := ltac:(gen_rect Tree).
Definition constrs_Tree := ltac:(gen_constrs Tree rect_Tree).
Print ind_Tree.
Print rect_Tree.
Print constrs_Tree.

End Test03.

(*********************************************************************)
(*                                                                   *)
(* Part B.                                                           *)
(*   Def "rect_type" t constrs P: the type of (t_rect P).            *)
(*   Def "apply_rect_type": a parameterized way of filling t_rect's  *)
(*     arguments.                                                    *)
(*   Def "Sol1.rect_correct / Sol2.rect_correct": any parameterized  *)
(*     way of filling t_rect's argument will result in the expected  *)
(*     value calculated by the branch.                               *)
(*   Tac "apply_rect_correctness_gen": Prove Sol2.rect_correct.      *)
(*                                                                   *)
(*********************************************************************)

Definition rect_clause_type
             (arg: list (option Type))
             (T: Type)
             (P: T -> Type): constr_type arg T -> Type :=
  (fix rect_clause_type (arg: list (option Type)) : constr_type arg T -> Type :=
     match arg with
     | nil =>
         fun c => P c
     | Some T0 :: arg0 =>
         fun c => forall x0: T0, rect_clause_type arg0 (c x0)
     | None :: arg0 =>
         fun c => forall (x: T) (IH: P x), rect_clause_type arg0 (c x)
     end) arg.

Definition rect_type (T: Type) (constrs: ConstrsType T) (P: T -> Type): Type :=
  (fix rect_type constrs: Type :=
     match constrs with
     | nil =>
         forall x: T, P x
     | existT _ arg constr :: constrs0 =>
         rect_clause_type arg T P constr -> rect_type constrs0
     end) constrs.

Definition ParaType (T: Type) (P: ConstrsType T -> T -> Type): Type :=
  forall (constrs1: ConstrsType T) arg2 constr2 (constrs3: ConstrsType T),
     rect_clause_type
       arg2
       T
       (P (rev_append constrs1 (_[arg2, constr2]_ :: constrs3)))
       constr2.

Fixpoint apply_rect_rec
         (T: Type)
         (P: ConstrsType T -> T -> Type)
         (constrs1 constrs23: ConstrsType T):
  ParaType T P ->
  rect_type T constrs23 (P (rev_append constrs1 constrs23)) ->
  forall t: T, (P (rev_append constrs1 constrs23)) t
:=
  match constrs23 with
  | nil =>
      fun para rect => rect
  | existT _ arg2 constr2 :: constrs3 =>
      fun para rect =>
        apply_rect_rec T P (_[arg2, constr2]_ :: constrs1) constrs3 para
          (rect (para constrs1 arg2 constr2 constrs3))
  end.

Definition apply_rect (T: Type)
           (P: ConstrsType T -> T -> Type)
           (constrs: ConstrsType T):
  ParaType T P -> rect_type T constrs (P constrs) -> forall t: T, (P constrs) t
:=
  apply_rect_rec T P nil constrs.

Fixpoint rect_correct_clause (T: Type) (P: T -> Type) (f: forall t: T, P t) (arg: list (option Type)):
  forall (constr: constr_type arg T), rect_clause_type arg T P constr -> Prop :=
  match arg with
  | nil =>
      fun constr rect_clause => f constr = rect_clause
  | Some A :: arg0 =>
      fun constr rect_clause =>
        forall a: A, rect_correct_clause T P f arg0 (constr a) (rect_clause a)
  | None :: arg0 =>
      fun constr rect_clause =>
        forall a: T, rect_correct_clause T P f arg0 (constr a) (rect_clause a (f a))
  end.

Fixpoint citer_and
           (T: Type)
           (X: ConstrsType T -> Type)
           (P: forall
                 (constrs1: ConstrsType T)
                 arg2 constr2
                 (constrs3: ConstrsType T),
                 X (rev_append constrs1 (_[ arg2, constr2 ]_ :: constrs3)) -> Prop)
           constrs1 constrs23: forall x, Prop:=
  match constrs23 with
  | nil => fun x => True
  | existT _ arg2 constr2 :: constrs3 => fun x => P constrs1 arg2 constr2 constrs3 x /\ citer_and T X P (_[arg2, constr2]_ :: constrs1) constrs3 x
  end.

Module Sol1.

Definition apply_rect_correct
           (T: Type)
           (P: ConstrsType T -> T -> Type)
           (para: ParaType T P)
           (constrs: ConstrsType T)
           (rect: rect_type T constrs (P constrs)): Prop
:=
  citer_and T
            (fun constrs => forall t, P constrs t)
            (fun constrs1 arg2 constr2 constrs3 f =>
               rect_correct_clause
                 T
                 (P (rev_append constrs1 (_[arg2, constr2]_ :: constrs3)))
                 f
                 arg2
                 constr2
                 (para constrs1 arg2 constr2 constrs3))
            nil
            constrs
            (apply_rect T P constrs para rect).

Definition rect_correct T constrs (rect: forall P, rect_type T constrs P): Prop :=
  forall P para, apply_rect_correct T P para constrs (rect (P constrs)).

End Sol1.

Module Sol2.

Definition apply_rect_correct
           (T: Type)
           (P: ConstrsType T -> T -> Type)
           (para: ParaType T P)
           (constrs: ConstrsType T)
           (rect: rect_type T constrs (P constrs)): Prop
:=
  citer_and T
    (fun constrs => rect_type T constrs (P constrs))
    (fun constrs1 arg2 constr2 constrs3 x =>
       rect_correct_clause
         T
         (P (rev_append constrs1 (_[arg2, constr2]_ :: constrs3)))
         (apply_rect
            T P (rev_append constrs1 (_[ arg2, constr2 ]_ :: constrs3))
            para x)
         arg2 constr2 (para constrs1 arg2 constr2 constrs3)) nil
    constrs rect.

Definition rect_correct T constrs (rect: forall P, rect_type T constrs P): Prop :=
  forall P para, apply_rect_correct T P para constrs (rect (P constrs)).

End Sol2.

Lemma apply_rect_correct_equiv: forall T P para constrs rect,
  Sol1.apply_rect_correct T P para constrs rect <->
  Sol2.apply_rect_correct T P para constrs rect.
Proof.
  intros.
  unfold Sol1.apply_rect_correct, Sol2.apply_rect_correct, apply_rect.
  change constrs with (rev_append nil constrs) in rect.
  change constrs with (rev_append nil constrs) at 2.
  set (constrs1 := @nil (sigT (fun arg => constr_type arg T))) in rect.
  change (@nil (sigT (fun arg => constr_type arg T))) with constrs1 at 1 3 5.
  set (constrs23 := constrs) in rect |- *.
  clearbody constrs1 constrs23.
  revert constrs1 rect.
  induction constrs23 as [| [arg2 constr2] constrs3]; intros; simpl.
  { tauto. }
  specialize (IHconstrs3 (_[arg2, constr2]_ :: constrs1) rect).
  tauto.
Qed.

Lemma rect_correctness_equiv : forall T constrs (rect : forall P, rect_type T constrs P),
    Sol2.rect_correct T constrs rect <-> Sol1.rect_correct T constrs rect .
Proof.
  intros.
  unfold Sol1.rect_correct , Sol2.rect_correct.
  split ; intros ; apply apply_rect_correct_equiv ; auto.
Qed. 

Import Sol2.

Ltac apply_rect_correctness_gen :=
  try unfold rect_correct;
  match goal with
  | |- forall P para, apply_rect_correct _ P para ?constrs (_ (P _)) =>
         intros;
         unfold apply_rect_correct, rect_correct_clause, constrs, apply_rect, apply_rect_rec, citer_and;
         repeat split
  end.

Module Test04.
Import Test03.
Import Test02.

Theorem Nat_rect_correctness:
  forall P para, apply_rect_correct Nat P para constrs_Nat (Nat_rect (P constrs_Nat)).
Proof.
  apply_rect_correctness_gen.
Qed.

Theorem Tree_rect_correctness:
  forall P para, apply_rect_correct Tree P para constrs_Tree (rect_Tree (P constrs_Tree)).
Proof.
  apply_rect_correctness_gen.
Qed.

End Test04.

(*********************************************************************)
(*                                                                   *)
(* Part C.                                                           *)
(*   Def "apply_rect_clause_rel _ _ _ _ _ _ _ R": the relation       *)
(*     between two rect_clauses X X0---no matter what arguments are  *)
(*     filled, the computation results of (X ...) and (X0 ...) has   *)
(*     relation [R].                                                 *)
(*   Thm "apply_rect_clause_rel_Prop": for any para1 and para2,      *)
(*     if they satisfy [apply_rect_clause_rel R] for every branch,   *)
(*     the their apply_rect satisfy [R].                             *)
(*                                                                   *)
(*********************************************************************)

Fixpoint apply_rect_clause_rel_rec
             T
             (P1 P2 : ConstrsType T -> T -> Type)
             constrs
             arg:
  forall
    (constr: constr_type arg T)
    (R : forall constrs t , P1 constrs t -> P2 constrs t -> Prop),
    rect_clause_type arg T (P1 constrs) constr ->
    rect_clause_type arg T (P2 constrs) constr -> Prop
:=
  match arg with
  | nil => fun constr R => R constrs constr
  | Some T0 :: arg0 => fun constr R X X0 =>
      forall x0: T0,
        apply_rect_clause_rel_rec T P1 P2 constrs arg0
          (constr x0) R (X x0) (X0 x0)
  | None :: arg0 => fun constr R X X0 =>
      forall x y1 y2,
        apply_rect_clause_rel_rec T P1 P2 constrs arg0
          (constr x) R (X x y1) (X0 x y2)
  end.

Definition apply_rect_clause_rel
             T
             (P1 P2 : ConstrsType T -> T -> Type) 
             constrs1 arg2 constr2 constrs3
             (R : forall constrs t , P1 constrs t -> P2 constrs t -> Prop) :
  rect_clause_type
    arg2 T (P1 (rev_append constrs1 (_[arg2,constr2]_ :: constrs3))) constr2 ->
  rect_clause_type
    arg2 T (P2 (rev_append constrs1 (_[arg2,constr2]_ :: constrs3))) constr2 ->
  Prop
:=
  apply_rect_clause_rel_rec T P1 P2
    (rev_append constrs1 (_[arg2,constr2]_::constrs3)) arg2 constr2 R.

Lemma apply_rect_clause_rel_Prop_clause_ind:
  forall T P1 P2 constrs1 arga argb constr constrb constrs3 para1 para2
         R clause1 clause2,
    apply_rect_clause_rel_rec
      T P1 P2
      (rev_append constrs1 (_[ rev_append arga argb, constr ]_ :: constrs3))
      argb constrb R clause1 clause2 ->
    forall
      rect_clause1:
        rect_type
          T
          constrs3
          (P1 (rev_append
                 constrs1
                 (_[ rev_append arga argb, constr ]_ :: constrs3))),
    rect_correct_clause
      T
      (P1 (rev_append
             constrs1
             (_[ rev_append arga argb, constr ]_ :: constrs3)))
      (apply_rect_rec
         T P1
         (_[ rev_append arga argb, constr ]_ :: constrs1)
         constrs3 para1 rect_clause1)
      argb constrb clause1 ->
    forall
      rect_clause2:
        rect_type
          T
          constrs3
          (P2 (rev_append
                 constrs1
                 (_[ rev_append arga argb, constr ]_ :: constrs3))),
    rect_correct_clause
      T
      (P2 (rev_append
             constrs1
             (_[ rev_append arga argb, constr ]_ :: constrs3)))
      (apply_rect_rec
         T P2
         (_[ rev_append arga argb, constr ]_ :: constrs1)
         constrs3 para2 rect_clause2)
      argb constrb clause2 ->
    rect_clause_type
      argb T
      (fun t0 : T =>
         R
           (rev_append
              constrs1
              (_[ rev_append arga argb, constr ]_ :: constrs3))
           t0
           (apply_rect_rec
              T P1
              (_[ rev_append arga argb, constr ]_ :: constrs1)
              constrs3 para1 rect_clause1 t0)
           (apply_rect_rec
              T P2
              (_[ rev_append arga argb, constr ]_ :: constrs1)
              constrs3 para2 rect_clause2 t0))
      constrb.
Proof.
  intros.
  revert dependent arga.
  induction argb as [ | [ | ]] .
  - simpl in * ; intros. rewrite H1. rewrite H0. auto.
  - intros.
    simpl.
    intros.
    apply (IHargb
             (constrb x0) (Some T0 :: arga) constr (clause1 x0) (clause2 x0));
    auto.
  - intros.
    simpl.
    intros.
    apply (IHargb
             (constrb x) (None :: arga) constr
             (clause1
                x
                (apply_rect_rec
                   T P1
                   (_[ rev_append arga (None :: argb), constr ]_ :: constrs1)
                   constrs3 para1 rect_clause1 x))
             (clause2
                x
                (apply_rect_rec
                   T P2
                   (_[ rev_append arga (None :: argb), constr ]_ :: constrs1)
                   constrs3 para2 rect_clause2 x)));
    auto.
Qed.

Lemma apply_rect_clause_rel_Prop_clause:
  forall T P1 P2 constrs1 arg constr constrs3 para1 para2 rect1 rect2 R,
    apply_rect_clause_rel
      T P1 P2 constrs1 arg constr constrs3 R
      (para1 constrs1 arg constr constrs3)
      (para2 constrs1 arg constr constrs3) -> 
    rect_correct_clause
      T
      (P1 (rev_append constrs1 (_[arg,constr]_::constrs3)))
      (apply_rect_rec T P1 constrs1 (_[arg,constr]_::constrs3) para1 rect1)
      arg constr
      (para1 constrs1 arg constr constrs3) ->
    rect_correct_clause
      T
      (P2 (rev_append constrs1 (_[arg,constr]_::constrs3)))
      (apply_rect_rec T P2 constrs1 (_[arg,constr]_::constrs3) para2 rect2)
      arg constr
      (para2 constrs1 arg constr constrs3) ->
  rect_clause_type arg T
  (fun t0 : T =>
   R (rev_append constrs1 (_[ arg, constr ]_ :: constrs3)) t0
     (apply_rect_rec T P1 (_[ arg, constr ]_ :: constrs1) constrs3 para1
        (rect1 (para1 constrs1 arg constr constrs3)) t0)
     (apply_rect_rec T P2 (_[ arg, constr ]_ :: constrs1) constrs3 para2
        (rect2 (para2 constrs1 arg constr constrs3)) t0)) constr.
Proof.
  intros. simpl in *.
  apply (apply_rect_clause_rel_Prop_clause_ind
           T P1 P2 constrs1 nil arg constr constr constrs3 para1 para2 R
           (para1 constrs1 arg constr constrs3)
           (para2 constrs1 arg constr constrs3)); auto.
Qed.

Theorem apply_rect_clause_rel_Prop:
  forall T P1 P2 constrs
         (para1: ParaType T P1) (para2: ParaType T P2)
         (rect: forall P, rect_type T constrs P)
         (rect_correctness: Sol1.rect_correct T constrs rect)
         R,
    (forall constrs1 arg constr constrs3,
       apply_rect_clause_rel
         T P1 P2 constrs1 arg constr constrs3 R
         (para1 constrs1 arg constr constrs3)
         (para2 constrs1 arg constr constrs3)) ->
    rect_type
      T constrs
      (fun t =>
         R constrs t
           (apply_rect T P1 constrs para1 (rect _) t)
           (apply_rect T P2 constrs para2 (rect _) t)) ->
    forall t,
      R constrs t
        (apply_rect T P1 constrs para1 (rect _) t)
        (apply_rect T P2 constrs para2 (rect _) t).
Proof.
  intros.
  pose proof rect_correctness _ para1 as H0.
  pose proof rect_correctness _ para2 as H1.
  hnf in H0, H1.
  clear rect_correctness.
  set (rect1 := rect (P1 constrs)) in *.
  set (rect2 := rect (P2 constrs)) in *.
  clearbody rect1 rect2; clear rect.
  unfold apply_rect in *.
  change constrs with (rev_append nil constrs) in rect1 at 2, rect2 at 2, X at 2.
  change constrs with (rev_append nil constrs) at 1.
  set (constrs1 := nil) in *;
  rename constrs into constrs23.
  clearbody constrs1.
  revert dependent constrs1.
  induction constrs23 as [ | [arg constr] constrs3 ]; simpl in *; intros; auto.
  apply IHconstrs3 with (constrs1 := _[arg,constr]_ :: constrs1); try (tauto).
  apply X.
  clear X IHconstrs3.
  apply apply_rect_clause_rel_Prop_clause ; auto ; tauto.
Qed.

(*********************************************************************)
(*                                                                   *)
(* Part D.                                                           *)
(*                                                                   *)
(*********************************************************************)

Lemma Sol1_rect_correct_lemma : forall T constrs1 arg2 constr2 constrs3 rect , 
    Sol1.rect_correct T (rev_append constrs1 (_[arg2,constr2]_ :: constrs3)) rect ->
    (forall (P : ConstrsType T -> T -> Type)
      (para : ParaType T P),
    citer_and T
      (fun constrs : ConstrsType T => forall t : T, P constrs t)
      (fun (constrs1 : ConstrsType T)
           arg2 constr2
           (constrs3 : ConstrsType T)
         (f : forall t : T, P (rev_append constrs1 (_[ arg2, constr2 ]_ :: constrs3)) t) =>
       rect_correct_clause T (P (rev_append constrs1 (_[ arg2, constr2 ]_ :: constrs3))) f arg2
         constr2 (para constrs1 arg2 constr2 constrs3)) constrs1
       (_[ arg2, constr2 ]_ :: constrs3)
      (apply_rect T P (rev_append constrs1 (_[ arg2, constr2 ]_ :: constrs3)) para
         (rect (P (rev_append constrs1 (_[ arg2, constr2 ]_ :: constrs3))))) ).
Proof.
  intros.
  unfold Sol1.rect_correct in H.
  unfold Sol1.apply_rect_correct in H.
  revert arg2 constr2 constrs3 rect H.
  induction constrs1 as [ | [arg1 constr1] constrs1]; simpl in * ; intros ; auto.
  apply (IHconstrs1 arg1 constr1 (_[arg2 , constr2]_ :: constrs3)) ; auto.
Qed.

Definition rect_type_rev (T: Type) (constrs1 constrs2 constrs3: ConstrsType T) (P: T -> Type) : Type :=
  (fix rect_type_rev constrs1 constrs2 constrs3 : Type :=
     match constrs1 with
      | nil => rect_type T constrs3 P
      | existT _ arg constr :: constrs0 => rect_clause_type arg T P constr -> rect_type_rev constrs0 (existT _ arg constr :: constrs2) constrs3
     end) constrs1 constrs2 constrs3.

Theorem rect_pro : forall T constrs21 constrs3 P arg constr, 
  (rect_type T (rev_append constrs21 (_[ arg , constr ]_ :: constrs3)) P -> rect_type T (_[ arg , constr ]_ :: rev_append constrs21 constrs3) P)* 
  (rect_type T (_[ arg , constr ]_ :: rev_append constrs21 constrs3) P -> rect_type T (rev_append constrs21 (_[ arg , constr ]_ :: constrs3)) P).
Proof.
  intros. 
  revert arg constr constrs3.
  induction constrs21 as [ | [arg0 constr0] constrs0] ; intros ; simpl ; auto.
  split ; intros.
  - apply IHconstrs0 in X.
    apply IHconstrs0. simpl. intros.
    specialize (X X1). apply IHconstrs0 in X. auto.  
  - apply IHconstrs0. intro. apply IHconstrs0. intro.
    specialize (X X1). apply IHconstrs0 in X. auto.
Qed.

Theorem rect_rev_pro : forall T constrs1 constrs2 constrs2' constrs3 P,
  rect_type_rev T constrs1 constrs2 constrs3 P = rect_type_rev T constrs1 constrs2' constrs3 P.
Proof.
  intros.
  revert constrs2 constrs2'.
  induction constrs1 as [ | [arg constr] constrs0] ;simpl ; intros; auto.
  rewrite (IHconstrs0 (_[ arg, constr ]_ :: constrs2) (_[ arg, constr ]_ :: constrs2')). auto.
Qed.

Theorem rect_arrow_rect_rev : forall T constrs21 constrs3 P, 
    rect_type T (rev_append constrs21 constrs3) P -> rect_type_rev T constrs21 nil constrs3 P.
Proof.
  intros. 
  induction constrs21 as [ | [arg constr] constrs0]; simpl; intros; auto.
  rewrite rect_rev_pro with (constrs2' := nil).
  apply IHconstrs0. apply rect_pro in X. auto.
Qed. 

