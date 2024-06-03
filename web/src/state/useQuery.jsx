import { useLocation } from "react-router-dom";
import { useMemo } from "react";

/**
 * @returns {URLSearchParams}
 */
export default function useQuery() {
  const { search } = useLocation();
  return useMemo(() => new URLSearchParams(search), [search]);
}
