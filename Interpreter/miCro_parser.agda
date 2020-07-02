-- First: Read from file into string --

-- process env = initial environment read from string
-- process prog = instructions read from string
-- run exec env prog, and return (print?) output

-- Tokens and related functions --
-- At this point we assume the input file has been parsed into tokens type
-- Token type is a list of strings with all whitespace removed, separated on special characters
-- So "while" should be one list entry, with the proceeding "(" being it's own, and so on.

module Interpreter.miCro_parser where

  open import Interpreter.miCro

  -- Builtins and Primitives --
  open import Agda.Builtin.Bool

  postulate Char : Set
  {-# BUILTIN CHAR Char #-}
  
  data List {a} (A : Set a) : Set a where
    []  : List A
    _∷_ : (x : A) (xs : List A) → List A
  {-# BUILTIN LIST List #-}
  infixr 5 _∷_

  -- List Append
  infixr 5 _++_
  _++_ : ∀ {A : Set} → List A → List A → List A
  []       ++ ys  =  ys
  (x ∷ xs) ++ ys  =  x ∷ (xs ++ ys)
  
  primitive
    primStringToList : String → List Char
    primIsDigit : Char → Bool
    primCharToNat : Char → Nat

  -- Token type, works as a list of strings --
  data Tokens : Set where
    [t] : Tokens
    _:t:_ : String → Tokens → Tokens
  infixr 5 _:t:_

  -- Token append --
  _+t+_ : Tokens → Tokens → Tokens
  [t]       +t+ ys  =  ys
  (x :t: xs) +t+ ys  =  x :t: (xs +t+ ys)

  -- Option and pair types, used with tokens for parse return
  data Option {a} (A : Set a) : Set a where
    None : Option A
    Some : A → Option A

  -- Can use Pair.fst on a pair type to get back the first etc.
  -- Construct with a × b i hope
  record Pair (A B : Set) : Set where
    constructor _×_
    field
      fst : A
      snd : B

  --- PARSING FUNCTIONS ---

  -- Token Split : Searches for the first instance of the given string not in parentheses in the given token list
  -- Splits the list at that point, and return either left or right half, depending on which function was called
  -- Avoid calling this function with "(" or ")" unless you're careful about removing parens
  stopper : Tokens → Bool
  stopper [t] = true
  stopper ("}" :t: tkns) = true
  stopper tkns = false

  -- Removes the given string from the front of tokens. Gives back an empty token list if the string was not found at the front
  eat : Tokens → String → Tokens
  eat [t] str = [t]
  eat (s1 :t: tkns) s2 with primStringEquality s1 s2
  ... | false = [t]
  ... | true = tkns

  -- Returns the first token as a name (could add checking to confirm it isn't a number/doesn't use a unallowed symbol)
  eatName : Tokens → String
  eatName [t] = ""
  eatName (s :t: tkns) = s

  -- Checks if a given character list is a number --
  isNumber : List Char → Bool
  isNumber [] = false
  isNumber (c ∷ []) with primIsDigit c
  ... | true = true
  ... | false = false
  isNumber (c ∷ chars) with primIsDigit c
  ... | true = isNumber chars
  ... | false = false

  -- Converts string to a nat, using arithmetic from miCro file
  strNatHelper : Nat → List Char → Nat
  strNatHelper n [] = n 
  strNatHelper n (m ∷ chars) = (strNatHelper ((n * 10) + ((primCharToNat m) - 48)) chars) 

  -- Please don't call this on non-numbers
  stringToNat : String → Nat
  stringToNat str = strNatHelper 0 (primStringToList str)

  -- Checks to see if a word is a keyword or if it should be treated as a var (assumes numbers filtered already; may change that later)
  -- Maybe should get a better workaround than this; current issue is parseExp will read so much as a var, esp. an issue with its call in parseComp
  isVarName : String → Bool
  isVarName "" = false
  isVarName "true" = false
  isVarName "false" = false
  isVarName "while" = false
  isVarName "and" = false
  isVarName "or" = false
  isVarName "(" = false
  isVarName ")" = false
  isVarName "[" = false
  isVarName "]" = false
  isVarName str = true
  -- may need more cases to handle symbols; will figure that out

  -- Parsing functions, directly interacting with the stream and parsing it. Split into condition, expression, and statement

  -- Parse functions for Conditions and Expressions, which are handled separately --
  {-# TERMINATING #-}
  parseExp : Tokens → (Option (Pair Tokens Exp))
  parseSum : Tokens → (Option (Pair Tokens Exp))
  parseMult : Tokens → (Option (Pair Tokens Exp))
  parseRestOfSum : Exp → Tokens → (Option (Pair Tokens Exp))
  parseRestOfMult : Exp → Tokens → (Option (Pair Tokens Exp))
  parseRead : Tokens → (Option (Pair Tokens Exp))
  parseAtom : Tokens → (Option (Pair Tokens Exp))
  parseVar : Tokens → (Option (Pair Tokens Exp))

  parseExp [t] = None -- need to make sure this works
  parseExp tkns = parseSum tkns

  parseSum tkns with parseMult tkns
  ... | None = None
  ... | Some (t × e) = parseRestOfSum e t

  parseRestOfSum e ("+" :t: tkns) with parseMult tkns
  ... | None = None
  ... | Some (t × e2) = parseRestOfSum (plus e e2) t
  parseRestOfSum e ("-" :t: tkns) with parseMult tkns
  ... | None = None
  ... | Some (t × e2) = parseRestOfSum (minus e e2) t
  parseRestOfSum e tkns = Some (tkns × e)

  parseMult tkns with parseRead tkns
  ... | None = None
  ... | Some (t × e) = parseRestOfMult e t

  parseRestOfMult e ("*" :t: tkns) with parseRead tkns
  ... | None = None
  ... | Some (t × e2) = parseRestOfMult (times e e2) t
  parseRestOfMult e tkns = Some (tkns × e)

  parseRead ("&" :t: tkns) with parseAtom tkns
  ... | None = None
  ... | Some (t × e) = Some (t × (readAddress e))
  parseRead tkns = parseAtom tkns

  parseAtom ("[" :t: tkns) with parseExp tkns
  ... | None = None
  ... | Some (t × e) = Some ((eat t "]") × e)
  parseAtom (str :t: tkns) with isNumber (primStringToList str)
  ... | true = Some (tkns × (const (stringToNat str)))
  ... | false = parseVar (str :t: tkns)
  parseAtom [t] = None --I think, might change later

  parseVar (str :t: tkns) with isVarName str
  ... | false = None
  ... | true = Some (tkns × (readVar str))
  parseVar [t] = None

  {-# TERMINATING #-} --Note: Will need to add ability to process literal booleans (t/f) later, unless not needed
  parseCnd : Tokens → Option (Pair Tokens Cnd)
  parseDisj : Tokens → Option (Pair Tokens Cnd)
  parseConj : Tokens → Option (Pair Tokens Cnd)
  parseNeg : Tokens → Option (Pair Tokens Cnd)
  parseComp : Tokens → Option (Pair Tokens Cnd)
  parseBaseCnd : Tokens → Option (Pair Tokens Cnd)
  parseRestOfDisj : Cnd → Tokens → Option (Pair Tokens Cnd)
  parseRestOfConj : Cnd → Tokens → Option (Pair Tokens Cnd)
  parseRestOfComp : Exp → Tokens → Option (Pair Tokens Cnd)

  parseCnd [t] = None
  parseCnd tkns = parseDisj tkns

  parseDisj tkns with parseConj tkns
  ... | None = None
  ... | Some (t × c) = parseRestOfDisj c t

  parseRestOfDisj c ("or" :t: tkns) with parseConj tkns
  ... | None = None
  ... | Some (t × c2) = parseRestOfDisj (c Or c2) t
  parseRestOfDisj c tkns = Some (tkns × c)

  parseConj tkns with parseNeg tkns
  ... | None = None
  ... | Some (t × c) = parseRestOfConj c t

  parseRestOfConj c ("and" :t: tkns) with parseNeg tkns
  ... | None = None
  ... | Some (t × c2) = parseRestOfConj (c And c2) t
  parseRestOfConj c tkns = Some (tkns × c)

  parseNeg ("not" :t: tkns) with parseNeg tkns
  ... | None = None
  ... | Some (t × c) = Some (t × (Not c))
  parseNeg tkns = parseComp tkns

  -- At this point, we attempt to parse what's next as an expression. If that fails, we ignore it, and continue parsing comparisons, where syntax errors would still be caught
  parseComp tkns with parseExp tkns
  ... | None = parseBaseCnd tkns
  ... | Some (t × e) = parseRestOfComp e t

  parseRestOfComp e ("==" :t: tkns) with parseExp tkns
  ... | None = None
  ... | Some (t × e2) = Some (t × (e == e2))
  parseRestOfComp e ("!=" :t: tkns) with parseExp tkns
  ... | None = None
  ... | Some (t × e2) = Some (t × (e != e2))
  parseRestOfComp e ("<=" :t: tkns) with parseExp tkns
  ... | None = None
  ... | Some (t × e2) = Some (t × (e <= e2))
  parseRestOfComp e (">=" :t: tkns) with parseExp tkns
  ... | None = None
  ... | Some (t × e2) = Some (t × (e >= e2))
  parseRestOfComp e ("<" :t: tkns) with parseExp tkns
  ... | None = None
  ... | Some (t × e2) = Some (t × (e < e2))
  parseRestOfComp e (">" :t: tkns) with parseExp tkns
  ... | None = None
  ... | Some (t × e2) = Some (t × (e > e2))
  parseRestOfComp e tkns = None --If we manage to parse an expression but are missing a proper comparison we throw an error, assuming no condition could parse as an expression.
  -- Rest should be filled out likewise

  parseBaseCnd ("(" :t: tkns) with parseCnd tkns
  ... | None = None
  ... | Some (t × c) = Some ((eat t ")") × c)
  parseBaseCnd ("true" :t: tkns) = Some (tkns × (cndBool true))
  parseBaseCnd ("false" :t: tkns) = Some (tkns × (cndBool false))
  parseBaseCnd other = None --shouldn't be anything else here that could be correct

  -- Statement parse functions --
  {-# TERMINATING #-}
  parseStmt1 : Tokens → (Option (Pair Tokens Stmt))
  parseStmt2 : (Option (Pair Tokens Stmt)) → (Option (Pair Tokens Stmt))
  parseStmt3 : (Option (Pair Tokens Stmt)) → (Option (Pair Tokens Stmt))
  parseSingleStmt : Tokens → (Option (Pair Tokens Stmt))
  parseRestOfWhile : Cnd → Tokens → (Option (Pair Tokens Stmt))
  parseRestOfIf : Cnd → Tokens → (Option (Pair Tokens Stmt))
  parseRestOfIfElse : Cnd → Stmt → Tokens → (Option (Pair Tokens Stmt))
  parseRestOfWrite : Exp → Tokens → (Option (Pair Tokens Stmt))

  -- Main Stmt parser; this continually creates a sequence of parsed stmts 
  parseStmt1 [t] = None
  parseStmt1 tkns = parseStmt2 (parseSingleStmt tkns)

  -- Helper function for Stmt1; if these combined I would have to write out parseSingleStmt tkns about five times (since I can't use "with" in a "let ... in"), which would mean five times slower parsing
  parseStmt2 None = None
  parseStmt2 (Some (t × s)) with stopper t
  ... | true = (Some ([t] × s))
  ... | false = parseStmt3 (Some (t × s)) -- Now we want "(Some ([t] × (Seq s (parseStmt1 t))))", but we must first check that parseStmt1 gives a Some return

  -- Another helper, since we need to make a Seq in second case above, but need to know we got back some Stmt and not a None option
  parseStmt3 None = None
  parseStmt3 (Some (tkns × s)) with parseStmt1 tkns
  ... | None = None
  ... | Some (t × s2) = (Some ([t] × (Seq s s2)))

  -- Parses a single statement from the tokens; does the "heavy lifting" stmt parsing
  parseSingleStmt [t] = (Some ([t] × No-op)) -- don't know if I need this, but just want to catch errors
  parseSingleStmt ("while" :t: tkns) with (parseCnd (eat tkns "("))
  ... | None = None
  ... | Some (tkns2 × c) = parseRestOfWhile c (eat (eat tkns2 ")") "{")
  parseSingleStmt ("if" :t: tkns) with (parseCnd (eat tkns "("))
  ... | None = None
  ... | Some (tkns2 × c) = parseRestOfIf c (eat (eat tkns2 ")") "{")
  parseSingleStmt ("*" :t: tkns) with parseExp (eat (eat tkns (eatName tkns)) "=") -- A little cheaty since this sort of looks two tokens ahead
  ... | None = None
  ... | Some (tkns2 × e) = Some ((eat tkns2 ";") × (AssignPtr (eatName tkns) e))
  parseSingleStmt ("&" :t: tkns) with parseExp tkns
  ... | None = None
  ... | Some (tkns2 × e) = parseRestOfWrite e (eat tkns2 "=")
  parseSingleStmt tkns with parseExp (eat (eat tkns (eatName tkns)) "=") --This will catch any other errors, as eat will return [t] if it can't eat the expeted token, leading to parseExp returning None
  ... | None = None
  ... | Some (tkns2 × e) = Some ((eat tkns2 ";") × (AssignVar Natural (eatName tkns) e))

  -- Parses the rest of a multi-part statement
  
  parseRestOfWhile c tkns with parseStmt1 tkns
  ... | None = None
  ... | Some (t × s) = Some ((eat t "}") × (While c s))

  parseRestOfIf c tkns with parseStmt1 tkns
  ... | None = None
  ... | Some (t × s) = parseRestOfIfElse c s (eat tkns "}")

  parseRestOfIfElse c s ("else" :t: tkns) with parseStmt1 (eat tkns "{")
  ... | None = None
  ... | Some (t × s2) = Some ((eat t "}") × (IfElse c s s2))
  parseRestOfIfElse c s tkns = Some (tkns × (If c s))

  parseRestOfWrite e [t] = None
  parseRestOfWrite e tkns with parseExp tkns
  ... | None = None
  ... | Some (t × e2) = Some ((eat t ";") × (WriteHeap e e2))

  -- Top level parser function; calls the other parsers and converts from the option (token stmt) type to the appropriate stmt
  parseTokens : Tokens → Stmt
  parseTokens tkns with parseStmt1 tkns
  ... | None  = No-op --The program failed to parse
  ... | (Some ([t] × s)) = s
  ... | (Some (t × s)) = (Seq No-op No-op) --Parser thinks it worked, but didn't finish parsing

  -- Main function; parses and then runs the program with empty intial RAM
  run : Tokens → RAM
  run t = exec ([e] & [h]) (parseTokens t)



--- Extra Notes ---
-- No ++ is allowed, since right now that reads as a plus operator (solution would be to make it process to "++":t:tkns)
-- Tokenizer should split on ; , { } ( ) operators etc
