const fs = require("fs");

const nvmVersion = fs.readFileSync(".nvmrc").toString().trim();
const desired = `v${nvmVersion}`;
const running = process.version;

if (!running.startsWith(desired)) {
  console.error(
    `You are running Node ${running} but version ${desired} is expected. Use nvm or something to install ${desired}.`
  );
  process.exit(1);
}
