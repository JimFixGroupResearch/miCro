module HoareTriples where

  open import Interpreter.miCro
  open import Interpreter.miCro_parser
  open import Expressions
  import Relation.Binary.PropositionalEquality as Eq
  open Eq using (_≡_; refl)
  open import Agda.Builtin.Bool

------------------------------------
  data SymbolicEnv : Set where
    _<S_ : Exp → Exp → SymbolicEnv
    _<=S_ : Exp → Exp → SymbolicEnv
    _>S_ : Exp → Exp → SymbolicEnv
    _>=S_ : Exp → Exp → SymbolicEnv
    _==S_ : Exp → Exp → SymbolicEnv
    _!=S_ : Exp → Exp → SymbolicEnv
    trueS : SymbolicEnv
    falseS : SymbolicEnv
    _andS_ : SymbolicEnv → SymbolicEnv → SymbolicEnv
    _orS_ : SymbolicEnv → SymbolicEnv → SymbolicEnv

  CombineEnv : SymbolicEnv → SymbolicEnv → SymbolicEnv
  CombineEnv falseS e = falseS
  CombineEnv e falseS = falseS
  CombineEnv trueS e = e
  CombineEnv e trueS = e
  CombineEnv (e1 orS e2) e3 = (CombineEnv e1 e3) orS (CombineEnv e2 e3)
  CombineEnv e1 (e2 orS e3) = (CombineEnv e1 e2) orS (CombineEnv e1 e3)
  CombineEnv e1 e2 = e1 andS e2

--- Condition Functions! ---
---This all assumes conditions are in a canonical form, without Not and with Or on the outermost level only; also Or should be x Or (y Or ...)
---Canonical Form also assumes all comparisons have one side with a single variable (and mult by const; by 1 at minimum); not sure how this would work out...
---Also need the forms to have EVERY variable multiplied by a const (so add times 1 where needed) as this makes later work easier

-- Will later separate some of these (those dealing only with Cnds and not states as well) into a separate file
-- That file will hopefully include a canonicalization for conditions

  --This will need an overhaul now
  AlwaysTrue : Cnd → Bool
  AlwaysTrue (cndBool true) = true
  AlwaysTrue (cndBool false) = false
  AlwaysTrue (c1 Or c2) = boolOr (AlwaysTrue c1) (AlwaysTrue c2)
  AlwaysTrue (c1 And c2) = boolAnd (AlwaysTrue c1) (AlwaysTrue c2)
  AlwaysTrue (Not c) with AlwaysTrue c --Don't have a boolNot function implemented yet; maybe should do that
  ... | true = false
  ... | false = true
  AlwaysTrue (e1 == e2) = ExpEquality (CFExp e1) (CFExp e2)
  AlwaysTrue (e1 != e2) with ExpEquality e1 e2
  ... | true = false
  ... | false = true
  AlwaysTrue (e1 < e2) = ExpLessThan e1 e2
  AlwaysTrue (e1 > e2) = ExpLessThan e2 e1
  AlwaysTrue other = false --Other comparisons currently not allowed, so get outta here

