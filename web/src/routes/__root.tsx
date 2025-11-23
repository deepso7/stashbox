import { PrivyProvider } from "@privy-io/react-auth";
import { createConfig, WagmiProvider } from "@privy-io/wagmi";
import { TanStackDevtools } from "@tanstack/react-devtools";
import type { QueryClient } from "@tanstack/react-query";
import {
  createRootRouteWithContext,
  HeadContent,
  Scripts,
} from "@tanstack/react-router";
import { TanStackRouterDevtoolsPanel } from "@tanstack/react-router-devtools";
import { Toaster } from "sonner";
import { http } from "viem";
import { base, baseSepolia } from "wagmi/chains";
import appCss from "../styles.css?url";

export const Route = createRootRouteWithContext<{
  queryClient: QueryClient;
}>()({
  head: () => ({
    meta: [
      {
        charSet: "utf-8",
      },
      {
        name: "viewport",
        content: "width=device-width, initial-scale=1",
      },
      {
        title: "Stash Some Cash",
      },
    ],
    links: [
      {
        rel: "stylesheet",
        href: appCss,
      },
    ],
  }),

  shellComponent: RootDocument,
});

function RootDocument({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <HeadContent />
      </head>
      <body className="vertical center mx-auto">
        <div className="md:w-1/3 [body.demo-page_&]:md:w-full">
          <Providers>{children}</Providers>
        </div>
        <Toaster />
        <TanStackDevtools
          config={{
            position: "bottom-right",
          }}
          plugins={[
            {
              name: "Stashbox",
              render: <TanStackRouterDevtoolsPanel />,
            },
          ]}
        />
        <Scripts />
      </body>
    </html>
  );
}

export const config = createConfig({
  chains: [base, baseSepolia],
  transports: {
    [base.id]: http(),
    [baseSepolia.id]: http(),
  },
});

const Providers = ({ children }: { children: React.ReactNode }) => (
  <PrivyProvider
    appId="cmi8e2idd00o2li0cf9847npq"
    config={{
      defaultChain: base,
      supportedChains: [base],
      embeddedWallets: {
        ethereum: {
          createOnLogin: "all-users",
        },
      },
    }}
  >
    <WagmiProvider config={config}>{children}</WagmiProvider>
  </PrivyProvider>
);
