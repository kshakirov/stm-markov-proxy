{-# LANGUAGE OverloadedStrings #-}
module MyLib (someFunc) where
import Data.ByteString (ByteString)

someFunc :: IO ()
someFunc = putStrLn "someFunc"

runMarkov :: ByteString -> ByteString
runMarkov s = s

runMarkovStep :: ByteString -> ByteString
runMarkovStep s =s 
