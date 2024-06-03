import reduceRight from "lodash/reduceRight";

export default function applyHocs(...funcs) {
  return reduceRight(
    funcs,
    (memo, f) => {
      return f(memo);
    },
    funcs.pop(),
  );
}
