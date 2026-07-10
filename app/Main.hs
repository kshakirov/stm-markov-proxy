{-# LANGUAGE NamedFieldPuns #-}

module Main where

import Control.Concurrent.STM (TVar, newTVarIO, readTVar, writeTVar)
import Control.Monad.Reader
import qualified Control.Monad.Trans.Reader as RT
import qualified MyLib (someFunc)

data Env = Env
  { proxyConfig :: Config,
    backendConfigs :: [BackendConfig],
    proxyTVarState :: TVar ProxyState
  }

data BackendConfig = BackendConfig
  { appName :: String,
    runningPort :: Int
  }

data Config = Config
  { hostName :: String,
    port :: Int
  }

data ProxyState = ProxyState
  { nextBackendIndex :: Int
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
  let initProxyState = ProxyState {nextBackendIndex = 0}
  refProxyTVarState <- newTVarIO initProxyState
  let c = Config {hostName = "localhost", port = 8989}

  let e = Env {proxyConfig = c, backendConfigs = [], proxyTVarState = refProxyTVarState}
  runReaderT listenAndServe e
