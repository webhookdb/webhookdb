import {
  faExclamationTriangle,
  faInfoCircle,
  faQuestionCircle,
  faThumbsUp,
} from "../icons.jsx";

/**
 * @param {ActionVariant} variant
 * @return {Icon}
 */
export function variantIcon(variant) {
  return variantIcons[variant] || null;
}

const variantIcons = {
  success: faThumbsUp,
  info: faInfoCircle,
  warning: faQuestionCircle,
  error: faExclamationTriangle,
};
