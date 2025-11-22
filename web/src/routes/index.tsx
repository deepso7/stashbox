import { AuthButton } from "@coinbase/cdp-react";
import { createFileRoute } from "@tanstack/react-router";
import { createServerFn } from "@tanstack/react-start";
import { getCookies } from "@tanstack/react-start/server";
import { Image } from "@unpic/react";

const getUser = createServerFn({ method: "GET" }).handler(() => {
  const cookies = getCookies();

  console.log({ cookies });

  return null;
});

export const Route = createFileRoute("/")({
  component: App,
  loader: async () => {
    await getUser();

    return null;
  },
});

function App() {
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
