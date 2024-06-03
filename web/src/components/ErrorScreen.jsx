import get from "lodash/get";
import isUndefined from "lodash/isUndefined";
import { useNavigate } from "react-router-dom";

import useMountEffect from "../state/useMountEffect.jsx";
import Button from "./uikit/Button.jsx";
import Stack from "./uikit/Stack.jsx";

/**
 * Show this component when an unhandled error has occurred.
 *
 * @param error The error being shown.
 * @param redirect403 If the error is a 403 from the API, and redirect403 is true,
 *   automatically send the user to /dashboard.
 *   This happens when someone is looking at a resource
 *   and switches orgs.
 */
export default function ErrorScreen({ error, redirect403 }) {
  redirect403 = isUndefined(redirect403) ? true : redirect403;
  const navigate = useNavigate();

  useMountEffect(() => {
    if (redirect403 && get(error, "response.status")) {
      navigate("/dashboard");
    }
  });

  return (
    <Stack className="px-4 pt-5 w-100 bg-background align-center" gap={5}>
      <h2>Whoops!</h2>
      <p className="text text-center color-red" style={{ maxWidth: 300 }}>
        Sorry, something went wrong. You can reload the page or start over.
      </p>
      <Button href="/dashboard" size="lg">
        Go to Dashboard
      </Button>
    </Stack>
  );
}
