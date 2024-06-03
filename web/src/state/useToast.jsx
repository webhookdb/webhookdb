import isUndefined from "lodash/isUndefined";
import React from "react";
import toast from "react-hot-toast";

import Toast from "../components/uikit/Toast.jsx";
import { ifEqElse } from "../modules/fp.js";

export default function useToast() {
  const showToast = React.useCallback(
    ({ message, title, duration, variant, icon, dismissable }) => {
      dismissable = isUndefined(dismissable) ? true : dismissable;
      const tid = toast.custom(
        <Toast
          variant={variant}
          title={title}
          message={message}
          icon={icon}
          onDismiss={dismissable && (() => toast.remove(tid))}
        ></Toast>,
        {
          duration: ifEqElse(
            duration,
            undefined,
            variantDurations[variant] || defaultDuration,
            duration,
          ),
          position: "bottom-center",
        },
      );
    },
    [],
  );
  return { showToast };
}

const variantDurations = { success: 1500 };
const defaultDuration = 4000;
