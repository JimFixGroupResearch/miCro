-- First: Read from file into string --

-- process env = initial environment read from string
-- process prog = instructions read from string
-- run exec env prog, and return (print?) output

-- Tokens and related functions --
-- At this point we assume the input file has been parsed into tokens type
-- Token type is a list of strings with all whitespace removed, separated on special characters
-- So "while" should be one list entry, with the proceeding "(" being it's own, and so on.

module miCro_parser where

  open import miCro

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

  --- PARSING FUNCTIONS ---

  -- Token Split : Searches for the first instance of the given string not in parentheses in the given token list
  -- Splits the list at that point, and return either left or right half, depending on which function was called
  -- Avoid calling this function with "(" or ")" unless you're careful about removing parens
  {-# TERMINATING #-}
  splitL : Tokens → String → Tokens
  splitR : Tokens → String → Tokens
  
  splitL [t] str = [t]
  splitL ( "(" :t: tkns) str = "(" :t: ((splitL tkns ")" ) +t+ (")" :t: (splitL (splitR tkns ")" ) str)))
  splitL ( "{" :t: tkns) str = "{" :t: ((splitL tkns "}" ) +t+ ("}" :t: (splitL (splitR tkns "}" ) str)))
  splitL ( "[" :t: tkns) str = "[" :t: ((splitL tkns "]" ) +t+ ("]" :t: (splitL (splitR tkns "]" ) str)))
  splitL (str1 :t: tkns) str2 with primStringEquality str1 str2
  ...                           | true = [t]
  ...                           | false = str1 :t: (splitL tkns str2)

  splitR [t] str = [t]
  splitR ( "(" :t: tkns) str = splitR (splitR tkns ")" ) str
  splitR ( "{" :t: tkns) str = splitR (splitR tkns "}" ) str
  splitR ( "[" :t: tkns) str = splitR (splitR tkns "]" ) str
  splitR (str1 :t: tkns) str2 with primStringEquality str1 str2
  ...                           | true = tkns
  ...                           | false = splitR tkns str2

  --And another helper function for curly brackets, since split needs to treat them like parens but we can't remove them as easily (since we use "(" :t: tkns and cant do "(" tkns "{" etc)
  trimTo : Tokens → String → Tokens
  trimTo [t] str = [t]
  trimTo (str1 :t: tkns) str2 with primStringEquality str1 str2
  ... | true = tkns
  ... | false = trimTo tkns str2

  -- Token Search : searches the tokens for the first instance of given string that is not in parentheses/brackets/braces
  -- Returns true if one is found, false otherwise
  {-# TERMINATING #-}
  token_search : Tokens → String → Bool
  token_search [t] str = false
  token_search ("(" :t: tkns) str = token_search (splitR tkns ")" ) str
  token_search ("{" :t: tkns) str = token_search (splitR tkns "}" ) str
  token_search ("[" :t: tkns) str = token_search (splitR tkns "]" ) str
  token_search (str1 :t: tkns) str2 with primStringEquality str1 str2
  ...                                 | true = true
  ...                                 | false = token_search tkns str2

  -- Comparison Token Search : Searches for one of six comparisons (outside of parentheses) and returns the first found
  -- If things were written properly, the first found should be the only one, and if none is found, then "none" is returned
  {-# TERMINATING #-}
  comp_token_search : Tokens → String
  comp_token_search  [t] = "none"
  comp_token_search ("(" :t: tkns) = comp_token_search (splitR tkns ")" )
  comp_token_search ("{" :t: tkns) = comp_token_search (splitR tkns "}" )
  comp_token_search ("[" :t: tkns) = comp_token_search (splitR tkns "]" )
  comp_token_search ( "==" :t: tkns) = "=="
  comp_token_search ( "!=" :t: tkns) = ">="
  comp_token_search ( "<=" :t: tkns) = "<="
  comp_token_search ( ">=" :t: tkns) = ">="
  comp_token_search ( "<" :t: tkns) = "<"
  comp_token_search ( ">" :t: tkns) = ">"
  comp_token_search (str :t: tkns) = comp_token_search tkns

  -- Plus/Minus search: Similarly returns the first instance of "+" or "-" if one occurs
  {-# TERMINATING #-}
  pm_search : Tokens → String
  pm_search [t] = "none"
  pm_search ("(" :t: tkns) = pm_search (splitR tkns ")" )
  pm_search ("{" :t: tkns) = pm_search (splitR tkns "}" )
  pm_search ("[" :t: tkns) = pm_search (splitR tkns "]" )
  pm_search ("+" :t: tkns) = "+"
  pm_search ("-" :t: tks) = "-"
  pm_search (str :t: tkns) = pm_search tkns

  -- Checks if a given character list is a number --
  is_number : List Char → Bool
  is_number [] = false
  is_number (c ∷ []) with primIsDigit c
  ... | true = true
  ... | false = false
  is_number (c ∷ chars) with primIsDigit c
  ... | true = is_number chars
  ... | false = false

  -- Converts string to a nat, using arithmetic from miCro file
  str_nat_helper : Nat → List Char → Nat
  str_nat_helper n [] = n 
  str_nat_helper n (m ∷ chars) = (str_nat_helper ((n * 10) + ((primCharToNat m) - 48)) chars) 

  -- Please don't call this on non-numbers
  string_to_nat : String → Nat
  string_to_nat str = str_nat_helper 0 (primStringToList str)

  -- Parsing functions, directly interacting with the stream and parsing it. Split into condition, expression, and statement

  -- Parse functions for Conditions and Expressions, which are handled separately --
  {-# TERMINATING #-}
  parse_exp : Tokens → Exp
  parse_pm : Tokens → Exp
  parse_plus_rest : Exp → Tokens → Exp
  parse_minus_rest : Exp → Tokens → Exp
  parse_mult : Tokens → Exp
  parse_address : Tokens → Exp
  parse_parens_exp : Tokens → Exp
  parse_term : Tokens → Exp

  parse_exp tkns = parse_pm tkns
  parse_pm tkns with pm_search tkns
  ... | "+" = parse_plus_rest (parse_mult (splitL tkns "+")) (splitR tkns "+")
  ... | "-" = parse_minus_rest (parse_mult (splitL tkns "-")) (splitR tkns "-")
  ... | none = parse_mult tkns

  parse_plus_rest exp tkns with pm_search tkns
  ... | "+" = parse_plus_rest (plus exp (parse_mult (splitL tkns "+"))) (splitR tkns "+")
  ... | "-" = parse_minus_rest (plus exp (parse_mult (splitL tkns "-"))) (splitR tkns "-")
  ... | none = (plus exp (parse_exp tkns))

  parse_minus_rest exp tkns with pm_search tkns
  ... | "+" = parse_plus_rest (minus exp (parse_mult (splitL tkns "+"))) (splitR tkns "+")
  ... | "-" = parse_minus_rest (minus exp (parse_mult (splitL tkns "-"))) (splitR tkns "-")
  ... | none = (minus exp (parse_exp tkns))

  parse_mult tkns with token_search tkns "*"
  ... | true = times (parse_address (splitL tkns "*")) (parse_mult (splitR tkns "*"))
  ... | false = parse_address tkns

  parse_address ("[" :t: tkns) = (readAddress (parse_exp (splitL tkns "]")))
  parse_address tkns = parse_parens_exp tkns

  parse_parens_exp ( "(" :t: tkns) = parse_exp (splitL tkns ")")
  parse_parens_exp tkns = parse_term tkns

  parse_term (str :t: [t]) with is_number (primStringToList str) -- At this point we should either have a number or a var; otherwise there's been some error
  ... | true = (const (string_to_nat str))
  ... | false = (readVar str) 
  parse_term [t] = (const 99) -- Unexpected EOF; token stream ended before it should have
  parse_term tkns = (const 400) -- Bad syntax; error on parsing leads to this

  {-# TERMINATING #-} --Note: Will need to add ability to process literal booleans (t/f) later, unless not needed
  parse_condition : Tokens → Cnd
  parse_disjunction : Tokens → Cnd
  parse_conjunction : Tokens → Cnd
  parse_negation : Tokens → Cnd
  parse_comparison : Tokens → Cnd
  parse_literal : Tokens → Cnd
  parse_parens_cnd : Tokens → Cnd

  parse_condition tkns = parse_disjunction tkns

  parse_disjunction tkns with token_search tkns "or"
  ...                       | true = ((parse_conjunction (splitL tkns "or")) Or (parse_disjunction (splitR tkns "or")))
  ...                       | false = parse_conjunction tkns

  parse_conjunction tkns with token_search tkns "and"
  ...                       | true = ((parse_negation (splitL tkns "and")) And (parse_conjunction (splitR tkns "and")))
  ...                       | false = parse_negation tkns

  parse_negation ("not" :t: tkns) = (Not (parse_negation tkns))
  parse_negation tkns = parse_comparison tkns

  parse_comparison tkns with comp_token_search tkns
  ... | "==" = ((parse_exp (splitL tkns "==")) == (parse_exp (splitR tkns "==")))
  ... | "!=" = ((parse_exp (splitL tkns "!=")) != (parse_exp (splitR tkns "!=")))
  ... | "<=" = ((parse_exp (splitL tkns "<=")) <= (parse_exp (splitR tkns "<=")))
  ... | ">=" = ((parse_exp (splitL tkns ">=")) >= (parse_exp (splitR tkns ">=")))
  ... | "<" = ((parse_exp (splitL tkns "<")) < (parse_exp (splitR tkns "<")))
  ... | ">" = ((parse_exp (splitL tkns ">")) > (parse_exp (splitR tkns ">")))
  ... | none = parse_literal tkns -- none just as generic pattern here to satisfy agda, although string "none" will be returned in this case

  parse_literal ("true" :t: [t]) = (cndBool true)
  parse_literal ("false" :t: [t]) = (cndBool false)
  parse_literal tkns = parse_parens_cnd tkns

  parse_parens_cnd ( "(" :t: tkns) = parse_condition (splitL tkns ")")
  parse_parens_cnd other = (cndBool false) --Error; this step should never be reached unless program was written wrong. Should raise error here once I find out how/if I can

  -- Statement parse function; directly parses statements and makes calls to parse conditions and expressions --
  {-# TERMINATING #-}
  parse_stmt : Tokens → Stmt
  parse_stmt [t] = No-op
  parse_stmt ("if" :t: ("(" :t: tkns)) = Seq (If (parse_condition (splitL tkns ")")) (parse_stmt (splitL (trimTo tkns "{") "}"))) (parse_stmt (splitR tkns ";"))
  parse_stmt ("ifElse" :t: ( "("  :t: tkns)) = Seq (IfElse (parse_condition (splitL tkns ")")) (parse_stmt (splitL (trimTo tkns "{") "}")) (parse_stmt (splitL (splitR (trimTo tkns "}") "{") "}"))) (parse_stmt (splitR tkns ";"))
  parse_stmt ("while" :t:( "(" :t: tkns)) =  Seq (While (parse_condition (splitL tkns ")")) (parse_stmt (splitL (trimTo tkns "{") "}"))) (parse_stmt (splitR tkns ";"))
  parse_stmt ("ptr" :t: str :t: "=" :t: tkns) = Seq (AssignPtr str (parse_exp (splitL tkns ";"))) (parse_stmt (splitR tkns ";"))
  parse_stmt ("[" :t: tkns) = Seq (WriteHeap (parse_exp (splitL tkns "]")) (parse_exp (splitL (splitR tkns "=") ";"))) (parse_stmt (splitR tkns ";"))
  parse_stmt (str :t: ( "=" :t: tkns)) = Seq (AssignVar Natural str (parse_exp (splitL tkns ";"))) (parse_stmt (splitR tkns ";"))
  parse_stmt error = No-op

  -- Environment Parse Function; parses the INIT variables attached to the beginning of a program; assumes it's passed a single proper init line
  parse_env : Tokens → Env
  parse_env [t] = [e]
  parse_env (str :t: ("=" :t: (num :t: tkns))) with is_number (primStringToList num)
  ... | true = ((Var Natural str (string_to_nat num)) :e: (parse_env tkns))
  ... | false = parse_env tkns
  parse_env (other :t: tkns) = parse_env tkns

  -- Main function; parses the environment and program statements, then runs the whole thing and returns end environment
  run : Tokens → RAM
  run ("INIT" :t: tkns) = exec ((parse_env (splitL tkns ";")) & [h]) (parse_stmt (splitR tkns ";"))
  run error = [e] & [h]

--- Extra Notes ---
-- No ++ is allowed, since right now that reads as a plus operator (solution would be to make it process to "++":t:tkns)
-- Tokenizer should split on ; , { } ( ) operators etc
