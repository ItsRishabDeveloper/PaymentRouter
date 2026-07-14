module Main (main) where

import PaymentTypes
import Validation (validateTransaction)
import Routing (selectBestPSP)
import Analytics (successRateByPSP, PSPStats(..))

availablePSPs :: [PSP]
availablePSPs =
  [ PSP "Razorpay"  0.97 120
  , PSP "PayU"      0.94 200
  , PSP "CCAvenue"  0.89 350
  ]

-- Simulates a live health-tracker (in DistribuLB this was a real async
-- HealthTracker; here it's a plain function, since the point of this
-- project is the FP patterns, not rebuilding DistribuLB in Haskell).
healthLookup :: String -> PSPHealth
healthLookup "Razorpay" = Unhealthy   -- simulate the top-ranked PSP being down
healthLookup _          = Healthy

sampleOutcomes :: [TransactionOutcome]
sampleOutcomes =
  [ TransactionOutcome "Razorpay" True
  , TransactionOutcome "Razorpay" True
  , TransactionOutcome "Razorpay" False
  , TransactionOutcome "PayU" True
  , TransactionOutcome "PayU" True
  , TransactionOutcome "CCAvenue" False
  , TransactionOutcome "CCAvenue" True
  ]

main :: IO ()
main = do
  putStrLn "=== 1. Validation ==="
  let goodTxn = TransactionRequest 1500.0 (UPI "rishab@okhdfcbank") "big-merchant"
  let badTxn  = TransactionRequest (-100) (UPI "bad-vpa-no-at-sign") "big-merchant"
  print (validateTransaction goodTxn)
  print (validateTransaction badTxn)

  putStrLn "\n=== 2. Routing (Razorpay is top-scored but simulated DOWN) ==="
  case selectBestPSP availablePSPs healthLookup of
    Nothing  -> putStrLn "No healthy PSP available!"
    Just psp -> putStrLn ("Routed to: " ++ pspName psp ++ " (automatic failover from Razorpay)")

  putStrLn "\n=== 3. Analytics ==="
  mapM_ printStats (successRateByPSP sampleOutcomes)
  where
    printStats s =
      putStrLn (statsPsp s ++ ": " ++ show (statsSuccess s) ++ "/" ++ show (statsTotal s)
                ++ " (" ++ show (statsRate s) ++ "% success)")
