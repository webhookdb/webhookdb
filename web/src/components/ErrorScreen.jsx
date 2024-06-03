import useMountEffect from "../state/useMountEffect.jsx";
import isUndefined from "lodash/isUndefined";
import get from "lodash/get";
import { useNavigate } from "react-router-dom";
import {Button, Stack} from "@mantine/core";
import ButtonLink from "./ButtonLink";

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
    <Stack>
      <h2>Whoops!</h2>
      <p>
        Sorry, something went wrong. You can reload the page or start over.
      </p>
      <ButtonLink href="/dashboard">
        Go to Dashboard
      </ButtonLink>
    </Stack>
  );
}
