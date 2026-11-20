import { Box, List, ListItem, ListItemText, Typography } from "@mui/material";
import React from "react";

import config from "../config";
import dayjs from "../modules/dayjs";

export default function StatusPage() {
  const [status, setStatus] = React.useState({});
  const [health, setHealth] = React.useState({});
  const [statusError, setStatusError] = React.useState();
  const [healthError, setHealthError] = React.useState();

  React.useEffect(() => {
    fetchAndSet("/statusz", setStatus, setStatusError);
    fetchAndSet("/healthz", setHealth, setHealthError);
  }, []);

  let rstatus = { ...status };
  if (status["released_at"]) {
    rstatus["released_ago"] = dayjs(status["released_at"]).fromNow();
  }
  return (
    <Box marginTop={3}>
      <Typography variant="h5">Health</Typography>
      <EntryList o={health} />
      {healthError && (
        <Typography gutterBottom>/healthz error, check console.</Typography>
      )}

      <Typography variant="h5">Status</Typography>
      <EntryList o={rstatus} />
      {statusError && (
        <Typography gutterBottom>/statusz error, check console.</Typography>
      )}
    </Box>
  );
}

function EntryList({ o }) {
  const entries = Object.entries(o);
  entries.sort();
  return (
    <List dense>
      {entries.map(([key, value]) => (
        <ListItem key={key}>
          <ListItemText primary={key} secondary={value} />
        </ListItem>
      ))}
    </List>
  );
}

function fetchAndSet(ep, set, setError) {
  fetch(config.apiHost + ep)
    .then((r) => {
      if (r.status >= 400) {
        throw r;
      }
      return r.json();
    })
    .then((j) => {
      set(j);
      setError(null);
    })
    .catch((e) => {
      console.error(`Calling ${ep}:`, e);
      setError(e);
      set({});
    });
}
