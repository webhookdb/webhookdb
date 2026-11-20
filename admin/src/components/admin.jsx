import { Datagrid, List, SearchInput, Show } from "react-admin";

/**
 * @param {boolean} noSearch
 * @param filters
 * @param {import('react-admin').ListProps} props
 */
export function CList({ noSearch, filters, ...props }) {
  const postFilters = [
    noSearch ? null : <SearchInput key="search" source="q" alwaysOn autoFocus />,
    ...(filters || []),
  ].filter(Boolean);
  return (
    <List
      sort={{ field: "id", order: "DESC" }}
      perPage={50}
      filters={postFilters.length === 0 ? null : postFilters}
      {...props}
    />
  );
}

/**
 * @param {import('react-admin').ShowProps} props
 */
export function CShow(props) {
  return <Show {...props} />;
}

/**
 * @param {import('react-admin').DatagridProps} props
 */
export function CDatagrid(props) {
  return <Datagrid rowClick="show" {...props} />;
}
