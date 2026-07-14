module Validation (validateTransaction) where

import PaymentTypes

-- Per-merchant transaction ceiling. In a real system this would come
-- from a config store, not be hardcoded -- kept simple here since the
-- point is demonstrating the validation pattern, not building a config service.
merchantLimit :: String -> Double
merchantLimit "small-merchant" = 50000
merchantLimit _                = 200000

validateAmount :: Double -> Either ValidationError Double
validateAmount amount
  | amount <= 0 = Left (InvalidAmount "Amount must be positive")
  | amount > 1000000 = Left (InvalidAmount "Amount exceeds platform maximum")
  | otherwise = Right amount

validateMethod :: PaymentMethod -> Either ValidationError PaymentMethod
validateMethod m@(Card _ month)
  | month < 1 || month > 12 = Left (UnsupportedMethod "Invalid card expiry month")
  | otherwise = Right m
validateMethod m@(UPI vpa)
  | '@' `notElem` vpa = Left (UnsupportedMethod "Malformed UPI VPA")
  | otherwise = Right m
validateMethod m@(NetBanking _) = Right m

validateMerchantLimit :: String -> Double -> Either ValidationError Double
validateMerchantLimit merchantName amount
  | amount > merchantLimit merchantName =
      Left (MerchantLimitExceeded (merchantName ++ " limit is " ++ show (merchantLimit merchantName)))
  | otherwise = Right amount

-- The full pipeline. Each step can short-circuit with a Left; if every
-- step passes, we get back a validated TransactionRequest wrapped in
-- Right. No exceptions, no null checks -- the type signature itself
-- documents that this function can fail and how.
validateTransaction :: TransactionRequest -> Either ValidationError TransactionRequest
validateTransaction req = do
  _ <- validateAmount (reqAmount req)
  _ <- validateMethod (reqMethod req)
  _ <- validateMerchantLimit (merchant req) (reqAmount req)
  Right req
