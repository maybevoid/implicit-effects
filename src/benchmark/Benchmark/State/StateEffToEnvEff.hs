
module Benchmark.State.StateEffToEnvEff
  ( stateEffToEnvEffToReaderTComp

  -- The simple action of exporting a specialized
  -- Identity base monad improves performance by ~25%
  , stateEffToEnvEffToReaderTIdentityComp
  )
where

import Control.Monad.Identity
import Control.Monad.Trans.Reader (ReaderT)
import Control.Monad.Trans.State.Strict (StateT, evalStateT)

import Control.Effect
import Benchmark.State.Base

stateEffToEnvEffPipeline
  :: forall s a eff1
   . (Effect eff1)
  => Computation (StateEff s) (Return a) eff1
  -> Computation (EnvEff s) (Return a) eff1
stateEffToEnvEffPipeline comp1 = Computation comp2
 where
  comp2 :: forall eff2 . (Effect eff2)
    => LiftEff eff1 eff2
    -> Operation (EnvEff s) eff2
    -> Return a eff2
  comp2 lift12 ops = withOps ops $ Return comp5
   where
    comp3 :: Computation NoEff (Return a) (StateT s eff2)
    comp3 = bindHandlerWithCast
      stateTHandler
      (liftComputation lift12 comp1)
      cast cast

    comp4 :: StateT s eff2 a
    comp4 = returnVal $ runComp comp3 idLift NoOp

    comp5 :: (OpsConstraint (EnvEff s) eff2) => eff2 a
    comp5 = do
      s <- ask
      res <- evalStateT comp4 s
      return res

statePComp1
  :: forall eff . (Effect eff)
  => Computation (EnvEff Int) (Return ()) eff
statePComp1 = stateEffToEnvEffPipeline stateBaseComp

statePComp2
  :: forall eff . (Effect eff)
  => Computation NoEff (Return ()) (ReaderT Int eff)
statePComp2 = bindHandlerWithCast
  readerTHandler statePComp1
  cast cast

stateEffToEnvEffToReaderTComp
  :: forall eff . (Effect eff)
  => ReaderT Int eff ()
stateEffToEnvEffToReaderTComp = returnVal $ runComp statePComp2 idLift NoOp

stateEffToEnvEffToReaderTIdentityComp
  :: ReaderT Int Identity ()
stateEffToEnvEffToReaderTIdentityComp = stateEffToEnvEffToReaderTComp