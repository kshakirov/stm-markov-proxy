{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedStrings #-}
module MyLib (someFunc) where
import qualified  Data.ByteString as B -- (ByteString, uncons, breakSubstring, concat, dro
import qualified Data.ByteString as B

someFunc :: IO ()
someFunc = putStrLn "someFunc"

runMarkovStep :: B.ByteString -> B.ByteString ->B.ByteString  -> B.ByteString
runMarkovStep s t r  =
  let (before, after) = B.breakSubstring  t s
      result = if (B.null after) then before else  B.concat [before, r,  B.drop (B.length t) after]
  in result



runMarkov :: B.ByteString -> B.ByteString
runMarkov  s =  case B.uncons s of
  Nothing -> ""
  Just (x,xs) -> xs
