import React from "react";
import NavigationBar from "./NavigationBar";
import FooterSection from "./FooterSection";
import useScrollTop from "../hooks/useScrollTop";

export default function LayoutPage({ children }) {
  useScrollTop();

  React.useEffect(() => {
    if (typeof window !== "undefined") {
      // eslint-disable-next-line global-require
      require("smooth-scroll")('a[href*="#"]');
    }
  }, []);

  return (
    <>
      <div>
        <NavigationBar />
      </div>
      <main>{children}</main>
      <FooterSection />
    </>
  );
}
