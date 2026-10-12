import { useSyncExternalStore } from "react"
import { FluentProvider, Toaster, webDarkTheme, webLightTheme } from "@fluentui/react-components"
import { RouterProvider } from "react-router-dom"
import { QueryProvider } from "@/providers/query-provider"
import { TOASTER_ID } from "@/hooks/use-notify"
import { router } from "@/router"

// Follow the OS light/dark preference live, the same default the starter's ThemeProvider had.
const darkQuery = window.matchMedia("(prefers-color-scheme: dark)")

function usePrefersDark() {
  return useSyncExternalStore(
    (onChange) => {
      darkQuery.addEventListener("change", onChange)
      return () => darkQuery.removeEventListener("change", onChange)
    },
    () => darkQuery.matches
  )
}

export default function App() {
  const prefersDark = usePrefersDark()

  return (
    <FluentProvider theme={prefersDark ? webDarkTheme : webLightTheme} style={{ minHeight: "100dvh" }}>
      <QueryProvider>
        <RouterProvider router={router} />
      </QueryProvider>
      <Toaster toasterId={TOASTER_ID} position="top" limit={3} />
    </FluentProvider>
  )
}
