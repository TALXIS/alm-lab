import { makeStyles, tokens } from "@fluentui/react-components";

export const useStyles = makeStyles({
  image: {
    width: "32px",
    height: "32px",
    objectFit: "contain",
    borderRadius: tokens.borderRadiusSmall,
  },
});
