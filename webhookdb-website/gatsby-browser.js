import { ContactUsProvider } from "./src/components/useContactUs";
import React from "react";

export const wrapRootElement = ({ element }) => (
  <ContactUsProvider>{element}</ContactUsProvider>
);
