import StatusIcon from "@mui/icons-material/MilitaryTech";
import {
  ListItemIcon,
  ListItemText,
  MenuItem,
  Typography,
  useTheme,
} from "@mui/material";
import React from "react";
import { AppBar, Logout, TitlePortal, UserMenu, useUserMenu } from "react-admin";

import config from "../config";
import RLink from "./RLink";

export default function AdminAppBar() {
  const theme = useTheme();
  const envColor =
    config.backendEnv === "production"
      ? theme.palette.error.main
      : theme.palette.warning.main;
  const envText = theme.palette.background.default;
  return (
    <AppBar
      userMenu={
        <UserMenu>
          <StatusMenuItem />
          <Logout />
        </UserMenu>
      }
    >
      <TitlePortal />
      <Typography
        style={{
          backgroundColor: envColor,
          color: envText,
          textTransform: "capitalize",
          fontSize: "90%",
        }}
        sx={{ padding: 1, marginRight: 1, borderRadius: 0.5 }}
      >
        {config.backendEnv}
      </Typography>
    </AppBar>
  );
}

// It's important to pass the ref to allow Material UI to manage the keyboard navigation
const StatusMenuItem = React.forwardRef(function StatusMenuItem(props, ref) {
  // We are not using MenuItemLink so we retrieve the onClose function from the UserContext
  const { onClose } = useUserMenu();
  return (
    <MenuItem
      component={RLink}
      onClick={onClose}
      ref={ref}
      href="/status"
      // It's important to pass the props to allow Material UI to manage the keyboard navigation
      {...props}
    >
      <ListItemIcon>
        <StatusIcon fontSize="small" />
      </ListItemIcon>
      <ListItemText>Status</ListItemText>
    </MenuItem>
  );
});
