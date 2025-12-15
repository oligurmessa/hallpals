import { NAVIGATION_ITEMS } from "./NavigationData";
import { NavigationItem } from "./NavigationItem";

export function DesktopNavigation() {
  return (
    <nav className="group/nav flex items-center gap-1">
      {NAVIGATION_ITEMS.map((item) => (
        <NavigationItem item={item} key={item.name} />
      ))}
    </nav>
  );
}
