module Main where

import qualified MyLib (someFunc)
import Control.Monad.Reader
import qualified  Control.Monad.Trans.Reader as RT

data Config = Config {
                     hostName :: String,
                     port:: Int,
                     backends :: [Int]
                     }

  
type ProxyM a = ReaderT Config IO a

listenAndServe ::  ProxyM ()
listenAndServe = do
--  let c = Config{hostName="proxyHost", port=8989, backends = [1,2]}
  config <- ask
  let name = hostName config
--  liftIO $  putStrLn $ hostName c
  liftIO $ putStrLn $  "The host is " ++  name 
--  putStrLn ""


main :: IO ()
main = do
  putStrLn "Hello, Haskell!"
  let c = Config{hostName="localhost", port=8989, backends = [1,2]}
  runReaderT listenAndServe c 

