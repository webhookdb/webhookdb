import React from "react";
import ReactDOM from "react-dom/client";

import App from "./App";
import "./assets/styles/content.css";
import "./assets/styles/layout.css";
import "./assets/styles/main.css";
import "./assets/styles/reset.css";
import "./assets/styles/typography.css";
import "./assets/styles/utilities.css";

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
