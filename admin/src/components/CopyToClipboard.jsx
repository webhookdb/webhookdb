import Icon from "@mui/icons-material/ContentCopy";
import { IconButton } from "@mui/material";
import React from "react";
import { useNotify } from "react-admin";

export default function CopyToClipboard({ targetId }) {
  const notify = useNotify();

  const [targetEl, setTargetEl] = React.useState(null);

  React.useEffect(() => {
    const hid = window.setInterval(() => {
      const el = document.querySelector(`[data-copy-clipboard-id=${targetId}]`);
      setTargetEl(el);
      if (el) {
        window.clearInterval(hid);
      }
    }, 300);
    return () => window.clearInterval(hid);
  }, [targetId]);

  function handleClick() {
    const el = targetEl;
    if (!el) {
      notify("Failed to copy", { type: "error", autoHideDuration: 4000 });
      return;
    }
    navigator.clipboard
      .writeText(el.innerText)
      .then(() => notify("Copied to clipboard", { type: "info", autoHideDuration: 1000 }))
      .catch(() => notify("Failed to copy", { type: "error", autoHideDuration: 4000 }));
  }

  if (!targetEl) {
    return null;
  }

  return (
    <IconButton
      aria-label="copy to clipboard"
      onClick={handleClick}
      sx={{
        position: "absolute",
        top: targetEl.offsetTop,
        transform: "translateY(-50%)",
        right: 40,
      }}
    >
      <Icon />
    </IconButton>
  );
}
