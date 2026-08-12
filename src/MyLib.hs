{-# LANGUAGE OverloadedStrings #-}

module MyLib (runMarkov) where
import qualified  Data.ByteString as B -- (ByteString, uncons, breakSubstring, concat, dro
import Data.Word



data ParserStatus =
  Method
  |URI
  |Version
  |Finish

data ParserState = ParserState{
  currentState :: ParserStatus,
  currentIndex :: Int ,
  parsed :: [Int]
                   }

someFunc :: IO ()
someFunc = putStrLn "someFunc"

runMarkovStep :: B.ByteString -> B.ByteString ->B.ByteString  -> (B.ByteString,  Bool)
runMarkovStep s t r  =
  let (before, after) = B.breakSubstring  t s
      result = if (B.null after) then (before, False)  else  (B.concat [before, r,  B.drop (B.length t) after], True)
  in result




runMarkov :: [(B.ByteString, B.ByteString)] -> B.ByteString ->B.ByteString
runMarkov allRules   s = go allRules s where
  go [] ss = ss
  go (r:rs ) ss = 
    let transformed = uncurry (runMarkovStep ss) r
    in case transformed of
         (ts, True) -> runMarkov allRules ts
         (ts, False) -> go rs ts




runWirth :: ParserState -> Word8 -> B.ByteString -> ParserState
runWirth state w8 s =
  case currentState state of
    Method | w8 == 0x20 -> runWirth ParserState {currentState = URI, currentIndex =currentIndex state + 1, parsed= currentIndex state  + 1  : parsed state } 1 s
                | w8 > 8 -> state
    _ -> state
     
  

  

