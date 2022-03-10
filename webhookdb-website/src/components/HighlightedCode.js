import React from "react";

export default function HighlightedCode({ language, code, children }) {
  return (
    <deckgo-highlight-code language={language} terminal={terminal} theme={theme}>
      {children || <code slot="code">{code}</code>}
    </deckgo-highlight-code>
  );
}

// Also om gatsby-config
const terminal = "carbon";
const theme = "blackboard";
