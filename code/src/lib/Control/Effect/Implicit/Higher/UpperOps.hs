{-# Language UndecidableInstances #-}

module Control.Effect.Implicit.Higher.UpperOps
where

import Data.Kind
import Control.Effect.Implicit.Base
import Control.Effect.Implicit.Higher.EffFunctor

data UpperOps ops
  (inEff :: Type -> Type)
  eff
  = UpperOps
    { innerOps' :: ops inEff
    , outerOps' :: ops eff
    }


instance
  (Effect eff, EffFunctor ops)
  => EffFunctor (UpperOps ops eff)
  where
    effmap _ = undefined

instance
  (EffFunctor ops)
  => HigherEffFunctor (UpperOps ops)
   where
    invEffmap _ = undefined
    contraEffmap _ = undefined