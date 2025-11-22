import { usePrivy } from "@privy-io/react-auth";
import { createFileRoute, redirect, useRouter } from "@tanstack/react-router";
import { Image } from "@unpic/react";
import { LogOut } from "lucide-react";
import { Badge } from "../components/ui/badge";
import { Button } from "../components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "../components/ui/card";
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
  const { user, logout } = usePrivy();
  const router = useRouter();

  const username =
    user?.google?.name?.split(" ")[0] ??
    user?.email?.address.split("@")[0] ??
    "Anon";

  return (
    <div className="flex min-h-screen w-full flex-col gap-4 p-4">
      <div className="flex w-full items-center justify-between">
        <Image
          alt="Stashbox"
          height={60}
          layout="constrained"
          src="/stashbox.png"
          width={60}
        />

        <div className="flex items-center gap-2">
          <Badge className="bg-amber-500 p-2">
            <span className="animate-bounce">🔥</span>5
          </Badge>

          <Button
            onClick={async () => {
              await logout();
              router.navigate({ to: "/" });
            }}
            size="icon"
          >
            <LogOut />
          </Button>
        </div>
      </div>

      <div className="mt-16">
        <h1 className="font-medium text-4xl">Hey {username},</h1>
        <p className="text-sm">Lets grow your stash!</p>
      </div>

      <Card className="hover:-translate-y-1 w-full rounded-4xl bg-primary/50 shadow-2xl transition delay-100 duration-150 ease-in-out hover:scale-105">
        <CardHeader>
          <CardTitle>Savings</CardTitle>
          <CardDescription>Total Saving till date</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex items-center gap-4">
            <h3 className="font-bold text-4xl">$1200</h3>
            <span className="rounded-4xl bg-secondary p-1.5">+$230</span>
          </div>
          <div>
            <p>5 Jars Active</p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
