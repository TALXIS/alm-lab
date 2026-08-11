import { Outlet, NavLink } from "react-router-dom"
import { Package, ArrowRightLeft, MapPin } from "lucide-react"

type LayoutProps = { showHeader?: boolean }

export default function Layout({ showHeader = true }: LayoutProps) {
  return (
    <div className="min-h-dvh flex flex-col">
      {showHeader && (
        <header className="h-14 border-b flex items-center">
          <div className="mx-auto w-full max-w-7xl px-6 flex items-center justify-between">
            <span className="font-semibold text-lg tracking-tight">Warehouse Picking</span>
            <nav className="flex items-center gap-4">
              <NavLink to="/" end
                className={({ isActive }) =>
                  `text-sm flex items-center gap-1.5 text-muted-foreground hover:text-foreground ${isActive ? "text-foreground font-medium" : ""}`
                }
              >
                <Package className="h-4 w-4" />
                Items
              </NavLink>
              <NavLink to="/transactions"
                className={({ isActive }) =>
                  `text-sm flex items-center gap-1.5 text-muted-foreground hover:text-foreground ${isActive ? "text-foreground font-medium" : ""}`
                }
              >
                <ArrowRightLeft className="h-4 w-4" />
                Transactions
              </NavLink>
              <NavLink to="/locations"
                className={({ isActive }) =>
                  `text-sm flex items-center gap-1.5 text-muted-foreground hover:text-foreground ${isActive ? "text-foreground font-medium" : ""}`
                }
              >
                <MapPin className="h-4 w-4" />
                Locations
              </NavLink>
            </nav>
          </div>
        </header>
      )}

      <main className="flex-1 flex">
        <div className="flex-1 mx-auto w-full max-w-7xl">
          <Outlet />
        </div>
      </main>
    </div>
  )
}

