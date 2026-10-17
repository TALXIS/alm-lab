import { makeStyles, tokens } from "@fluentui/react-components";

export const useStyles = makeStyles({
  content: {
    display: "flex",
    flexDirection: "column",
    gap: tokens.spacingVerticalL,
  },
  video: {
    width: "100%",
    aspectRatio: "16 / 9",
    backgroundColor: "black",
    borderRadius: tokens.borderRadiusMedium,
    border: `${tokens.strokeWidthThin} solid ${tokens.colorNeutralStroke2}`,
  },
  eanRow: {
    display: "flex",
    gap: tokens.spacingHorizontalS,
  },
  eanInput: {
    flex: 1,
  },
  product: {
    flexDirection: "row",
    alignItems: "center",
    gap: tokens.spacingHorizontalL,
  },
  image: {
    width: "64px",
    height: "64px",
    flexShrink: 0,
    objectFit: "contain",
    borderRadius: tokens.borderRadiusSmall,
  },
  imagePlaceholder: {
    width: "64px",
    height: "64px",
    flexShrink: 0,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    borderRadius: tokens.borderRadiusSmall,
    backgroundColor: tokens.colorNeutralBackground3,
  },
  productText: {
    display: "flex",
    flexDirection: "column",
  },
  muted: {
    color: tokens.colorNeutralForeground3,
  },
});
