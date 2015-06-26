module defeq where

open import lib
open import cedille-types
open import rename 
open import tpstate

{- we will rename variables away from strings recognized by the given
   predicate.  Currently, we are not checking termination, though this
   could maybe be done by bounding the size of the domain of the
   tpstate.  This size would decrease when we follow a definition. -}

-- the predicate just needs to return tt for bound local variables (not global ones)

{-# NO_TERMINATION_CHECK #-}
eq-kind : tpstate → (var → 𝔹) → renamectxt → kind → kind → 𝔹 
eq-type : tpstate → (var → 𝔹) → renamectxt → type → type → 𝔹 
eq-kind-pi : tpstate → (var → 𝔹) → renamectxt → var → tk → kind → kind → 𝔹 
eq-term : tpstate → (var → 𝔹) → renamectxt → term → term → 𝔹
eq-term-var : tpstate → (var → 𝔹) → renamectxt → var → term → 𝔹
eq-kind s b r (KndParens k) k' = eq-kind s b r k k'
eq-kind s b r k (KndParens k') = eq-kind s b r k k'
eq-kind s b r (KndArrow k1 k2) k' = eq-kind-pi s b r (tpstate-fresh-var s b "X" r) (Tkk k1) k2 k'
eq-kind s b r k (KndArrow k1' k2') = eq-kind-pi s b r (tpstate-fresh-var s b "X" r) (Tkk k1') k2' k
eq-kind s b r (KndTpArrow t k) k' = eq-kind-pi s b r (tpstate-fresh-var s b "x" r) (Tkt t) k k'
eq-kind s b r k (KndTpArrow t' k') = eq-kind-pi s b r (tpstate-fresh-var s b "x" r) (Tkt t') k' k
eq-kind s b r (KndPi x (Tkk k1) k2) k = eq-kind-pi s b r x (Tkk k1) k2 k
eq-kind s b r k (KndPi x' (Tkk k1') k2') = eq-kind-pi s b r x' (Tkk k1') k2' k
eq-kind s b r (KndPi x (Tkt t) k) k' = eq-kind-pi s b r x (Tkt t) k k'
eq-kind s b r k (KndPi x' (Tkt t') k') = eq-kind-pi s b r x' (Tkt t') k' k
eq-kind s b r Star Star = tt
eq-kind s b r k (KndVar v) with lookup-kind-var s v
eq-kind s b r k (KndVar v) | just k' = eq-kind s b r k k'
eq-kind s b r k (KndVar v) | nothing = ff
eq-kind s b r (KndVar v) k' with lookup-kind-var s v
eq-kind s b r (KndVar v) k' | just k = eq-kind s b r k k'
eq-kind s b r (KndVar v) k' | nothing = ff

eq-kind-pi s b r X a k2 (KndParens k) = eq-kind-pi s b r X a k2 k -- redundant case, but Agda can't tell
eq-kind-pi s b r X (Tkk k1) k2 (KndArrow k1' k2') = eq-kind s b r k1 k1' && eq-kind s b r k2 k2'
eq-kind-pi s b r X (Tkk k1) k2 (KndPi v (Tkk k1') k2') = 
  eq-kind s b r k1 k1' && eq-kind s b (renamectxt-insert r X v) k2 k2'
eq-kind-pi s b r X (Tkk k1) k2 (KndPi x (Tkt _) k') = ff
eq-kind-pi s b r X (Tkk k1) k2 (KndTpArrow x k') = ff
eq-kind-pi s b r X a k2 (KndVar x) with lookup-kind-var s (renamectxt-rep r x)
eq-kind-pi s b r X a k2 (KndVar x) | just k = eq-kind-pi s b r X a k2 k
eq-kind-pi s b r X a k2 (KndVar x) | nothing = ff
eq-kind-pi s b r X (Tkk k1) k2 Star = ff
eq-kind-pi s b r X (Tkt t) k (KndTpArrow t' k') = eq-type s b r t t' && eq-kind s b r k k'
eq-kind-pi s b r X (Tkt t) k (KndPi x (Tkt t') k') =
  eq-type s b r t t' && eq-kind s b (renamectxt-insert r X x) k k'
eq-kind-pi s b r X (Tkt t) k (KndPi v (Tkk _) k2') = ff
eq-kind-pi s b r X (Tkt t) k (KndArrow k1' k2') = ff
eq-kind-pi s b r X (Tkt t) k Star = ff

eq-term s b r t (Parens t') = eq-term s b r t t'
eq-term s b r (Parens t) t' = eq-term s b r t t'
eq-term s b r (App t1 t2) (App t1' t2') = eq-term s b r t1 t1' && eq-term s b r t2 t2'
eq-term s b r (Var x) t' = eq-term-var s b r (renamectxt-rep r x) t'
eq-term s b r t (Var x) = eq-term-var s b r x t
eq-term s b r (Lam x1 t1) (Lam x2 t2) =
  eq-term s b (renamectxt-insert r x1 x2) t1 t2
eq-term s b r (Lam _ _) (App _ _) = ff
eq-term s b r (App _ _) (Lam _ _) = ff

eq-term-var s b r x t' with lookup-term-var s x 
eq-term-var s b r x t' | just t = eq-term s b r t t'
eq-term-var s b r x (Var y) | nothing with lookup-term-var s y
eq-term-var s b r x (Var y) | nothing | just t' = eq-term-var s b r x t'
eq-term-var s b r x (Var y) | nothing | nothing = eq-var r x y
eq-term-var s b r x (App _ _) | nothing = ff
eq-term-var s b r x (Lam _ _) | nothing = ff
eq-term-var s b r x (Parens t) | nothing = eq-term-var s b r x t

-- unimplemented:
eq-type s b r t t' = tt

