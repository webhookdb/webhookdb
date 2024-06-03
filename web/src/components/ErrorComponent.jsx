import Stack from "./uikit/Stack.jsx";

/**
 * Show this when some subcomponent fails to load.
 * Can be used for a chart on a page, for example.
 */
export default function ErrorComponent(props) {
  return (
    <Stack className="p-3 bg-background align-center" {...props}>
      <p className="text text-center color-red" style={{ maxWidth: 300 }}>
        Sorry, something went wrong. You can try reloading the page.
      </p>
    </Stack>
  );
}
