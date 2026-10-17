import { makeStyles, tokens } from "@fluentui/react-components"

export const useStyles = makeStyles({
  root: {
    minHeight: "100dvh",
    display: "flex",
    flexDirection: "column",
  },
  header: {
    borderBottom: `${tokens.strokeWidthThin} solid ${tokens.colorNeutralStroke2}`,
  },
  headerInner: {
    boxSizing: "border-box",
    maxWidth: "1280px",
    height: "56px",
    margin: "0 auto",
    padding: `0 ${tokens.spacingHorizontalXXL}`,
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
  },
  main: {
    flex: 1,
    boxSizing: "border-box",
    width: "100%",
    maxWidth: "1280px",
    margin: "0 auto",
  },
})
