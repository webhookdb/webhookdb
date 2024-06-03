import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import '@mantine/core/styles.css';
import {MantineProvider} from "@mantine/core";
import theme from "./theme.jsx"

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <MantineProvider theme={theme}>
    <App />
    </MantineProvider>
  </React.StrictMode>,
);
