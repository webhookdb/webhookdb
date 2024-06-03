/**
 * Pluralizes a string. Return `word + suffix` if count is 0 or greater than 1.
 * @param {number} count
 * @param {string} word
 * @param {string=} suffix
 */
export default function spluralize(count, word, suffix = "s") {
  if (count === 1) {
    return word;
  }
  return word + suffix;
}
