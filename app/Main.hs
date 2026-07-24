{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}


module Main where

import Control.Concurrent.STM (TVar, newTVarIO, readTVar, writeTVar, STM,atomically)
import Control.Monad.Reader
import qualified Control.Monad.Trans.Reader as RT
import Network.Socket (Socket)
import qualified Network.Socket as S

import qualified MyLib (someFunc)
import Control.Monad (forever)
import Control.Concurrent (forkIO)
import Network.Socket.ByteString (recv, sendAll)
import qualified Data.ByteString as B


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
    port :: Int,
    backends ::Int
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
  let ends =( backends  . proxyConfig)env
  let tVarState = proxyTVarState env
  liftIO $ putStrLn $ "The host is " ++ name
  socket <-  liftIO  $ openListeningSocket 9000
  forever $ do 
    (conn, addr) <- liftIO $ S.accept socket
    liftIO $ forkIO (runReaderT (handleClient conn) env)
    liftIO $ print 1 
    -- здесь будет наш форк ищ 
--    forkIO $ handleClient conn 
  liftIO $ print socket 
  

--  putStrLn ""

main :: IO ()
main = do
  putStrLn "Hello, Haskell!"
  let initProxyState = ProxyState {nextBackendIndex = 0}
  refProxyTVarState <- newTVarIO initProxyState
  let c = Config {hostName = "localhost", port = 8989, backends=3}

  let e = Env {proxyConfig = c, backendConfigs = [], proxyTVarState = refProxyTVarState}
  
  runReaderT listenAndServe e


-- Нам понадобятся функции readTVar и writeTVar из Control.Concurrent.STM
nextBackendIdxTx :: TVar ProxyState -> Int -> STM Int
nextBackendIdxTx stateRef totalBackends = do
  -- 1. Читаем текущее состояние из транзакционной переменной
  currentState <- readTVar stateRef
  
  -- 2. Достаем текущий индекс
  let currentIdx = nextBackendIndex currentState
  
  -- 3. Вычисляем следующий индекс по формуле Round-Robin
  -- Если бэкендов 0, то индекс всегда 0, чтобы избежать деления на ноль
  let nextIdx = if totalBackends == 0 
                then 0 
                else (currentIdx + 1) `mod` totalBackends
                
  -- 4. Записываем обновленное состояние обратно
  writeTVar stateRef (ProxyState { nextBackendIndex = nextIdx })
  
  -- 5. Возвращаем ТЕКУЩИЙ индекс, по которому прокси должен отправить запрос
  return currentIdx


openListeningSocket :: Int -> IO Socket
openListeningSocket portNum = do
  let hints = S.defaultHints { S.addrFlags = [S.AI_PASSIVE], S.addrSocketType = S.Stream }
  addrInfo <- head <$> S.getAddrInfo (Just hints) (Just "127.0.0.1") (Just (show portNum))
  sock <- S.socket (S.AF_INET) (S.addrSocketType addrInfo) (S.addrProtocol addrInfo)
  S.setSocketOption sock S.ReuseAddr 1
  S.bind sock (S.addrAddress addrInfo)
  S.listen sock 1024
  return sock

handleClient:: Socket -> ProxyM ()

handleClient s = do
  env <- ask
  let name = (hostName . proxyConfig) env
  let ends =( backends  . proxyConfig)env
  let tVarState = proxyTVarState env
  sb <- liftIO $ atomically $ nextBackendIdxTx tVarState ends
  liftIO $ putStrLn  (show sb)
  let resp = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 12\r\nConnection: close\r\n\r\nHello, world"
  request <- liftIO $ recv s 1024
  liftIO $ sendAll s resp
  liftIO $ S.close s 
  return ()
