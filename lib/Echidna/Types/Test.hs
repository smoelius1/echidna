{-# LANGUAGE TemplateHaskell #-}

module Echidna.Types.Test where

import Control.Lens
import Data.Aeson (ToJSON(..), object)
import Data.DoubleWord (Int256)
import Data.Maybe (maybeToList)
import Data.Text (Text)
import EVM (VM)
import EVM.Types (Addr)

import Echidna.Exec (ExecException)
import Echidna.Events (Events, EventMap)
import Echidna.Types.Tx (Tx, TxResult)
import Echidna.Types.Signature (SolSignature)

type TestMode = String

-- | Configuration for the creation of Echidna tests.
data TestConf = TestConf { classifier :: Text -> VM -> Bool
                           -- ^ Given a VM state and test name, check if a test just passed (typically
                           -- examining '_result'.)
                         , testSender :: Addr -> Addr
                           -- ^ Given the address of a test, return the address to send test evaluation
                           -- transactions from.
                         }

-- | An Echidna test is either the name of the function to call and the address where its contract is,
-- or a function that could experience an exception
--type SolTest = Either (Text, Addr) SolSignature

type TestAttempts = Int

-- | State of a particular Echidna test. N.B.: \"Solved\" means a falsifying call sequence was found.
data TestState = Open Int        -- ^ Maybe solvable, tracking attempts already made
               | Large Int       -- ^ Solved, maybe shrinable, tracking shrinks tried + best solve
               | Passed          -- ^ Presumed unsolvable
               | Solved          -- ^ Solved with no need for shrinking
               | Failed ExecException -- ^ Broke the execution environment
                 deriving Show

data TestValue = BoolValue Bool
               | IntValue Int256
               | NoValue
                 deriving (Eq)

instance Show TestValue where
  show (BoolValue x) = show x
  show (IntValue x)  = show x
  show NoValue       = ""

data TestType = PropertyTest Text Addr
              | OptimizationTest Text Addr
              | AssertionTest SolSignature Addr 
              | CallTest Text (EventMap -> VM -> TestValue) 
              | Exploration

instance Eq TestType where -- MinTest is missing
  (PropertyTest t a)     == (PropertyTest t' a')  = t == t' && a == a'
  (AssertionTest s a)    == (AssertionTest s' a') = s == s' && a == a'
  (OptimizationTest s a) == (OptimizationTest s' a') = s == s' && a == a'
  (CallTest t _)         == (CallTest t' _)       = t == t'
  Exploration            == Exploration           = True
  _                      == _                     = False


instance Eq TestState where
  (Open i)  == (Open j)    = i == j
  (Large i) == (Large j)   = i == j 
  Passed    == Passed      = True
  Solved    == Solved      = True
  _         == _           = False


data EchidnaTest = EchidnaTest { 
                                 _testState      :: TestState
                               , _testType       :: TestType
                               , _testValue      :: TestValue
                               , _testReproducer :: [Tx]
                               , _testResult     :: TxResult
                               , _testEvents     :: Events 
                               } deriving Eq  

makeLenses ''EchidnaTest

isOpen :: EchidnaTest -> Bool
isOpen t = case (t ^. testState) of
            Open _ -> True
            _      -> False

isPassed :: EchidnaTest -> Bool 
isPassed t = case (t ^. testState) of
              Passed -> True
              _      -> False
 

instance ToJSON TestState where
  toJSON s = object $ ("passed", toJSON passed) : maybeToList desc where
    (passed, desc) = case s of Open _    -> (True, Nothing)
                               Passed    -> (True, Nothing)
                               Large _   -> (False, Nothing)
                               Solved    -> (False, Nothing)
                               Failed  e -> (False, Just ("exception", toJSON $ show e))