{-# LANGUAGE AllowAmbiguousTypes #-}

module Main where
import Criterion.Main

import Control.Monad.Identity
import Control.Monad.Trans.Reader
import Control.Monad.Trans.State.Strict

import Control.Effect.Implicit

import qualified Control.Effect.Implicit.Free as Free
import qualified Control.Effect.Implicit.Freer as Freer

import Benchmark.State

rounds :: Int
rounds = 5000

applyCurriedComp
  :: (Int -> Computation NoEff (Return a) Identity)
  -> a
applyCurriedComp comp = runIdentity $ returnVal $
  runComp (comp rounds) idLift NoOp

runReaderTComp
  :: ReaderT Int Identity ()
  -> ()
runReaderTComp m = runIdentity $ runReaderT m rounds

evalStateTComp
  :: StateT Int Identity ()
  -> ()
evalStateTComp m = runIdentity $ evalStateT m rounds

main :: IO ()
main = defaultMain
  [ bgroup "State Benchmark"
    [ bench "MTL Baseline" $
        whnf evalStateTComp
        stateMTLFunc

    , bench "With StateT Ops" $
        whnf evalStateTComp
        withStateOpsComp

    , bench "With StateT Handler" $
        whnf evalStateTComp
        withStateTHandlerComp

    , bench "With StateT ReaderT Computation" $
        whnf runReaderTComp
        withStateTReaderTComp

    , bench "Bind StateT OpsHandler Computation"  $
        whnf evalStateTComp
        stateTHandlerComp

    , bench "with CoOpHandler on ChurchMonad"  $
        whnf (\comp -> runIdentity $ comp rounds)
        (handleFreeComp @Free.ChurchMonad)

    , bench "with CoOpHandler on FreeMonad"  $
        whnf (\comp -> runIdentity $ comp rounds)
        (handleFreeComp @Free.FreeMonad)

    , bench "with Freer CoOpHandler on FreerMonad"  $
        whnf (\comp -> runIdentity $ comp rounds)
        (handleFreerComp @Freer.FreerMonad)

    , bench "with Freer CoOpHandler on ChurchMonad"  $
        whnf (\comp -> runIdentity $ comp rounds)
        (handleFreerComp @Freer.ChurchMonad)

    , bench "Curried StateT Pipeline" $
        whnf applyCurriedComp
        curriedStateTComp

    , bench "Transformer StateEff to EnvEff to ReaderT Pipeline" $
        whnf runReaderTComp
        stateToReaderComp

    , bench "Manual StateEff to EnvEff to ReaderT Pipeline"  $
        whnf runReaderTComp
        stateEffToEnvEffToReaderTComp

    , bench "Manual StateEff to ReaderT Pipeline"  $
        whnf runReaderTComp
        stateEffToReaderTComp

    , bench "Curried ChurchMonad" $
        whnf applyCurriedComp
        (curriedFreeComp @Free.ChurchMonad)
    , bench "Curried FreeMonad"  $
        whnf applyCurriedComp
        (curriedFreeComp @Free.FreeMonad)

    , bench "ReaderT ChurchMonad"  $
        whnf runReaderTComp
        (readerTFreeComp @Free.ChurchMonad)
    , bench "ReaderT FreeMonad"  $
        whnf runReaderTComp
        (readerTFreeComp @Free.FreeMonad)

    ]
  ]
