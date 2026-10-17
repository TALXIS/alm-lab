import { makeStyles, tokens } from "@fluentui/react-components"

export const useStyles = makeStyles({
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
