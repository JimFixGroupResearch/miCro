--Examples, proofs, and tests of the Hoare Triple Data type
module HoareTripleExamples where

    open import Language.miCro
    open import Language.miCro_parser
    open import Language.miCro_tokenizer
    open import Semantics.Expressions
    open import Semantics.Conditions
    import Relation.Binary.PropositionalEquality as Eq
    open Eq using (_≡_; refl; cong; sym)
    open Eq.≡-Reasoning using (begin_; _≡⟨⟩_; step-≡; _∎)
    open import Agda.Builtin.Bool
    open import HoareTriples

    --Needed for some proofs; not in agda standard library?
    cong₂ : ∀ {A B C : Set} (f : A → B → C) {u x : A} {v y : B}
      → u ≡ x
      → v ≡ y
      -------------
      → f u v ≡ f x y
    cong₂ f refl refl  =  refl
    ----------

--- Two proofs for the Pre-False and the Post-True triples ---

    PreFalseEx1 : SEnvSatisfiesCnd falseS (cndBool true) ≡ true
    PreFalseEx1 = refl

    PreFalseExample : HoareTriple (cndBool false) No-op (cndBool true)
    PreFalseExample = HTSymbolicEnvProof (ConditionHoldsProof PreFalseEx1) 

    PreFalseHelper : ∀ (s : Stmt) (n : Nat) → (SymbolicExec n falseS s) ≡ falseS
    PreFalseHelper (AssignVar str e) n = refl
    PreFalseHelper (IfElse c s1 s2) n rewrite (PreFalseHelper s2 n) = refl
    PreFalseHelper (Seq s1 s2) n rewrite (PreFalseHelper s1 n) rewrite (PreFalseHelper s2 (suc n)) = refl
    PreFalseHelper (While zero c s) n = refl
    PreFalseHelper (While (suc n2) c s) n = refl
    PreFalseHelper (ReadHeap var e) n = refl
    PreFalseHelper (WriteHeap e1 e2) n = refl
    PreFalseHelper (New var e) n = refl
    PreFalseHelper No-op n = refl

    PreFalseHelper2 : ∀ (s : Stmt) (c : Cnd) → SEnvSatisfiesCnd (SymbolicExec 1 falseS s) c ≡ true
    PreFalseHelper2 s c = 
      begin
        SEnvSatisfiesCnd (SymbolicExec 1 falseS s) c
      ≡⟨ cong₂ (SEnvSatisfiesCnd) (PreFalseHelper s 1) refl ⟩
        SEnvSatisfiesCnd falseS c
      ≡⟨⟩
        true
      ∎
      
    PreFalse : ∀ (s : Stmt) (c : Cnd) → HoareTriple (cndBool false) s (c)
    PreFalse s c = HTSymbolicEnvProof (ConditionHoldsProof (PreFalseHelper2 s (CFCnd c)))

    PostTrueHelper : ∀ (state : SymbolicEnv) → SEnvSatisfiesCnd state (cndBool true) ≡ true
    PostTrueHelper falseS = refl
    PostTrueHelper trueS = refl
    --Can't figure out a way to do all the comparisons at once...
    PostTrueHelper (e1 <S e2) = refl
    PostTrueHelper (e1 >S e2) = refl
    PostTrueHelper (e1 <=S e2) = refl
    PostTrueHelper (e1 >=S e2) = refl
    PostTrueHelper (e1 ==S e2) = refl
    PostTrueHelper (e1 !=S e2) = refl
    PostTrueHelper (e1 orS e2) rewrite (PostTrueHelper e1) | (PostTrueHelper e2) = refl
    PostTrueHelper (e1 andS e2) rewrite (PostTrueHelper e1) | (PostTrueHelper e2) = refl

    PostTrue : ∀ (s : Stmt) (c : Cnd) → HoareTriple (c) s (cndBool true)
    PostTrue = λ s c → HTSymbolicEnvProof (ConditionHoldsProof (PostTrueHelper (SymbolicExec 1 (StatesSatisfying (CFCnd c)) s)))

