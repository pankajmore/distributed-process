-- module DemoTransport where
module Main where

import Network.Transport
import qualified Network.Transport.MVar
import Network.Transport.TCP (mkTransport, TCPConfig (..))

import qualified Network.Transport.Pipes as Pipes

import Control.Concurrent
import Control.Monad
import Control.Exception
import System.IO (stderr, hPutStrLn)

import qualified Data.ByteString.Char8 as BS

import Debug.Trace

forkWithExceptions :: (IO () -> IO ThreadId) -> String -> IO () -> IO ThreadId
forkWithExceptions forkit descr action = do 
   parent <- myThreadId
   forkit $ 
      Control.Exception.catch 
         action
	 (\ e -> do
	  hPutStrLn stderr $ "Exception inside "++descr++": "++show e
	  throwTo parent (e::SomeException)
	 )

-------------------------------------------
-- Example program using backend directly
--

-- | Check if multiple messages can be sent on the same connection.
-- demo0 :: IO ()
demo0 mkTrans = do
  trans <- mkTrans

  (sourceAddr, targetEnd) <- newConnection trans

--  forkWithExceptions forkIO "receiver thread" $ logServer "logServer" targetEnd
--  forkWithExceptions forkOS "receiver thread" $ logServer "logServer" targetEnd
  forkIO $ logServer "logServer" targetEnd
  threadDelay 100000

  sourceEnd <- connect sourceAddr

  mapM_ (\n -> send sourceEnd [BS.pack ("hello " ++ show n)]) [1 .. 10]
  threadDelay 100000


main = do 
   putStrLn "MVAR:"
   demo0 Network.Transport.MVar.mkTransport
   putStrLn "TCP:"
   demo0$ mkTransport $ TCPConfig undefined "127.0.0.1" "8080"
   putStrLn "Pipes:"
   demo0 Pipes.mkTransport




{-
-- | Check endpoint serialization and deserialization.
demo1 :: IO ()
demo1 = do
  -- trans <- mkTransport
  trans <- mkTransport $ TCPConfig undefined "127.0.0.1" "8080"

  (sourceAddr, targetEnd) <- newConnection trans

  forkIO $ logServer "logServer" targetEnd
  threadDelay 100000

  sourceEnd <- connect sourceAddr

  -- This use of Just is slightly naughty
  let Just sourceAddr' = deserialize trans (serialize sourceAddr)
  sourceEnd' <- connect sourceAddr'

  send sourceEnd  [BS.pack "hello 1"]
  send sourceEnd' [BS.pack "hello 2"]
  threadDelay 100000

-- | Check that messages can be sent before receive is set up.
demo2 :: IO ()
demo2 = do
  -- trans <- mkTransport
  trans <- mkTransport $ TCPConfig undefined "127.0.0.1" "8080"

  (sourceAddr, targetEnd) <- newConnection trans

  sourceEnd <- connect sourceAddr
  forkIO $ send sourceEnd [BS.pack "hello 1"]
  threadDelay 100000

  forkIO $ logServer "logServer" targetEnd
  return ()

-- | Check that two different transports can be created.
demo3 :: IO ()
demo3 = do
  trans1 <- mkTransport $ TCPConfig undefined "127.0.0.1" "8080"
  trans2 <- mkTransport $ TCPConfig undefined "127.0.0.1" "8081"

  (sourceAddr1, targetEnd1) <- newConnection trans1
  (sourceAddr2, targetEnd2) <- newConnection trans2

  forkIO $ logServer "logServer1" targetEnd1
  forkIO $ logServer "logServer2" targetEnd2

  sourceEnd1 <- connect sourceAddr1
  sourceEnd2 <- connect sourceAddr2

  send sourceEnd1 [BS.pack "hello1"]
  send sourceEnd2 [BS.pack "hello2"]

-- | Check that two different connections on the same transport can be created.
demo4 :: IO ()
demo4 = do
  trans <- mkTransport $ TCPConfig undefined "127.0.0.1" "8080"
  -- trans <- Network.Transport.MVar.mkTransport

  (sourceAddr1, targetEnd1) <- newConnection trans
  (sourceAddr2, targetEnd2) <- newConnection trans

  forkIO $ logServer "logServer1" targetEnd1
  forkIO $ logServer "logServer2" targetEnd2

  sourceEnd1 <- connect sourceAddr1
  sourceEnd2 <- connect sourceAddr2

  send sourceEnd1 [BS.pack "hello1"]
  send sourceEnd2 [BS.pack "hello2"]

-}

logServer :: String -> TargetEnd -> IO ()
logServer name targetEnd = forever $ do
  x <- receive targetEnd
  trace (name ++ " rcvd: " ++ show x) $ return ()

