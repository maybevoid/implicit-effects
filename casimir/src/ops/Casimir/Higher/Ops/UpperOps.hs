{-# LANGUAGE UndecidableInstances #-}

module Casimir.Higher.Ops.UpperOps
where

import Data.Kind

import Casimir.Base
  ( EffFunctor (..)
  )
import Casimir.Higher

import qualified Casimir.Base as Base

data UpperEff ops

data UpperOps ops
  (inEff :: Type -> Type)
  (m :: Type -> Type)
  = UpperOps
    { innerOps' :: ops inEff
    , outerOps' :: ops m
    }

instance
  (Base.Effects ops)
  => Effects (UpperEff ops) where
    type Operations' (UpperEff ops) = UpperOps (Base.Operations' ops)

instance
  ( Monad m
  , EffFunctor lift ops
  )
  => EffFunctor lift (UpperOps ops m)
  where
    effmap lift (UpperOps ops1 ops2) =
      UpperOps ops1 (effmap lift ops2)


instance
  (EffFunctor lift ops)
  => HigherEffFunctor lift (UpperOps ops)
   where
    higherEffmap lift (UpperOps ops1 ops2) =
      UpperOps (effmap lift ops1) (effmap lift ops2)
