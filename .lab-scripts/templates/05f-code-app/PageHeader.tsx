import type { ReactElement, ReactNode } from "react"
import { Body1, Title2 } from "@fluentui/react-components"
import { useStyles } from "./PageHeader.styles"

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
