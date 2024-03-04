/**
 * Based on react-admin/theme/houseTheme.ts.
 * We need to copy it in order to customize colors,
 * and add the RLink components,
 * which do not work when merging into the theme.
 */
import { alpha, createTheme, darken } from "@mui/material";

import RLink from "./components/RLink";

const componentsOverrides = (theme) => ({
  MuiBackdrop: {
    styleOverrides: {
      root: {
        backgroundColor: alpha(darken("#000C57", 0.4), 0.2),
        backdropFilter: "blur(2px)",
        "&.MuiBackdrop-invisible": {
          backgroundColor: "transparent",
          backdropFilter: "blur(2px)",
        },
      },
    },
  },
  MuiButtonBase: {
    defaultProps: {
      LinkComponent: RLink,
    },
  },
  MuiFormControl: {
    defaultProps: {
      margin: "dense",
    },
  },
  MuiLink: {
    defaultProps: {
      component: RLink,
    },
  },
  MuiOutlinedInput: {
    styleOverrides: {
      input: {
        padding: `${theme.spacing(1)} ${theme.spacing(2)}`,
      },
    },
  },
  MuiTab: {
    styleOverrides: {
      root: {
        padding: 0,
        height: 38,
        minHeight: 38,
        borderRadius: 6,
        transition: "color .2s",

        "&.MuiButtonBase-root": {
          minWidth: "auto",
          paddingLeft: 20,
          paddingRight: 20,
          marginRight: 4,
        },
        "&.Mui-selected, &.Mui-selected:hover": {
          color: theme.palette.primary.contrastText,
          zIndex: 5,
        },
        "&:hover": {
          color: theme.palette.primary.main,
        },
      },
    },
  },
  MuiTableRow: {
    styleOverrides: {
      root: {
        "&:last-child td": { border: 0 },
      },
    },
  },
  MuiTableCell: {
    styleOverrides: {
      root: {
        padding: theme.spacing(2),
        "&.MuiTableCell-sizeSmall": {
          padding: theme.spacing(1.5),
        },
        "&.MuiTableCell-paddingNone": {
          padding: theme.spacing(0.5),
        },
      },
    },
  },
  MuiTabs: {
    styleOverrides: {
      root: {
        height: 38,
        minHeight: 38,
        overflow: "visible",
      },
      indicator: {
        height: 38,
        minHeight: 38,
        borderRadius: 6,
        border: `1px solid ${theme.palette.primary.light}`,
        boxShadow: theme.shadows[1],
      },
      scrollableX: {
        overflow: "visible !important",
      },
    },
  },
  MuiTextField: {
    defaultProps: {
      variant: "outlined",
    },
  },
  RaAppBar: {
    styleOverrides: {
      root: {
        color: theme.palette.text.primary,
        "& .RaAppBar-toolbar": {
          backgroundColor: theme.palette.primary.main,
          color: theme.palette.background.default,
          backgroundImage: `linear-gradient(310deg, ${theme.palette.primary.light}, ${theme.palette.secondary.dark})`,
        },
      },
    },
  },
  RaDatagrid: {
    styleOverrides: {
      root: {
        marginTop: theme.spacing(1.5),
      },
    },
  },
  RaMenuItemLink: {
    styleOverrides: {
      root: {
        padding: 10,
        marginRight: 10,
        marginLeft: 10,
        "&:hover": {
          borderRadius: 5,
        },
        "&.RaMenuItemLink-active": {
          borderRadius: 10,
          backgroundColor: theme.palette.common.white,
          color: theme.palette.primary.main,
          "&:before": {
            content: '""',
            position: "absolute",
            top: "0; right: 0; bottom: 0; left: 0",
            zIndex: "-1",
            margin: "-2px",
            borderRadius: "12px",
            background: `linear-gradient(310deg, ${theme.palette.primary.light}, ${theme.palette.secondary.main})`,
          },
          "& .MuiSvgIcon-root": {
            fill: theme.palette.primary.main,
          },
        },
      },
    },
  },
});

const alert = {
  error: { main: "#f61908" },
  warning: { main: "#e1970e" },
  info: { main: "#3ED0EB" },
  success: { main: "#0FBF9F" },
};

const darkPalette = {
  primary: { main: "#ffcd00", dark: "#deb800", light: "#ffcd00" },
  secondary: { main: "#0083da", dark: "#0083da", light: "#21a4ff" },
  background: { default: "#363D40", paper: "#2B3033" },
  ...alert,
  mode: "dark",
};

// "primary": #0099ff,
//         "primary-light": rgb(233 244 255),
//         "secondary": #ffcd00,
//         "light": #f4faff,
//         "dark": #08090a,
const lightPalette = {
  primary: { main: "#0083da", light: "#0099ff" },
  secondary: { main: "#ffcd00", dark: "#deb800" },
  background: { default: "#f4faff", paper: "#ffffff" },
  ...alert,
  mode: "light",
};

const createHouseTheme = (palette) => {
  const themeOptions = {
    palette,
    shape: { borderRadius: 20 },
    sidebar: { width: 250 },
    spacing: 9,
    typography: { fontFamily: `'Open Sans', sans-serif` },
  };
  const theme = createTheme(themeOptions);
  theme.components = componentsOverrides(theme);
  return theme;
};

export const lightTheme = createHouseTheme(lightPalette);
export const darkTheme = createHouseTheme(darkPalette);
