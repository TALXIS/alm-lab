import { createBrowserRouter } from "react-router-dom"
import Layout from "@/pages/_layout"
import WarehouseItemsPage from "@/pages/warehouse-items"
import WarehouseItemDetailPage from "@/pages/warehouse-item-detail"
import TransactionsPage from "@/pages/transactions"
import LocationsPage from "@/pages/locations"
import NotFoundPage from "@/pages/not-found"

// IMPORTANT: Do not remove or modify the code below!
// Normalize basename when hosted in Power Apps
const BASENAME = new URL(".", location.href).pathname
if (location.pathname.endsWith("/index.html")) {
  history.replaceState(null, "", BASENAME + location.search + location.hash);
}

export const router = createBrowserRouter([
  {
    path: "/",
    element: <Layout showHeader={true} />,
    errorElement: <NotFoundPage />,
    children: [
      { index: true, element: <WarehouseItemsPage /> },
      { path: "items/:id", element: <WarehouseItemDetailPage /> },
      { path: "transactions", element: <TransactionsPage /> },
      { path: "locations", element: <LocationsPage /> },
    ],
  },
], {
  basename: BASENAME // IMPORTANT: Set basename for proper routing when hosted in Power Apps
})

