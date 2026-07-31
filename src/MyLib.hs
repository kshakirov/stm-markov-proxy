{-# LANGUAGE OverloadedStrings #-}
module MyLib (someFunc) where
import qualified  Data.ByteString as B -- (ByteString, uncons, breakSubstring, concat, dro
import qualified Data.ByteString as B

someFunc :: IO ()
someFunc = putStrLn "someFunc"

runMarkovStep :: B.ByteString -> B.ByteString ->B.ByteString  -> B.ByteString
runMarkovStep s t r  =
  let (before, after) = B.breakSubstring  t s
      tail = B.drop 2 after
  in B.concat [before, r, tail]



runMarkov :: B.ByteString -> B.ByteString
runMarkov  s =  case B.uncons s of
  Nothing -> ""
  Just (x,xs) -> xs
