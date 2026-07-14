module Main (main) where

import System.Exit (exitFailure, exitSuccess)
import PaymentTypes
import Validation (validateTransaction)
import Routing (selectBestPSP, rankedHealthyPSPs, scorePSP)
import Analytics (successRateByPSP, PSPStats(..))

-- A minimal test harness: no external test framework is used (this
-- environment has no package-index access), so this is a small,
-- honest, hand-rolled assertion runner rather than pretending to use
-- a library that isn't actually there.
data TestResult = Pass String | Fail String String

check :: String -> Bool -> TestResult
check name True  = Pass name
check name False = Fail name "assertion failed"

checkEq :: (Show a, Eq a) => String -> a -> a -> TestResult
checkEq name expected actual
  | expected == actual = Pass name
  | otherwise = Fail name ("expected " ++ show expected ++ ", got " ++ show actual)

-- ---------- Validation tests ----------

testValidAmountPasses :: TestResult
testValidAmountPasses =
  let req = TransactionRequest 500.0 (UPI "a@bank") "big-merchant"
  in check "valid transaction passes validation" (isRight (validateTransaction req))
  where isRight (Right _) = True
        isRight (Left _)  = False

testNegativeAmountRejected :: TestResult
testNegativeAmountRejected =
  let req = TransactionRequest (-10) (UPI "a@bank") "big-merchant"
  in checkEq "negative amount rejected" (Left (InvalidAmount "Amount must be positive")) (validateTransaction req)

testMalformedUpiRejected :: TestResult
testMalformedUpiRejected =
  let req = TransactionRequest 500 (UPI "no-at-sign") "big-merchant"
  in checkEq "malformed UPI VPA rejected"
       (Left (UnsupportedMethod "Malformed UPI VPA")) (validateTransaction req)

testMerchantLimitEnforced :: TestResult
testMerchantLimitEnforced =
  let req = TransactionRequest 60000 (UPI "a@bank") "small-merchant"
  in check "small-merchant over their limit is rejected"
       (case validateTransaction req of
          Left (MerchantLimitExceeded _) -> True
          _                               -> False)

testSameMerchantHigherLimitPasses :: TestResult
testSameMerchantHigherLimitPasses =
  let req = TransactionRequest 60000 (UPI "a@bank") "big-merchant"
  in check "same amount passes for a merchant with a higher limit"
       (case validateTransaction req of
          Right _ -> True
          _       -> False)

-- ---------- Routing tests ----------

samplePSPs :: [PSP]
samplePSPs =
  [ PSP "A" 0.99 100
  , PSP "B" 0.80 50
  , PSP "C" 0.60 500
  ]

testHighestScoringHealthyPSPWins :: TestResult
testHighestScoringHealthyPSPWins =
  checkEq "best-scored healthy PSP is selected"
    (Just "A") (fmap pspName (selectBestPSP samplePSPs (const Healthy)))

testFailoverSkipsUnhealthyTop :: TestResult
testFailoverSkipsUnhealthyTop =
  checkEq "unhealthy top PSP is skipped in favor of next best"
    (Just "B") (fmap pspName (selectBestPSP samplePSPs healthAllExceptA))
  where healthAllExceptA "A" = Unhealthy
        healthAllExceptA _   = Healthy

testAllUnhealthyReturnsNothing :: TestResult
testAllUnhealthyReturnsNothing =
  checkEq "no healthy PSPs means no route is selected"
    Nothing (selectBestPSP samplePSPs (const Unhealthy))

testRankingIsFullyOrdered :: TestResult
testRankingIsFullyOrdered =
  let ranked = rankedHealthyPSPs samplePSPs (const Healthy)
      scores = map scorePSP ranked
  in check "ranked PSPs are sorted best-score-first" (isSortedDesc scores)
  where isSortedDesc xs = and (zipWith (>=) xs (drop 1 xs))

-- ---------- Analytics tests ----------

testSuccessRateComputedPerPSP :: TestResult
testSuccessRateComputedPerPSP =
  let outcomes = [ TransactionOutcome "X" True
                 , TransactionOutcome "X" True
                 , TransactionOutcome "X" False
                 , TransactionOutcome "Y" False
                 ]
      stats = successRateByPSP outcomes
      xStats = head (filter ((== "X") . statsPsp) stats)
      yStats = head (filter ((== "Y") . statsPsp) stats)
  in check "per-PSP success rate is computed correctly"
       (statsTotal xStats == 3 && statsSuccess xStats == 2
        && abs (statsRate xStats - 66.666667) < 0.001
        && statsTotal yStats == 1 && statsRate yStats == 0.0)

-- ---------- Runner ----------

allTests :: [TestResult]
allTests =
  [ testValidAmountPasses
  , testNegativeAmountRejected
  , testMalformedUpiRejected
  , testMerchantLimitEnforced
  , testSameMerchantHigherLimitPasses
  , testHighestScoringHealthyPSPWins
  , testFailoverSkipsUnhealthyTop
  , testAllUnhealthyReturnsNothing
  , testRankingIsFullyOrdered
  , testSuccessRateComputedPerPSP
  ]

main :: IO ()
main = do
  results <- mapM report allTests
  let failures = length (filter not results)
  putStrLn ("\n" ++ show (length allTests - failures) ++ "/" ++ show (length allTests) ++ " tests passed")
  if failures > 0 then exitFailure else exitSuccess
  where
    report (Pass name) = do
      putStrLn ("  [PASS] " ++ name)
      return True
    report (Fail name reason) = do
      putStrLn ("  [FAIL] " ++ name ++ " -- " ++ reason)
      return False
