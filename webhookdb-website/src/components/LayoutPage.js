import FooterSection from "./FooterSection";
import NavigationBar from "./NavigationBar";
import React from "react";
import SmoothScroll from "smooth-scroll/dist/smooth-scroll"; // Default has polyfills we don't need
import useScrollTop from "../hooks/useScrollTop";

export default function LayoutPage({ children }) {
  useScrollTop();

  React.useEffect(() => {
    try {
      new SmoothScroll('a[href*="#"]', { speed: 100 });
    } catch (e) {
      console.error("Error while smooth scrolling:", e);
    }
  }, []);

  return (
    <>
      <div>
        <NavigationBar />
      </div>
      <main style={{ minHeight: "75vh" }}>{children}</main>
      <FooterSection />
    </>
  );
}
