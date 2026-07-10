module Main where

import qualified MyLib (someFunc)
import Control.Monad.Reader

data Config = Config {
                     hostName :: String,
                     port:: Int ,
                     backends :: [Int]
                     }

getHostName ::  Reader  Config  String
getHostName = do
  config <- ask
  let name = hostName config
  return name
  



main :: IO ()
main = do
  putStrLn "Hello, Haskell!"
  let c = Config{hostName="localhost", port=8989, backends = [1,2]}
  putStrLn $ hostName c
  putStrLn $ runReader (getHostName)  c
  MyLib.someFunc
