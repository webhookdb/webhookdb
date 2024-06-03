import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import clsx from "clsx";
import { useLocation } from "react-router-dom";

import Hr from "./Hr.jsx";
import "./SidebarNav.css";
import { RelLink } from "./links.jsx";

/**
 * @param {Array<SidebarNavPageItem>} items
 */
export default function SidebarNav({ items }) {
  if (!items) {
    return null;
  }
  return (
    <div className="sidebar-nav">
      {items.map((item) => (
        <PageItem key={item.label} {...item} />
      ))}
      <Hr className="mt-4" />
    </div>
  );
}

function DisabledItem({ icon, label }) {
  return (
    <div className="sidebar-nav-item disabled">
      <FontAwesomeIcon icon={icon} className="sidebar-nav-icon disabled" />
      <span className="subtitle sidebar-nav-text">{label}</span>
    </div>
  );
}

function PageItem({ active, label, href, icon, disabled }) {
  const location = useLocation();
  if (disabled) {
    return <DisabledItem icon={icon} label={label} />;
  }
  const hrefArray = typeof href === "string" ? [href] : href;
  active = active || hrefArray.includes(location.pathname);
  return (
    <RelLink
      href={hrefArray[0]}
      className={clsx("sidebar-nav-link sidebar-nav-item", active && "active")}
    >
      <FontAwesomeIcon
        icon={icon}
        className={clsx("sidebar-nav-icon", active && "active")}
      />
      <span className={clsx("subtitle sidebar-nav-text", active && "active")}>
        {label}
      </span>
    </RelLink>
  );
}

/**
 * @typedef SidebarNavPageItem
 * @property {string} label
 * @property {Icon} icon
 * @property {string|Array<string>=} href
 * @property {boolean=} disabled
 * @property {boolean=} active If true, force this item to be active.
 *   Use when the href matching won't work.
 */
