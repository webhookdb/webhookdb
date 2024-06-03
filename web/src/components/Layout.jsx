import clsx from "clsx";

import "./Layout.css";
import ScrollTopOnMount from "./ScrollToTopOnMount";
import TopNav from "./TopNav.jsx";

/**
 * Choose the layout associated with the page.
 * Note that this puts the content into an outer div which
 * gives the given background color to the entire page.
 *
 * @param children
 * @param {('sidebar'|'center-form'|'base')=} variant Name of the layout-* class to style the content root with.
 * @param {boolean=} noNav Hide top nav.
 * @param {boolean=} noScrollTop By default, scroll to top when the page mounts.
 * @param {string} className
 */
export default function Layout({ variant, noNav, noScrollTop, className, children }) {
  variant = variant || "base";
  return (
    <div className="layout-root">
      {!noScrollTop && <ScrollTopOnMount />}
      {!noNav && <TopNav />}
      <div className={clsx(`layout-subroot`, `layout-subroot-${variant}`, className)}>
        <div className={clsx(`layout-content`, `layout-${variant}`)}>{children}</div>
        {/*<Footer />*/}
      </div>
    </div>
  );
}
