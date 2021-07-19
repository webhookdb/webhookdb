import FooterSection from "./FooterSection";
import NavigationBar from "./NavigationBar";
import React from "react";
import smoothScroll from "smooth-scroll";
import useScrollTop from "../hooks/useScrollTop";

export default function LayoutPage({ children }) {
  useScrollTop();

  React.useEffect(() => {
    try {
      smoothScroll('a[href*="#"]');
    } catch (e) {
      console.error("Error while smooth scrolling:", e);
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
