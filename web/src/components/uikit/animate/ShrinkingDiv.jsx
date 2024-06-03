import { motion } from "framer-motion";

/**
 * Div that shrinks out.
 * @param {number} duration Exit in seconds.
 * @param children
 * @param {string} className
 * @param {object} style
 * @param {('vertical')} direction Direction to shrink (can add more as needed).
 * @param rest
 * @return {*}
 * @constructor
 */
export default function ShrinkingDiv({ duration, children, className, style, ...rest }) {
  return (
    <motion.div
      className={className}
      exit={{
        height: 0,
        scaleY: 0,
        opacity: 0,
        marginTop: 0,
        marginBottom: 0,
      }}
      transition={{ duration: duration || 0.2 }}
      style={{ ...style, originY: 0 }}
      {...rest}
    >
      {children}
    </motion.div>
  );
}
