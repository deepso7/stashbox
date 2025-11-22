import { CDPHooksProvider } from "@coinbase/cdp-hooks";
import { CDPReactProvider } from "@coinbase/cdp-react";
import { TanStackDevtools } from "@tanstack/react-devtools";
import type { QueryClient } from "@tanstack/react-query";
import {
  createRootRouteWithContext,
  HeadContent,
  Scripts,
} from "@tanstack/react-router";
import { TanStackRouterDevtoolsPanel } from "@tanstack/react-router-devtools";
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
        <div className="md:w-1/3">
          <Providers>{children}</Providers>
        </div>
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

const Providers = ({ children }: { children: React.ReactNode }) => (
  <CDPReactProvider
    config={{
      projectId: "4d35e6de-5016-495b-befb-719eee9d0afa",
      ethereum: {
        // if you want to create an EVM account on login
        createOnLogin: "eoa", // or "smart" for smart accounts
      },
      appName: "Stashbox",
      appLogoUrl: "https://stashbox.deepso.dev/stashbox.png",
      authMethods: ["email", "oauth:google"],
    }}
    theme={{
      // Backgrounds
      "colors-bg-default": "var(--color-background)",
      "colors-bg-alternate": "var(--color-card)",
      "colors-bg-primary": "var(--color-primary)",
      "colors-bg-secondary": "var(--color-secondary)",

      // Text
      "colors-fg-default": "var(--color-foreground)",
      "colors-fg-muted": "var(--color-muted-foreground)",
      "colors-fg-primary": "var(--color-primary)",
      "colors-fg-onPrimary": "var(--color-primary-foreground)",

      // Borders
      "colors-line-default": "var(--color-border)",
      "colors-line-heavy": "var(--color-accent)",
      "colors-line-primary": "var(--color-ring)",

      // Typography
      "font-family-sans": "var(--font-sans)",
      "font-size-base": "16px",
    }}
  >
    <CDPHooksProvider
      config={{
        projectId: "4d35e6de-5016-495b-befb-719eee9d0afa",
        ethereum: {
          // if you want to create an EVM account on login
          createOnLogin: "eoa", // or "smart" for smart accounts
        },
      }}
    >
      {children}
    </CDPHooksProvider>
  </CDPReactProvider>
);
