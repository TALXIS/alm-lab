import type { ReactElement, ReactNode } from "react"
import { Body1, Title2, makeStyles, tokens } from "@fluentui/react-components"

const useStyles = makeStyles({
  root: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    gap: tokens.spacingHorizontalL,
    flexWrap: "wrap",
  },
  heading: {
    display: "flex",
    alignItems: "center",
    gap: tokens.spacingHorizontalM,
  },
  icon: {
    fontSize: "32px",
    color: tokens.colorBrandForeground1,
  },
  text: {
    display: "flex",
    flexDirection: "column",
  },
  subtitle: {
    color: tokens.colorNeutralForeground3,
  },
  actions: {
    display: "flex",
    gap: tokens.spacingHorizontalS,
  },
})

type PageHeaderProps = {
  icon: ReactElement
  title: string
  subtitle: string
  actions?: ReactNode
}

// Shared title row for the list pages: icon + title + subtitle on the left, actions on the right.
export function PageHeader({ icon, title, subtitle, actions }: PageHeaderProps) {
  const styles = useStyles()

  return (
    <div className={styles.root}>
      <div className={styles.heading}>
        <span className={styles.icon}>{icon}</span>
        <div className={styles.text}>
          <Title2 as="h1">{title}</Title2>
          <Body1 className={styles.subtitle}>{subtitle}</Body1>
        </div>
      </div>
      {actions && <div className={styles.actions}>{actions}</div>}
    </div>
  )
}
