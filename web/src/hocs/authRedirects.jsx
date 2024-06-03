import Redirect from "../components/Redirect";
import useUser from "../state/useUser";

export function redirectUnless(to, test) {
  return (Wrapped) => {
    return function RedirectUnless(props) {
      const userCtx = useUser();
      if (userCtx.userLoading) {
        return null;
      }
      return test(userCtx) ? <Wrapped {...props} /> : <Redirect to={to} />;
    };
  };
}

export const redirectIfAuthed = redirectUnless(
  "/dashboard",
  ({ userUnauthed }) => userUnauthed,
);

export const redirectIfUnauthed = redirectUnless("/", ({ userAuthed }) => userAuthed);
