import {
  AppBar,
  Box,
  Button,
  Drawer,
  Menu,
  MenuItem,
  SwipeableDrawer,
  Typography,
} from "@mui/material";
import { useEffect, useState } from "react";
import "../index.js";
import Logo from "./Logo.jsx";
import MenuOpenIcon from "@mui/icons-material/MenuOpen";
import CloseIcon from "@mui/icons-material/Close";
import { cutAddress } from "../commons.js";
import Identicon from "@polkadot/react-identicon";
import KeyboardArrowDownIcon from "@mui/icons-material/KeyboardArrowDown";
import KeyboardArrowUpIcon from "@mui/icons-material/KeyboardArrowUp";
import ChooseAccount from "./ChooseAccount.jsx";
import { Link } from "react-router-dom";
import { useLocation } from "react-router-dom";
import { useAccount, useConnect, useDisconnect } from 'wagmi';
import { InjectedConnector } from 'wagmi/connectors/injected';
import { useBalance } from 'wagmi'
import BN from "bn.js";
function ConnectButton(props) {
  const [anchorEl, setAnchorEl] = useState(null);
  const openMenu = Boolean(anchorEl);
  // const handleClick = (event) => {
  //   setAnchorEl(event.currentTarget);
  // };
  // const handleClose = () => {
  //   setAnchorEl(null);
  // };
  const { address, isConnected } = useAccount();
  const { connect } = useConnect({
    connector: new InjectedConnector(),
  });
  const testConnect = isConnected;
  console.log("testconetc #{testConnect}")
  const { disconnect } = useDisconnect()

  //useEffect(() => {
    // address = address;

    const { data, isError, isLoading } = useBalance({
      address: address,
    },[address]);

  return (
    <>
      <Box
        className="connectBtn"
        sx={{
          fontFamily: "'Ubuntu Condensed', sans-serif",
          backgroundColor: "rgb(255 255 255 / 44%)",
          padding: "10px 20px",
          cursor: "pointer",
          width: "fit-content",
          margin: "0 11.8px",
          position: !address ? "relative" : "absolute",
          opacity: !address ? 1 : 0,
          zIndex: !address ? "auto" : -1,
        }}
        onClick={() => connect()}
      >
        Connect Wallet TEST 2 {address} hello {isConnected}
        <Box
          className="connectBtnBgd"
          sx={{
            position: "absolute",
            bottom: "-6px",
            right: "-5px",
            backgroundColor: "#c93a37",
            height: "110%",
            width: "107%",
            zIndex: "-1",
            filter: "blur(3px)",
          }}
          tabIndex={"2"}
        ></Box>
      </Box>

      <Box
        className="connectedBtn"
        sx={{
          fontFamily: "'Ubuntu Condensed', sans-serif",
          padding: "10px 20px",
          cursor: "pointer",
          position: "relative",
          width: "fit-content",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          color: "white",
          display: !address ? "none" : "flex",
        }}
        id="profile"
        aria-controls={openMenu ? "profile-menu" : undefined}
        aria-haspopup="true"
        aria-expanded={openMenu ? "true" : undefined}
        onClick={() => disconnect()}
      >
        <Box
          sx={{
            marginRight: "10px",
            borderRadius: "50%",
            border: "2px solid rgba(255, 255, 255, 0.63)",
            height: "20px",
          }}
        >
          <Identicon
            size={20}
            theme={"polkadot"}
            value={address}
          />
        </Box>
        <Box>
          <Typography sx={{ fontSize: "13px" }}>
            {cutAddress(address)}
          </Typography>
          <Typography sx={{ fontSize: "10px", color: "gray" }}>
          testConnect{testConnect? "hello" : "est"} : {testConnect}: {data?.formatted} {data?.symbol} 
          </Typography>
        </Box>
        {/* {!openMenu ? (
          <KeyboardArrowDownIcon sx={{ marginLeft: "10px" }} />
        ) : (
          <KeyboardArrowUpIcon sx={{ marginLeft: "10px" }} />
        )} */}
      </Box>
      {/* <Menu
        id="profile-menu"
        anchorEl={anchorEl}
        open={openMenu}
        onClose={handleClose}
        MenuListProps={{
          "aria-labelledby": "profile",
        }}
        sx={{ marginTop: "5px" }}
        PaperProps={{
          sx: {
            background: "#03080f",
            color: "white",
            border: "1px solid white",
            marginTop: "5px",
          },
        }}
      >
        <Link
          to={"/profile/" + address}
          style={{ width: "100%", height: "100%", color: "white" }}
        >
          <MenuItem onClick={handleClose}>Profile</MenuItem>
        </Link>
        <MenuItem
          onClick={() => {
            props.handleOpen();
            handleClose();
          }}
        >
          Change Account
        </MenuItem>
        <MenuItem
          onClick={() => {
            props.setActiveAccount(null);
            handleClose();
          }}
        >
          Logout
        </MenuItem>
      </Menu> */}
    </>
  );
}

