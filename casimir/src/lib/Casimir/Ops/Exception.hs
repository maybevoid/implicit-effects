module Casimir.Ops.Exception
where

import Data.Void
import qualified Control.Exception as Ex

import Casimir.Base
import Casimir.Free
import Casimir.Computation

import Casimir.Ops.Io

data ExceptionEff e

data ExceptionOps e eff = ExceptionOps {
  raiseOp :: e -> eff Void
}

data ExceptionCoOp e r =
  RaiseOp e

instance EffOps (ExceptionEff e) where
  type Operation (ExceptionEff e) = ExceptionOps e

instance EffCoOp (ExceptionEff e) where
  type CoOperation (ExceptionEff e) = ExceptionCoOp e

instance EffFunctor Lift (ExceptionOps e) where
  effmap (Lift lift) ops = ExceptionOps {
    raiseOp = \e -> lift $ raiseOp ops e
  }

instance Functor (ExceptionCoOp e) where
  fmap _ (RaiseOp e) = RaiseOp e

instance FreeOps (ExceptionEff e) where
  mkFreeOps liftCoOp = ExceptionOps {
    raiseOp = \e -> liftCoOp $ RaiseOp e
  }

type ExceptionConstraint e eff =
  (?_Control_Effect_Implicit_Ops_Exception_exceptionOps :: ExceptionOps e eff)

instance ImplicitOps (ExceptionEff e) where
  type OpsConstraint (ExceptionEff e) eff = ExceptionConstraint e eff

  withOps ops comp =
    let
      ?_Control_Effect_Implicit_Ops_Exception_exceptionOps
        = ops in comp

  captureOps =
    ?_Control_Effect_Implicit_Ops_Exception_exceptionOps

raise
  :: forall e a eff
   . (Effect eff, ExceptionConstraint e eff)
  => e
  -> eff a
raise e = raiseOp captureOps e >>= absurd

mkExceptionCoOpHandler
  :: forall eff e a
   . (Effect eff)
  => (e -> eff a)
  -> CoOpHandler (ExceptionEff e) a a eff
mkExceptionCoOpHandler handleException =
  CoOpHandler return $
    \(RaiseOp e) -> handleException e

exceptionToEitherHandler
  :: forall eff e a
   . (Effect eff)
  => CoOpHandler (ExceptionEff e) a (Either e a) eff
exceptionToEitherHandler =
  CoOpHandler handleReturn handleCoOp
   where
    handleReturn x = return $ Right x
    handleCoOp (RaiseOp e) = return $ Left e

tryIo
  :: forall e a .
    (Ex.Exception e)
  => IO a
  -> Eff (IoEff ∪ (ExceptionEff e)) a
tryIo m = do
  res <- liftIo $ Ex.try @e m
  case res of
    Left err -> raise err
    Right val -> return val

try
  :: forall free eff e a
   . ( Effect eff
     , FreeHandler free
     )
  => (OpsConstraint (ExceptionEff e) (free (ExceptionEff e) eff)
      => free (ExceptionEff e) eff a)
  -> (e -> eff a)
  -> eff a
try comp handler1 = withCoOpHandler @free handler2 comp
 where
  handler2 :: CoOpHandler (ExceptionEff e) a a eff
  handler2 = CoOpHandler return $
    \(RaiseOp e) -> handler1 e

tryFinally
  :: forall free eff e a
   . ( FreeHandler free
     , EffConstraint (ExceptionEff e) eff
     )
  => ((OpsConstraint (ExceptionEff e) (free (ExceptionEff e) eff))
      => free (ExceptionEff e) eff a)
  -> (() -> eff ())
  -> eff a
tryFinally comp handler1 =
 do
  res1' <- res1
  handler1 ()
  res2 res1'
   where
    res1 :: eff (Either e a)
    res1 = withCoOpHandler @free exceptionToEitherHandler comp

    res2 :: Either e a -> eff a
    res2 res
      = case res of
        Left e -> raise e
        Right x -> return x

tryComp
  :: forall free eff ops e a
   . ( FreeHandler free
     , EffOps ops
     , ImplicitOps ops
     , EffConstraint ops eff
     , EffFunctor Lift (Operation ops)
     )
  => Computation Lift ((ExceptionEff e) ∪ ops) (Return a) eff
  -> (e -> eff a)
  -> eff a
tryComp comp1 handler1 = handleFree handler2 comp2
 where
  comp2 :: free (ExceptionEff e) eff a
  comp2 = returnVal $ runComp comp1 freeLiftEff $
    UnionOps freeOps $ effmap (Lift liftFree) captureOps

  handler2 :: CoOpHandler (ExceptionEff e) a a eff
  handler2 = CoOpHandler return $
    \(RaiseOp e) -> handler1 e

bracketComp
  :: forall free eff ops e a b
   . ( FreeHandler free
     , EffOps ops
     , ImplicitOps ops
     , EffConstraint ops eff
     , EffFunctor Lift (Operation ops)
     )
  => BaseComputation ((ExceptionEff e) ∪ ops) (Return a) eff          -- init
  -> (a -> BaseComputation ((ExceptionEff e) ∪ ops) (Return ()) eff)  -- cleanup
  -> (a -> BaseComputation ((ExceptionEff e) ∪ ops) (Return b) eff)   -- between
  -> BaseComputation ((ExceptionEff e) ∪ ops) (Return b) eff
bracketComp initComp cleanupComp betweenComp = Computation comp1
 where
  comp1
    :: forall eff2
     . (Effect eff2)
    => Lift eff eff2
    -> Operation ((ExceptionEff e) ∪ ops) eff2
    -> Return b eff2
  comp1 lift12 ops@(UnionOps eOps ops1) = Return comp5
   where
    comp2 :: eff2 a
    comp2 = returnVal $ runComp initComp lift12 ops

    comp3 :: a -> eff2 (Either e b)
    comp3 x = handleFree @free
      exceptionToEitherHandler $ returnVal $
        runComp (betweenComp x)
          (joinLift lift12 freeLiftEff) $
          UnionOps freeOps $
            effmap (Lift liftFree) ops1

    comp4 :: a -> eff2 ()
    comp4 x = returnVal $ runComp (cleanupComp x) lift12 ops

    comp5 :: eff2 b
    comp5 = do
      x <- comp2
      res <- comp3 x
      comp4 x
      case res of
        Left e -> raiseOp eOps e >>= absurd
        Right res' -> return res'
