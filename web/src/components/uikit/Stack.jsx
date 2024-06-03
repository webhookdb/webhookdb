import clsx from "clsx";
import isUndefined from "lodash/isUndefined";

/**
 * Flex div with a gap.
 *
 * direction='vertical', direction='column', col={true} and column={true} all get a flex-direction: column.
 *
 * direction='horizontal', direction='row', row={true} all get a flex-direction: row.
 *
 * Defaults to flex-direction: column since that is most popular.
 *
 * @param {('vertical'|'horizontal'|'row'|'column')} direction
 * @param {boolean=} row
 * @param {boolean=} col
 * @param {boolean=} column
 * @param {Spacing} gap
 * @param {string=} className
 * @param rest
 */
export default function Stack({ direction, row, col, column, gap, className, ...rest }) {
  gap = isUndefined(gap) ? 0 : gap;
  let cls = "column";
  if (row || direction === "horizontal" || direction === "row") {
    cls = "row";
  } else if (col || column) {
    cls = "column";
  }
  return <div className={clsx("flex", cls, `gap-${gap}`, className)} {...rest} />;
}
