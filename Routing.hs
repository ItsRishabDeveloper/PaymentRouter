module Routing
  ( scorePSP
  , rankedHealthyPSPs
  , selectBestPSP
  ) where

import Data.List (sortBy)
import Data.Ord (comparing, Down(..))
import PaymentTypes

-- A single pure scoring function: higher success rate is good, higher
-- latency is bad. Weights are simplistic on purpose -- a real system
-- would tune these against actual conversion data (exactly the kind of
-- problem the JD's "Data Science" section is describing), but the
-- SHAPE of the solution -- a pure function from PSP stats to a
-- comparable score -- is the actual reusable idea.
scorePSP :: PSP -> Double
scorePSP psp = successRate psp * 1000 - avgLatencyMs psp * 0.1

-- Given all known PSPs and a health-lookup function, return the
-- healthy ones ranked best-first. Keeping "health" as a function
-- parameter (rather than baking health into PSP itself) means this
-- logic doesn't care WHERE health data comes from -- it could be a live
-- health-check tracker (like DistribuLB's HealthTracker), a static
-- test double, or a database lookup. That's dependency inversion via
-- plain functions, no framework required.
rankedHealthyPSPs :: [PSP] -> (String -> PSPHealth) -> [PSP]
rankedHealthyPSPs psps healthOf =
  sortBy (comparing (Down . scorePSP)) (filter isHealthy psps)
  where
    isHealthy psp = healthOf (pspName psp) == Healthy

-- The routing decision Juspay's JD calls "intelligent traffic routing":
-- pick the highest-scoring HEALTHY PSP. If the top-ranked PSP is down,
-- this automatically "fails over" to the next one, because unhealthy
-- PSPs are filtered out before ranking -- there's no special-case
-- failover code path, it falls out of the two functions above composing.
selectBestPSP :: [PSP] -> (String -> PSPHealth) -> Maybe PSP
selectBestPSP psps healthOf =
  case rankedHealthyPSPs psps healthOf of
    []      -> Nothing
    (top:_) -> Just top
