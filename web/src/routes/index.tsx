import { useIsInitialized, useIsSignedIn } from "@coinbase/cdp-hooks";
import { AuthButton } from "@coinbase/cdp-react";
import { createFileRoute, useRouter } from "@tanstack/react-router";
import { Image } from "@unpic/react";
import { useEffect } from "react";
import { Spinner } from "../components/ui/spinner";

export const Route = createFileRoute("/")({
  component: App,
});

function App() {
  const { isInitialized } = useIsInitialized();
  const { isSignedIn } = useIsSignedIn();
  const router = useRouter();

  useEffect(() => {
    console.log({ isSignedIn });

    if (isSignedIn) {
      router.navigate({
        to: "/comps",
      });
    }
  }, [isSignedIn, router]);

  if (!isInitialized) {
    return (
      <div className="flex min-h-screen w-full items-center justify-center p-4">
        <Spinner />
      </div>
    );
  }

  return (
    <div className="flex min-h-screen w-full flex-col items-center justify-between p-4">
      <div className="vertical centre gap-16">
        <h1 className="horizontal center flex gap-2 font-bold text-2xl">
          <Image
            alt="Stashbox"
            height={30}
            layout="constrained"
            src="/stashbox.png"
            width={30}
          />
          Stashbox
        </h1>
        <h2 className="text-lg">Stash Some Cash 💰</h2>
      </div>
      <Image
        alt="Stashbox"
        className="animate-bounce"
        height={200}
        layout="constrained"
        src="/stashbox.png"
        width={200}
      />

      <AuthButton />
    </div>
  );
}
