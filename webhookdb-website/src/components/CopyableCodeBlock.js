import { FaClipboardCheck, FaRegClipboard } from "react-icons/fa";

import HighlightedCode from "./HighlightedCode";
import React from "react";
import clsx from "clsx";

export default function CopyableCodeBlock({ code, language, className }) {
  const [checked, setChecked] = React.useState(false);
  function onClick() {
    navigator.clipboard.writeText(code);
    setChecked(true);
    window.setTimeout(() => setChecked(false), 3000);
  }
  const Icon = checked ? FaClipboardCheck : FaRegClipboard;
  return (
    <div className={clsx(className, "position-relative")}>
      <Icon
        size="1.5em"
        className={clsx(
          "mr-4 d-block float-right cursor-pointer mt-4 position-absolute",
          checked ? "text-success" : "text-light"
        )}
        style={{ top: 0, right: 0 }}
        title="Copy to clipboard"
        onClick={onClick}
      />
      <HighlightedCode language={language} code={code} />
    </div>
  );
}
