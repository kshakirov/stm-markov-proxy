{-# LANGUAGE OverloadedStrings #-}
module MyLib (someFunc) where
import Data.ByteString (ByteString, uncons, breakSubstring)

someFunc :: IO ()
someFunc = putStrLn "someFunc"

runMarkovStep :: ByteString -> ByteString
runMarkovStep s =
  let (before, after) = breakSubstring  "fd" s 
      result = after
  in result 



runMarkov :: ByteString -> ByteString
runMarkov  s =  case uncons s of
  Nothing -> ""
  Just (x,xs) -> runMarkovStep xs
