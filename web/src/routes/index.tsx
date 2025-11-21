import { createFileRoute } from "@tanstack/react-router";
import { Image } from "@unpic/react";
import { Button } from "../components/ui/button";

export const Route = createFileRoute("/")({ component: App });

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
      <Button
        className="hover:-translate-y-1 relative w-1/2 transition delay-100 duration-300 ease-in-out hover:scale-110"
        size="lg"
      >
        <Image
          alt="Stashbox"
          className="-translate-y-1/2 absolute top-1/2 left-8"
          height={30}
          layout="fixed"
          src="/stashbox.png"
          width={30}
        />
        Get Started
      </Button>
    </div>
  );
}
