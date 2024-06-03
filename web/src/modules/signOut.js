import api from "../api";
import { localStorageCache } from "./localStorageHelper";
import refreshAsync from "./refreshAsync";

export default function signOut() {
  return api
    .logout()
    .then(() => localStorageCache.clear())
    .then(refreshAsync);
}
