module Control.Effect.Ops.Exception
where

import Data.Void
import qualified Control.Exception as Ex

import Control.Effect.Base
import Control.Effect.Ops.Io
import Control.Effect.Computation

data ExceptionEff e

data ExceptionOps e eff = ExceptionOps {
  raiseOp :: e -> eff Void
}

data ExceptionCoOp e r =
  RaiseOp e

type ExceptionConstraint e eff = (?exceptionOps :: ExceptionOps e eff)

instance EffFunctor (ExceptionOps e) where
  effmap lifter ops = ExceptionOps {
    raiseOp = \e -> lifter $ raiseOp ops e
  }

instance Functor (ExceptionCoOp e) where
  fmap _ (RaiseOp e) = RaiseOp e

instance FreeOps (ExceptionEff e) where
  type Operation (ExceptionEff e) = ExceptionOps e
  type CoOperation (ExceptionEff e) = ExceptionCoOp e

  mkFreeOps liftCoOp = ExceptionOps {
    raiseOp = \e -> liftCoOp $ RaiseOp e
  }

instance EffOps (ExceptionEff e) where
  type OpsConstraint (ExceptionEff e) eff = ExceptionConstraint e eff

  withOps ops comp = let ?exceptionOps = ops in comp

  captureOps = ?exceptionOps

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
mkExceptionCoOpHandler handleException = CoOpHandler {
  handleReturn = return,
  handleCoOp = \(RaiseOp e) -> handleException e
}

exceptionToEitherHandler
  :: forall eff e a
   . (Effect eff)
  => CoOpHandler (ExceptionEff e) a (Either e a) eff
exceptionToEitherHandler = CoOpHandler {
  handleReturn = \x -> return $ Right x,
  handleCoOp = \(RaiseOp e) -> return $ Left e
}

tryIo
  :: forall eff e a .
  ( Effect eff
  , Ex.Exception e
  , OpsConstraint IoEff eff
  , OpsConstraint (ExceptionEff e) eff
  )
  => IO a
  -> eff a
tryIo m = do
  res <- liftIo $ Ex.try @e m
  case res of
    Left err -> raise err
    Right val -> return val

tryIoHandler
  :: forall e eff
   . (Effect eff, Ex.Exception e)
  => Handler (Union (ExceptionEff e) IoEff) IoEff eff eff
tryIoHandler = genericHandler $ IoOps {
  liftIoOp = tryIo
}

try
  :: forall free eff e a
   . ( Effect eff
     , FreeEff free
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
   . ( Effect eff
     , FreeEff free
     , OpsConstraint (ExceptionEff e) eff
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
   . ( Effect eff
     , FreeEff free
     , EffOps ops
     , OpsConstraint ops eff
     )
  => Computation (Union (ExceptionEff e) ops) (Return a) eff
  -> (e -> eff a)
  -> eff a
tryComp comp1 handler1 = handleFree handler2 comp2
 where
  comp2 :: free (ExceptionEff e) eff a
  comp2 = returnVal $ runComp comp1 freeLiftEff $
    UnionOps freeOps $ effmap liftFree captureOps

  handler2 :: CoOpHandler (ExceptionEff e) a a eff
  handler2 = CoOpHandler return $
    \(RaiseOp e) -> handler1 e

bracketComp
  :: forall free eff ops e a b
   . ( Effect eff
     , FreeEff free
     , EffOps ops
     , OpsConstraint ops eff
     )
  => Computation (Union (ExceptionEff e) ops) (Return a) eff          -- init
  -> (a -> Computation (Union (ExceptionEff e) ops) (Return ()) eff)  -- cleanup
  -> (a -> Computation (Union (ExceptionEff e) ops) (Return b) eff)   -- between
  -> Computation (Union (ExceptionEff e) ops) (Return b) eff
bracketComp initComp cleanupComp betweenComp = Computation comp1
 where
  comp1
    :: forall eff2
     . (Effect eff2)
    => LiftEff eff eff2
    -> Operation (Union (ExceptionEff e) ops) eff2
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
            effmap liftFree ops1

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
