const fs = require("fs");

const nodeVersion = fs
  .readFileSync(".tool-versions")
  .toString()
  .split("\n")
  .find((line) => line.includes("nodejs "))
  .split(" ")[1]
  .trim(); // 1.2.3
const majorMinor = nodeVersion.slice(0, nodeVersion.lastIndexOf(".")); // 1.2
const desired = `v${majorMinor}`; // v1.2
const running = process.version; // v1.2.4

if (!running.startsWith(desired)) {
  console.error(
    `You are running Node ${running} but version ${desired} is expected. Use asdf, nvm or something to install and activate ${desired}.`
  );
  process.exit(1);
}
