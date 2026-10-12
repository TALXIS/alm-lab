import { useMemo } from "react"
import { Toast, ToastTitle, useToastController } from "@fluentui/react-components"

export const TOASTER_ID = "app-toaster"

// Fluent dispatches toasts through a hook rather than a global function, so each component
// grabs one stable { success, error } pair and calls it exactly like a plain toast() would.
// The Toaster also mirrors every message into a screen-reader live region, so UI tests locate
// the visible toast by its test id rather than by text alone (the text exists twice).
export function useNotify() {
  const { dispatchToast } = useToastController(TOASTER_ID)

  return useMemo(() => {
    const show = (intent: "success" | "error", message: string) =>
      dispatchToast(
        <Toast>
          <ToastTitle data-testid="toast-message">{message}</ToastTitle>
        </Toast>,
        { intent, timeout: 3000 }
      )
    return {
      success: (message: string) => show("success", message),
      error: (message: string) => show("error", message),
    }
  }, [dispatchToast])
}
