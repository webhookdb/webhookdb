import react from "@vitejs/plugin-react-swc";
import { defineConfig } from "vite";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  define: {
    "process.env": process.env,
  },
  publicDir: "src/static",
  server: {
    host: true,
    port: 18031,
    hot: true,
  },
  base: "/app/",
});