export default function NavBar(props) {

  const { address, isConnected } = useAccount();
  const location = useLocation();
  const navItems = [
    { text: "Home", link: "/", exact: true },
    { text: "Mint", link: "/mint" },
    { text: "Fractionalise", link: "/fractionalise" },
    { text: "Create a listing", link: "/list" },
  ];
  const [activeTab, setActiveTab] = useState("");
  const [openDrawer, setOpenDrawer] = useState(false);
  const [openChooseAccount, setOpenChooseAccount] = useState(false);
  const setSelectedAccount = (acc) => {
    props.setActiveAccount(acc);
  };

  const handleChooseAccClose = () => {
    setOpenChooseAccount(false);
  };

  const handleChooseAccOpen = () => {
    setOpenChooseAccount(true);
  };

  const onNavItemClick = (tab) => {
    setActiveTab(tab);
  };

  const toggleDrawer = () => {
    setOpenDrawer(!openDrawer);
  };

  useEffect(() => {
    let match = navItems.filter((item) => {
      return location.pathname === item.link;
    })[0]?.text;
    setActiveTab(match);
    console.log(navItems.filter((item) => {
      return location.pathname === item.link ;
    }))
    console.log("Match" , navItems.filter((item) => {
      return location.pathname === item.link;
    }));
  }, [location.pathname]);

  return (
    <AppBar
      component="nav"
      sx={{
        height: "70px",
        padding: "0 7%",
        background: "#03080f",
        zIndex: "99999",
      }}
    >
      <Logo />
      <Box
        sx={{
          display: { sm: "none", xs: "none", md: "flex" },
          right: "0px",
          top: "0px",
          height: "100%",
          alignItems: "center",
          position: "absolute",
          padding: "0 7%",
        }}
      >
        {navItems.map((item) => (
          <Link to={item.link} key={item.text}>
            <Box
              component="div"
              key={item.text}
              sx={{
                marginRight: "60px",
                fontFamily: "'Ubuntu Condensed', sans-serif",
                fontSize: "16px",
                letterSpacing: "1px",
                cursor: "pointer",
              }}
              className={
                "navBtn " + (activeTab === item.text ? "navBtnActive" : "")
              }
              tabIndex={"1"}
              onClick={() => onNavItemClick(item.text)}
            >
              {item.text}
            </Box>
          </Link>
        ))}

        <ConnectButton
          // //handleOpen={() => handleChooseAccOpen()}
          // setActiveAccount={(address) => props.setActiveAccount(address)}
          activeAccount={address}
          api={props.api}
        />
      </Box>
      <Box
        className="hamburger"
        sx={{
          position: "absolute",
          right: "0px",
          top: "0px",
          height: "100%",
          marginRight: "7%",
          display: "flex",
          justifyContent: "center",
          alignItems: "center",
        }}
      >
        {!openDrawer ? (
          <MenuOpenIcon
            sx={{
              display: { xs: "block", md: "none" },
              fontSize: "30px",
              cursor: "pointer",
            }}
            onClick={() => toggleDrawer()}
          />
        ) : (
          <CloseIcon
            sx={{
              display: { xs: "block", md: "none" },
              fontSize: "30px",
              cursor: "pointer",
            }}
            onClick={() => toggleDrawer()}
          />
        )}
      </Box>
      <Drawer
        open={openDrawer}
        sx={{
          position: "absolute",
          top: "80px",
          left: "0px",
          display: { xs: "block", md: "none" },
        }}
        PaperProps={{
          sx: {
            backgroundColor: "#03080f",
            marginTop: "60px",
            padding: "40px 0",
          },
        }}
      >
        {navItems.map((item) => (
          <Box
            sx={{
              width: "300px",
              display: "flex",
              justifyContent: "center",
              alignItems: "center",
            }}
            key={item.text}
          >
            <Link to={item.link}>
              <Box
                component="div"
                sx={{
                  fontFamily: "'Ubuntu Condensed', sans-serif",
                  fontSize: "16px",
                  letterSpacing: "1px",
                  cursor: "pointer",
                  height: "30px",
                  width: "fit-content",
                  backgroundColor: "#03080f",
                  marginTop: "20px",
                  display: "flex",
                  justifyContent: "center",
                  alignItems: "center",
                }}
                className={
                  "navBtn " + (activeTab === item.text ? "navBtnActive" : "")
                }
                tabIndex={"1"}
                onClick={() => {
                  toggleDrawer();
                  onNavItemClick(item.text);
                }}
              >
                {item.text}
              </Box>
            </Link>
          </Box>
        ))}
        <Box
          sx={{
            marginTop: "30px",
            display: "flex",
            justifyContent: "center",
            alignItems: "center",
          }}
        >
          <ConnectButton
            activeAccount={address}
            api={props.api}
          />
        </Box>
      </Drawer>
      {/* <ChooseAccount
        open={openChooseAccount}
        handleClose={() => handleChooseAccClose()}
        setActiveAccount={(acc) => setSelectedAccount(acc)}
      /> */}
    </AppBar>
  );
}
