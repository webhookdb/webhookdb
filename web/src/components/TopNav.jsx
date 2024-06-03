import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import clsx from "clsx";
import find from "lodash/find";
import isEmpty from "lodash/isEmpty";
import { useLocation } from "react-router-dom";

import api from "../api";
import logo from "../assets/images/webhookdb-logo-512.png";
import signOut from "../modules/signOut";
import useErrorToast from "../state/useErrorToast.jsx";
import useGlobalViewState from "../state/useGlobalViewState";
import useRoleAccess from "../state/useRoleAccess.jsx";
import useScreenLoader from "../state/useScreenLoader.jsx";
import useUser from "../state/useUser.jsx";
import "./TopNav.css";
import { faArrowRight, faBell, faGear, faUserGroup } from "./icons.jsx";
import Button from "./uikit/Button.jsx";
import Dropdown, {
  DropdownHeading,
  DropdownItem,
  DropdownSeperator,
} from "./uikit/Dropdown.jsx";
import Stack from "./uikit/Stack.jsx";
import { RelLink } from "./uikit/links.jsx";

export default function TopNav({ forceReadAll }) {
  const { showErrorToast } = useErrorToast();
  const { setTopNav } = useGlobalViewState();
  const screenLoader = useScreenLoader();
  const { user, setUser } = useUser();
  const { canRead } = useRoleAccess({ forceReadAll });

  function handleAvatarSelection(actionKey) {
    if (actionKey === "logout") {
      signOut().catch(showErrorToast);
    } else if (actionKey === null) {
      // We get this when selecting URLs, don't do anything.
    } else {
      console.error("unknown actionKey:", actionKey);
    }
  }
  function handleSwitchOrg(orgKey) {
    const org = find(user.availableOrganizations, (o) => o.id === orgKey);
    if (org.active) {
      return;
    }
    screenLoader.turnOn();
    api
      .updateActiveOrganization({ organizationId: org.id })
      .then((r) => setUser(r.data))
      .catch(showErrorToast)
      .finally(screenLoader.turnOff);
  }

  return (
    <div ref={setTopNav} className="top-nav-root">
      <div className="top-nav-logo">
        <RelLink href="/dashboard">
          <img src={logo} alt="WebhookDB Logo" height="100%" />
        </RelLink>
      </div>
      <Stack row gap={1}>
        <NavTextLink to="/dashboard">Dashboard</NavTextLink>
        {canRead("contractmanager") && (
          <NavTextLink to="/contracts">Contract Manager</NavTextLink>
        )}
      </Stack>
      <div className="top-nav-icongroup">
        <NavIconLink
          icon={faGear}
          to="/manage-org/members"
          className={clsx(location.pathname.startsWith("/manage-org/") && "active")}
        />
        {forceReadAll && <NavIconLink icon={faBell} to="#" />}
        {!isEmpty(user.availableOrganizations) && (
          <Dropdown
            aria-label="Switch Org"
            onSelectionChange={handleSwitchOrg}
            renderButton={({ isOpen, setOpen }) => (
              <NavIconButton
                icon={faUserGroup}
                className={clsx(isOpen && "active")}
                onClick={() => setOpen(true)}
              />
            )}
          >
            <DropdownHeading>Switch Organization</DropdownHeading>
            {user.availableOrganizations?.map(({ id, name, active }) => (
              <DropdownItem
                key={id}
                value={id}
                className={clsx("top-nav-orgswitch", active && "active")}
              >
                {name}
              </DropdownItem>
            ))}
          </Dropdown>
        )}
      </div>
      <div className="top-nav-sep" />
      <Dropdown
        aria-label="User Menu"
        onSelectionChange={handleAvatarSelection}
        renderButton={({ isOpen, setOpen }) => (
          <Button
            className={clsx("top-nav-avatar-root", isOpen && "focused")}
            variant="free"
            onClick={() => setOpen(true)}
          >
            <img
              className="border-radius-50 mr-2"
              src={user.avatarSrc}
              height={40}
              width={40}
              alt="profile picture"
            />
            <div className="flex column align-start">
              <p className="text-btn-sm color-foreground mb-1">{user.name}</p>
              <p className="text-desc color-grey">{user.activeOrganization?.name}</p>
            </div>
          </Button>
        )}
      >
        {(forceReadAll || user.invitedOrganizations.length > 0) && (
          <>
            <DropdownItem href="/invitations" value="invites">
              View Invitations
            </DropdownItem>
            <DropdownSeperator />
          </>
        )}
        <DropdownItem value="logout">Logout</DropdownItem>
        {user.adminUrl && (
          <DropdownItem href={user.adminUrl} value="admin" target="_blank">
            WebhookDB Admin <FontAwesomeIcon icon={faArrowRight} />
          </DropdownItem>
        )}
      </Dropdown>
    </div>
  );
}

function NavTextLink({ to, children }) {
  return (
    <NavLink to={to} className={clsx("top-nav-textlink", "subtitle")}>
      {children}
    </NavLink>
  );
}

function NavIconButton({ className, icon, onClick }) {
  return (
    <div className="top-nav-iconlink-root">
      <Button
        className={clsx("top-nav-iconlink", className)}
        variant="free"
        onClick={onClick}
      >
        <FontAwesomeIcon icon={icon} />
      </Button>
    </div>
  );
}

function NavIconLink({ to, icon, className }) {
  return (
    <NavLink to={to} className={clsx("top-nav-iconlink", className)}>
      <FontAwesomeIcon icon={icon} />
    </NavLink>
  );
}

function NavLink({ to, className, children }) {
  const location = useLocation();
  const isAtHref = location.pathname.startsWith(to);
  function handleClick(e) {
    if (isAtHref) {
      e.preventDefault();
    }
  }
  return (
    <RelLink
      href={to}
      className={clsx(className, isAtHref && "active")}
      onClick={handleClick}
    >
      {children}
    </RelLink>
  );
}
