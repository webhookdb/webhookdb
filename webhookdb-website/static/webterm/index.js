(function () {
  const BREAK = "__whdb_break";
  const isWindows = (
    navigator?.userAgentData?.platform ||
    navigator?.platform ||
    "unknown"
  ).includes("Win");
  let prompt = ">";
  const registry = new window.Map();
  const env = new window.Map();
  if (window.location.hostname === "localhost") {
    env.set("WEBHOOKDB_API_HOST", "http://localhost:18001");
    env.set("DEBUG", "true");
  }
  env.set("WEBHOOKDB_WEBSITE_HOST", window.location.origin);
  const historyReversedStack = [];
  let historyIdx = null;
  let historyCommandCache = null;
  let currentBlock;
  let currentInput;

  function isBreak(e) {
    if (e.key === "Break") {
      return true;
    }
    if (e.ctrlKey && e.key === "d") {
      // We'll let this exit even on windows.
      return true;
    }
    if (isWindows) {
      return;
    }
    return e.ctrlKey && e.key === "c";
  }

  function getCommandInput() {
    return document.getElementById("input_source");
  }
  function getInlineInput() {
    return document.getElementById("inline-input");
  }
  currentInput = getCommandInput();

  function removePrompt() {
    document.getElementById("input_title").innerText = "";
    getCommandInput().classList.add("nocaret");
  }

  function restorePrompt(options) {
    const { skipFocus } = options || {};
    document.getElementById("input_title").innerText = prompt;
    const input = getCommandInput();
    input.classList.remove("nocaret");
    if (!skipFocus) {
      input.focus();
    }
  }

  function newBlock() {
    const wrapper = document.getElementById("wrapper");
    currentBlock = document.createElement("div");
    currentBlock.classList.add("log");
    wrapper.appendChild(currentBlock);
  }

  function blockLog() {
    blockLogWithClass(Array.from(arguments), null);
  }

  function blockLogWithClass(lines, className) {
    const clsPart = className ? ` class="${className}"` : "";
    let message = lines.join("<br />");
    if (!message) {
      message = "<br />";
    }
    currentBlock.innerHTML += `<p${clsPart}>${message}</p>`;
  }

  function log() {
    const message = Array.from(arguments).join("<br />");
    const wrapper = document.getElementById("wrapper");
    wrapper.innerHTML += "<div class='log'><p>" + message + "</p></div>";
  }

  /**
   * On every click, we want to try to focus.
   * However we only re-focus if we click empty space, or if there is nothing selected.
   * There is a little weird behavior where if we select text, then release,
   * we have to click again to focus. But oh well.
   */
  document.getElementById("screen").onmouseup = function (e) {
    const shouldFocus =
      e.target.id === "screen" || !document.getSelection()?.toString();
    if (shouldFocus) {
      currentInput.focus();
    }
  };
  document.onkeyup = function (e) {
    // If we keypress outside of the input, we want to focus it,
    // and potentially append its value to what's there.
    // This will fire on any keypress inside the iframe, not outside,
    // so won't catch errant keypresses.
    if (e.target?.tagName?.toUpperCase() === "INPUT") {
      return;
    }
    currentInput.focus();
    // Assume any key that is more than a single char is a modifier key.
    // Only append the key value if it's not a modifier key.
    if (e.key.length === 1) {
      currentInput.value += e.key;
    }
  };

  getCommandInput().addEventListener("keyup", inputKeyUp);

  function registerCmd(cmd_name, func) {
    registry.set(cmd_name.toString().toLowerCase(), func);
  }

  function inputKeyUp(e) {
    e.preventDefault();
    if (e.keyCode === 38) {
      handleUpArrow();
    } else if (e.keyCode === 40) {
      handleDownArrow();
    } else if (e.keyCode === 13) {
      handleEnter();
    } else if (isBreak(e)) {
      handleBreak();
    }
  }

  function handleUpArrow() {
    if (historyReversedStack.length === 0) {
      // No history, nothing to do.
      return;
    }
    const input = getCommandInput();
    if (historyIdx === null) {
      // This is the first time we are hitting up, so use the previous command.
      // Store this value in the 'pending' cache so we can restore it on 'down'.
      historyCommandCache = input.value;
      input.value = historyReversedStack[0];
      historyIdx = 0;
      return;
    }
    if (historyIdx === historyReversedStack.length - 1) {
      // At end of stack, noop.
      return;
    }
    historyIdx += 1;
    input.value = historyReversedStack[historyIdx];
  }

  function handleDownArrow() {
    if (historyReversedStack.length === 0) {
      // No history, nothing to do.
      return;
    }
    if (historyIdx === null) {
      // We haven't yet hit up arrow, so noop.
      return;
    }
    if (historyIdx === 0) {
      // We are leaving our history. Set the index to null,
      // and restore any cached command from the first 'up'.
      historyIdx = null;
      getCommandInput().value = historyCommandCache;
      return;
    }
    // Use the history at the new index.
    historyIdx -= 1;
    getCommandInput().value = historyReversedStack[historyIdx];
  }

  function handleBreak() {
    const shellStr = getCommandInput().value;
    getCommandInput().value = "";
    newBlock();
    blockLogWithClass([prompt + " " + shellStr], "command");
  }

  function handleEnter() {
    const shellStr = getCommandInput().value;
    getCommandInput().value = "";

    newBlock();

    if (!shellStr) {
      blockLogWithClass([prompt], "command");
      return;
    }
    blockLogWithClass([prompt + " " + shellStr], "command");

    historyIdx = null;
    historyReversedStack.unshift(shellStr);

    const args = window.shellQuote.parse(shellStr);
    const command = registry.get(args[0].toLowerCase());
    if (!command) {
      blockLog(
        `Sorry, only the following commands are supported: ${Array.from(
          registry.keys()
        ).join(", ")}`
      );
      return;
    }

    const isSimple = args.every((i) => typeof i === "string");
    if (!isSimple) {
      blockLog(
        "Sorry, only simple commands are supported. No env vars, pipes, redirects, etc."
      );
      return;
    }

    command(args);
  }

  registerCmd("help", function () {
    blockLog(
      `The following commands are available: ${Array.from(registry.keys()).join(", ")}`
    );
    blockLog("Run 'webhookdb help' for more info.");
  });

  registerCmd("export", function (args) {
    if (args.length !== 2) {
      blockLog("usage: export KEY=VALUE");
      return;
    }
    const str = args[1];
    const key = str.slice(0, str.indexOf("="));
    const value = str.slice(str.indexOf("=") + 1);
    env.set(key, value);
  });
  registerCmd("env", function () {
    const keys = Array.from(env.keys());
    keys.sort();
    const lines = keys.map((k) => `${k}=${env.get(k)}`);
    blockLog.apply(null, lines);
  });

  async function whcmd(args) {
    const cliArgs = ["webhookdb"].concat(args.slice(1));
    let resultStr;
    removePrompt();
    try {
      resultStr = await window.webhookdbRun(env, cliArgs);
    } catch (e) {
      console.error(e);
      blockLog(
        "Sorry, webhookdb could not be loaded. Check the console for more details.",
        "You can download the CLI from https://webhookdb.com/download.",
        `The error was: ${e}`
      );
      restorePrompt();
      return;
    }
    if (!resultStr) {
      blockLog("WASM did not return a string. Code broke.");
      restorePrompt();
      return;
    }
    try {
      const { stdout, stderr } = JSON.parse(resultStr);
      stdout && blockLog(stdout);
      stderr && blockLogWithClass([stderr], "error");
    } catch (e) {
      console.error(e);
      blockLogWithClass(
        [`Error processing WASM result: ${e}`, "From WASM: " + resultStr],
        "error"
      );
      restorePrompt();
      return;
    }
    restorePrompt();
  }

  registerCmd("wh", whcmd);
  registerCmd("webhookdb", whcmd);
  /**
   * Called from Go. Print feedback to terminal.
   */
  window.wasmFeedback = function (text) {
    blockLog(text);
  };
  /**
   * Can be called form anywhere. Just prints some text to terminal.
   */
  window.wasmLog = function (text) {
    log(text);
  };
  /**
   * Called from Go. Create a new element prompting for inline input.
   * On submit, invoke the given callback, and replace the input
   * with plain text.
   */
  window.wasmPrompt = async function (text, hidden, callback) {
    currentBlock.innerHTML += `<div class="inline-input-root">
      <p>${text}</p>
      <input id="inline-input" class="inline-input command-input"
        type="${hidden ? "new-password" : "text"}"
        autocomplete="off" autocorrect="off" autocapitalize="off" spellcheck="false" autofocus="on">
    </div>`;
    currentInput = getInlineInput();
    currentInput.focus();
    function swapPrompt(isBreak) {
      const inputEl = getInlineInput();
      const value = inputEl.value;
      const parent = inputEl.parentElement;
      inputEl.remove();
      currentInput = getCommandInput();
      const valueElement = document.createElement("p");
      valueElement.classList.add("inline-input");
      valueElement.innerText = hidden ? "***" : value;
      parent.appendChild(valueElement);
      callback(isBreak ? BREAK : value);
    }
    currentInput.addEventListener("keyup", (e) => {
      if (isBreak(e)) {
        swapPrompt(true);
      } else if (e.key === "Enter") {
        swapPrompt(false);
      }
    });
  };

  log(
    "Welcome to WebhookDB interactive terminal! You can run any WebhookDB CLI command.",
    "The CLI is available as 'webhookdb' and 'wh'.",
    "Run 'webhookdb auth login' to get started, or 'webhookdb help' to see what's available."
  );

  window.webhookdbOnAuthed = function (j) {
    const { email, org_key } = JSON.parse(j);
    if (email) {
      prompt = `${email}/${org_key} >`;
    } else {
      prompt = ">";
    }
    const inputFocused = document.activeElement === getCommandInput();
    removePrompt();
    restorePrompt({ skipFocus: !inputFocused });
  };

  if (new URL(window.location.href).searchParams.get("autofocus")) {
    getCommandInput().focus();
  }

  // Update the auth display when we start up.
  window.webhookdbRun(env, ["webhookdb", "debug", "update-auth-display"]);
})();