--Finds state sets complying with the given condition; handles Or then passes off the rest
--Essentially transforms a Cnd into a the minimum formula which upholds the Cnd
  StatesSatisfying : Cnd → SymbolicEnv
  StatesSatisfying (c1 Or c2) = (StatesSatisfying c1) orS (StatesSatisfying c2)
  StatesSatisfying (cndBool true) = trueS
  StatesSatisfying (cndBool false) = falseS
  StatesSatisfying (c1 And c2) = CombineEnv (StatesSatisfying c1) (StatesSatisfying c2)
  StatesSatisfying ((times (readVar str) k) == e) = ((times (readVar str) k) ==S e)
  StatesSatisfying ((times (readVar str) k) < e) = ((times (readVar str) k) <S e)
  StatesSatisfying ((times (readVar str) k) <= e) = ((times (readVar str) k) <=S e)
  StatesSatisfying ((times (readVar str) k) > e) = ((times (readVar str) k) >S e)
  StatesSatisfying ((times (readVar str) k) >= e) = ((times (readVar str) k) >=S e)
  StatesSatisfying ((times (readVar str) k) != e) = ((times (readVar str) k) !=S e) 
  StatesSatisfying other = falseS --Currently not allowing any other conditions to keep it simple

  --Checks to see if the given expression contains the given variable,
  --so we know when we have to replace or modify conditions
  ContainsVar : String → Exp → Bool
  ContainsVar var (readVar str) = primStringEquality var str
  ContainsVar var (plus e1 e2) = boolOr (ContainsVar var e1) (ContainsVar var e2)
  ContainsVar var (minus e1 e2) = boolOr (ContainsVar var e1) (ContainsVar var e2)
  ContainsVar var (times e n) = ContainsVar var e
  ContainsVar var e = false --We don't allow heap operations, so excluding those nothing else could contain the variable

  --Checks to see if the condition contains the given variable
  --NOTE: currently this assumes the condition is a comparison; it will not break down and/or/etc.
  CndContainsVar : String → Cnd → Bool
  CndContainsVar var (e1 == e2) = boolOr (ContainsVar var e1) (ContainsVar var e2)
  CndContainsVar var (e1 <= e2) = boolOr (ContainsVar var e1) (ContainsVar var e2)
  CndContainsVar var (e1 >= e2) = boolOr (ContainsVar var e1) (ContainsVar var e2)
  CndContainsVar var (e1 != e2) = boolOr (ContainsVar var e1) (ContainsVar var e2)
  CndContainsVar var (e1 < e2) = boolOr (ContainsVar var e1) (ContainsVar var e2)
  CndContainsVar var (e1 > e2) = boolOr (ContainsVar var e1) (ContainsVar var e2)
  CndContainsVar var c = false

  data Side : Set where
    Left : Side
    Right : Side
    NoSide : Side

  --Extra containment function, returning Left Right or NoSide, for what part of a comp Cnd contains the var
  --Could modify some things to have this replace CndContainsVar later
  WhichSideContainsVar : String → Cnd → Side
  WhichSideContainsVar var (e1 == e2) = boolIfElse (ContainsVar var e1) (Left) (boolIfElse (ContainsVar var e2) (Right) (NoSide))
  WhichSideContainsVar var (e1 <= e2) = boolIfElse (ContainsVar var e1) (Left) (boolIfElse (ContainsVar var e2) (Right) (NoSide))
  WhichSideContainsVar var (e1 >= e2) = boolIfElse (ContainsVar var e1) (Left) (boolIfElse (ContainsVar var e2) (Right) (NoSide))
  WhichSideContainsVar var (e1 != e2) = boolIfElse (ContainsVar var e1) (Left) (boolIfElse (ContainsVar var e2) (Right) (NoSide))
  WhichSideContainsVar var (e1 < e2) = boolIfElse (ContainsVar var e1) (Left) (boolIfElse (ContainsVar var e2) (Right) (NoSide))
  WhichSideContainsVar var (e1 > e2) = boolIfElse (ContainsVar var e1) (Left) (boolIfElse (ContainsVar var e2) (Right) (NoSide))
  WhichSideContainsVar var c = NoSide --this function only accepts comparisons conditions, so the rest are disregarded

  -- If string is a variable in Cnd, this multiplies the Cnd (assumed to be a comp)
  -- By nat, then replaces all instances of nat*var in Cnd with exp, and returns that Cnd
  --- !!!!! Need to fix this; change so that instead of times its a "canonical times" that pushes the times down to the "lowest level" (closest to the variables/consts)
  ReplaceInCnd : Nat → String → Exp → Cnd → Cnd
  ReplaceInCnd n var e1 (e2 == e3) with boolOr (ContainsVar var e2) (ContainsVar var e3)
  ... | true = (ReplaceInExp n var e1 (times e2 n)) == (ReplaceInExp n var e1 (times e3 n))
  ... | false = (e2 == e3)
  ReplaceInCnd n var e1 (e2 < e3) with boolOr (ContainsVar var e2) (ContainsVar var e3)
  ... | true = (ReplaceInExp n var e1 (times e2 n)) < (ReplaceInExp n var e1 (times e3 n))
  ... | false = (e2 < e3)
  ReplaceInCnd n var e1 (e2 > e3) with boolOr (ContainsVar var e2) (ContainsVar var e3)
  ... | true = (ReplaceInExp n var e1 (times e2 n)) > (ReplaceInExp n var e1 (times e3 n))
  ... | false = (e2 > e3)
  ReplaceInCnd n var e1 (e2 != e3) with boolOr (ContainsVar var e2) (ContainsVar var e3)
  ... | true = (ReplaceInExp n var e1 (times e2 n)) != (ReplaceInExp n var e1 (times e3 n))
  ... | false = (e2 != e3)
  ReplaceInCnd n var e otherCnd = cndBool false --Need to finish this?

  --Returns a modified version of the given condition, where the given SEnv is taken into account as a restriction
  -- Currently these will sometimes lose their canonical form, which may be an issue, but so far isn't
  -- I don't think this function itself relies on the form, however, so maybe can be fixed
  -- By just doing canonicalization later; before AlwaysTrue is evaluated?
  ModifyCnd : SymbolicEnv → Cnd → Cnd
  ModifyCnd s (cndBool true) = (cndBool true)
  ModifyCnd s (cndBool false) = (cndBool false)
  ModifyCnd s (c1 Or c2) = (ModifyCnd s c1) Or (ModifyCnd s c2) --We shouldn't be getting either of these cases based on how this is used in SEnvSatisfies
  ModifyCnd s (c1 And c2) = (ModifyCnd s c1) And (ModifyCnd s c2) --But I'm writing them out in case for clarity and in case this function is later used for anything else
  ModifyCnd ((times (readVar var) k) ==S e1) c = ReplaceInCnd k var e1 c
  ModifyCnd ((times (readVar var) k) !=S e1) c with CndContainsVar var c
  ... | true = c And ((times (readVar var) k) != e1)
  ... | false = c
  ModifyCnd ((times (readVar var) k) <S e1) (e2 == e3) with WhichSideContainsVar var (e2 == e3)
  ... | Left = (e2 == e3) And (ReplaceInCnd k var (minus e1 (const 1)) ((plus e2 (const 1)) > e3))
  ... | Right = (e2 == e3) And (ReplaceInCnd k var (minus e1 (const 1)) (e2 < (plus e3 (const 1)))) --trust me this works
  ... | NoSide = (e2 == e3)
  ModifyCnd ((times (readVar var) k) <S e1) (e2 < e3) with WhichSideContainsVar var (e2 < e3)
  ... | Left = (e2 < e3) Or (ReplaceInCnd k var (minus e1 (const 1)) (e2 < e3)) --No plus one like before since we're dealing with a strict less than
  ... | Right = (e2 < e3) And (ReplaceInCnd k var (minus e1 (const 1)) (e2 < e3))
  ... | NoSide = (e2 < e3)
  ModifyCnd ((times (readVar var) k) <S e1) (e2 > e3) with WhichSideContainsVar var (e2 > e3)
  ... | Left = (e2 > e3) And (ReplaceInCnd k var (minus e1 (const 1)) (e2 > e3))
  ... | Right = (e2 > e3) Or (ReplaceInCnd k var (minus e1 (const 1)) (e2 > e3))
  ... | NoSide = (e2 > e3)
  ModifyCnd ((times (readVar var) k) >S e1) (e2 == e3) with WhichSideContainsVar var (e2 == e3)
  ... | Left = (e2 == e3) And (ReplaceInCnd k var (plus e1 (const 1)) ((minus e2 (const 1)) < e3))
  ... | Right = (e2 == e3) And (ReplaceInCnd k var (plus e1 (const 1)) (e2 > (minus e3 (const 1)))) --trust me this works
  ... | NoSide = (e2 == e3)
  ModifyCnd ((times (readVar var) k) >S e1) (e2 > e3) with WhichSideContainsVar var (e2 > e3)
  ... | Left = (e2 > e3) Or (ReplaceInCnd k var (plus e1 (const 1)) (e2 > e3))
  ... | Right = (e2 > e3) And (ReplaceInCnd k var (plus e1 (const 1)) (e2 > e3))
  ... | NoSide = (e2 > e3)
  ModifyCnd ((times (readVar var) k) >S e1) (e2 < e3) with WhichSideContainsVar var (e2 < e3)
  ... | Left = (e2 < e3) And (ReplaceInCnd k var (plus e1 (const 1)) (e2 < e3))
  ... | Right = (e2 < e3) Or (ReplaceInCnd k var (plus e1 (const 1)) (e2 < e3))
  ... | NoSide = (e2 < e3)
  ModifyCnd vr c = c --The Env at this point should be a comparison between a var and expression, so we shouldn't reac these cases


  --Will return false if there is any state from the SymbolicEnv in which Cnd does not hold, and true otherwise
  --The idea here is that state restrictions (comparisons) are consumed and used to modify the condition until they are all "absorbed"
  --Where the condition will now read as AlwaysTrue if the it met the restrictions (eg, rstr x = 4, cnd x < 5 becomes cnd 4 < 5, reads as AlwaysTrue)
  {-# TERMINATING #-}
  SEnvSatisfiesCnd : SymbolicEnv → Cnd → Bool
  SEnvSatisfiesCnd falseS c = true
  SEnvSatisfiesCnd trueS c = (AlwaysTrue c)
  SEnvSatisfiesCnd (e1 orS e2) c =  boolAnd (SEnvSatisfiesCnd e1 c) (SEnvSatisfiesCnd e2 c)
  SEnvSatisfiesCnd (e1 andS e2) c = SEnvSatisfiesCnd e2 (ModifyCnd e1 c) --Assuming the Envs are in proper form, e1 will be an atomic and e2 could be an atomic or another and
  SEnvSatisfiesCnd comp c = SEnvSatisfiesCnd trueS (ModifyCnd comp c) --All other symbolic constructors are comparisons, so we 

  --An object which provides evidence that the predicate holds in all states in the state set
  data ConditionHolds : SymbolicEnv → Cnd → Set where
    ConditionHoldsProof : ∀ {st : SymbolicEnv} {c : Cnd}
      → (SEnvSatisfiesCnd st c ≡ true)
      -----------------------------
      → ConditionHolds st c

  --New type used for symbolic check function
  --Always is for when the Cnd is always true in all states represented by the symbolicEnv
  --Never is similar, and Sometimes is when it holds in some but not all of the states (eg, SE is x < 4, cnd is x == 2)
  data HoldsWhen : Set where
    Always : HoldsWhen
    Sometimes : HoldsWhen
    Never : HoldsWhen

  --Helper function for when the condition could be Never or Sometimes
  SymbolicCheck2 : SymbolicEnv → Cnd → HoldsWhen
  SymbolicCheck2 env c with SEnvSatisfiesCnd env (Not c) --This is when we will Canonical Forms for Cnds; could also only finish the FlipCnd function for this part
  ... | true = Never
  ... | false = Sometimes

  -- Symbolic version of the check function
  SymbolicCheck : SymbolicEnv → Cnd → HoldsWhen
  SymbolicCheck falseS c = Never --I'm not sure this is right at all, but if we have false at any point we will have false at the end so it doesn't matter
  SymbolicCheck env c with SEnvSatisfiesCnd env c
  ... | true = Always
  ... | false = SymbolicCheck2 env c

  --The main function for symbolic execution, this modifies the Env appropriately based on variable changes
  --Makes use of lVars currently?
  SymbolicUpdate : SymbolicEnv → String → Exp → SymbolicEnv
  SymbolicUpdate falseS str e = falseS
  SymbolicUpdate trueS str e = ((times (readVar str) 1) ==S e)
  SymbolicUpdate (env1 orS env2) str e = ((SymbolicUpdate env1 str e) orS (SymbolicUpdate env2 str e))
  SymbolicUpdate (env1 andS env2) str e = ((SymbolicUpdate env1 str e) andS (SymbolicUpdate env2 str e))
  SymbolicUpdate comp str e = 

  -- Functions similar to exec, but different rules on changing the Env; also while is not allowed at present (is skipped over)
  SymbolicExec : SymbolicEnv → Stmt → SymbolicEnv
  SymbolicExec env (Seq s1 s2) = SymbolicExec (SymbolicExec env s1) s2
  SymbolicExec env (IfElse c s1 s2) with (SymbolicCheck env c)
  ...                         | Always = SymbolicExec env s1
  ...                         | Never = SymbolicExec env s2
  ...                         | Sometimes = (SymbolicExec env s1) orS (SymbolicExec env s2) --This might break the form of the Env? I think treed (instead of listed) orS are okay, but I'll check...
  SymbolicExec env (While c s) with (SymbolicCheck env c)
  ... | false = env
  ... | true = env -- SymbolicExec r (Seq s (While c s)) -- skipped for now
  SymbolicExec env (AssignVar str e) = (SymbolicUpdate env str e)
  SymbolicExec r other = r --Heaps ops currently not allowed

  

{- --Assumes c1 and c2 are in canonical form (canonicalization function not yet written)
  data HoareTripleStateSet : Cnd → Stmt → Cnd → Set where
    HTStateSetProof : ∀ {c1 c2 : Cnd} {s : Stmt}
      → (ConditionHolds (ExecStateSet (StatesSatisfying c1) s) c2)
      ---------------------------
      → HoareTripleStateSet c1 s c2
-}
