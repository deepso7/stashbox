import { createServerFn } from "@tanstack/react-start";
import { getCookie } from "@tanstack/react-start/server";

export const checkLoginHint = createServerFn({
  method: "GET",
}).handler(() => {
  const authCookie = getCookie("privy-token");

  if (authCookie) {
    return true;
  }

  return false;
});
