import { usePrivy } from "@privy-io/react-auth";
import { createFileRoute, redirect } from "@tanstack/react-router";
import { Button } from "../components/ui/button";
import { checkLoginHint } from "../lib/auth";

export const Route = createFileRoute("/home")({
  beforeLoad: async () => {
    const hint = await checkLoginHint();

    if (!hint) {
      throw redirect({ to: "/" });
    }
  },
  component: RouteComponent,
});

function RouteComponent() {
  const { logout } = usePrivy();

  return (
    <div>
      <span>Hello "/home"!</span>
      <Button onClick={logout}>Signout</Button>
    </div>
  );
}
