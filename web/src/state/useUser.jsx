import React from "react";
import { UserContext } from "./UserProvider";

/**
 * @returns {{user: User, setUser: function, userLoading: boolean, userError: object, userAuthed: boolean, userUnauthed: boolean}}
 */
export default function useUser() {
  return React.useContext(UserContext);
}

/**
 * @typedef Organization
 * @property {number} id
 * @property {string} name
 */

/**
 * @typedef User
 * @property {{id: number, email: string, activeOrganization: Organization}}
 */
