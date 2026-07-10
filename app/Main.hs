module Main where

import Control.Monad.Reader
import qualified Control.Monad.Trans.Reader as RT
import qualified MyLib (someFunc)

data Env = Env
  { proxyConfig :: Config,
    backendConfigs :: [BackendConfig]
  }

data BackendConfig = BackendConfig
  { appName :: String,
    runningPort :: Int
  }

data Config = Config
  { hostName :: String,
    port :: Int
  }

type ProxyM a = ReaderT Env IO a

listenAndServe :: ProxyM ()
listenAndServe = do
  --  let c = Config{hostName="proxyHost", port=8989, backends = [1,2]}
  env <- ask
  let name = (hostName . proxyConfig) env
  --  liftIO $  putStrLn $ hostName c
  liftIO $ putStrLn $ "The host is " ++ name

--  putStrLn ""

main :: IO ()
main = do
  putStrLn "Hello, Haskell!"
  let c = Config {hostName = "localhost", port = 8989}
  let e = Env {proxyConfig = c, backendConfigs = []}
  runReaderT listenAndServe e
