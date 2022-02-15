const fs = require("fs");
const path = require("path");

const buildDir = "./public";
const sourceDirs = ["./src/docs"];
const destDirs = ["docs"];

sourceDirs.forEach((sourceDir, i) => {
  const destDir = destDirs[i];
  const paths = fs.readdirSync(sourceDir);
  paths.forEach((basename) => {
    const dest = path.join(buildDir, destDir, basename);
    fs.copyFileSync(path.join(sourceDir, basename), dest);
  });
});
