/-
Copyright (c) 2018 Jeremy Avigad. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jeremy Avigad, Mario Carneiro, Simon Hudon, Alex Keizer
-/

import Qpf.MathlibPort.Fin2
import Qpf.Util.HEq
import Lean.Elab.Tactic.Conv

universe u v w

abbrev DVec {n : Nat} (αs : Fin2 n → Type u)  : Type _
  := (i : Fin2 n) → αs i

abbrev Vec (α : Type _) (n : Nat)
  := @DVec n fun _ => α

namespace Vec
  def append1 {α : Type u} {n} (tl : Vec α n) (hd : α) : Vec α (.succ n)
    | (Fin2.fs i) => tl i
    | Fin2.fz     => hd

  -- infixl:67 " ::: " => append1

  /-- Drop the last element from a `Vec` -/
  def drop (v : Vec α (n+1)) : Vec α n
    := fun i => v (Fin2.fs i)

  def constVec {α : Type _} (a : α) (n : Nat) : Vec α n
    := fun _ => a
end Vec

unif_hint (n : Nat) where |- Fin2 n → Type u =?= Vec (Type u) n
unif_hint {α : Type _} (n : Nat) where |- DVec (Vec.constVec α n) =?= Vec α n

namespace DVec
  /-- Return the last element from a `DVec` -/
  abbrev last (v : @DVec (n+1) αs ) : αs 0
    := v 0

  /-- Drop the last element from a `DVec` -/
  def drop (v : DVec αs) : DVec (Vec.drop αs)
    := fun i => v (Fin2.fs i)

  @[reducible]
  def nil : @DVec 0 αs
    := fun emp => by contradiction

  @[reducible]
  def append1 {α : Type u} {αs : Vec (Type u) n} (tl : DVec αs) (hd : α) : DVec (Vec.append1 αs α)
    | (Fin2.fs i) => tl i
    | Fin2.fz     => hd
  

  -- infixl:67 " ::: " => append1
end DVec

namespace Vec
  variable {α : Type _} {n : Nat}

  abbrev nil  : Vec α 0           := DVec.nil
  abbrev last : Vec α n.succ → α  := DVec.last
end Vec



/-
  # Notation macros
-/

syntax "![" term,* "]" : term
macro_rules
  | `(![])    => `(Vec.nil)
  | `(![$x])  => `(Vec.append1 ![] $x)
  | `(![ $xs,* , $x]) => `(Vec.append1 ![$xs,*] $x)



namespace Vec
  theorem drop_append1 {v : Vec α n} {a : α} {i : Fin2 n} : 
      drop (append1 v a) i = v i := 
    rfl

  theorem drop_append1' {v : Vec α n} {a : α} : 
      drop (append1 v a) = v :=
  by funext x; rfl

  theorem last_append1 {v : Vec α n} {a : α} : 
    last (append1 v a) = a
  := rfl

  @[simp]
  theorem append1_drop_last (v : Vec α (n+1)) : append1 (drop v) (last v) = v :=
    funext $ fun i => by cases i; rfl; rfl



  /--
    Turns `n`-ary vector into their canonical `![α(n-1), α(n-2), ..., α(1), α(0)]` form.
    `normalize_lawful` shows that this does not change the vector (up to functional extensionality),
    but it has the nice side effect that vectors whose elements are definitionally equal, will be 
    definitionally equal after normalization.
  -/
  def normalize : {n : Nat} → Vec α n → Vec α n
  | 0,    _ => nil
  | n+1,  v => append1 (normalize v.drop) v.last

  @[simp]
  theorem normalize_lawful (v : Vec α n) : 
    v.normalize = v :=
  by
    induction n
    <;> simp[normalize]
    case zero =>
      funext i; cases i;

    case succ _ ih =>
      rw[ih]
      apply append1_drop_last


  
  def reverse (v : Vec α n) : Vec α n :=
    normalize (fun i => v i.inv)


  @[simp]
  theorem reverse_involution {v : Vec α n} :
    v.reverse.reverse = v :=
  by
    funext i;
    simp[reverse, normalize_lawful]
    apply congrArg;
    exact Fin2.inv_involution
