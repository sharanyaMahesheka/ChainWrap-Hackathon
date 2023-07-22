import "./App.css";
import { Box, List, Typography } from "@mui/material";
import NavBar from "./component/Navbar";
import { useState, useEffect } from "react";
import { web3FromSource } from "@polkadot/extension-dapp";
import { ethers } from 'ethers';
import { BrowserRouter, Route, Routes } from "react-router-dom";
import { ContractPromise } from "@polkadot/api-contract";
import { ApiPromise, WsProvider } from "@polkadot/api";
import Homepage from "./component/HomePage";
import Footer from "./component/Footer";
import ListNFT from "./component/ListNFT";
import ListingDetail from "./component/ListingDetails/ListingDetail";
import MintNFT from "./component/Mint/MintNFT";
import Fractionalise from "./component/Fractionalise";
import { createPublicClient, http } from 'viem'
import Profile from "./component/Profile";
import { WagmiConfig, createConfig, configureChains, mainnet } from 'wagmi'
 
import { alchemyProvider } from 'wagmi/providers/alchemy'
import { publicProvider } from 'wagmi/providers/public'
 
import { CoinbaseWalletConnector } from 'wagmi/connectors/coinbaseWallet'
import { InjectedConnector } from 'wagmi/connectors/injected'
import { MetaMaskConnector } from 'wagmi/connectors/metaMask'
import { WalletConnectConnector } from 'wagmi/connectors/walletConnect'
import {
  ABI_ERC721,
  ABI_FRACTIONALIZER,
  ABI_NFT_LENDING,
  ERC721_ADDRESS,
  NFT_LENDING_ADDRESS,
  FRACTIONALIZER_ADDRESS,
  NETWORK_ENDPOINT,
} from "./commons";
function App() {
  const [contracts, setContracts] = useState({
    erc721: null,
    fractionalizer: null,
    nftLending: null,
  });
  //const [activeAccount, setActiveAccount] = useState(null);
  const [api, setApi] = useState(null);
  // const [signer, setSigner] = useState(null);

  // const config = createConfig({
  //   autoConnect: true,
  //   publicClient: createPublicClient({
  //     chain: mainnet,
  //     transport: http()
  //   }),
  // })

  const { chains, publicClient, webSocketPublicClient } = configureChains(
    [mainnet],
    [alchemyProvider({ apiKey: 'HCgbOhLANZEEqih5mHOsXFQUoJgxNL_W' }), publicProvider()],
  )

  const config = createConfig({
    autoConnect: true,
    connectors: [
      new MetaMaskConnector({ chains })
    ],
    publicClient,
    webSocketPublicClient,
  })

  //const { address, isConnected } = useAccount();
  // useEffect(() => {
  //   const createSigner = async () => {
  //     const {ethereum} = window;
  //     const activeAccount = await ethereum.request({
  //       method: "eth_requestAccounts"
  //     })
  //     const provider = new ethers.BrowserProvider(ethereum);
  //     activeAccount
  //       ? setSigner(
  //         await provider.getSigner()
  //         )
  //       : setSigner(null);
  //   };
  //   createSigner();
  // }, [activeAccount]);

  const connectToContract = async () => {
    const wsProvider = new WsProvider(NETWORK_ENDPOINT);
    const api = await ApiPromise.create({ provider: wsProvider });
    const erc721Contract = new ContractPromise(api, ABI_ERC721, ERC721_ADDRESS);
    const fractionaliserContract = new ContractPromise(
      api,
      ABI_FRACTIONALIZER,
      FRACTIONALIZER_ADDRESS
    );
    const nftLendingContract = new ContractPromise(
      api,
      ABI_NFT_LENDING,
      NFT_LENDING_ADDRESS
    );
    setApi(api);
    setContracts({
      erc721: erc721Contract,
      fractionalizer: fractionaliserContract,
      nftLending: nftLendingContract,
    });
  };

  useEffect(() => {
    connectToContract();
  }, []);

  // return (
  //   <WagmiConfig config={config}>
  //     <Profile />
  //   </WagmiConfig>
  // )
  return (
    <WagmiConfig config={config}>
    
    
    <Box sx={{ width: "100%" }} className="app">
      <BrowserRouter basename={process.env.PUBLIC_URL}>
        <NavBar
          //activeAccount={address}
          contracts={contracts}
          api={api}
          //signer={}
        />
        <Routes>
          <Route
            exact
            path="/"
            element={
              <Homepage
              //activeAccount={address}
                contracts={contracts}
                api={api}
                //signer={signer}
              />
            }
          />
          <Route
            exact
            path="/mint"
            element={
              <MintNFT
              //activeAccount={address}
                contracts={contracts}
                api={api}
                //signer={signer}
              />
            }
          />
          <Route
            exact
            path="/list"
            element={
              <ListNFT
              //activeAccount={address}
                contracts={contracts}
                api={api}
                //signer={signer}
              />
            }
          />
          <Route
            exact
            path="/fractionalise"
            element={
              !true ? (
                <Box
                  sx={{
                    marginTop: "350px",
                    width: "100%",
                    display: "flex",
                    justifyContent: "center",
                  }}
                >
                  <Typography
                    sx={{
                      fontFamily: "'Ubuntu Condensed', sans-serif",
                      height: "100px",
                      width: "300px",
                      color: "white",
                      background: "#0d0d0d",
                      boxShadow: "0px 0px 5px #232323",
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                    }}
                    variant={"h6"}
                    textAlign={"center"}
                  >
                    Connect your wallet
                  </Typography>{" "}
                </Box>
              ) : (
                <Fractionalise
                //activeAccount={address}
                  contracts={contracts}
                  api={api}
                  //signer={signer}
                />
              )
            }
          />
          <Route
            exact
            path="/profile/:address"
            element={
              <Profile
              // address={address}
                contracts={contracts}
                api={api}
                //signer={signer}
              />
            }
          />
          <Route
            exact
            path="/listing/:id"
            element={
              <ListingDetail
              //activeAccount={address}
                contracts={contracts}
                api={api}
                //signer={signer}
              />
            }
          />
          <Route exact path="/error" element={<>Error</>} />
        </Routes>
      </BrowserRouter>
      <Footer />
    </Box>
    </WagmiConfig>
  );
}

export default App;
