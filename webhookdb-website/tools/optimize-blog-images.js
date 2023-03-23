/**
 * @module
 * Resize images from temp/blog-images into static/content/blog.
 */

const sharp = require("sharp");
const fs = require("fs");
const path = require("path");

const inputFolder = `${process.env.PWD}/temp/blog-images`;
const outputFolder = `${process.env.PWD}/static/content/blog`;

const main = async () => {
  const paths = fs.readdirSync(inputFolder);
  const promises = [];
  paths.forEach((f) => {
    const p = path.join(inputFolder, f);
    const basename = path.basename(p);
    const [extless] = basename.split(".");
    const width = 1280;
    const thumbWidth = 384;
    let height = 1024;
    let thumbHeight = thumbWidth;
    if (extless.endsWith("-nocrop")) {
      height = undefined;
      thumbHeight = undefined;
    }
    const newBasename = `${extless}.jpg`;
    const headerOutput = path.join(outputFolder, newBasename);
    const thumbnailOutput = path.join(outputFolder, "thumbnail", newBasename);
    promises.push(
      sharp(p)
        .resize({
          width,
          height,
          fit: sharp.fit.cover,
          position: sharp.strategy.attention,
        })
        .jpeg({ quality: 80 })
        .toFile(headerOutput)
    );
    promises.push(
      sharp(p)
        .resize({
          width: thumbWidth,
          height: thumbHeight,
          fit: sharp.fit.cover,
          position: sharp.strategy.attention,
        })
        .jpeg({ quality: 75 })
        .toFile(thumbnailOutput)
    );
  });
  await Promise.all(promises);
};
main();
