(function () {
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

  function removePrompt() {
    document.getElementById("input_title").innerText = "";
    document.getElementById("input_source").classList.add("nocaret");
  }

  function restorePrompt() {
    document.getElementById("input_title").innerText = prompt;
    document.getElementById("input_source").classList.remove("nocaret");
  }

  restorePrompt();

  let currentBlock;

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

  document.getElementById("screen").onclick = function (e) {
    if (e.target.id === "screen") {
      document.getElementById("input_source").focus();
    }
  };
  document.onkeyup = function (e) {
    // If we keypress outside of the input, we want to focus it,
    // and potentially append its value to what's there.
    // This will fire on any keypress inside the iframe, not outside,
    // so won't catch errant keypresses.
    if (e.target?.id === "input_source") {
      return;
    }
    const input = document.getElementById("input_source");
    input.focus();
    // Assume any key that is more than a single char is a modifier key.
    // Only append the key value if it's not a modifier key.
    if (e.key.length === 1) {
      input.value += e.key;
    }
  };

  document.getElementById("input_source").addEventListener("keyup", inputKeyUp);

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
    }
  }

  function handleUpArrow() {
    if (historyReversedStack.length === 0) {
      // No history, nothing to do.
      return;
    }
    if (historyIdx === null) {
      // This is the first time we are hitting up, so use the previous command.
      // Store this value in the 'pending' cache so we can restore it on 'down'.
      historyCommandCache = document.getElementById("input_source").value;
      document.getElementById("input_source").value = historyReversedStack[0];
      historyIdx = 0;
      return;
    }
    if (historyIdx === historyReversedStack.length - 1) {
      // At end of stack, noop.
      return;
    }
    historyIdx += 1;
    document.getElementById("input_source").value = historyReversedStack[historyIdx];
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
      document.getElementById("input_source").value = historyCommandCache;
      return;
    }
    // Use the history at the new index.
    historyIdx -= 1;
    document.getElementById("input_source").value = historyReversedStack[historyIdx];
  }

  function handleEnter() {
    const shellStr = document.getElementById("input_source").value;
    document.getElementById("input_source").value = "";

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
  window.wasmFeedback = function (text) {
    blockLog(text);
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
    removePrompt();
    restorePrompt();
  };
  // Update the auth display when we start up.
  window.webhookdbRun(env, ["webhookdb", "debug", "update-auth-display"]);

  if (new URL(window.location.href).searchParams.get("autofocus")) {
    document.getElementById("input_source").focus();
  }
})();
