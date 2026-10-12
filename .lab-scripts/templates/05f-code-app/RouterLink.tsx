import type { ReactNode } from "react"
import { Link } from "@fluentui/react-components"
import { useHref, useLinkClickHandler } from "react-router-dom"

type RouterLinkProps = {
  to: string
  className?: string
  children: ReactNode
}

// A Fluent-styled <a> that navigates client-side through react-router: useHref keeps the
// Power Apps basename in the real href, the click handler swaps the full page load for a
// router navigation (while still honouring ctrl/cmd-click to open a new tab).
export function RouterLink({ to, className, children }: RouterLinkProps) {
  const href = useHref(to)
  const handleClick = useLinkClickHandler<HTMLAnchorElement>(to)

  return (
    <Link href={href} className={className} onClick={handleClick}>
      {children}
    </Link>
  )
}
