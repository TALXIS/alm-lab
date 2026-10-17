import { Outlet, useLocation, useNavigate } from "react-router-dom"
import { Subtitle1, Tab, TabList } from "@fluentui/react-components"
import { BoxRegular, ArrowSwapRegular, LocationRegular } from "@fluentui/react-icons"
import { useStyles } from "./_layout.styles"

// The items list is the index route and also owns the /items/:id detail pages.
function selectedTab(pathname: string) {
  if (pathname.startsWith("/transactions")) return "/transactions"
  if (pathname.startsWith("/locations")) return "/locations"
  return "/"
}

type LayoutProps = { showHeader?: boolean }

export default function Layout({ showHeader = true }: LayoutProps) {
  const styles = useStyles()
  const { pathname } = useLocation()
  const navigate = useNavigate()

  return (
    <div className={styles.root}>
      {showHeader && (
        <header className={styles.header}>
          <div className={styles.headerInner}>
            <Subtitle1>Warehouse Picking</Subtitle1>
            <TabList
              selectedValue={selectedTab(pathname)}
              onTabSelect={(_, data) => navigate(String(data.value))}
            >
              <Tab value="/" icon={<BoxRegular />}>Items</Tab>
              <Tab value="/transactions" icon={<ArrowSwapRegular />}>Transactions</Tab>
              <Tab value="/locations" icon={<LocationRegular />}>Locations</Tab>
            </TabList>
          </div>
        </header>
      )}

      <main className={styles.main}>
        <Outlet />
      </main>
    </div>
  )
}