end Vec


namespace DVec 
  /--
    Turns `n`-ary vector into a canonical form in terms of `append1`
    `normalize_lawful` shows that this does not change the vector (up to functional extensionality),
    but it has the nice side effect that vectors whose elements are definitionally equal, will be 
    definitionally equal after normalization.
  -/
  def normalize : {n : Nat} → {αs : Vec (Type _) n} → DVec αs → DVec αs
  | 0,   _,  _ => nil
  | n+1, _,  v => append1 (normalize v.drop) v.last
                  |> cast (congrArg _ (Vec.append1_drop_last _))


  theorem append1_drop_last {αs : Vec _ (n+1)} (v : DVec αs) : 
    append1 (drop v) (last v) |> HEq v :=
  by
    have type_eq : DVec αs = DVec (Vec.append1 (Vec.drop αs) (αs.last))
      := congrArg _ (Vec.append1_drop_last _).symm;
    have : HEq v (cast type_eq v)
      := by simp_heq
    apply HEq.trans this
    apply heq_of_eq
    funext i;
    cases i <;> {    
      rw [cast_arg _]
      case h₁ => rfl
      case h₃ => simp[cast_eq]
      rfl
    }
      

  @[simp]
  theorem normalize_lawful {αs : Vec _ n} (v : DVec αs) :
    v.normalize = v :=
  by
    induction n
    <;> simp[normalize]
    case zero =>
      funext i; cases i;

    case succ _ ih =>
      rw[ih]
      apply eq_of_heq
      simp_heq
      apply HEq.symm
      apply append1_drop_last


end DVec



namespace Vec
  /-- Create a `Vec` from a `List`. Note that this conceptually reverses the list, since in a `Vec`
      the 0th index points to the right-most element
   -/
  def ofList : (as : List α) → Vec α (as.length)
    | List.nil        => Vec.nil
    | List.cons a as  => Vec.append1 (ofList as) a
  
  
  /-- Create a `List` from a `Vec`. Note that this conceptually reverses the vector, since in a `Vec`
      the 0th index points to the right-most element
   -/
  def toList : {n : Nat} → Vec α n → List α
    | 0,    _  => List.nil
    | n+1,  v  => List.cons v.last (toList v.drop)


  @[simp]
  theorem toList_length_eq_n {v : Vec α n} : 
    v.toList.length = n :=
  by
    induction n
    case zero => rfl
    case succ n ih =>
      dsimp only [toList, List.length]
      dsimp only [HAdd.hAdd, Add.add, Nat.add]
      apply congrArg
      apply ih

  @[simp]
  theorem ofList_toList_iso {v : Vec α n} :
    HEq (ofList (toList v)) v :=
  by
    apply HEq.trans (b := cast (β:=Vec α (List.length (toList v))) ?hc v);
    case hc =>
      simp only [toList_length_eq_n]
    case h₂ => 
      apply cast_heq
    case h₁ =>
      apply heq_of_eq;
      funext i;
      apply eq_of_heq;
      rw[cast_arg] <;> try (solve | simp);
      simp_heq

      induction n <;> cases i;
      case succ.fz n ih => {
        dsimp[ofList, toList, append1, last, DVec.last]
        apply hcongr <;> (try solve | intros; rfl)
        simp_heq;
        simp only [OfNat.ofNat]
        apply hcongr <;> (try solve | intros; rfl)
        simp
      }
      case succ.fs n ih i => {
        dsimp[ofList, toList, append1, drop]
        
        apply HEq.trans (@ih (fun i => v (Fin2.fs i)) i);
        apply hcongr <;> (try solve | intros; rfl)
        simp_heq
        apply hcongr;
        case H₂ => apply cast_heq
        case H₃ => apply congrArg; simp
        case H₄ => intro j; apply congrArg; simp
        
        apply hcongr <;> (try solve | intros; rfl);
        simp
      }

  @[simp]
  theorem toList_ofList_iso {as : List α} :
    toList (ofList as) = as :=
  by
    induction as;
    case nil          => rfl
    case cons a as ih => simp only [toList, ofList, append1, last, DVec.last, drop, ih]

end Vec