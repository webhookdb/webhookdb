import { useMemo } from "react";
import { useLocation } from "react-router-dom";

/**
 * @returns {URLSearchParams}
 */
export default function useQuery() {
  const { search } = useLocation();
  return useMemo(() => new URLSearchParams(search), [search]);
}
