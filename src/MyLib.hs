{-# LANGUAGE OverloadedStrings #-}

module MyLib (someFunc) where
import qualified  Data.ByteString as B -- (ByteString, uncons, breakSubstring, concat, dro


someFunc :: IO ()
someFunc = putStrLn "someFunc"

runMarkovStep :: B.ByteString -> B.ByteString ->B.ByteString  -> (B.ByteString,  Bool)
runMarkovStep s t r  =
  let (before, after) = B.breakSubstring  t s
      result = if (B.null after) then (before, False)  else  (B.concat [before, r,  B.drop (B.length t) after], True)
  in result




runMarkov :: [(B.ByteString, B.ByteString)] -> B.ByteString ->B.ByteString
runMarkov  [] s = s
runMarkov allRules   s = go allRules s where
  go [] s = s
  go (r:rs ) s = 
    let transformed = runMarkovStep s (fst r) (snd r)
    in case transformed of
         (ts, True) -> runMarkov allRules ts
         (ts, False) -> go rs ts
 
  
  
  

