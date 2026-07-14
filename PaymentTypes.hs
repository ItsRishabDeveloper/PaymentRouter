module PaymentTypes
  ( PaymentMethod(..)
  , PSP(..)
  , PSPHealth(..)
  , TransactionRequest(..)
  , ValidationError(..)
  , TransactionOutcome(..)
  ) where

-- Algebraic data type: a payment can be made through exactly one of
-- these methods. Adding a new method later (e.g. Wallet) means the
-- compiler will flag every function that pattern-matches on this type
-- and doesn't yet handle the new case.
data PaymentMethod
  = UPI String
  | Card { lastFour :: String, expiryMonth :: Int }
  | NetBanking String
  deriving (Show, Eq)

-- A Payment Service Provider: the actual downstream rail a transaction
-- gets routed through (mirrors how Juspay routes across 300+ PSPs).
data PSP = PSP
  { pspName       :: String
  , successRate   :: Double   -- observed rolling success rate, 0.0-1.0
  , avgLatencyMs  :: Double
  } deriving (Show, Eq)

data PSPHealth = Healthy | Unhealthy
  deriving (Show, Eq)

data TransactionRequest = TransactionRequest
  { reqAmount :: Double
  , reqMethod :: PaymentMethod
  , merchant  :: String
  } deriving (Show, Eq)

-- Every way a transaction can fail validation, named explicitly instead
-- of a generic "ValidationError String". Named error constructors mean
-- callers can pattern-match and react differently per failure type
-- (e.g. retry on RateLimited, but never retry on InvalidAmount).
data ValidationError
  = InvalidAmount String
  | UnsupportedMethod String
  | MerchantLimitExceeded String
  deriving (Show, Eq)

data TransactionOutcome = TransactionOutcome
  { outcomePsp     :: String
  , outcomeSuccess :: Bool
  } deriving (Show)
