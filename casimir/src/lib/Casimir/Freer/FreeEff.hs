
module Casimir.Freer.FreeEff
  ( FreeEff (..)
  , CoOpHandler (..)
  )
where

import Casimir.Base

import Casimir.Freer.CoOp
import Casimir.Freer.FreeOps

data CoOpHandler handler a r eff =
  CoOpHandler {
    returnHandler :: a -> eff r,
    coOpHandler
      :: forall x
       . CoOperation handler x
      -> (x -> (eff r))
      -> eff r
  }

class
  (forall ops eff . (FreeOps ops, Monad eff) => Monad (free ops eff))
  => FreeEff free where
    freeOps :: forall ops eff
      . (FreeOps ops, Monad eff)
      => Operation ops (free ops eff)

    liftFree :: forall ops eff a
       . (FreeOps ops, Monad eff)
      => eff a
      -> free ops eff a

    handleFree
      :: forall ops eff a r
      . (Monad eff, FreeOps ops)
      => CoOpHandler ops a r eff
      -> free ops eff a
      -> eff r