--- Hoare Triple Testing with concrete examples ---
-- I also ran across some bugs testing these, so there are other proofs included to test that certain parts were working (mostly parsing issues)

    AssignXBasic : HoareTriple (cndBool true) (parseString "x = 1;") ((readVar "x") == const 1)
    AssignXBasic = HTSymbolicEnvProof (ConditionHoldsProof refl)

    BasicTest : SymbolicExec 1 trueS (parseString "x = x + 1;") ≡ (times (readVar "x") 1) ==S (plus (readVar "x1") (const 1))
    BasicTest = refl

    BasicTest2 :  ReplaceInCnd 1 "x" (plus (readVar "x1") (const 1)) (times (readVar "x") 1 > const 0) ≡ (times (plus (readVar "x1") (const 1)) 1 > const 0)
    BasicTest2 = refl

    BasicTest3 : AlwaysTrue (times (plus (readVar "x1") (const 1)) 1 > const 0) ≡ true
    BasicTest3 =
      begin
        AlwaysTrue (times (plus (readVar "x1") (const 1)) 1 > const 0)
      ≡⟨⟩
        ExpLessThan (const 0) (plus (times (readVar "x1") 1) (const 1))
      ≡⟨⟩
        true
      ∎

    IncXBasic : HoareTriple (cndBool true) (parseString "x = x + 1;") (readVar "x" > const 0)
    IncXBasic = HTSymbolicEnvProof (ConditionHoldsProof refl)

    BasicTest4 : SymbolicExec 1 trueS (parseString "x = y + 1;") ≡ ((times (readVar "x") 1) ==S (plus (readVar "y") (const 1)))
    BasicTest4 = refl

    BasicTest5 : ModifyCnd (((times (readVar "x") 1) ==S (plus (readVar "y") (const 1)))) (readVar "x" > readVar "y") ≡ (plus (readVar "y") (const 1)) > times (readVar "y") 1
    BasicTest5 = refl

    BasicTest6 : ExpLessThan (times (readVar "y") 1) (plus (times (readVar "y") 1) (const 1)) ≡ true
    BasicTest6 = refl

    IncXY : [ cndBool true ] (parseString "x = y + 1;") [ readVar "x" > readVar "y" ]
    IncXY = HTSymbolicEnvProof (ConditionHoldsProof refl)

    -- A test which should pass but does not; my canonical forms fail to recognize groups of comparisons that are equal to false or true
    -- As a result, you would have to simplify such comparisons yourself before entering them
    -- In which case they simply pass under prefalse or post true or similar rules
    --AbsurdTest : [ ((readVar "x") < (const 5)) And ((readVar "x") > (const 5))  ] (No-op) [ (cndBool false) ]
    --AbsurdTest = HTSymbolicEnvProof (ConditionHoldsProof {!!})

   --- Everything below here is a part of a test of a while loop triple which does not work
   --- though most bugs were fixed there is still an issue with ModifyCnd, explained at the bottom

    AgdaNeedsADebuggingMode : tokenize "if (x == 3) {x = 2} else { x = 1};" ≡ "if" :t: "(" :t: "x" :t: "==" :t: "3" :t: ")" :t: "{" :t: "x" :t: "=" :t: "2" :t: "}" :t: "else" :t: "{" :t: "x" :t: "=" :t: "1" :t: "}" :t: ";" :t: [t]
    AgdaNeedsADebuggingMode = refl

    TestAnotherOne : parseStmt1 ("x" :t: "=" :t: "2" :t: ";" :t: "}" :t: "else" :t: "{" :t: "x" :t: "=" :t: "1" :t: ";" :t: "}" :t: ";" :t: [t]) ≡ Some (("}" :t: "else" :t: "{" :t: "x" :t: "=" :t: "1" :t: ";" :t: "}" :t: ";" :t: [t]) × (AssignVar "x" (const 2)))
    TestAnotherOne = refl

    IfElseTest : [ (readVar "x") == const 6 ] parseString "if (x == 3) {x = 2;} else { x = 1;}" [ (readVar "x") < const 3 ]
    IfElseTest = HTSymbolicEnvProof (ConditionHoldsProof refl)

    WhileParseTest : (parseStmt1 ("while" :t: "(" :t: "x" :t: ">" :t: "0" :t: ")" :t: "{" :t: "x" :t: "=" :t: "x" :t: "-" :t: "1" :t: ";" :t: "}" :t: [t])) ≡ Some ([t] × (While 512 ((readVar "x") > (const zero)) (AssignVar "x" (minus (readVar "x") (const 1)))))
    WhileParseTest =
      begin
        (parseStmt1 ("while" :t: "(" :t: "x" :t: ">" :t: "0" :t: ")" :t: "{" :t: "x" :t: "=" :t: "x" :t: "-" :t: "1" :t: ";" :t: "}" :t: [t]))
      ≡⟨⟩
        (parseStmt2 (parseSingleStmt ("while" :t: "(" :t: "x" :t: ">" :t: "0" :t: ")" :t: "{" :t: "x" :t: "=" :t: "x" :t: "-" :t: "1" :t: ";" :t: "}"  :t: [t])))
      ≡⟨⟩
        parseStmt2 (parseRestOfWhile ((readVar "x") > (const 0)) ("x" :t: "=" :t: "x" :t: "-" :t: "1" :t: ";" :t: "}" :t: [t]))
      ≡⟨⟩
        parseStmt2 (Some ([t] × (While 512 ((readVar "x") > (const zero)) (AssignVar "x" (minus (readVar "x") (const 1))))))
      ≡⟨⟩
        (Some ([t] × (While 512 ((readVar "x") > (const zero)) (AssignVar "x" (minus (readVar "x") (const 1))))))
      ∎

    WhileParseTest3 : parseStmt1 ("x" :t: "=" :t: "x" :t: "-" :t: "1" :t: ";" :t: "}" :t: ";" :t: [t]) ≡  (Some (("}" :t: ";" :t: [t]) × (AssignVar "x" (minus (readVar "x") (const 1)))))
    WhileParseTest3 =
      begin
        parseStmt1 ("x" :t: "=" :t: "x" :t: "-" :t: "1" :t: ";" :t: "}" :t: ";" :t: [t])
      ≡⟨⟩
        parseStmt2 (parseSingleStmt ("x" :t: "=" :t: "x" :t: "-" :t: "1" :t: ";" :t: "}" :t: ";" :t: [t]))
      ≡⟨⟩
        parseStmt2 (Some (("}" :t: ";" :t: [t]) × (AssignVar "x" (minus (readVar "x") (const 1)))))
      ≡⟨⟩
        parseStmt2 (Some (("}" :t: ";" :t: [t]) × (AssignVar "x" (minus (readVar "x") (const 1)))))
      ≡⟨⟩
       (Some (("}" :t: ";" :t: [t]) × (AssignVar "x" (minus (readVar "x") (const 1)))))
      ∎
        

    WhileParseTest2 : (parseExp ("x" :t: "-" :t: "1" :t: ";" :t: "}" :t: ";" :t: [t])) ≡ (Some ((";" :t: "}" :t: ";" :t: [t]) × (minus (readVar "x") (const 1))))
    WhileParseTest2 =
      begin
         (parseExp ("x" :t: "-" :t: "1" :t: ";" :t: "}" :t: ";" :t: [t]))
       ≡⟨⟩
         (Some ((";" :t: "}" :t: ";" :t: [t]) × (minus (readVar "x") (const 1))))
       ∎

    --Although this is now parsing, it still won't work
    --I believe this is due to an error with the ModifyCnd function; if it first goes through the restriction "x1 = 1",
    --It will discard it since it seems irrelevant. Next, it will process "x = x1 - 1", and add that, resulting in
    -- "x1 - 1 == 0" as the final condition to check; this will fail the AlwaysTrue test.
    -- the "simple" fix to this is to hold onto restrictions instead of discarding them when they are not added,
    -- and then to continually iterate over the restrictions in the SEnv until none are added.
    -- The better solution to this would be to create a state space for the variables, using restrictions to modify that space
    -- and then checking if that state space is a subset of the space that the final conditions occupy
    -- But that's a lot of math
    -- So I think this is where this project ends
    WhileTest1 : [ (readVar "x") == const 1 ] parseString "while (x > 0) {x = x - 1;};"  [ (readVar "x") == const zero ]
    WhileTest1 = HTSymbolicEnvProof (ConditionHoldsProof {!!})

    

    
