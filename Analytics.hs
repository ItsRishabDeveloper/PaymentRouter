module Analytics
  ( successRateByPSP
  , PSPStats(..)
  ) where

import Data.List (groupBy, sortOn)
import Data.Function (on)
import PaymentTypes

data PSPStats = PSPStats
  { statsPsp     :: String
  , statsTotal   :: Int
  , statsSuccess :: Int
  , statsRate    :: Double
  } deriving (Show)

-- Groups a flat list of outcomes by PSP and folds each group down to a
-- success-rate summary. This is the same map/filter/fold family from
-- the earlier lesson, just composed to answer a real question: "which
-- PSP is actually performing well?" -- mirrors the JD's "Aesthetic
-- Visualization of Data" / "Intelligence from transactions" bullets,
-- minus the visualization layer.
successRateByPSP :: [TransactionOutcome] -> [PSPStats]
successRateByPSP outcomes =
  map summarize grouped
  where
    sorted = sortOn outcomePsp outcomes
    grouped = groupBy ((==) `on` outcomePsp) sorted
    summarize group' =
      let name = outcomePsp (head group')
          total = length group'
          successes = length (filter outcomeSuccess group')
          rate = fromIntegral successes / fromIntegral total * 100
      in PSPStats name total successes rate
